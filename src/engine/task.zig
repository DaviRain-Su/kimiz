const std = @import("std");
const utils = @import("../utils/root.zig");

// ============================================================================
// Task Model (T-128-02)
// ============================================================================

pub const TaskStatus = enum {
    todo,
    in_progress,
    done,
    blocked,
    failed,
};

pub const TaskPriority = enum {
    p0,
    p1,
    p2,
    p3,
};

/// Task parsed from markdown file YAML frontmatter
pub const Task = struct {
    id: []const u8,
    title: []const u8,
    status: TaskStatus = .todo,
    priority: TaskPriority = .p1,
    dependencies: [][]const u8 = &.{},
    max_steps: u32 = 50,
    estimated_hours: f32 = 0,
    spec_path: []const u8 = "",
    task_path: []const u8 = "",

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        _ = allocator;
        return .{
            .id = "",
            .title = "",
            .dependencies = &.{},
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        for (self.dependencies) |dep| allocator.free(dep);
        allocator.free(self.dependencies);
        allocator.free(self.id);
        allocator.free(self.title);
        if (self.spec_path.len > 0) allocator.free(self.spec_path);
        if (self.task_path.len > 0) allocator.free(self.task_path);
    }

    pub fn isBlockedBy(self: *const Self, done_ids: []const []const u8) bool {
        for (self.dependencies) |dep_id| {
            var found = false;
            for (done_ids) |done| {
                if (std.mem.eql(u8, dep_id, done)) {
                    found = true;
                    break;
                }
            }
            if (!found) return true;
        }
        return false;
    }
};

// ============================================================================
// Minimal YAML Frontmatter Parser
// ============================================================================

pub fn parseFrontmatter(allocator: std.mem.Allocator, content: []const u8) !?std.StringHashMap([]const u8) {
    const trimmed = std.mem.trim(u8, content, " \t\n\r");
    if (!std.mem.startsWith(u8, trimmed, "---")) return null;

    const rest = trimmed[3..];
    const end_idx = std.mem.indexOf(u8, rest, "\n---") orelse return null;
    if (end_idx == 0) return null;

    const yaml_block = std.mem.trim(u8, rest[0..end_idx], " \n\r");
    var map = std.StringHashMap([]const u8).init(allocator);
    errdefer map.deinit();

    var lines_it = std.mem.splitScalar(u8, yaml_block, '\n');
    while (lines_it.next()) |line| {
        const colon_idx = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const key = std.mem.trim(u8, line[0..colon_idx], " \t");
        if (key.len == 0) continue;

        const raw_value = if (colon_idx + 1 < line.len)
            std.mem.trim(u8, line[colon_idx + 1 ..], " \t")
        else
            "";

        const value = try allocator.dupe(u8, raw_value);
        errdefer allocator.free(value);
        try map.put(key, value);
    }

    return map;
}

// ============================================================================
// Parse Task from markdown content
// ============================================================================

pub fn parseTask(allocator: std.mem.Allocator, content: []const u8, task_path: []const u8) !?Task {
    const maybe_map = try parseFrontmatter(allocator, content);
    if (maybe_map == null) return null;
    var map = maybe_map.?;
    defer {
        var it = map.iterator();
        while (it.next()) |entry| allocator.free(entry.value_ptr.*);
        map.deinit();
    }

    const id = map.get("id") orelse return null;

    var task = Task.init(allocator);
    errdefer task.deinit(allocator);

    task.id = try allocator.dupe(u8, id);
    task.title = try allocator.dupe(u8, map.get("title") orelse "");

    if (map.get("status")) |s| task.status = parseStatus(s);
    if (map.get("priority")) |p| task.priority = parsePriority(p);
    if (map.get("max_steps")) |ms| task.max_steps = parseUint(ms, 50);
    if (map.get("estimated_hours")) |h| task.estimated_hours = parseFloat(h, 0);
    task.task_path = try allocator.dupe(u8, task_path);

    // Parse dependencies array: [T-001, T-002]
    if (map.get("dependencies")) |deps_str| {
        const trimmed = std.mem.trim(u8, deps_str, " []");
        if (trimmed.len > 0) {
            var deps: std.ArrayList([]const u8) = .empty;
            errdefer deps.deinit(allocator);
            var it = std.mem.splitScalar(u8, trimmed, ',');
            while (it.next()) |dep| {
                const d = std.mem.trim(u8, dep, " \t\r\"");
                if (d.len > 0) try deps.append(allocator, try allocator.dupe(u8, d));
            }
            task.dependencies = try deps.toOwnedSlice(allocator);
        }
    }

    return task;
}

pub fn parseStatus(s: []const u8) TaskStatus {
    if (std.mem.eql(u8, s, "in_progress")) return .in_progress;
    if (std.mem.eql(u8, s, "done")) return .done;
    if (std.mem.eql(u8, s, "blocked")) return .blocked;
    if (std.mem.eql(u8, s, "failed")) return .failed;
    return .todo;
}

