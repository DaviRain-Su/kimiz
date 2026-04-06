//! PluginLoader - Load and validate WASM skill plugins from the filesystem

const std = @import("std");
const zwasm = @import("zwasm");
const utils = @import("../utils/root.zig");
const wasm_skill = @import("wasm_skill.zig");
const WasmSkill = wasm_skill.WasmSkill;
const WasmSkillError = wasm_skill.WasmSkillError;

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

        const module = if (std.mem.endsWith(u8, path, ".wat"))
            try zwasm.WasmModule.loadFromWat(self.allocator, source)
        else
            try zwasm.WasmModule.load(self.allocator, source);
        errdefer module.deinit();

        // Host imports will be linked in T-129-03
        // try linkHostImports(module);

        return try WasmSkill.init(self.allocator, module);
    }
};

// ============================================================================
// Tests
// ============================================================================

const test_wat =
    \\(module
    \\  (memory (export "memory") 1)
    \\  (data (i32.const 0) "echo")
    \\  (data (i32.const 16) "echoes input")
    \\  (global (export "kimiz_skill_version") i32 (i32.const 1))
    \\  (global (export "kimiz_skill_name") i32 (i32.const 0))
    \\  (global (export "kimiz_skill_name_len") i32 (i32.const 4))
    \\  (global (export "kimiz_skill_desc") i32 (i32.const 16))
    \\  (global (export "kimiz_skill_desc_len") i32 (i32.const 12))
    \\  (func (export "kimiz_skill_execute") (param i32 i32 i32 i32) (result i32)
    \\    i32.const 0
    \\  )
    \\)
;

test "PluginLoader.loadFromFile with valid .wat skill" {
    const allocator = std.testing.allocator;
    const cwd = std.fs.cwd();

    const wat_path = ".zig-cache/tmp_test_skill.wat";
    var file = try cwd.createFile(wat_path, .{});
    try file.writeAll(test_wat);
    file.close();
    defer cwd.deleteFile(wat_path) catch {};

    var loader = PluginLoader.init(allocator);

    var skill = try loader.loadFromFile(wat_path);
    defer skill.deinit();
    defer skill.inner.deinit();

    try std.testing.expectEqualStrings("echo", skill.name);
    try std.testing.expectEqualStrings("echoes input", skill.description);
}

test "PluginLoader.loadFromFile with missing function export" {
    const allocator = std.testing.allocator;
    const cwd = std.fs.cwd();

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
    var file = try cwd.createFile(wat_path, .{});
    try file.writeAll(bad_wat);
    file.close();
    defer cwd.deleteFile(wat_path) catch {};

    var loader = PluginLoader.init(allocator);

    const result = loader.loadFromFile(wat_path);
    try std.testing.expectError(WasmSkillError.MissingExport, result);
}

test "PluginLoader.loadFromFile with invalid binary" {
    const allocator = std.testing.allocator;
    const cwd = std.fs.cwd();

    const wasm_path = ".zig-cache/tmp_invalid.wasm";
    var file = try cwd.createFile(wasm_path, .{});
    try file.writeAll("not wasm");
    file.close();
    defer cwd.deleteFile(wasm_path) catch {};

    var loader = PluginLoader.init(allocator);

    const result = loader.loadFromFile(wasm_path);
    try std.testing.expectError(error.InvalidWasm, result);
}
