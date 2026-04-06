//! Document-driven Agent Loop Tools (T-121)
//! Tools for task management, log updates, and spec consistency checks.

const std = @import("std");
const tool = @import("../tool.zig");
const utils = @import("../../utils/root.zig");

// ============================================================================
// Tool 1: read_active_task
// ============================================================================

const READ_ACTIVE_TASK_NAME = "read_active_task";
const READ_ACTIVE_TASK_DESCRIPTION =
    \\Reads the current active task from the sprint board and returns its full content.
    \\Automatically finds the first todo/in_progress task in the latest sprint directory.
;

const READ_ACTIVE_TASK_SCHEMA =
    \\{
    \\  "type": "object",
    \\  "properties": {
    \\    "sprint_dir": {
    \\      "type": "string",
    \\      "description": "Optional sprint directory override (e.g., 'tasks/active/sprint-2026-04')"
    \\    }
    \\  }
    \\}
;

pub const read_active_task_definition = tool.Tool{
    .name = READ_ACTIVE_TASK_NAME,
    .description = READ_ACTIVE_TASK_DESCRIPTION,
    .parameters_json = READ_ACTIVE_TASK_SCHEMA,
};

pub const ReadActiveTaskContext = struct {};

pub fn createReadActiveTaskTool(ctx: *ReadActiveTaskContext) tool.AgentTool {
    return .{
        .tool = read_active_task_definition,
        .execute_fn = struct {
            fn exec(ptr: *anyopaque, arena: std.mem.Allocator, args: std.json.Value) anyerror!tool.ToolResult {
                _ = ptr;
                return executeReadActiveTask(arena, args);
            }
        }.exec,
        .ctx = ctx,
    };
}

fn executeReadActiveTask(arena: std.mem.Allocator, args: std.json.Value) !tool.ToolResult {
    const sprint_dir = if (args.object.get("sprint_dir")) |v| v.string else null;

    if (sprint_dir) |dir| {
        return try findAndReadTask(arena, dir);
    }

    // Auto-detect latest sprint
    const latest_sprint = try detectLatestSprint(arena);
    return try findAndReadTask(arena, latest_sprint);
}

fn detectLatestSprint(arena: std.mem.Allocator) ![]const u8 {
    const io = try utils.getIo();
    const dir = try utils.openDir("tasks/active", .{ .iterate = true });
    defer dir.close(io);

    var latest: []const u8 = "";
    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .directory) continue;
        if (!std.mem.startsWith(u8, entry.name, "sprint-")) continue;
        if (latest.len == 0 or std.mem.order(u8, entry.name, latest).compare(.gt)) {
            latest = try arena.dupe(u8, entry.name);
        }
    }

    if (latest.len == 0) return error.NoSprintFound;
    return try std.fmt.allocPrint(arena, "tasks/active/{s}", .{latest});
}

fn findAndReadTask(arena: std.mem.Allocator, sprint_dir: []const u8) !tool.ToolResult {
    const readme_path = try std.fmt.allocPrint(arena, "{s}/README.md", .{sprint_dir});
    const readme_content = utils.readFileAlloc(arena, readme_path, 256 * 1024) catch |err|
        return tool.errorResult(arena, try std.fmt.allocPrint(arena, "Failed to read sprint board: {s}", .{@errorName(err)}));

    const task_filename = try findFirstPendingTask(arena, readme_content);

    const task_path = try std.fmt.allocPrint(arena, "{s}/{s}", .{ sprint_dir, task_filename });
    const task_content = utils.readFileAlloc(arena, task_path, 256 * 1024) catch |err|
        return tool.errorResult(arena, try std.fmt.allocPrint(arena, "Failed to read task file {s}: {s}", .{ task_path, @errorName(err) }));

    const sep_pos = std.mem.indexOfScalar(u8, task_filename, '-') orelse 0;
    const task_id = task_filename[0..std.mem.indexOfScalarPos(u8, task_filename, sep_pos + 1, '-').?];

    const response = try std.fmt.allocPrint(arena, "# Active Task: {s}\n{s}", .{ task_id, task_content });
    return tool.textContent(arena, response);
}

