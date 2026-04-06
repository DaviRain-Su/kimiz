//! Git Tools - Safe wrappers around system git command
//! Provides: git_status, git_diff, git_log

const std = @import("std");
const tool = @import("../tool.zig");

// ============================================================================
// git_status
// ============================================================================

pub const GIT_STATUS_NAME = "git_status";

const GIT_STATUS_DESCRIPTION =
    \\Get the current git repository status in a concise format.
    \\Returns branch info, modified files, untracked files, and staged changes.
    \\Example: {}
;

const GIT_STATUS_SCHEMA =
    \\{
    \\  "type": "object",
    \\  "properties": {}
    \\}
;

pub const git_status_definition = tool.Tool{
    .name = GIT_STATUS_NAME,
    .description = GIT_STATUS_DESCRIPTION,
    .parameters_json = GIT_STATUS_SCHEMA,
};

pub const GitStatusContext = struct {};

pub fn createGitStatusTool(ctx: *GitStatusContext) tool.AgentTool {
    return tool.AgentTool{
        .tool = git_status_definition,
        .execute_fn = executeGitStatus,
        .ctx = ctx,
    };
}

fn executeGitStatus(
    ctx_ptr: *anyopaque,
    arena: std.mem.Allocator,
    args: std.json.Value,
) anyerror!tool.ToolResult {
    _ = ctx_ptr;
    _ = args;

    return runGitCommand(arena, &[_][]const u8{
        "git", "status", "--porcelain", "-b",
    }, formatStatusOutput);
}

fn formatStatusOutput(arena: std.mem.Allocator, raw: []const u8) !tool.ToolResult {
    if (raw.len == 0) {
        return tool.textContent(arena, "Working tree clean");
    }

    var lines = std.mem.splitScalar(u8, raw, '\n');
    var branch_line: ?[]const u8 = null;
    var modified: std.ArrayList([]const u8) = .empty;
    defer modified.deinit(arena);
    var untracked: std.ArrayList([]const u8) = .empty;
    defer untracked.deinit(arena);
    var staged: std.ArrayList([]const u8) = .empty;
    defer staged.deinit(arena);

    while (lines.next()) |line| {
        if (line.len == 0) continue;
        if (std.mem.startsWith(u8, line, "## ")) {
            branch_line = line[3..];
            continue;
        }
        if (line.len < 3) continue;
        const status = line[0..2];
        const path = line[3..];
        if (status[0] != ' ' and status[0] != '?') {
            try staged.append(arena, path);
        } else if (status[1] == 'M' or status[1] == 'D') {
            try modified.append(arena, path);
        } else if (status[1] == '?') {
            try untracked.append(arena, path);
        }
    }

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(arena);

    if (branch_line) |b| {
        try buf.appendSlice(arena, try std.fmt.allocPrint(arena, "On branch {s}\n", .{b}));
    }

    const max_files = 50;

    if (staged.items.len > 0) {
        try buf.appendSlice(arena, try std.fmt.allocPrint(arena, "\nStaged: {d}\n", .{staged.items.len}));
        const show = @min(staged.items.len, max_files);
        for (staged.items[0..show]) |p| {
            try buf.appendSlice(arena, try std.fmt.allocPrint(arena, "  {s}\n", .{p}));
        }
        if (staged.items.len > max_files) {
            try buf.appendSlice(arena, try std.fmt.allocPrint(arena, "  ... and {d} more\n", .{staged.items.len - max_files}));
        }
    }

    if (modified.items.len > 0) {
        try buf.appendSlice(arena, try std.fmt.allocPrint(arena, "\nModified: {d}\n", .{modified.items.len}));
        const show = @min(modified.items.len, max_files);
        for (modified.items[0..show]) |p| {
            try buf.appendSlice(arena, try std.fmt.allocPrint(arena, "  {s}\n", .{p}));
        }
        if (modified.items.len > max_files) {
            try buf.appendSlice(arena, try std.fmt.allocPrint(arena, "  ... and {d} more\n", .{modified.items.len - max_files}));
        }
    }

    if (untracked.items.len > 0) {
        try buf.appendSlice(arena, try std.fmt.allocPrint(arena, "\nUntracked: {d}\n", .{untracked.items.len}));
        const show = @min(untracked.items.len, max_files);
        for (untracked.items[0..show]) |p| {
            try buf.appendSlice(arena, try std.fmt.allocPrint(arena, "  {s}\n", .{p}));
        }
        if (untracked.items.len > max_files) {
            try buf.appendSlice(arena, try std.fmt.allocPrint(arena, "  ... and {d} more\n", .{untracked.items.len - max_files}));
        }
    }

    if (buf.items.len == 0) {
        return tool.textContent(arena, "Working tree clean");
    }
    return tool.textContent(arena, try arena.dupe(u8, buf.items));
}

