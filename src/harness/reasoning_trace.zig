//! Reasoning Trace - Track agent thinking process and decisions
//! Production-grade debugging and auditing system

const std = @import("std");
const core = @import("../core/root.zig");
const ToolCall = core.ToolCall;
const TokenUsage = core.TokenUsage;
const log = @import("../utils/log.zig");
const utils = @import("../utils/root.zig");

/// A single step in the reasoning process
pub const ReasoningStep = struct {
    step_number: u32,
    timestamp: i64,
    thought: []const u8,
    tool_call: ?ToolCall,
    tool_result: ?[]const u8,
    duration_ms: u64,
    tokens_used: ?TokenUsage,

    pub fn deinit(self: ReasoningStep, allocator: std.mem.Allocator) void {
        allocator.free(self.thought);
        if (self.tool_result) |result| {
            allocator.free(result);
        }
        if (self.tool_call) |tc| {
            allocator.free(tc.id);
            allocator.free(tc.name);
            allocator.free(tc.arguments);
        }
    }
};

/// Complete reasoning trace for a task
pub const Trace = struct {
    allocator: std.mem.Allocator,
    session_id: []const u8,
    task: []const u8,
    workspace: []const u8,
    started_at: i64,
    completed_at: ?i64,
    steps: std.ArrayList(ReasoningStep),
    final_answer: ?[]const u8,
    total_cost_usd: f64,
    total_tokens: ?TokenUsage,
    error_message: ?[]const u8,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        session_id: []const u8,
        task: []const u8,
        workspace: []const u8,
    ) !Self {
        return .{
            .allocator = allocator,
            .session_id = try allocator.dupe(u8, session_id),
            .task = try allocator.dupe(u8, task),
            .workspace = try allocator.dupe(u8, workspace),
            .started_at = std.time.timestamp(),
            .completed_at = null,
            .steps = std.ArrayList(ReasoningStep).init(allocator),
            .final_answer = null,
            .total_cost_usd = 0.0,
            .total_tokens = null,
            .error_message = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.session_id);
        self.allocator.free(self.task);
        self.allocator.free(self.workspace);
        
        for (self.steps.items) |step| {
            step.deinit(self.allocator);
        }
        self.steps.deinit();
        
        if (self.final_answer) |answer| {
            self.allocator.free(answer);
        }
        
        if (self.error_message) |err| {
            self.allocator.free(err);
        }
    }

    /// Record a new reasoning step
    pub fn recordStep(
        self: *Self,
        thought: []const u8,
        tool_call: ?ToolCall,
        tool_result: ?[]const u8,
        duration_ms: u64,
        tokens_used: ?TokenUsage,
    ) !void {
        const step = ReasoningStep{
            .step_number = @intCast(self.steps.items.len + 1),
            .timestamp = std.time.timestamp(),
            .thought = try self.allocator.dupe(u8, thought),
            .tool_call = if (tool_call) |tc| .{
                .id = try self.allocator.dupe(u8, tc.id),
                .name = try self.allocator.dupe(u8, tc.name),
                .arguments = try self.allocator.dupe(u8, tc.arguments),
            } else null,
            .tool_result = if (tool_result) |result| try self.allocator.dupe(u8, result) else null,
            .duration_ms = duration_ms,
            .tokens_used = tokens_used,
        };
        
        try self.steps.append(step);
        
        log.debug("Recorded trace step {d}: {s}", .{ step.step_number, thought[0..@min(thought.len, 50)] });
    }

    /// Record a thought without tool call
    pub fn recordThought(self: *Self, thought: []const u8) !void {
        try self.recordStep(thought, null, null, 0, null);
    }

    /// Record tool execution
    pub fn recordToolExecution(
        self: *Self,
        thought: []const u8,
        tool_call: ToolCall,
        tool_result: []const u8,
        duration_ms: u64,
    ) !void {
        try self.recordStep(thought, tool_call, tool_result, duration_ms, null);
    }

    /// Finalize the trace with the answer
    pub fn finalize(self: *Self, answer: []const u8, total_cost: f64, tokens: ?TokenUsage) !void {
        self.final_answer = try self.allocator.dupe(u8, answer);
        self.total_cost_usd = total_cost;
        self.total_tokens = tokens;
        self.completed_at = std.time.timestamp();
        
        log.info("Trace finalized: {d} steps, ${d:.4f} cost", .{ self.steps.items.len, total_cost });
    }

    /// Record an error
    pub fn recordError(self: *Self, error_message: []const u8) !void {
        self.error_message = try self.allocator.dupe(u8, error_message);
        self.completed_at = std.time.timestamp();
        
        log.err("Trace error: {s}", .{error_message});
    }

    /// Export trace to JSON
    pub fn toJson(self: Self, allocator: std.mem.Allocator) ![]const u8 {
        var buf = std.ArrayList(u8).init(allocator);
        defer buf.deinit();
        
        const writer = buf.writer();
        
        try writer.print("{{\n", .{});
        try writer.print("  \"session_id\": \"{s}\",\n", .{self.session_id});
        try writer.print("  \"task\": \"{s}\",\n", .{self.task});
        try writer.print("  \"workspace\": \"{s}\",\n", .{self.workspace});
        try writer.print("  \"started_at\": {d},\n", .{self.started_at});
        
        if (self.completed_at) |completed| {
            try writer.print("  \"completed_at\": {d},\n", .{completed});
        } else {
            try writer.print("  \"completed_at\": null,\n", .{});
        }
        
        try writer.print("  \"steps\": [\n", .{});
        
        for (self.steps.items, 0..) |step, i| {
            try writer.print("    {{\n", .{});
            try writer.print("      \"step_number\": {d},\n", .{step.step_number});
            try writer.print("      \"timestamp\": {d},\n", .{step.timestamp});
            try writer.print("      \"thought\": \"{s}\",\n", .{step.thought});
            
            if (step.tool_call) |tc| {
                try writer.print("      \"tool_call\": {{\n", .{});
                try writer.print("        \"name\": \"{s}\",\n", .{tc.name});
                try writer.print("        \"arguments\": {s}\n", .{tc.arguments});
                try writer.print("      }},\n", .{});
            } else {
                try writer.print("      \"tool_call\": null,\n", .{});
            }
            
            if (step.tool_result) |result| {
                // Truncate long results
                const display_result = if (result.len > 200) result[0..200] else result;
                try writer.print("      \"tool_result\": \"{s}...\",\n", .{display_result});
            } else {
                try writer.print("      \"tool_result\": null,\n", .{});
            }
            
            try writer.print("      \"duration_ms\": {d}\n", .{step.duration_ms});
            try writer.print("    }}", .{});
            
            if (i < self.steps.items.len - 1) {
                try writer.print(",", .{});
            }
            try writer.print("\n", .{});
        }
        
        try writer.print("  ],\n", .{});
        
        if (self.final_answer) |answer| {
            try writer.print("  \"final_answer\": \"{s}\",\n", .{answer});
        } else {
            try writer.print("  \"final_answer\": null,\n", .{});
        }
        
        try writer.print("  \"total_cost_usd\": {d:.6},\n", .{self.total_cost_usd});
        
        if (self.error_message) |err| {
            try writer.print("  \"error\": \"{s}\"\n", .{err});
        } else {
            try writer.print("  \"error\": null\n", .{});
        }
        
        try writer.print("}}", .{});
        
        return buf.toOwnedSlice();
    }

    /// Save trace to file
    pub fn saveToFile(self: Self, path: []const u8) !void {
        const json = try self.toJson(self.allocator);
        defer self.allocator.free(json);
        
        // Use utils to write file (Zig 0.16 compatible)
        try utils.writeFile(path, json);
        
        log.info("Trace saved to: {s}", .{path});
    }

    /// Get trace statistics
    pub fn getStats(self: Self) struct { steps: usize, total_duration_ms: u64, avg_step_duration_ms: u64 } {
        var total_duration: u64 = 0;
        for (self.steps.items) |step| {
            total_duration += step.duration_ms;
        }
        
        const avg_duration = if (self.steps.items.len > 0) 
            total_duration / @as(u64, @intCast(self.steps.items.len)) 
        else 
            0;
        
        return .{
            .steps = self.steps.items.len,
            .total_duration_ms = total_duration,
            .avg_step_duration_ms = avg_duration,
        };
    }
};

