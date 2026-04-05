//! FFF Tool - Fast Fuzzy File Finder
//! High-performance search powered by libfff_c
//! Supports: fuzzy file search, content grep, multi-pattern grep

const std = @import("std");
const tool = @import("../tool.zig");
const fff = @import("../../ffi/fff.zig");

pub const TOOL_NAME = "grep";

const TOOL_DESCRIPTION =
    \\Search for patterns in files using fff (Fast Fuzzy Finder).
    \\Supports plain text, regex, and fuzzy matching.
    \\Returns matching lines with file paths and line numbers.
    \\Example: {"pattern": "TODO", "path": "/path/to/dir"}
;

const PARAMETERS_SCHEMA =
    \\{
    \\  "type": "object",
    \\  "required": ["pattern"],
    \\  "properties": {
    \\    "pattern": {
    \\      "type": "string",
    \\      "description": "Pattern to search for (supports plain text, regex, and fuzzy matching)"
    \\    },
    \\    "path": {
    \\      "type": "string",
    \\      "description": "Directory to search in (defaults to project root)"
    \\    },
    \\    "mode": {
    \\      "type": "string",
    \\      "enum": ["plain", "regex", "fuzzy"],
    \\      "description": "Search mode: plain (SIMD-accelerated), regex, or fuzzy (default: plain)"
    \\    },
    \\    "max_results": {
    \\      "type": "integer",
    \\      "description": "Maximum number of results (default: 50)"
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
    mode: ?[]const u8 = null,
    max_results: ?u32 = null,
};

pub const FFFGrepContext = struct {
    project_path: []const u8 = ".",
};

pub fn createAgentTool(ctx: *FFFGrepContext) tool.AgentTool {
    return tool.AgentTool{
        .tool = tool_definition,
        .execute_fn = execute,
        .ctx = ctx,
    };
}

fn execute(
    ctx_ptr: *anyopaque,
    arena: std.mem.Allocator,
    args: std.json.Value,
) anyerror!tool.ToolResult {
    const ctx: *FFFGrepContext = @ptrCast(@alignCast(ctx_ptr));

    const parsed_args = tool.parseArguments(arena, args, GrepArgs) catch {
        return tool.errorResult(arena, "Invalid arguments: expected {\"pattern\": \"...\"}");
    };

    if (parsed_args.pattern.len == 0) {
        return tool.errorResult(arena, "Pattern cannot be empty");
    }

    const search_path = parsed_args.path orelse ctx.project_path;

    // Determine search mode
    const mode: u8 = if (parsed_args.mode) |m| blk: {
        if (std.mem.eql(u8, m, "regex")) break :blk 1;
        if (std.mem.eql(u8, m, "fuzzy")) break :blk 2;
        break :blk 0; // plain
    } else 0;

    const max_results = parsed_args.max_results orelse 50;

    // Create fff instance for the search path
    var instance = fff.FFFInstance.init(arena, search_path) catch |err| {
        const err_msg = try std.fmt.allocPrint(arena, "Failed to initialize fff: {s}", .{@errorName(err)});
        return tool.errorResult(arena, err_msg);
    };
    defer instance.deinit();

    // Wait for initial scan (up to 5 seconds)
    _ = instance.waitForScan(5000) catch {};

    // Perform grep
    const result = instance.grep(arena, parsed_args.pattern, .{
        .mode = mode,
        .max_results = max_results,
        .context_before = 0,
        .context_after = 0,
    }) catch |err| {
        const err_msg = try std.fmt.allocPrint(arena, "Search failed: {s}", .{@errorName(err)});
        return tool.errorResult(arena, err_msg);
    };

    if (result.matches.len == 0) {
        return tool.textContent(arena, "No matches found");
    }

    // Format results grouped by file
    const formatted = try groupGrepResults(arena, result.matches);

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(arena);
    try buf.appendSlice(arena, formatted);

    if (result.total_matched > result.matches.len) {
        const summary = try std.fmt.allocPrint(arena, "\n... {d} total matches ({d} shown)", .{
            result.total_matched,
            result.matches.len,
        });
        try buf.appendSlice(arena, summary);
    }

    return tool.textContent(arena, try arena.dupe(u8, buf.items));
}

/// Group grep results by file path for better readability
fn groupGrepResults(arena: std.mem.Allocator, matches: []const fff.GrepMatch) ![]u8 {
    var groups = std.StringHashMap(std.ArrayList([]const u8)).init(arena);
    defer {
        var iter = groups.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit(arena);
        }
        groups.deinit();
    }

    for (matches) |m| {
        const line = try std.fmt.allocPrint(arena, "{d}: {s}", .{ m.line_number, m.line_content });
        const entry = try groups.getOrPut(m.path);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList([]const u8).empty;
        }
        try entry.value_ptr.append(arena, line);
    }

    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(arena);

    var iter = groups.iterator();
    var first = true;
    while (iter.next()) |entry| {
        if (!first) try result.append(arena, '\n');
        first = false;
        try result.appendSlice(arena, try std.fmt.allocPrint(arena, "{s} ({d} matches):\n", .{ entry.key_ptr.*, entry.value_ptr.items.len }));
        for (entry.value_ptr.items) |match| {
            try result.appendSlice(arena, try std.fmt.allocPrint(arena, "  {s}\n", .{match}));
        }
    }

    return try result.toOwnedSlice(arena);
}