fn findFirstPendingTask(arena: std.mem.Allocator, readme_content: []const u8) ![]const u8 {
    var lines = std.mem.splitScalar(u8, readme_content, '\n');
    while (lines.next()) |line| {
        // Match lines like: | 8 | P1 | **T-121** | ... | `todo` | ...
        if (std.mem.indexOf(u8, line, "`todo`") != null or
            std.mem.indexOf(u8, line, "`in_progress`") != null or
            std.mem.indexOf(u8, line, "`implement`") != null or
            std.mem.indexOf(u8, line, "`research`") != null or
            std.mem.indexOf(u8, line, "`spec`") != null)
        {
            // Extract task filename from the line: look for `T-XXX-...md`
            const tick = std.mem.indexOfScalar(u8, line, '`') orelse continue;
            const after_tick = line[tick + 1 ..];
            const end_tick = std.mem.indexOfScalar(u8, after_tick, '`') orelse continue;
            const first_cell = after_tick[0..end_tick];

            // Check if it ends with .md
            if (std.mem.endsWith(u8, first_cell, ".md")) {
                return try arena.dupe(u8, first_cell);
            }
        }
    }
    return error.NoPendingTask;
}

// ============================================================================
// Tool 2: update_task_log
// ============================================================================

const UPDATE_TASK_LOG_NAME = "update_task_log";
const UPDATE_TASK_LOG_DESCRIPTION =
    \\Appends a timestamped log entry to the specified task file's Log section.
    \\Use this after each meaningful step during task execution.
    \\The sprint_dir is auto-detected from tasks/active/.
;

const UPDATE_TASK_LOG_SCHEMA =
    \\{
    \\  "type": "object",
    \\  "required": ["task_id", "message"],
    \\  "properties": {
    \\    "task_id": {
    \\      "type": "string",
    \\      "description": "Task ID (e.g., 'T-121')"
    \\    },
    \\    "message": {
    \\      "type": "string",
    \\      "description": "Log message to append"
    \\    },
    \\    "sprint_dir": {
    \\      "type": "string",
    \\      "description": "Override sprint directory (optional)"
    \\    }
    \\  }
    \\}
;

pub const update_task_log_definition = tool.Tool{
    .name = UPDATE_TASK_LOG_NAME,
    .description = UPDATE_TASK_LOG_DESCRIPTION,
    .parameters_json = UPDATE_TASK_LOG_SCHEMA,
};

pub const UpdateTaskLogContext = struct {};

pub fn createUpdateTaskLogTool(ctx: *UpdateTaskLogContext) tool.AgentTool {
    return .{
        .tool = update_task_log_definition,
        .execute_fn = struct {
            fn exec(ptr: *anyopaque, arena: std.mem.Allocator, args: std.json.Value) anyerror!tool.ToolResult {
                _ = ptr;
                return executeUpdateTaskLog(arena, args);
            }
        }.exec,
        .ctx = ctx,
    };
}

fn executeUpdateTaskLog(arena: std.mem.Allocator, args: std.json.Value) !tool.ToolResult {
    const task_id_val = args.object.get("task_id") orelse
        return tool.errorResult(arena, "Missing required parameter: task_id");
    const message_val = args.object.get("message") orelse
        return tool.errorResult(arena, "Missing required parameter: message");

    const task_id = task_id_val.string;
    const message = message_val.string;

    if (task_id.len == 0) return tool.errorResult(arena, "task_id cannot be empty");
    if (message.len == 0) return tool.errorResult(arena, "message cannot be empty");

    // Find the task file
    const sprint_dir_val = args.object.get("sprint_dir");
    const sprint_dir = if (sprint_dir_val) |v| v.string else null;

    const task_file = try findTaskFile(arena, task_id, sprint_dir);

    // Read existing content
    const existing = utils.readFileAlloc(arena, task_file, 256 * 1024) catch |err|
        return tool.errorResult(arena, try std.fmt.allocPrint(arena, "Failed to read task file: {s}", .{@errorName(err)}));

    // Generate timestamp using the current date (no time access needed for daily logs)
    const timestamp = try getCurrentTimestamp(arena);

    const log_entry = try std.fmt.allocPrint(arena, "- `{s}` — {s}\n", .{ timestamp, message });

    const modified = try appendToLogSection(arena, existing, log_entry);

    // Atomic write: write to tmp then rename
    const tmp_path = try std.fmt.allocPrint(arena, "{s}.tmp", .{task_file});
    try utils.writeFile(tmp_path, modified);
    try utils.rename(tmp_path, task_file);

    const response = try std.fmt.allocPrint(arena, "Log appended to {s}:\n{s}", .{ task_file, log_entry });
    return tool.textContent(arena, response);
}

