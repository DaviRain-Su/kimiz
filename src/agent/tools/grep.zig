//! Grep Tool - Search for patterns in files
//! Uses system grep/rg for reliable pattern matching

const std = @import("std");
const tool = @import("../tool.zig");

pub const TOOL_NAME = "grep";

const TOOL_DESCRIPTION =
    \\Search for a pattern in files. Returns matching lines with file paths and line numbers.
    \\Example: {"pattern": "TODO", "path": "/path/to/dir"}
;

const PARAMETERS_SCHEMA =
    \\{
    \\  "type": "object",
    \\  "required": ["pattern"],
    \\  "properties": {
    \\    "pattern": {
    \\      "type": "string",
    \\      "description": "Pattern to search for (literal string or regex)"
    \\    },
    \\    "path": {
    \\      "type": "string",
    \\      "description": "Path to search in (file or directory, defaults to current directory)"
    \\    },
    \\    "glob": {
    \\      "type": "string",
    \\      "description": "Glob pattern to filter files (e.g. \"*.zig\")"
    \\    }
    \\  }
    \\}
;

pub const tool_definition = tool.Tool{
    .name = TOOL_NAME,
    .description = TOOL_DESCRIPTION,
    .parameters_json = PARAMETERS_SCHEMA,
};

const GrepArgs = struct {
    pattern: []const u8,
    path: ?[]const u8 = null,
    glob: ?[]const u8 = null,
};

pub const GrepContext = struct {};

pub fn createAgentTool(ctx: *GrepContext) tool.AgentTool {
    return tool.AgentTool{
        .tool = tool_definition,
        .execute_fn = execute,
        .ctx = ctx,
    };
}

fn execute(
    ctx: *anyopaque,
    arena: std.mem.Allocator,
    args: std.json.Value,
) anyerror!tool.ToolResult {
    _ = ctx;

    const parsed_args = tool.parseArguments(arena, args, GrepArgs) catch {
        return tool.errorResult(arena, "Invalid arguments: expected {\"pattern\": \"...\"}");
    };

    if (parsed_args.pattern.len == 0) {
        return tool.errorResult(arena, "Pattern cannot be empty");
    }

    const search_path = parsed_args.path orelse ".";
    const file_io = @import("file_io.zig");

    // If path is a file, do in-process search
    const content = file_io.readFileAlloc(arena, search_path, 10 * 1024 * 1024) catch {
        // Not a file or can't read -- treat as directory, fall through to grep
        return runGrepCommand(arena, parsed_args.pattern, search_path, parsed_args.glob);
    };

    // Search in single file
    var result_buf: std.ArrayList(u8) = .empty;
    defer result_buf.deinit(arena);
    var line_num: usize = 1;
    var iter = std.mem.splitScalar(u8, content, '\n');
    while (iter.next()) |line| {
        if (std.mem.indexOf(u8, line, parsed_args.pattern) != null) {
            if (result_buf.items.len > 0) try result_buf.append(arena, '\n');
            const formatted = try std.fmt.allocPrint(arena, "{s}:{d}: {s}", .{ search_path, line_num, line });
            try result_buf.appendSlice(arena, formatted);
        }
        line_num += 1;
    }

    if (result_buf.items.len == 0) {
        return tool.textContent(arena, "No matches found");
    }
    return tool.textContent(arena, try arena.dupe(u8, result_buf.items));
}

fn runGrepCommand(
    arena: std.mem.Allocator,
    pattern: []const u8,
    path: []const u8,
    glob: ?[]const u8,
) !tool.ToolResult {
    var cmd_buf: std.ArrayList(u8) = .empty;
    defer cmd_buf.deinit(arena);

    // Use grep -rn (available on all Unix)
    try cmd_buf.appendSlice(arena, "grep -rn ");
    if (glob) |g| {
        try cmd_buf.appendSlice(arena, "--include='");
        try cmd_buf.appendSlice(arena, g);
        try cmd_buf.appendSlice(arena, "' ");
    }
    try cmd_buf.appendSlice(arena, "-- '");
    // Escape single quotes in pattern
    for (pattern) |ch| {
        if (ch == '\'') {
            try cmd_buf.appendSlice(arena, "'\\\"'\\'\"'\\\"\''");
        } else {
            try cmd_buf.append(arena, ch);
        }
    }
    try cmd_buf.appendSlice(arena, "' '");
    try cmd_buf.appendSlice(arena, path);
    try cmd_buf.appendSlice(arena, "' 2>/dev/null | head -100");

    // Execute via /bin/sh
    const cc = @cImport({ @cInclude("stdlib.h"); @cInclude("stdio.h"); });
    const c_cmd = try arena.dupeZ(u8, cmd_buf.items);
    const pipe = cc.popen(c_cmd.ptr, "r") orelse {
        return tool.errorResult(arena, "Failed to execute grep");
    };
    defer _ = cc.pclose(pipe);

    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(arena);
    var read_buf: [4096]u8 = undefined;
    while (true) {
        const n = cc.fread(&read_buf, 1, read_buf.len, pipe);
        if (n == 0) break;
        try output.appendSlice(arena, read_buf[0..n]);
    }

    if (output.items.len == 0) {
        return tool.textContent(arena, "No matches found");
    }
    return tool.textContent(arena, try arena.dupe(u8, output.items));
}

test "tool definition" {
    try std.testing.expectEqualStrings("grep", tool_definition.name);
}