/// Trace manager for multiple traces
pub const TraceManager = struct {
    allocator: std.mem.Allocator,
    traces_dir: []const u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, traces_dir: []const u8) !Self {
        // Create traces directory
        // Use utils to create directory (Zig 0.16 compatible)
        utils.makeDirRecursive(traces_dir) catch |e| switch (e) {
            error.PathAlreadyExists => {},
            else => return e,
        };

        return .{
            .allocator = allocator,
            .traces_dir = try allocator.dupe(u8, traces_dir),
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.traces_dir);
    }

    /// Get path for a trace file
    pub fn getTracePath(self: Self, session_id: []const u8) ![]const u8 {
        const filename = try std.fmt.allocPrint(self.allocator, "{s}.json", .{session_id});
        defer self.allocator.free(filename);
        
        return try std.fs.path.join(self.allocator, &.{ self.traces_dir, filename });
    }

    /// Save a trace
    pub fn saveTrace(self: Self, trace: *const Trace) !void {
        const path = try self.getTracePath(trace.session_id);
        defer self.allocator.free(path);
        
        try trace.saveToFile(path);
    }

    /// List all trace files
    pub fn listTraces(self: Self) ![][]const u8 {
        var traces = std.ArrayList([]const u8).init(self.allocator);
        errdefer {
            for (traces.items) |t| self.allocator.free(t);
            traces.deinit();
        }

        // Use utils to open directory (Zig 0.16 compatible)
        const io = try utils.getIo();
        var dir = try utils.openDir(self.traces_dir, .{ .iterate = true });
        defer dir.close(io);

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".json")) {
                // Remove .json extension
                const name = entry.name[0 .. entry.name.len - 5];
                try traces.append(try self.allocator.dupe(u8, name));
            }
        }

        return traces.toOwnedSlice();
    }

    /// Load a trace from file
    pub fn loadTrace(self: Self, session_id: []const u8) !?Trace {
        const path = try self.getTracePath(session_id);
        defer self.allocator.free(path);

        const content = utils.readFileAlloc(self.allocator, path, 10 * 1024 * 1024) catch |err| switch (err) {
            error.FileNotFound => return null,
            else => return err,
        };
        defer self.allocator.free(content);

        // Parse JSON and reconstruct Trace
        // TODO: Implement full deserialization
        return null;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Trace init/deinit" {
    const allocator = std.testing.allocator;
    var trace = try Trace.init(allocator, "session-123", "Fix bug", "/home/user/project");
    defer trace.deinit();
    
    try std.testing.expectEqualStrings("session-123", trace.session_id);
    try std.testing.expectEqualStrings("Fix bug", trace.task);
}