fn findTaskFile(arena: std.mem.Allocator, task_id: []const u8, sprint_dir: ?[]const u8) ![]const u8 {
    const dir = sprint_dir orelse blk: {
        const latest = try detectLatestSprint(arena);
        break :blk latest;
    };

    const io = try utils.getIo();
    const tasks_dir = try utils.openDir(dir, .{ .iterate = true });
    defer tasks_dir.close(io);

    var it = tasks_dir.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".md")) continue;
        if (!std.mem.startsWith(u8, entry.name, task_id)) continue;

        return try std.fmt.allocPrint(arena, "{s}/{s}", .{ dir, entry.name });
    }

    return error.TaskFileNotFound;
}

fn getCurrentTimestamp(arena: std.mem.Allocator) ![]const u8 {
    const ts = utils.milliTimestamp();
    return std.fmt.allocPrint(arena, "{d}", .{ts});
}

fn appendToLogSection(arena: std.mem.Allocator, content: []const u8, entry: []const u8) ![]const u8 {
    var buf: std.ArrayList(u8) = .empty;

    const log_section = std.mem.indexOf(u8, content, "\n## Log\n") orelse
        std.mem.indexOf(u8, content, "\n## Log") orelse
        std.mem.indexOf(u8, content, "## Log\n") orelse
        null;

    if (log_section) |pos| {
        const after_section = content[pos + 6 ..];
        const next_heading = std.mem.indexOf(u8, after_section, "\n## ") orelse after_section.len;
        const insert_pos = pos + 6 + next_heading;

        try buf.appendSlice(arena, content[0..insert_pos]);
        try buf.append(arena, '\n');
        try buf.appendSlice(arena, entry);
        try buf.appendSlice(arena, content[insert_pos..]);
    } else {
        try buf.appendSlice(arena, content);
        try buf.appendSlice(arena, "\n\n## Log\n\n");
        try buf.appendSlice(arena, entry);
    }

    return try buf.toOwnedSlice(arena);
}

// ============================================================================
// Tool 3: sync_spec_with_code
// ============================================================================

const SYNC_SPEC_WITH_CODE_NAME = "sync_spec_with_code";
const SYNC_SPEC_WITH_CODE_DESCRIPTION =
    \\Compares a Technical Spec document with actual source code files
    \\to detect inconsistencies (missing implementations, renamed functions, etc.).
    \\Returns structured JSON with specific findings.
;

const SYNC_SPEC_WITH_CODE_SCHEMA =
    \\{
    \\  "type": "object",
    \\  "required": ["spec_path"],
    \\  "properties": {
    \\    "spec_path": {
    \\      "type": "string",
    \\      "description": "Path to the spec file (e.g., 'docs/specs/T-121-*.md')"
    \\    },
    \\    "code_paths": {
    \\      "type": "array",
    \\      "items": { "type": "string" },
    \\      "description": "List of code files to check against spec"
    \\    }
    \\  }
    \\}
;

pub const sync_spec_with_code_definition = tool.Tool{
    .name = SYNC_SPEC_WITH_CODE_NAME,
    .description = SYNC_SPEC_WITH_CODE_DESCRIPTION,
    .parameters_json = SYNC_SPEC_WITH_CODE_SCHEMA,
};

pub const SyncSpecWithCodeContext = struct {};

