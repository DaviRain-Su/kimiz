//! TUI Main - Terminal User Interface Application (stubbed for Zig 0.16)

const std = @import("std");
const core = @import("../core/root.zig");
const agent = @import("../agent/root.zig");
const vaxis = @import("vaxis");

pub fn runTui(allocator: std.mem.Allocator, model: core.Model, options: agent.AgentOptions) !void {
    _ = allocator;
    _ = model;
    _ = options;
    std.log.warn("TUI mode is temporarily disabled (libvaxis/uucode Zig 0.16 compatibility pending)", .{});
}
