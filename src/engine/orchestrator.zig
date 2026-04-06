const std = @import("std");
const task = @import("task.zig");
const project = @import("project.zig");

// ============================================================================
// Orchestrator
// ============================================================================

pub const Decision = struct {
    rollback_required: bool,
    target_phase: ?project.Phase,
    insert_directly: bool,
    priority: task.TaskPriority,
    depends_on: []const []const u8,
    reasoning: []const u8,
    interrupt_current: bool,

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.reasoning);
        for (self.depends_on) |dep| allocator.free(dep);
        allocator.free(self.depends_on);
    }

    const Self = @This();
};

pub const AIAnalyzer = struct {
    ctx: *anyopaque,
    analyze: *const fn (ctx: *anyopaque, allocator: std.mem.Allocator, prompt: []const u8) anyerror![]const u8,

    pub fn init(
        ctx: *anyopaque,
        analyze: *const fn (ctx: *anyopaque, allocator: std.mem.Allocator, prompt: []const u8) anyerror![]const u8,
    ) AIAnalyzer {
        return .{ .ctx = ctx, .analyze = analyze };
    }

    pub fn call(self: AIAnalyzer, allocator: std.mem.Allocator, prompt: []const u8) anyerror![]const u8 {
        return self.analyze(self.ctx, allocator, prompt);
    }
};

pub const Orchestrator = struct {
    allocator: std.mem.Allocator,
    ai: ?AIAnalyzer,

    pub fn init(allocator: std.mem.Allocator, ai: ?AIAnalyzer) Self {
        return .{ .allocator = allocator, .ai = ai };
    }

    pub fn buildAnalysisPrompt(
        self: *const Self,
        title: []const u8,
        description: []const u8,
        current_phase: project.Phase,
        queue_snapshot: *const task.TaskQueue,
    ) ![]const u8 {
        var buf: std.ArrayList(u8) = .empty;
        errdefer buf.deinit(self.allocator);

        try buf.appendSlice(self.allocator, "You are the Orchestrator of a 7-phase AI development project.\n\n");
        try buf.appendSlice(self.allocator, "- Phase: ");
        try buf.appendSlice(self.allocator, @tagName(current_phase));
        try buf.appendSlice(self.allocator, "\n- Tasks in queue: ");
        var cnt: [20]u8 = undefined;
        {
            const s = try std.fmt.bufPrint(&cnt, "{d}", .{queue_snapshot.tasks.items.len});
            try buf.appendSlice(self.allocator, s);
        }
        try buf.appendSlice(self.allocator, "\n\n## New Requirement Title\n");
        try buf.appendSlice(self.allocator, title);
        try buf.appendSlice(self.allocator, "\n## Description\n");
        try buf.appendSlice(self.allocator, description);
        try buf.appendSlice(self.allocator,
            "\n\n## Rules\n" ++
            "1. Changes product goals/scope -> rollback to Phase 1 (prd)\n" ++
            "2. Changes architecture/interfaces -> rollback to Phase 2 (architecture)\n" ++
            "3. Changes technical approach only -> rollback to Phase 3 (technical_spec)\n" ++
            "4. Just adds a task -> insert directly (no rollback)\n\n" ++
            "Respond with EXACTLY this JSON:\n" ++
            "```json\n" ++
            "{\"rollback_required\":false,\"target_phase\":null,\"insert_directly\":true,\"priority\":\"p2\",\"reasoning\":\"\",\"interrupt_current\":false}\n" ++
            "```",
        );

        return try buf.toOwnedSlice(self.allocator);
    }

    pub fn evaluateNewNeed(
        self: *const Self,
        title: []const u8,
        description: []const u8,
        current_phase: project.Phase,
        queue_snapshot: *const task.TaskQueue,
    ) !Decision {
        if (self.ai) |ai| {
            const prompt = try self.buildAnalysisPrompt(title, description, current_phase, queue_snapshot);
            defer self.allocator.free(prompt);
            const raw = try ai.call(self.allocator, prompt);
            defer self.allocator.free(raw);
            return parseDecision(self.allocator, raw);
        }

        return .{
            .rollback_required = false,
            .target_phase = null,
            .insert_directly = true,
            .priority = .p2,
            .depends_on = &.{},
            .reasoning = try self.allocator.dupe(u8, "No AI; default: insert into queue"),
            .interrupt_current = false,
        };
    }

    pub fn executeDecision(
        self: *const Self,
        ctx: *TaskInsertionContext,
        decision: *const Decision,
        new_title: []const u8,
        new_description: []const u8,
    ) !task.Task {
        const new_task = try task.Task.init(
            self.allocator,
            try generateTaskId(self.allocator),
            new_title,
            if (decision.insert_directly) task.TaskStatus.todo else task.TaskStatus.blocked,
            decision.priority,
            decision.depends_on,
        );
        errdefer new_task.deinit(self.allocator);

        try ctx.queue.addTask(self.allocator, new_task);

        if (decision.rollback_required) {
            if (decision.target_phase) |phase| {
                ctx.project.current_phase = phase;
            }
        }

        _ = new_description;
        return new_task;
    }

    const Self = @This();
};