pub fn createSyncSpecWithCodeTool(ctx: *SyncSpecWithCodeContext) tool.AgentTool {
    return .{
        .tool = sync_spec_with_code_definition,
        .execute_fn = struct {
            fn exec(ptr: *anyopaque, arena: std.mem.Allocator, args: std.json.Value) anyerror!tool.ToolResult {
                _ = ptr;
                return executeSyncSpecWithCode(arena, args);
            }
        }.exec,
        .ctx = ctx,
    };
}

const Inconsistency = struct {
    type: []const u8,
    spec_reference: []const u8,
    code_path: []const u8,
    detail: []const u8,
};

fn executeSyncSpecWithCode(arena: std.mem.Allocator, args: std.json.Value) !tool.ToolResult {
    const spec_path_val = args.object.get("spec_path") orelse
        return tool.errorResult(arena, "Missing required parameter: spec_path");
    const spec_path = spec_path_val.string;

    // Read spec file
    const spec_content = utils.readFileAlloc(arena, spec_path, 256 * 1024) catch |err|
        return tool.errorResult(arena, try std.fmt.allocPrint(arena, "Failed to read spec file: {s}", .{@errorName(err)}));

    var inconsistencies: std.ArrayList(Inconsistency) = .empty;

    // Check 1: Files listed in "影响文件" table exist
    try checkExpectedFilesExist(arena, spec_content, &inconsistencies);

    // Check 2: Function identifiers in spec appear in code
    if (args.object.get("code_paths")) |paths_val| {
        if (paths_val == .array) {
            const arr = paths_val.array;
            var i: usize = 0;
            while (i < arr.items.len) : (i += 1) {
                const path_val = arr.items[i];
                if (path_val == .string) {
                    try checkSpecKeywordsInCode(arena, spec_content, path_val.string, &inconsistencies);
                }
            }
        }
    }

    // Build JSON response
    return try buildJsonReport(arena, inconsistencies.items);
}

fn checkExpectedFilesExist(
    arena: std.mem.Allocator,
    spec_content: []const u8,
    out: *std.ArrayList(Inconsistency),
) !void {
    var lines = std.mem.splitScalar(u8, spec_content, '\n');

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t");
        if (std.mem.startsWith(u8, trimmed, "| `src/") or
            std.mem.startsWith(u8, trimmed, "| `docs/"))
        {
            // Extract file path from markdown table cell
            const tick_start = std.mem.indexOfScalar(u8, line, '`') orelse continue;
            const after = line[tick_start + 1 ..];
            const tick_end = std.mem.indexOfScalar(u8, after, '`') orelse continue;
            const file_path = after[0..tick_end];

            if (!utils.fileExists(file_path)) {
                try out.append(arena,Inconsistency{
                    .type = "missing_file",
                    .spec_reference = file_path,
                    .code_path = file_path,
                    .detail = "File listed in spec's 影响文件 table does not exist",
                });
            }
        }
    }
}

fn checkSpecKeywordsInCode(
    arena: std.mem.Allocator,
    spec_content: []const u8,
    code_path: []const u8,
    out: *std.ArrayList(Inconsistency),
) !void {
    const code_content = utils.readFileAlloc(arena, code_path, 256 * 1024) catch {
        try out.append(arena,Inconsistency{
            .type = "unreadable_file",
            .spec_reference = code_path,
            .code_path = code_path,
            .detail = "Cannot read code file",
        });
        return;
    };

    // Extract function/struct identifiers from spec
    var lines = std.mem.splitScalar(u8, spec_content, '\n');
    while (lines.next()) |line| {
        // Look for `functionName` patterns in spec
        var remaining = line;
        while (std.mem.indexOfScalar(u8, remaining, '`')) |ts| {
            const after = remaining[ts + 1 ..];
            const te = std.mem.indexOfScalar(u8, after, '`') orelse break;
            const identifier = after[0..te];

            // Skip short/non-meaningful identifiers
            if (identifier.len < 5) {
                remaining = after[te..];
                continue;
            }

            // Check if this appears in code (simplified: just check if name is mentioned)
            if (std.mem.indexOf(u8, code_content, identifier) == null) {
                // Only report for function-like identifiers (camelCase or snake_case with parens)
                if (std.mem.indexOf(u8, line, "{d}") == null or
                    std.mem.indexOf(u8, line, "(") != null or
                    std.mem.indexOf(u8, line, "struct") != null)
                {
                    try out.append(arena,Inconsistency{
                        .type = "missing_identifier",
                        .spec_reference = identifier,
                        .code_path = code_path,
                        .detail = try std.fmt.allocPrint(arena, "Identifier `{s}` from spec not found in {s}", .{ identifier, code_path }),
                    });
                }
            }

            remaining = after[te..];
        }
    }
}