pub fn parsePriority(s: []const u8) TaskPriority {
    if (std.mem.eql(u8, s, "p0")) return .p0;
    if (std.mem.eql(u8, s, "p1")) return .p1;
    if (std.mem.eql(u8, s, "p2")) return .p2;
    if (std.mem.eql(u8, s, "p3")) return .p3;
    return .p1;
}

fn parseUint(s: []const u8, default: u32) u32 {
    return std.fmt.parseInt(u32, s, 10) catch default;
}

fn parseFloat(s: []const u8, default: f32) f32 {
    return std.fmt.parseFloat(f32, s) catch default;
}

// ============================================================================
// Task Queue (T-128-03)
// ============================================================================

pub const TaskQueue = struct {
    allocator: std.mem.Allocator,
    tasks: std.ArrayList(Task),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .tasks = .empty,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.tasks.items) |*t| t.deinit(self.allocator);
        self.tasks.deinit(self.allocator);
    }

    pub fn isEmpty(self: *const Self) bool {
        return self.tasks.items.len == 0;
    }

    pub fn addTask(self: *Self, allocator: std.mem.Allocator, t: Task) !void {
        try self.tasks.append(allocator, t);
    }

    pub fn getDoneTasks(self: *const Self, out: *std.ArrayList([]const u8)) void {
        for (self.tasks.items) |t| {
            if (t.status == .done) {
                out.append(self.allocator, t.id) catch continue;
            }
        }
    }

    pub fn getNextTask(self: *const Self) ?*Task {
        var done_ids: std.ArrayList([]const u8) = .empty;
        defer done_ids.deinit(self.allocator);
        self.getDoneTasks(&done_ids);

        const done_slice = done_ids.items;
        var best: ?*Task = null;
        for (self.tasks.items) |*t| {
            if (t.status == .done or t.status == .blocked) continue;
            if (t.isBlockedBy(done_slice)) continue;

            if (best == null) {
                best = t;
            } else if (priorityValue(best.?.priority) > priorityValue(t.priority)) {
                best = t;
            }
        }
        return best;
    }

    pub fn getBlockedCount(self: *const Self) usize {
        var done_ids: std.ArrayList([]const u8) = .empty;
        defer done_ids.deinit(self.allocator);
        self.getDoneTasks(&done_ids);

        var count: usize = 0;
        for (self.tasks.items) |t| {
            if (t.status != .done and t.status != .blocked and t.isBlockedBy(done_ids.items)) {
                count += 1;
            }
        }
        return count;
    }

    fn priorityValue(p: TaskPriority) u32 {
        return switch (p) {
            .p0 => @as(u32, 0),
            .p1 => @as(u32, 1),
            .p2 => @as(u32, 2),
            .p3 => @as(u32, 3),
        };
    }

    /// Check for dependency cycles
    pub fn hasCycles(self: *const Self) bool {
        // Simple cycle detection: check if any task depends (transitively) on itself
        for (self.tasks.items) |root| {
            var stack: std.ArrayList([]const u8) = .empty;
            defer stack.deinit(self.allocator);
            var seen: std.StringHashMap(void) = .init(self.allocator);
            defer seen.deinit();
            stack.append(self.allocator, root.id) catch continue;
            while (stack.popOrNull()) |current| {
                if (seen.get(current) != null) continue;
                seen.put(current, {}) catch continue;
                for (self.tasks.items) |t| {
                    if (std.mem.eql(u8, t.id, current)) {
                        for (t.dependencies) |dep| {
                            if (std.mem.eql(u8, dep, root.id)) return true;
                            stack.append(self.allocator, dep) catch continue;
                        }
                        break;
                    }
                }
            }
        }
        return false;
    }
};

// ============================================================================
// Task lifecycle operations
// ============================================================================

pub fn loadTasksFromDir(allocator: std.mem.Allocator, dir_path: []const u8) !TaskQueue {
    var queue = TaskQueue.init(allocator);
    errdefer queue.deinit();

    const dir = utils.openDir(dir_path, .{ .iterate = true }) catch |err| {
        if (err == error.FileNotFound) return queue;
        return err;
    };

    const io = try utils.getIo();
    var it = dir.iterate(io);
    while (try it.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".md")) continue;
        if (std.mem.startsWith(u8, entry.name, "README")) continue;

        const path = try std.fs.path.join(allocator, &.{ dir_path, entry.name });
        defer allocator.free(path);

        const content = utils.readFileAlloc(allocator, path, 64 * 1024) catch {
            continue;
        };
        defer allocator.free(content);

        if (try parseTask(allocator, content, path)) |t| {
            var t_copy = t;
            errdefer t_copy.deinit(allocator);
            try queue.addTask(allocator, t_copy);
        }
    }

    return queue;
}

fn replaceStatus(allocator: std.mem.Allocator, content: []const u8, old_status: []const u8, new_status: []const u8) !?[]u8 {
    const idx = std.mem.indexOf(u8, content, old_status) orelse return null;
    const before = content[0..idx];
    const after = content[idx + old_status.len ..];
    return try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ before, new_status, after });
}