pub const TaskInsertionContext = struct {
    project: *project.Project,
    queue: *task.TaskQueue,
};

// ============================================================================
// parseDecision (pub so tests can call it)
// ============================================================================

pub fn parseDecision(allocator: std.mem.Allocator, raw: []const u8) !Decision {
    var decision: Decision = .{
        .rollback_required = false,
        .target_phase = null,
        .insert_directly = true,
        .priority = .p2,
        .depends_on = &.{},
        .reasoning = "",
        .interrupt_current = false,
    };
    errdefer decision.deinit(allocator);

    var content = raw;
    if (std.mem.indexOf(u8, content, "```json")) |s| {
        content = content[s + 8 ..];
        if (std.mem.indexOfScalar(u8, content, '`')) |e| {
            content = content[0..e];
        }
    }

    if (extractField(content, "rollback_required")) |v| {
        decision.rollback_required = std.mem.indexOf(u8, v, "true") != null;
    }
    if (extractField(content, "insert_directly")) |v| {
        decision.insert_directly = std.mem.indexOf(u8, v, "true") != null;
    }
    if (extractField(content, "interrupt_current")) |v| {
        decision.interrupt_current = std.mem.indexOf(u8, v, "true") != null;
    }

    if (extractStringField(content, "priority")) |p| {
        decision.priority = if (std.mem.eql(u8, p, "p0")) .p0
            else if (std.mem.eql(u8, p, "p1")) .p1
            else if (std.mem.eql(u8, p, "p3")) .p3
            else .p2;
    }

    if (extractIntField(content, "target_phase")) |n| {
        decision.target_phase = switch (n) {
            1 => .prd,
            2 => .architecture,
            3 => .technical_spec,
            4 => .task_breakdown,
            5 => .test_spec,
            6 => .implementation,
            7 => .review_deploy,
            else => null,
        };
        if (decision.target_phase != null) decision.rollback_required = true;
    }

    if (extractStringField(content, "reasoning")) |r| {
        decision.reasoning = try allocator.dupe(u8, r);
    }

    return decision;
}

// ============================================================================
// JSON helpers
// ============================================================================

fn ltrim(s: []const u8) []const u8 {
    var i: usize = 0;
    while (i < s.len) : (i += 1) {
        const c = s[i];
        if (c != ' ' and c != '\t' and c != '\n' and c != '\r') break;
    }
    return s[i..];
}

fn trim(s: []const u8) []const u8 {
    var l: usize = 0;
    while (l < s.len) : (l += 1) {
        if (s[l] != ' ' and s[l] != '\t' and s[l] != '\n' and s[l] != '\r') break;
    }
    var r = s.len;
    while (r > l) : (r -= 1) {
        if (s[r - 1] != ' ' and s[r - 1] != '\t' and s[r - 1] != '\n' and s[r - 1] != '\r') break;
    }
    return s[l..r];
}

fn buildKey(buf: *[64]u8, key: []const u8) ?[]const u8 {
    if (key.len + 4 > buf.len) return null;
    buf[0] = '"';
    @memcpy(buf[1 .. 1 + key.len], key);
    buf[1 + key.len] = '"';
    buf[1 + key.len + 1] = ':';
    return buf[0 .. 1 + key.len + 2];
}

fn extractField(json: []const u8, key: []const u8) ?[]const u8 {
    var buf: [64]u8 = undefined;
    const sk = buildKey(&buf, key) orelse return null;
    // sk = "\"key\":" — already includes the colon
    const pos = std.mem.indexOf(u8, json, sk) orelse return null;
    const val = ltrim(json[pos + sk.len ..]);
    var end: usize = 0;
    while (end < val.len) : (end += 1) {
        const c = val[end];
        if (c == ',' or c == '}' or c == '\n') break;
    }
    return trim(val[0..end]);
}

