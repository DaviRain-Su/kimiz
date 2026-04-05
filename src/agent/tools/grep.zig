//! Grep Tool - Search for patterns in files

const std = @import("std");
const tool = @import("../tool.zig");

pub const TOOL_NAME = "grep";

const TOOL_DESCRIPTION =
    \\Searches for a pattern in files using regular expressions.
    \\Returns matching lines with file names and line numbers.
    \\Example: {"pattern": "TODO|FIXME", "path": "/project/src", "glob": "*.zig"}
;

const PARAMETERS_SCHEMA =
    \\{
    \\  "type": "object",
    \\  "required": ["pattern"],
    \\  "properties": {
    \\    "pattern": {
    \\      "type": "string",
    \\      "description": "Regular expression pattern to search for"
    \\    },
    \\    "path": {
    \\      "type": "string",
    \\      "description": "Directory or file to search in (default: current directory)"
    \\    },
    \\    "glob": {
    \\      "type": "string",
    \\      "description": "File pattern to limit search (e.g., '*.zig', '*.md')"
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

    const parsed_args = tool.parseArguments(args, GrepArgs) catch {
        return tool.errorResult(arena, "Invalid arguments: expected {\"pattern\": \"...\"}");
    };

    if (parsed_args.pattern.len == 0) {
        return tool.errorResult(arena, "Pattern cannot be empty");
    }

    const search_path = parsed_args.path orelse ".";

    // Try to compile as regex
    const regex = std.regex.Regex.compile(arena, parsed_args.pattern) catch |err| {
        const err_msg = try std.fmt.allocPrint(arena, "Invalid regex pattern: {s}", .{@errorName(err)});
        return tool.errorResult(arena, err_msg);
    };
    defer regex.deinit();

    var matches = std.ArrayList(Match).init(arena);
    defer matches.deinit();

    // Check if search_path is a file or directory
    const stat = std.fs.cwd().statFile(search_path) catch |err| {
        if (err == error.IsDir) {
            // It's a directory, search recursively
            try searchDirectory(arena, search_path, parsed_args.glob, &regex, &matches);
        } else {
            const err_msg = try std.fmt.allocPrint(arena, "Failed to access path: {s}", .{@errorName(err)});
            return tool.errorResult(arena, err_msg);
        }
    };
    _ = stat;

    if (matches.items.len == 0) {
        return tool.textContent(arena, "No matches found");
    }

    // Format results
    var result = std.ArrayList(u8).init(arena);
    defer result.deinit();

    for (matches.items, 0..) |match, i| {
        if (i > 0) try result.append('\n');
        try std.fmt.format(result.writer(), "{s}:{d}: {s}", .{ match.file_path, match.line_num, match.line_content });
    }

    return tool.textContent(arena, result.items);
}

const Match = struct {
    file_path: []const u8,
    line_num: usize,
    line_content: []const u8,
};

fn searchDirectory(
    arena: std.mem.Allocator,
    dir_path: []const u8,
    glob_pattern: ?[]const u8,
    regex: *const std.regex.Regex,
    matches: *std.ArrayList(Match),
) !void {
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(arena);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;

        // Check glob pattern if specified
        if (glob_pattern) |pattern| {
            if (!globMatch(pattern, entry.basename)) continue;
        }

        const full_path = try std.fs.path.join(arena, &[_][]const u8{ dir_path, entry.path });
        try searchFile(arena, full_path, regex, matches);
    }
}

fn searchFile(
    arena: std.mem.Allocator,
    file_path: []const u8,
    regex: *const std.regex.Regex,
    matches: *std.ArrayList(Match),
) !void {
    const content = std.fs.cwd().readFileAlloc(arena, file_path, 10 * 1024 * 1024) catch |err| {
        if (err == error.IsDir) return;
        return;
    };
    defer arena.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    var line_num: usize = 1;

    while (lines.next()) |line| {
        if (regex.match(line)) {
            try matches.append(.{
                .file_path = file_path,
                .line_num = line_num,
                .line_content = try arena.dupe(u8, line),
            });
        }
        line_num += 1;
    }
}

/// Simple glob matching
fn globMatch(pattern: []const u8, text: []const u8) bool {
    var p: usize = 0;
    var t: usize = 0;
    var star: ?usize = null;
    var match: usize = 0;

    while (t < text.len) {
        if (p < pattern.len and (pattern[p] == text[t] or pattern[p] == '?')) {
            p += 1;
            t += 1;
        } else if (p < pattern.len and pattern[p] == '*') {
            star = p;
            match = t;
            p += 1;
        } else if (star != null) {
            p = star.? + 1;
            match += 1;
            t = match;
        } else {
            return false;
        }
    }

    while (p < pattern.len and pattern[p] == '*') {
        p += 1;
    }

    return p == pattern.len;
}

// ============================================================================
// Tests
// ============================================================================

test "tool definition" {
    try std.testing.expectEqualStrings("grep", tool_definition.name);
}