pub fn startTask(allocator: std.mem.Allocator, task_path: []const u8) !void {
    const content = try utils.readFileAlloc(allocator, task_path, 64 * 1024);
    defer allocator.free(content);

    const needle = "status: todo";
    const replacement = "status: in_progress";
    const new_content = try replaceStatus(allocator, content, needle, replacement) orelse {
        return error.TaskNotInTodo;
    };
    defer allocator.free(new_content);

    try utils.writeFile(task_path, new_content);
}

pub fn completeTask(allocator: std.mem.Allocator, task_path: []const u8) !void {
    const content = try utils.readFileAlloc(allocator, task_path, 64 * 1024);
    defer allocator.free(content);

    // Minimal validation: at least one checklist item must be checked
    const has_check = std.mem.indexOf(u8, content, "- [x]") != null or
        std.mem.indexOf(u8, content, "-[x]") != null;
    if (!has_check) {
        return error.NoChecklistCompletion;
    }

    const needle = "status: in_progress";
    const replacement = "status: done";
    const new_content = try replaceStatus(allocator, content, needle, replacement) orelse {
        return error.TaskNotInProgress;
    };
    defer allocator.free(new_content);

    try utils.writeFile(task_path, new_content);
}

pub fn archiveCompleted(allocator: std.mem.Allocator, active_dir: []const u8, completed_dir: []const u8) !void {
    try utils.makeDirRecursive(completed_dir);

    const dir = utils.openDir(active_dir, .{ .iterate = true }) catch |err| {
        if (err == error.FileNotFound) return;
        return err;
    };

    const io = try utils.getIo();
    var it = dir.iterate(io);
    while (try it.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endswith(u8, entry.name, ".md")) continue;

        const path = try std.fs.path.join(allocator, &.{ active_dir, entry.name });
        defer allocator.free(path);

        const content = utils.readFileAlloc(allocator, path, 64 * 1024) catch continue;
        defer allocator.free(content);

        if (std.mem.indexOf(u8, content, "status: done") != null) {
            const dest = try std.fs.path.join(allocator, &.{ completed_dir, entry.name });
            defer allocator.free(dest);
            try utils.rename(path, dest);
        }
    }
}

// ============================================================================
// Tests
// ============================================================================

test "task parse from markdown frontmatter" {
    const content =
        \\---
        \\id: T-042
        \\title: Test task
        \\status: todo
        \\priority: p1
        \\max_steps: 30
        \\dependencies: [T-001, T-002]
        \\---
        \\Some content here
    ;
    const maybe_task = try parseTask(std.testing.allocator, content, "tasks/active/T-042.md");
    try std.testing.expect(maybe_task != null);
    var task = maybe_task.?;
    defer task.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("T-042", task.id);
    try std.testing.expectEqualStrings("Test task", task.title);
    try std.testing.expectEqual(TaskStatus.todo, task.status);
    try std.testing.expectEqual(TaskPriority.p1, task.priority);
    try std.testing.expectEqual(@as(u32, 30), task.max_steps);
    try std.testing.expectEqual(@as(usize, 2), task.dependencies.len);
    try std.testing.expectEqualStrings("T-001", task.dependencies[0]);
    try std.testing.expectEqualStrings("T-002", task.dependencies[1]);
}

test "task parse - no frontmatter returns null" {
    const content = "Just some markdown content";
    const result = try parseTask(std.testing.allocator, content, "");
    try std.testing.expect(result == null);
}

test "task parse - minimal frontmatter" {
    const content =
        \\---
        \\id: T-001
        \\---
        \\Content
    ;
    const result = try parseTask(std.testing.allocator, content, "");
    try std.testing.expect(result != null);
    var task = result.?;
    defer task.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("T-001", task.id);
    try std.testing.expectEqual(TaskStatus.todo, task.status);
    try std.testing.expectEqual(@as(u32, 50), task.max_steps);
    try std.testing.expectEqual(@as(usize, 0), task.dependencies.len);
}

test "task isBlockedBy - no deps not blocked" {
    const no_deps: [0][]const u8 = .{};
    const task = Task{ .id = "T-001", .title = "", .dependencies = &no_deps };
    const done: [1][]const u8 = .{"anything"};
    try std.testing.expectEqual(false, task.isBlockedBy(&done));
}

test "task isBlockedBy - dependency met" {
    var deps: [1][]const u8 = .{"T-000"};
    const task = Task{ .id = "T-001", .title = "", .dependencies = &deps };
    const done: [1][]const u8 = .{"T-000"};
    try std.testing.expectEqual(false, task.isBlockedBy(&done));
}

test "task isBlockedBy - dependency not met" {
    var deps: [1][]const u8 = .{"T-999"};
    const task = Task{ .id = "T-001", .title = "", .dependencies = &deps };
    const done: [1][]const u8 = .{"T-000"};
    try std.testing.expectEqual(true, task.isBlockedBy(&done));
}
