//! Observability Metrics Collector
//! Built-in metrics collection for KimiZ with JSON Lines storage
//! Based on TigerBeetle patterns: low-overhead, append-only, batch flush

const std = @import("std");
const utils = @import("../utils/root.zig");

// ============================================================================
// Metrics Event Types
// ============================================================================

pub const EventType = enum {
    session_start,
    session_end,
    agent_iteration,
    tool_execution,
    llm_call,
    memory_snapshot,
    assertion_trigger,
};

// ============================================================================
// Metrics Data Structures
// ============================================================================

pub const SessionStartData = struct {
    model: []const u8,
    max_iterations: u32,
};

pub const SessionEndData = struct {
    total_iterations: u32,
    total_messages: usize,
    exit_reason: []const u8,
};

pub const AgentIterationData = struct {
    iteration: u32,
    state: []const u8,
    duration_ms: i64,
};

pub const ToolExecutionData = struct {
    tool_name: []const u8,
    success: bool,
    duration_ms: i64,
    error_msg: ?[]const u8,
};

pub const LLMCallData = struct {
    provider: []const u8,
    model: []const u8,
    tokens_input: usize,
    tokens_output: usize,
    duration_ms: i64,
    cost_usd: ?f64,
};

pub const MemorySnapshotData = struct {
    allocated_bytes: usize,
    freed_bytes: usize,
    live_bytes: usize,
    allocations_count: usize,
};

pub const AssertionTriggerData = struct {
    file: []const u8,
    line: u32,
    message: []const u8,
};

pub const MetricsData = union(EventType) {
    session_start: SessionStartData,
    session_end: SessionEndData,
    agent_iteration: AgentIterationData,
    tool_execution: ToolExecutionData,
    llm_call: LLMCallData,
    memory_snapshot: MemorySnapshotData,
    assertion_trigger: AssertionTriggerData,
};

// ============================================================================
// Metrics Snapshot
// ============================================================================

pub const MetricsSnapshot = struct {
    timestamp: i64,
    session_id: []const u8,
    event_type: EventType,
    data: MetricsData,
};

// ============================================================================
// Metrics Collector
// ============================================================================

pub const MetricsCollector = struct {
    allocator: std.mem.Allocator,
    session_id: []const u8,
    file: ?std.fs.File,
    buffer: std.ArrayList(u8),
    last_flush: i64,
    enabled: bool,
    
    const FLUSH_INTERVAL_MS = 500;
    const BUFFER_SIZE = 4096;
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, session_id: []const u8) !*Self {
        std.debug.assert(session_id.len > 0); // Session ID must be valid
        
        // 创建 ~/.kimiz/metrics/ 目录
        const home = std.posix.getenv("HOME") orelse return error.NoHomeDir;
        std.debug.assert(home.len > 0); // Home directory must exist
        
        const metrics_dir = try std.fs.path.join(allocator, &.{ home, ".kimiz", "metrics" });
        defer allocator.free(metrics_dir);
        
        std.fs.makeDirAbsolute(metrics_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };
        
        // 打开 {session_id}.jsonl 文件（追加模式）
        const filename = try std.fmt.allocPrint(allocator, "{s}.jsonl", .{session_id});
        defer allocator.free(filename);
        
        const filepath = try std.fs.path.join(allocator, &.{ metrics_dir, filename });
        defer allocator.free(filepath);
        
        const file = std.fs.createFileAbsolute(filepath, .{
            .truncate = false,
            .read = false,
        }) catch |err| {
            std.log.warn("Failed to create metrics file: {s}", .{@errorName(err)});
            // 如果文件创建失败，metrics收集器仍然可以工作，只是不写入磁盘
            const self = try allocator.create(Self);
            self.* = .{
                .allocator = allocator,
                .session_id = try allocator.dupe(u8, session_id),
                .file = null,
                .buffer = std.ArrayList(u8).init(allocator),
                .last_flush = std.time.milliTimestamp(),
                .enabled = false,
            };
            return self;
        };
        
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .session_id = try allocator.dupe(u8, session_id),
            .file = file,
            .buffer = std.ArrayList(u8).init(allocator),
            .last_flush = std.time.milliTimestamp(),
            .enabled = true,
        };
        
        std.debug.assert(self.session_id.len > 0); // Session ID copied correctly
        std.debug.assert(self.buffer.capacity == 0); // Buffer initialized empty
        
        return self;
    }
    
    pub fn deinit(self: *Self) void {
        std.debug.assert(self.session_id.len > 0); // Valid state at deinit
        
        self.flush() catch |err| {
            std.log.warn("Failed to flush metrics on deinit: {s}", .{@errorName(err)});
        };
        
        if (self.file) |f| f.close();
        self.allocator.free(self.session_id);
        self.buffer.deinit();
        self.allocator.destroy(self);
    }
    
    pub fn record(self: *Self, snapshot: MetricsSnapshot) !void {
        if (!self.enabled) return;
        
        std.debug.assert(snapshot.timestamp > 0); // Timestamp must be valid
        std.debug.assert(snapshot.session_id.len > 0); // Session ID must be valid
        std.debug.assert(std.mem.eql(u8, snapshot.session_id, self.session_id)); // Session ID must match
        
        // 序列化为JSON
        const json_str = try std.json.stringifyAlloc(self.allocator, snapshot, .{});
        defer self.allocator.free(json_str);
        
        std.debug.assert(json_str.len > 0); // JSON string must not be empty
        
        // 追加到缓冲区
        const buffer_len_before = self.buffer.items.len;
        try self.buffer.appendSlice(json_str);
        try self.buffer.append('\n');
        std.debug.assert(self.buffer.items.len > buffer_len_before); // Buffer grew
        
        // 检查是否需要刷新
        const now = std.time.milliTimestamp();
        if (self.buffer.items.len >= BUFFER_SIZE or (now - self.last_flush) >= FLUSH_INTERVAL_MS) {
            try self.flush();
        }
    }
    
    fn flush(self: *Self) !void {
        if (!self.enabled) return;
        if (self.buffer.items.len == 0) return;
        
        std.debug.assert(self.file != null); // File must be open if enabled
        
        const file = self.file.?;
        try file.seekFromEnd(0); // 确保追加到文件末尾
        try file.writeAll(self.buffer.items);
        
        self.buffer.clearRetainingCapacity();
        self.last_flush = std.time.milliTimestamp();
        
        std.debug.assert(self.buffer.items.len == 0); // Buffer cleared after flush
    }
};

