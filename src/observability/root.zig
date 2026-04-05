//! Observability module root (stubbed for Zig 0.16 compatibility)

const std = @import("std");
const utils = @import("../utils/root.zig");

pub const EventType = enum {
    session_start,
    session_end,
    agent_iteration,
    tool_execution,
    llm_call,
    memory_snapshot,
    assertion_trigger,
};

pub const MetricsSnapshot = struct {
    timestamp: i64,
    session_id: []const u8,
    event_type: EventType,
    data: union(EventType) {
        session_start: struct { model: []const u8, max_iterations: u32 },
        session_end: struct { total_iterations: u32, total_messages: usize, exit_reason: []const u8 },
        agent_iteration: struct { iteration: u32, state: []const u8, duration_ms: i64 },
        tool_execution: struct { tool_name: []const u8, success: bool, duration_ms: i64, error_msg: ?[]const u8 },
        llm_call: struct { provider: []const u8, model: []const u8, tokens_input: usize, tokens_output: usize, duration_ms: i64, cost_usd: ?f64 },
        memory_snapshot: struct { allocated_bytes: usize, freed_bytes: usize, live_bytes: usize, allocations_count: usize },
        assertion_trigger: struct { file: []const u8, line: u32, message: []const u8 },
    },
};

pub const MetricsCollector = struct {
    allocator: std.mem.Allocator,
    session_id: []const u8,
    enabled: bool,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, session_id: []const u8) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .session_id = try allocator.dupe(u8, session_id),
            .enabled = false,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.session_id);
        self.allocator.destroy(self);
    }

    pub fn record(self: *Self, _: MetricsSnapshot) !void {
        _ = self;
    }
};

pub fn generateSessionId(allocator: std.mem.Allocator) ![]const u8 {
    const ts = utils.milliTimestamp();
    var prng = std.Random.DefaultPrng.init(@as(u64, @intCast(ts)));
    const random_value = prng.random().int(u32);
    return try std.fmt.allocPrint(allocator, "s-{d}-{x:0>8}", .{ ts, random_value });
}

pub fn estimateCost(_: []const u8, _: []const u8, _: usize, _: usize) ?f64 {
    return null;
}

test {
    _ = EventType;
    _ = MetricsSnapshot;
    _ = MetricsCollector;
}
