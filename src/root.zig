//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

// Core module - types, session, workspace
pub const core = @import("core/root.zig");

// Utils module - utility functions and compatibility layers
pub const utils = @import("utils/root.zig");

// Workspace module - workspace context and file management
pub const workspace = @import("workspace/root.zig");

// Agent module - provides tool definitions and execution capabilities
pub const agent = @import("agent/root.zig");

// Skills module - Skill-Centric Architecture
pub const skills = @import("skills/root.zig");

// Harness module - Harness Engineering Platform
pub const harness = @import("harness/root.zig");

// Extension module - WASM-based extension system
pub const extension = @import("extension/root.zig");

// Memory module - memory management and recall
pub const memory = @import("memory/root.zig");

// Learning module - adaptive learning engine
pub const learning = @import("learning/root.zig");

// Config module - configuration management
pub const config = @import("config.zig");

pub fn bufferedPrint() !void {
    // Stdout is for the actual output of your application
    var stdout_buffer: [1024]u8 = undefined;
    var io_mgr = try std.Io.init(std.heap.page_allocator, .{});
    defer io_mgr.deinit();
    var stdout_writer = std.Io.File.stdout().writer(&io_mgr.interface, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try stdout.flush(); // Don't forget to flush!
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}