// ============================================================================
// git_diff
// ============================================================================

pub const GIT_DIFF_NAME = "git_diff";

const GIT_DIFF_DESCRIPTION =
    \\Show code changes (diff) in the working directory or staged changes.
    \\Example: {"staged": true} or {"path": "src/main.zig"}
;

const GIT_DIFF_SCHEMA =
    \\{
    \\  "type": "object",
    \\  "properties": {
    \\    "staged": {
    \\      "type": "boolean",
    \\      "description": "Show staged changes instead of unstaged"
    \\    },
    \\    "path": {
    \\      "type": "string",
    \\      "description": "Limit diff to a specific file or directory"
    \\    }
    \\  }
    \\}
;

pub const git_diff_definition = tool.Tool{
    .name = GIT_DIFF_NAME,
    .description = GIT_DIFF_DESCRIPTION,
    .parameters_json = GIT_DIFF_SCHEMA,
};

pub const GitDiffContext = struct {};

pub fn createGitDiffTool(ctx: *GitDiffContext) tool.AgentTool {
    return tool.AgentTool{
        .tool = git_diff_definition,
        .execute_fn = executeGitDiff,
        .ctx = ctx,
    };
}

fn executeGitDiff(
    ctx_ptr: *anyopaque,
    arena: std.mem.Allocator,
    args: std.json.Value,
) anyerror!tool.ToolResult {
    _ = ctx_ptr;

    const staged = if (args.object.get("staged")) |v| v.bool else false;
    const path = if (args.object.get("path")) |v| v.string else null;

    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(arena);
    try argv.append(arena, "git");
    try argv.append(arena, "diff");
    if (staged) try argv.append(arena, "--cached");
    try argv.append(arena, "--");
    if (path) |p| try argv.append(arena, p);

    return runGitCommandArgv(arena, argv.items, truncateDiffOutput);
}

fn truncateDiffOutput(arena: std.mem.Allocator, raw: []const u8) !tool.ToolResult {
    const max_len: usize = 50 * 1024; // 50KB
    if (raw.len == 0) {
        return tool.textContent(arena, "No changes");
    }
    if (raw.len <= max_len) {
        return tool.textContent(arena, try arena.dupe(u8, raw));
    }
    const truncated = try arena.dupe(u8, raw[0..max_len]);
    const note = try std.fmt.allocPrint(arena, "\n\n[Diff truncated: {d} bytes total, {d} shown]", .{ raw.len, max_len });
    const combined = try std.mem.concat(arena, u8, &[_][]const u8{ truncated, note });
    return tool.textContent(arena, combined);
}

// ============================================================================
// git_log
// ============================================================================

pub const GIT_LOG_NAME = "git_log";

const GIT_LOG_DESCRIPTION =
    \\Show recent git commit history.
    \\Example: {"limit": 10} or {"path": "src/main.zig"}
;

const GIT_LOG_SCHEMA =
    \\{
    \\  "type": "object",
    \\  "properties": {
    \\    "limit": {
    \\      "type": "integer",
    \\      "description": "Maximum number of commits (default: 10, max: 50)"
    \\    },
    \\    "path": {
    \\      "type": "string",
    \\      "description": "Show log for a specific file or directory"
    \\    }
    \\  }
    \\}
;

pub const git_log_definition = tool.Tool{
    .name = GIT_LOG_NAME,
    .description = GIT_LOG_DESCRIPTION,
    .parameters_json = GIT_LOG_SCHEMA,
};