fn buildJsonReport(arena: std.mem.Allocator, items: []const Inconsistency) !tool.ToolResult {
    if (items.len == 0) {
        return tool.textContent(arena, "{\"inconsistencies\": [], \"status\": \"all_clear\"}");
    }

    // Build the JSON using a simple array of anonymous structs
    const ReportItem = struct {
        type: []const u8,
        spec_reference: []const u8,
        code_path: []const u8,
        detail: []const u8,
    };

    var report_items: std.ArrayList(ReportItem) = .empty;
    defer report_items.deinit(arena);

    for (items) |item| {
        try report_items.append(arena, ReportItem{
            .type = item.type,
            .spec_reference = item.spec_reference,
            .code_path = item.code_path,
            .detail = item.detail,
        });
    }

    const Report = struct {
        inconsistencies: []const ReportItem,
        total_issues: usize,
    };

    const report = Report{
        .inconsistencies = report_items.items,
        .total_issues = items.len,
    };

    return tool.textContent(arena, try std.json.Stringify.valueAlloc(arena, report, .{}));
}

// ============================================================================
// Tests
// ============================================================================

test "read_active_task tool definition" {
    try std.testing.expectEqualStrings("read_active_task", read_active_task_definition.name);
}

test "update_task_log tool definition" {
    try std.testing.expectEqualStrings("update_task_log", update_task_log_definition.name);
}

test "sync_spec_with_code tool definition" {
    try std.testing.expectEqualStrings("sync_spec_with_code", sync_spec_with_code_definition.name);
}

test "update_task_log detects sprint" {
    const allocator = std.testing.allocator;
    const sprint = try detectLatestSprint(allocator);
    defer allocator.free(sprint);
    try std.testing.expect(std.mem.startsWith(u8, sprint, "tasks/active/"));
}

test "update_task_log append to section" {
    const allocator = std.testing.allocator;

    const existing =
        \\# Task: T-121
        \\
        \\## Log
        \\
        \\- old entry
    ;

    const entry = "- new entry\n";
    const result = try appendToLogSection(allocator, existing, entry);
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "- old entry") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "- new entry") != null);
    // New entry should come before old entry in the Log section
    const new_pos = std.mem.indexOf(u8, result, "- new entry").?;
    const old_pos = std.mem.indexOf(u8, result, "- old entry").?;
    try std.testing.expect(new_pos < old_pos);
}

test "appendToLogSection creates section when missing" {
    const allocator = std.testing.allocator;

    const existing = "# Task: T-999\n\nNo log section here.";
    const entry = "- new entry\n";
    const result = try appendToLogSection(allocator, existing, entry);
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "## Log") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "- new entry") != null);
}

test "findFirstPendingTask parses README table" {
    const allocator = std.testing.allocator;

    const readme =
        \\| # | ID | Title | Status |
        \\|---|------|-------|--------|
        \\| 1 | T-090 | ~~old~~ | `done` |
        \\| 2 | T-121 | new task | `todo` |
        \\| 3 | T-122 | future | `todo` |
    ;

    const result = try findFirstPendingTask(allocator, readme);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("T-121", result[0..5]);
}

test "sync_spec_with_code detects missing file" {
    const allocator = std.testing.allocator;

    const spec =
        \\## 影响文件
        \\| 文件 | 改动 |
        \\| `src/xxx.zig` | description |
        \\| `zzz/no_such_file_12345.zig` | will not exist |
    ;

    var list = std.ArrayList(Inconsistency).init(allocator);
    defer list.deinit();

    try checkExpectedFilesExist(allocator, spec, &list);
    try std.testing.expect(list.items.len >= 1);
}
