//! PluginLoader - Load and validate WASM skill plugins from the filesystem

const std = @import("std");
const zwasm = @import("zwasm");
const utils = @import("../utils/root.zig");
const wasm_skill = @import("wasm_skill.zig");
const WasmSkill = wasm_skill.WasmSkill;
const WasmSkillError = wasm_skill.WasmSkillError;

/// Host context passed to WASM skill imports.
pub const HostContext = struct {
    allocator: std.mem.Allocator,
    module: *zwasm.WasmModule,
    bump_offset: u32 = 1024,
};

/// Host import callbacks for WASM skills.
pub const HostImports = struct {
    /// Build an ImportEntry slice for zwasm.loadWithImports.
    pub fn getImportEntry(host_ctx: *HostContext) zwasm.ImportEntry {
        return .{
            .module = "kimiz",
            .source = .{ .host_fns = &[_]zwasm.HostFnEntry{
                .{ .name = "kimiz_log", .callback = hostLog, .context = @intFromPtr(host_ctx) },
                .{ .name = "kimiz_alloc", .callback = hostAlloc, .context = @intFromPtr(host_ctx) },
                .{ .name = "kimiz_free", .callback = hostFree, .context = @intFromPtr(host_ctx) },
            } },
        };
    }
};

fn hostLog(ctx: *anyopaque, context: usize) anyerror!void {
    const vm: *zwasm.Vm = @ptrCast(@alignCast(ctx));
    const host_ctx: *HostContext = @ptrFromInt(context);

    const len = @as(u32, @intCast(vm.popOperand()));
    const ptr = @as(u32, @intCast(vm.popOperand()));
    const level = @as(i32, @intCast(vm.popOperand()));

    const msg = try host_ctx.module.memoryRead(host_ctx.allocator, ptr, len);
    defer host_ctx.allocator.free(msg);

    switch (level) {
        0 => std.log.err("{s}", .{msg}),
        1 => std.log.warn("{s}", .{msg}),
        2 => std.log.info("{s}", .{msg}),
        3 => std.log.debug("{s}", .{msg}),
        else => std.log.info("{s}", .{msg}),
    }
}

fn hostAlloc(ctx: *anyopaque, context: usize) anyerror!void {
    const vm: *zwasm.Vm = @ptrCast(@alignCast(ctx));
    const host_ctx: *HostContext = @ptrFromInt(context);

    const size = vm.popOperand();
    if (size == 0) {
        try vm.pushOperand(0);
        return;
    }

    const size_u32: u32 = @intCast(size);
    const result_offset = host_ctx.bump_offset;

    // Probe memory boundary
    host_ctx.module.memoryWrite(result_offset + size_u32, &[_]u8{}) catch {
        try vm.pushOperand(@as(u64, @bitCast(@as(i32, -1))));
        return;
    };

    host_ctx.bump_offset += size_u32;
    try vm.pushOperand(@as(u64, result_offset));
}

fn hostFree(ctx: *anyopaque, context: usize) anyerror!void {
    const vm: *zwasm.Vm = @ptrCast(@alignCast(ctx));
    const host_ctx: *HostContext = @ptrFromInt(context);

    const size = @as(u32, @intCast(vm.popOperand()));
    const ptr = @as(u32, @intCast(vm.popOperand()));

    // Simple bump allocator free: if freeing the most recent allocation, roll back bump.
    if (ptr + size == host_ctx.bump_offset) {
        host_ctx.bump_offset -= size;
    }
}

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

        return try WasmSkill.init(self.allocator, module);
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
    const cwd = std.fs.cwd();

    const wat_path = ".zig-cache/tmp_test_skill.wat";
    var file = try cwd.createFile(wat_path, .{});
    try file.writeAll(base_wat);
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

test "host import kimiz_log is callable" {
    const allocator = std.testing.allocator;
    const cwd = std.fs.cwd();

    const wat_path = ".zig-cache/tmp_log_skill.wat";
    var file = try cwd.createFile(wat_path, .{});
    try file.writeAll(base_wat);
    file.close();
    defer cwd.deleteFile(wat_path) catch {};

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
    const cwd = std.fs.cwd();

    const wat_path = ".zig-cache/tmp_alloc_skill.wat";
    var file = try cwd.createFile(wat_path, .{});
    try file.writeAll(base_wat);
    file.close();
    defer cwd.deleteFile(wat_path) catch {};

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