pub const GitLogContext = struct {};

pub fn createGitLogTool(ctx: *GitLogContext) tool.AgentTool {
    return tool.AgentTool{
        .tool = git_log_definition,
        .execute_fn = executeGitLog,
        .ctx = ctx,
    };
}

fn executeGitLog(
    ctx_ptr: *anyopaque,
    arena: std.mem.Allocator,
    args: std.json.Value,
) anyerror!tool.ToolResult {
    _ = ctx_ptr;

    const limit: usize = blk: {
        if (args.object.get("limit")) |v| {
            break :blk @min(@as(usize, @intCast(v.integer)), 50);
        }
        break :blk 10;
    };
    const path = if (args.object.get("path")) |v| v.string else null;

    var limit_str: [8]u8 = undefined;
    const limit_slice = try std.fmt.bufPrint(&limit_str, "{d}", .{limit});

    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(arena);
    try argv.append(arena, "git");
    try argv.append(arena, "log");
    try argv.append(arena, "--oneline");
    try argv.append(arena, "-n");
    try argv.append(arena, limit_slice);
    try argv.append(arena, "--");
    if (path) |p| try argv.append(arena, p);

    return runGitCommandArgv(arena, argv.items, identityOutput);
}

fn identityOutput(arena: std.mem.Allocator, raw: []const u8) !tool.ToolResult {
    if (raw.len == 0) {
        return tool.textContent(arena, "No commits found");
    }
    return tool.textContent(arena, try arena.dupe(u8, raw));
}

// ============================================================================
// Common helpers
// ============================================================================

fn runGitCommand(
    arena: std.mem.Allocator,
    argv: []const []const u8,
    formatter: *const fn (std.mem.Allocator, []const u8) anyerror!tool.ToolResult,
) !tool.ToolResult {
    return runGitCommandArgv(arena, argv, formatter);
}

fn runGitCommandArgv(
    arena: std.mem.Allocator,
    argv: []const []const u8,
    formatter: *const fn (std.mem.Allocator, []const u8) anyerror!tool.ToolResult,
) !tool.ToolResult {
    const utils = @import("../../utils/root.zig");
    const io = utils.getIo() catch {
        return tool.errorResult(arena, "IoManager not initialized");
    };

    // Execute git command using Zig 0.16 native API
    const run_result = std.process.run(arena, io, .{
        .argv = argv,
    }) catch {
        return tool.errorResult(arena, "Failed to execute git command");
    };

    // Combine stdout and stderr
    var output_buf: std.ArrayList(u8) = .empty;
    defer output_buf.deinit(arena);
    try output_buf.appendSlice(arena, run_result.stdout);
    if (run_result.stderr.len > 0) {
        try output_buf.appendSlice(arena, run_result.stderr);
    }

    const result = try arena.dupe(u8, output_buf.items);

    // Detect common errors
    if (std.mem.containsAtLeast(u8, result, 1, "not a git repository")) {
        return tool.errorResult(arena, "Not a git repository");
    }
    if (std.mem.containsAtLeast(u8, result, 1, "fatal:")) {
        // Return as formatted error but include raw message
        const err_msg = try std.fmt.allocPrint(arena, "Git error: {s}", .{std.mem.trim(u8, result, "\n")});
        return tool.errorResult(arena, err_msg);
    }

    return formatter(arena, std.mem.trim(u8, result, "\n"));
}

// ============================================================================
// Tests
// ============================================================================

test "tool definitions" {
    try std.testing.expectEqualStrings("git_status", git_status_definition.name);
    try std.testing.expectEqualStrings("git_diff", git_diff_definition.name);
    try std.testing.expectEqualStrings("git_log", git_log_definition.name);
}

test "formatStatusOutput clean" {
    const allocator = std.testing.allocator;
    const result = try formatStatusOutput(allocator, "");
    try std.testing.expectEqualStrings("Working tree clean", result.content[0].text);
}

test "truncateDiffOutput" {
    const allocator = std.testing.allocator;
    const small = try truncateDiffOutput(allocator, "small change");
    try std.testing.expectEqualStrings("small change", small.content[0].text);
}