// ============================================================================
// File search tool (fff_search)
// ============================================================================

pub const FILE_SEARCH_NAME = "file_search";

const FILE_SEARCH_DESCRIPTION =
    \\Fuzzy file search with smart ranking, typo correction, and frecency.
    \\Finds files by name across the project. Much faster than glob.
    \\Example: {"query": "main.zig"} or {"query": "agnt"} (finds agent.zig)
;

const FILE_SEARCH_SCHEMA =
    \\{
    \\  "type": "object",
    \\  "required": ["query"],
    \\  "properties": {
    \\    "query": {
    \\      "type": "string",
    \\      "description": "File name or fuzzy query (supports typos)"
    \\    },
    \\    "max_results": {
    \\      "type": "integer",
    \\      "description": "Maximum number of results (default: 20)"
    \\    }
    \\  }
    \\}
;

pub const file_search_definition = tool.Tool{
    .name = FILE_SEARCH_NAME,
    .description = FILE_SEARCH_DESCRIPTION,
    .parameters_json = FILE_SEARCH_SCHEMA,
};

pub fn createFileSearchTool(ctx: *FFFGrepContext) tool.AgentTool {
    return tool.AgentTool{
        .tool = file_search_definition,
        .execute_fn = executeFileSearch,
        .ctx = ctx,
    };
}

fn executeFileSearch(
    ctx_ptr: *anyopaque,
    arena: std.mem.Allocator,
    args: std.json.Value,
) anyerror!tool.ToolResult {
    const ctx: *FFFGrepContext = @ptrCast(@alignCast(ctx_ptr));

    const parsed = tool.parseArguments(arena, args, struct {
        query: []const u8,
        max_results: ?u32 = null,
    }) catch {
        return tool.errorResult(arena, "Invalid arguments: expected {\"query\": \"...\"}");
    };

    if (parsed.query.len == 0) {
        return tool.errorResult(arena, "Query cannot be empty");
    }

    var instance = fff.FFFInstance.init(arena, ctx.project_path) catch |err| {
        const err_msg = try std.fmt.allocPrint(arena, "Failed to initialize fff: {s}", .{@errorName(err)});
        return tool.errorResult(arena, err_msg);
    };
    defer instance.deinit();

    _ = instance.waitForScan(5000) catch {};

    const result = instance.search(arena, parsed.query, parsed.max_results orelse 20) catch |err| {
        const err_msg = try std.fmt.allocPrint(arena, "File search failed: {s}", .{@errorName(err)});
        return tool.errorResult(arena, err_msg);
    };

    if (result.items.len == 0) {
        return tool.textContent(arena, "No files found");
    }

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(arena);

    for (result.items, 0..) |item, i| {
        if (i > 0) try buf.append(arena, '\n');
        const line = try std.fmt.allocPrint(arena, "{d}. {s} (score: {d})", .{
            i + 1,
            item.relative_path,
            item.score,
        });
        try buf.appendSlice(arena, line);
    }

    const summary = try std.fmt.allocPrint(arena, "\n\nFound {d} files (out of {d} indexed)", .{
        result.total_matched,
        result.total_files,
    });
    try buf.appendSlice(arena, summary);

    return tool.textContent(arena, try arena.dupe(u8, buf.items));
}

test "tool definition" {
    try std.testing.expectEqualStrings("grep", tool_definition.name);
    try std.testing.expectEqualStrings("file_search", file_search_definition.name);
}
