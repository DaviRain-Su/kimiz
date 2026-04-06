//! WASM Skill - ABI wrapper for dynamic skill plugins
//! Bridges zwasm runtime with KimiZ's Skill domain model

const std = @import("std");
const zwasm = @import("zwasm");
const ext_wasm = @import("../extension/wasm.zig");

pub const WasmSkillAbi = struct {
    pub const VERSION: u32 = 1;
};

pub const WasmSkillError = error{
    VersionMismatch,
    MissingExport,
    InvalidExportType,
    OutOfBoundsMemoryAccess,
    ExecutionFailed,
    OutputTooLarge,
};

/// A loaded WASM skill instance.
/// Wraps a zwasm module and provides JSON-in/JSON-out execution.
pub const WasmSkill = struct {
    allocator: std.mem.Allocator,
    inner: *zwasm.WasmModule,
    name: []const u8,
    description: []const u8,

    const Self = @This();

    /// Initialize from an already-loaded zwasm module.
    /// Validates ABI, reads metadata (name, description), and takes ownership
    /// of the module pointer (does NOT deinit the module on failure).
    pub fn init(allocator: std.mem.Allocator, inner: *zwasm.WasmModule) !Self {
        // 1. Verify required function export
        _ = inner.module.getExport("kimiz_skill_execute", .func) orelse
            return WasmSkillError.MissingExport;

        // 2. Verify version global
        const version_idx = inner.module.getExport("kimiz_skill_version", .global) orelse
            return WasmSkillError.MissingExport;
        const version_global = try inner.instance.getGlobal(@intCast(version_idx));
        const version = @as(i32, @intCast(version_global.value & 0xFFFFFFFF));
        if (version != WasmSkillAbi.VERSION) {
            return WasmSkillError.VersionMismatch;
        }

        // 3. Read metadata from globals
        const name = try readMetadata(allocator, inner, "kimiz_skill_name", "kimiz_skill_name_len");
        errdefer allocator.free(name);

        const description = try readMetadata(allocator, inner, "kimiz_skill_desc", "kimiz_skill_desc_len");
        errdefer allocator.free(description);

        return .{
            .allocator = allocator,
            .inner = inner,
            .name = name,
            .description = description,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.name);
        self.allocator.free(self.description);
        // Note: we do NOT deinit inner here because ownership is held externally
    }

    /// Execute the skill with JSON input and return JSON output.
    /// Caller owns the returned memory.
    /// Input/output buffers are placed in WASM linear memory using fixed safe offsets.
    pub fn execute(self: *Self, input_json: []const u8) ![]const u8 {
        const output_cap: u32 = 64 * 1024; // 64KB max output
        const input_ptr: u32 = 8192; // safe offset above metadata + bump area
        const output_ptr: u32 = input_ptr + @as(u32, @intCast(input_json.len));

        // Write input JSON into WASM linear memory
        try self.inner.memoryWrite(input_ptr, input_json);

        // Call kimiz_skill_execute(input_ptr, input_len, output_ptr, output_cap)
        var results = [_]u64{0};
        try self.inner.invoke("kimiz_skill_execute", &[_]u64{
            input_ptr,
            input_json.len,
            output_ptr,
            output_cap,
        }, &results);

        const result_len = @as(i32, @bitCast(@as(u32, @intCast(results[0]))));
        if (result_len < 0) {
            return WasmSkillError.ExecutionFailed;
        }
        const result_u32: u32 = @intCast(result_len);
        return try self.inner.memoryRead(self.allocator, output_ptr, result_u32);
    }
};

/// Read a string metadata export from WASM linear memory.
fn readMetadata(
    allocator: std.mem.Allocator,
    inner: *zwasm.WasmModule,
    ptr_export_name: []const u8,
    len_export_name: []const u8,
) ![]const u8 {
    const ptr_idx = inner.module.getExport(ptr_export_name, .global) orelse
        return WasmSkillError.MissingExport;
    const len_idx = inner.module.getExport(len_export_name, .global) orelse
        return WasmSkillError.MissingExport;

    const ptr_global = try inner.instance.getGlobal(@intCast(ptr_idx));
    const len_global = try inner.instance.getGlobal(@intCast(len_idx));

    const ptr = @as(u32, @intCast(ptr_global.value & 0xFFFFFFFF));
    const len = @as(u32, @intCast(len_global.value & 0xFFFFFFFF));

    return try inner.memoryRead(allocator, ptr, len);
}

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

test "WasmSkill init validates ABI and reads metadata" {
    const allocator = std.testing.allocator;

    var module = try zwasm.WasmModule.loadFromWat(allocator, test_wat);
    defer module.deinit();

    var skill = try WasmSkill.init(allocator, module);
    defer skill.deinit();

    try std.testing.expectEqualStrings("echo", skill.name);
    try std.testing.expectEqualStrings("echoes input", skill.description);
}

test "WasmSkill init fails on missing export" {
    const allocator = std.testing.allocator;

    const bad_wat =
        \\(module
        \\  (memory (export "memory") 1)
        \\  (global (export "kimiz_skill_version") i32 (i32.const 1))
        \\)
    ;

    var module = try zwasm.WasmModule.loadFromWat(allocator, bad_wat);
    defer module.deinit();

    const result = WasmSkill.init(allocator, module);
    try std.testing.expectError(WasmSkillError.MissingExport, result);
}

test "WasmSkill init fails on version mismatch" {
    const allocator = std.testing.allocator;

    const bad_wat =
        \\(module
        \\  (memory (export "memory") 1)
        \\  (data (i32.const 0) "echo")
        \\  (data (i32.const 16) "echoes input")
        \\  (global (export "kimiz_skill_version") i32 (i32.const 99))
        \\  (global (export "kimiz_skill_name") i32 (i32.const 0))
        \\  (global (export "kimiz_skill_name_len") i32 (i32.const 4))
        \\  (global (export "kimiz_skill_desc") i32 (i32.const 16))
        \\  (global (export "kimiz_skill_desc_len") i32 (i32.const 12))
        \\  (func (export "kimiz_skill_execute") (param i32 i32 i32 i32) (result i32)
        \\    i32.const 0
        \\  )
        \\)
    ;

    var module = try zwasm.WasmModule.loadFromWat(allocator, bad_wat);
    defer module.deinit();

    const result = WasmSkill.init(allocator, module);
    try std.testing.expectError(WasmSkillError.VersionMismatch, result);
}