test "Trace recordStep and finalize" {
    const allocator = std.testing.allocator;
    var trace = try Trace.init(allocator, "session-123", "Fix bug", "/home/user/project");
    defer trace.deinit();
    
    // Record a step
    try trace.recordThought("Analyzing the code...");
    try std.testing.expectEqual(@as(usize, 1), trace.steps.items.len);
    
    // Finalize
    try trace.finalize("Bug fixed!", 0.023, null);
    try std.testing.expect(trace.final_answer != null);
    try std.testing.expectEqual(@as(f64, 0.023), trace.total_cost_usd);
}

test "Trace toJson" {
    const allocator = std.testing.allocator;
    var trace = try Trace.init(allocator, "session-123", "Fix bug", "/home/user/project");
    defer trace.deinit();
    
    try trace.recordThought("Analyzing...");
    try trace.finalize("Done!", 0.023, null);
    
    const json = try trace.toJson(allocator);
    defer allocator.free(json);
    
    try std.testing.expect(std.mem.indexOf(u8, json, "session-123") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "Fix bug") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "Analyzing...") != null);
}

test "TraceManager init" {
    const allocator = std.testing.allocator;
    var manager = try TraceManager.init(allocator, ".test_traces");
    defer manager.deinit();
    
    try std.testing.expectEqualStrings(".test_traces", manager.traces_dir);
    
    // Cleanup (Zig 0.16 compatible - use utils)
    utils.deleteTree(".test_traces") catch {};
}

test "Trace getStats" {
    const allocator = std.testing.allocator;
    var trace = try Trace.init(allocator, "session-123", "Fix bug", "/home/user/project");
    defer trace.deinit();
    
    try trace.recordThought("Step 1");
    try trace.recordThought("Step 2");
    try trace.recordThought("Step 3");
    
    const stats = trace.getStats();
    try std.testing.expectEqual(@as(usize, 3), stats.steps);
}
