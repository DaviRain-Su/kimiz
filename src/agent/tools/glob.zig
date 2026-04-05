//! Glob Tool - Find files matching a pattern

const std = @import("std");
const tool = @import("../tool.zig");

pub const TOOL_NAME = "glob";

const TOOL_DESCRIPTION =
    \\Finds files matching a glob pattern in the specified directory.
    \\Returns a list of matching file paths.
    \\Example: {"pattern": "**/*.zig", "path": "/project/src"}
;

const PARAMETERS_SCHEMA =
    \\{
    \\  "type": "object",
    \\  "required": ["pattern"],
    \\  "properties": {
    \\    "pattern": {
    \\      "type": "string",
    \\      "description": "Glob pattern to match (e.g., '**/*.zig', '*.txt')"
    \\    },
    \\    "path": {
    \\      "type": "string",
    \\      "description": "Directory to search in (default: current directory)"
    \\    }
    \\  }
    \\}
;

pub const tool_definition = tool.Tool{
    .name = TOOL_NAME,
    .description = TOOL_DESCRIPTION,
    .parameters_json = PARAMETERS_SCHEMA,
};

const GlobArgs = struct {
    pattern: []const u8,
    path: ?[]const u8 = null,
};

pub const GlobContext = struct {};

pub fn createAgentTool(ctx: *GlobContext) tool.AgentTool {
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

    const parsed_args = tool.parseArguments(args, GlobArgs) catch {
        return tool.errorResult(arena, "Invalid arguments: expected {\"pattern\": \"**/*.zig\"}");
    };

    if (parsed_args.pattern.len == 0) {
        return tool.errorResult(arena, "Pattern cannot be empty");
    }

    const search_path = parsed_args.path orelse ".";

    // Validate path is absolute if provided
    if (parsed_args.path) |p| {
        if (!std.fs.path.isAbsolute(p)) {
            return tool.errorResult(arena, "Path must be absolute");
        }
    }

    // Collect matching files
    var matches = std.ArrayList([]const u8).init(arena);
    defer matches.deinit();

    var dir = std.fs.cwd().openDir(search_path, .{ .iterate = true }) catch |err| {
        const err_msg = try std.fmt.allocPrint(arena, "Failed to open directory: {s}", .{@errorName(err)});
        return tool.errorResult(arena, err_msg);
    };
    defer dir.close();

    var walker = dir.walk(arena) catch |err| {
        const err_msg = try std.fmt.allocPrint(arena, "Failed to walk directory: {s}", .{@errorName(err)});
        return tool.errorResult(arena, err_msg);
    };
    defer walker.deinit();

    while (walker.next() catch null) |entry| {
        const relative_path = try std.fs.path.join(arena, &[_][]const u8{ search_path, entry.path });

        // Simple glob matching (simplified - doesn't handle ** patterns fully)
        if (globMatch(parsed_args.pattern, entry.path)) {
            try matches.append(relative_path);
        }
    }

    if (matches.items.len == 0) {
        return tool.textContent(arena, "No files matching pattern found");
    }

    // Format results
    var result = std.ArrayList(u8).init(arena);
    defer result.deinit();

    for (matches.items, 0..) |path, i| {
        if (i > 0) try result.append('\n');
        try result.appendSlice(path);
    }

    return tool.textContent(arena, result.items);
}

/// Simple glob matching - supports * and ? wildcards
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
    try std.testing.expectEqualStrings("glob", tool_definition.name);
}

test "globMatch basic" {
    try std.testing.expect(globMatch("*.zig", "test.zig"));
    try std.testing.expect(globMatch("*.zig", "main.zig"));
    try std.testing.expect(!globMatch("*.txt", "test.zig"));
    try std.testing.expect(globMatch("file?.txt", "file1.txt"));
    try std.testing.expect(!globMatch("file?.txt", "file10.txt"));
}