// ============================================================================
// Helper Functions
// ============================================================================

/// 生成唯一的session ID
pub fn generateSessionId(allocator: std.mem.Allocator) ![]const u8 {
    const timestamp = std.time.milliTimestamp();
    const random = std.crypto.random.int(u32);
    return try std.fmt.allocPrint(allocator, "s-{d}-{x:0>8}", .{ timestamp, random });
}

/// 估算LLM调用成本（基于token数量）
pub fn estimateCost(provider: []const u8, model: []const u8, tokens_input: usize, tokens_output: usize) ?f64 {
    _ = provider;
    
    // 简化版本：仅支持Anthropic Claude模型
    if (std.mem.indexOf(u8, model, "claude") != null) {
        // Claude 3.7 Sonnet pricing (2024)
        // Input: $3/MTok, Output: $15/MTok
        const input_cost = @as(f64, @floatFromInt(tokens_input)) * 3.0 / 1_000_000.0;
        const output_cost = @as(f64, @floatFromInt(tokens_output)) * 15.0 / 1_000_000.0;
        return input_cost + output_cost;
    }
    
    return null; // 未知模型，不估算
}

// ============================================================================
// Tests
// ============================================================================

test "MetricsCollector init and deinit" {
    const allocator = std.testing.allocator;
    
    const collector = try MetricsCollector.init(allocator, "test-session-001");
    defer collector.deinit();
    
    try std.testing.expect(collector.enabled);
    try std.testing.expectEqualStrings("test-session-001", collector.session_id);
}

test "MetricsCollector record session_start" {
    const allocator = std.testing.allocator;
    
    const collector = try MetricsCollector.init(allocator, "test-session-002");
    defer collector.deinit();
    
    const snapshot = MetricsSnapshot{
        .timestamp = std.time.milliTimestamp(),
        .session_id = collector.session_id,
        .event_type = .session_start,
        .data = .{ .session_start = .{
            .model = "claude-3.7-sonnet",
            .max_iterations = 50,
        }},
    };
    
    try collector.record(snapshot);
    
    // 验证buffer有内容
    try std.testing.expect(collector.buffer.items.len > 0);
}

test "generateSessionId uniqueness" {
    const allocator = std.testing.allocator;
    
    const id1 = try generateSessionId(allocator);
    defer allocator.free(id1);
    
    const id2 = try generateSessionId(allocator);
    defer allocator.free(id2);
    
    // 两个ID应该不同
    try std.testing.expect(!std.mem.eql(u8, id1, id2));
    
    // ID应该以 "s-" 开头
    try std.testing.expect(std.mem.startsWith(u8, id1, "s-"));
}

test "estimateCost Claude model" {
    const cost = estimateCost("anthropic", "claude-3.7-sonnet", 1000, 500);
    
    try std.testing.expect(cost != null);
    try std.testing.expect(cost.? > 0);
    
    // 1000 input tokens = $0.003
    // 500 output tokens = $0.0075
    // Total ≈ $0.0105
    const expected = 0.0105;
    const epsilon = 0.0001;
    try std.testing.expect(@abs(cost.? - expected) < epsilon);
}
