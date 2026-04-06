//! PluginLoader - Load and validate WASM skill plugins from the filesystem

const std = @import("std");
const zwasm = @import("zwasm");
const utils = @import("../utils/root.zig");
const wasm_skill = @import("wasm_skill.zig");
const WasmSkill = wasm_skill.WasmSkill;
const WasmSkillError = wasm_skill.WasmSkillError;
const HostContext = wasm_skill.HostContext;
const HostImports = wasm_skill.HostImports;

pub const PluginLoader = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    /// Load a WASM skill from a file path.
    /// Supports `.wasm` (binary) and `.wat` (text) extensions.
    /// Returns a WasmSkill that wraps the instantiated module.
    /// Caller owns both the WasmSkill and the underlying zwasm module
    /// (deinit the skill first, then deinit the module).
    pub fn loadFromFile(self: *Self, path: []const u8) !WasmSkill {
        const source = try utils.readFileAlloc(self.allocator, path, 10 * 1024 * 1024);
        defer self.allocator.free(source);

        const host_ctx = try self.allocator.create(HostContext);
        errdefer self.allocator.destroy(host_ctx);
        host_ctx.* = .{ .allocator = self.allocator, .module = undefined };

        const import_entry = HostImports.getImportEntry(host_ctx);
        const imports = &[_]zwasm.ImportEntry{import_entry};

        const module = if (std.mem.endsWith(u8, path, ".wat"))
            try zwasm.WasmModule.loadWithImports(self.allocator, source, imports)
        else
            try zwasm.WasmModule.loadWithImports(self.allocator, source, imports);
        errdefer module.deinit();

        host_ctx.module = module;

        var skill = try WasmSkill.init(self.allocator, module);
        skill.host_ctx = host_ctx;
        return skill;
    }
};

// ============================================================================
// Tests
// ============================================================================

const base_wat =
    \\(module
    \\  (import "kimiz" "kimiz_log" (func $kimiz_log (param i32 i32 i32)))
    \\  (import "kimiz" "kimiz_alloc" (func $kimiz_alloc (param i32) (result i32)))
    \\  (import "kimiz" "kimiz_free" (func $kimiz_free (param i32 i32)))
    \\  (memory (export "memory") 1)
    \\  (data (i32.const 0) "echo")
    \\  (data (i32.const 16) "echoes input")
    \\  (data (i32.const 128) "hello from wasm")
    \\  (global (export "kimiz_skill_version") i32 (i32.const 1))
    \\  (global (export "kimiz_skill_name") i32 (i32.const 0))
    \\  (global (export "kimiz_skill_name_len") i32 (i32.const 4))
    \\  (global (export "kimiz_skill_desc") i32 (i32.const 16))
    \\  (global (export "kimiz_skill_desc_len") i32 (i32.const 12))
    \\  (func (export "kimiz_skill_execute") (param i32 i32 i32 i32) (result i32)
    \\    i32.const 0
    \\  )
    \\  (func (export "test_log") (param i32 i32 i32)
    \\    local.get 0
    \\    local.get 1
    \\    local.get 2
    \\    call $kimiz_log
    \\  )
    \\  (func (export "test_alloc") (param i32) (result i32)
    \\    local.get 0
    \\    call $kimiz_alloc
    \\  )
    \\)
;

test "PluginLoader.loadFromFile with valid .wat skill" {
    const allocator = std.testing.allocator;

    const wat_path = ".zig-cache/tmp_test_skill.wat";
    try utils.writeFile(wat_path, base_wat);
    defer utils.deleteFile(wat_path) catch {};

    var loader = PluginLoader.init(allocator);

    var skill = try loader.loadFromFile(wat_path);
    defer skill.deinit();
    defer skill.inner.deinit();

    try std.testing.expectEqualStrings("echo", skill.name);
    try std.testing.expectEqualStrings("echoes input", skill.description);
}

test "PluginLoader.loadFromFile with missing function export" {
    const allocator = std.testing.allocator;

    const bad_wat =
        \\(module
        \\  (memory (export "memory") 1)
        \\  (data (i32.const 0) "echo")
        \\  (data (i32.const 16) "echoes input")
        \\  (global (export "kimiz_skill_version") i32 (i32.const 1))
        \\  (global (export "kimiz_skill_name") i32 (i32.const 0))
        \\  (global (export "kimiz_skill_name_len") i32 (i32.const 4))
        \\  (global (export "kimiz_skill_desc") i32 (i32.const 16))
        \\  (global (export "kimiz_skill_desc_len") i32 (i32.const 12))
        \\)
    ;

    const wat_path = ".zig-cache/tmp_bad_skill.wat";
    try utils.writeFile(wat_path, bad_wat);
    defer utils.deleteFile(wat_path) catch {};

    var loader = PluginLoader.init(allocator);

    const result = loader.loadFromFile(wat_path);
    try std.testing.expectError(WasmSkillError.MissingExport, result);
}

test "PluginLoader.loadFromFile with invalid binary" {
    const allocator = std.testing.allocator;

    const wasm_path = ".zig-cache/tmp_invalid.wasm";
    try utils.writeFile(wasm_path, "not wasm");
    defer utils.deleteFile(wasm_path) catch {};

    var loader = PluginLoader.init(allocator);

    const result = loader.loadFromFile(wasm_path);
    try std.testing.expectError(error.InvalidWasm, result);
}

test "host import kimiz_log is callable" {
    const allocator = std.testing.allocator;

    const wat_path = ".zig-cache/tmp_log_skill.wat";
    try utils.writeFile(wat_path, base_wat);
    defer utils.deleteFile(wat_path) catch {};

    var loader = PluginLoader.init(allocator);
    var skill = try loader.loadFromFile(wat_path);
    defer skill.deinit();
    defer skill.inner.deinit();

    // Invoke test_log(level=2, ptr=128, len=15)
    var results = [_]u64{0};
    try skill.inner.invoke("test_log", &[_]u64{ 2, 128, 15 }, &results);
}

test "host import kimiz_alloc returns bump offset" {
    const allocator = std.testing.allocator;

    const wat_path = ".zig-cache/tmp_alloc_skill.wat";
    try utils.writeFile(wat_path, base_wat);
    defer utils.deleteFile(wat_path) catch {};

    var loader = PluginLoader.init(allocator);
    var skill = try loader.loadFromFile(wat_path);
    defer skill.deinit();
    defer skill.inner.deinit();

    // Invoke test_alloc(64)
    var results = [_]u64{0};
    try skill.inner.invoke("test_alloc", &[_]u64{64}, &results);
    try std.testing.expectEqual(@as(u64, 1024), results[0]);

    // Invoke test_alloc(32)
    var results2 = [_]u64{0};
    try skill.inner.invoke("test_alloc", &[_]u64{32}, &results2);
    try std.testing.expectEqual(@as(u64, 1088), results2[0]);
}