fn extractStringField(json: []const u8, key: []const u8) ?[]const u8 {
    var buf: [64]u8 = undefined;
    const sk = buildKey(&buf, key) orelse return null;
    const pos = std.mem.indexOf(u8, json, sk) orelse return null;
    const val = ltrim(json[pos + sk.len ..]);
    if (val.len < 2 or val[0] != '"') return null;
    const qe = std.mem.indexOfScalarPos(u8, val, 1, '"') orelse return null;
    return val[1..qe];
}

fn extractIntField(json: []const u8, key: []const u8) ?u32 {
    const raw = extractField(json, key) orelse return null;
    if (raw.len > 0 and raw[0] == '"') return null;
    return std.fmt.parseUnsigned(u32, raw, 10) catch return null;
}

fn generateTaskId(allocator: std.mem.Allocator) ![]u8 {
    return try allocator.dupe(u8, "T-DYNAMIC-001");
}

// ============================================================================
// Tests
// ============================================================================

test "parseDecision - rollback to PRD" {
    const raw =
        \\{"rollback_required": true, "target_phase": 1, "insert_directly": false, "priority": "p0", "reasoning": "Changes product scope", "interrupt_current": true}
    ;
    var d = try parseDecision(std.testing.allocator, raw);
    defer d.deinit(std.testing.allocator);

    try std.testing.expect(d.rollback_required);
    try std.testing.expectEqual(project.Phase.prd, d.target_phase);
    try std.testing.expect(d.interrupt_current);
    try std.testing.expectEqual(task.TaskPriority.p0, d.priority);
}

test "parseDecision - insert directly" {
    const raw =
        \\{"rollback_required": false, "target_phase": null, "insert_directly": true, "priority": "p2", "reasoning": "Minor task", "interrupt_current": false}
    ;
    var d = try parseDecision(std.testing.allocator, raw);
    defer d.deinit(std.testing.allocator);

    try std.testing.expect(!d.rollback_required);
    try std.testing.expect(d.insert_directly);
    try std.testing.expectEqual(task.TaskPriority.p2, d.priority);
}

test "parseDecision - markdown fenced" {
    const raw =
        \\```json
        \\{"rollback_required": false, "target_phase": 3, "insert_directly": false, "priority": "p1", "reasoning": "Tech spec change", "interrupt_current": false}
        \\```
    ;
    var d = try parseDecision(std.testing.allocator, raw);
    defer d.deinit(std.testing.allocator);

    try std.testing.expect(d.rollback_required);
    try std.testing.expectEqual(project.Phase.technical_spec, d.target_phase);
    try std.testing.expectEqual(task.TaskPriority.p1, d.priority);
    try std.testing.expectEqualStrings("Tech spec change", d.reasoning);
}

test "Orchestrator without AI returns conservative default" {
    const orch = Orchestrator.init(std.testing.allocator, null);
    var q = task.TaskQueue.init(std.testing.allocator);
    defer q.deinit();

    const d = try orch.evaluateNewNeed("add logging", "need more logging", .implementation, &q);
    defer std.testing.allocator.free(d.reasoning);

    try std.testing.expect(!d.rollback_required);
    try std.testing.expect(d.insert_directly);
}

test "buildKey" {
    var buf: [64]u8 = undefined;
    const key = buildKey(&buf, "rollback_required");
    try std.testing.expect(key != null);
    try std.testing.expectEqualStrings("\"rollback_required\":", key.?);
}

test "extractField - bool value" {
    const json = "{\"rollback_required\": true, \"other\": false}";
    const v = extractField(json, "rollback_required");
    try std.testing.expect(v != null);
    try std.testing.expectEqualStrings("true", v.?);
}

test "extractStringField - string value" {
    const json = "{\"priority\": \"p0\", \"reasoning\": \"hello world\"}";
    const p = extractStringField(json, "priority");
    try std.testing.expect(p != null);
    try std.testing.expectEqualStrings("p0", p.?);
}

test "extractIntField - number value" {
    const json = "{\"target_phase\": 3}";
    const n = extractIntField(json, "target_phase");
    try std.testing.expect(n != null);
    try std.testing.expect(n.? == 3);
}

test "extractIntField rejects string values" {
    const json = "{\"priority\": \"p0\"}";
    const n = extractIntField(json, "priority");
    try std.testing.expect(n == null);
}

test "ltrim trim" {
    try std.testing.expectEqualStrings("hello  ", ltrim("  hello  "));
    try std.testing.expectEqualStrings("hello", trim("  hello  "));
}
