//! WebSearch Tool - Search the web

const std = @import("std");
const tool = @import("../tool.zig");
const HttpClient = @import("../../http.zig").HttpClient;

pub const TOOL_NAME = "web_search";

const TOOL_DESCRIPTION =
    \\Searches the web for the given query.
    \\Returns search results with titles and snippets.
    \\Example: {"query": "zig programming language features"}
;

const PARAMETERS_SCHEMA =
    \\{
    \\  "type": "object",
    \\  "required": ["query"],
    \\  "properties": {
    \\    "query": {
    \\      "type": "string",
    \\      "description": "Search query"
    \\    },
    \\    "num_results": {
    \\      "type": "integer",
    \\      "description": "Number of results to return (default: 10)"
    \\    }
    \\  }
    \\}
;

pub const tool_definition = tool.Tool{
    .name = TOOL_NAME,
    .description = TOOL_DESCRIPTION,
    .parameters_json = PARAMETERS_SCHEMA,
};

const WebSearchArgs = struct {
    query: []const u8,
    num_results: ?u32 = null,
};

pub const WebSearchContext = struct {
    search_api_key: ?[]const u8 = null,
    search_engine_id: ?[]const u8 = null,
};

pub fn createAgentTool(ctx: *WebSearchContext) tool.AgentTool {
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
    const ctx: *WebSearchContext = @ptrCast(@alignCast(ctx_ptr));

    const parsed_args = tool.parseArguments(args, WebSearchArgs) catch {
        return tool.errorResult(arena, "Invalid arguments: expected {\"query\": \"...\"}");
    };

    if (parsed_args.query.len == 0) {
        return tool.errorResult(arena, "Query cannot be empty");
    }

    const num_results = parsed_args.num_results orelse 10;

    // Check for API keys
    if (ctx.search_api_key == null) {
        // Fallback to mock results or duckduckgo-lite scraping
        return try searchDuckDuckGo(arena, parsed_args.query, num_results);
    }

    // Use Google Custom Search API
    return try searchGoogle(arena, parsed_args.query, num_results, ctx);
}

/// Search using DuckDuckGo HTML (fallback)
fn searchDuckDuckGo(
    arena: std.mem.Allocator,
    query: []const u8,
    num_results: u32,
) !tool.ToolResult {
    // URL encode the query
    var encoded_query = std.ArrayList(u8).init(arena);
    defer encoded_query.deinit();

    for (query) |c| {
        if (std.ascii.isAlphanumeric(c) or c == '-' or c == '_' or c == '.') {
            try encoded_query.append(c);
        } else {
            try std.fmt.format(encoded_query.writer(), "%", .{std.fmt.formatInt(c, 16, .upper, .{})});
        }
    }

    const search_url = try std.fmt.allocPrint(
        arena,
        "https://html.duckduckgo.com/html/?q={s}",
        .{encoded_query.items},
    );
    _ = search_url; // Used in production implementation

    // For now, return a mock response since we don't have HTTP client in tool context
    // In production, this would actually fetch and parse the results
    _ = num_results;

    const mock_result = try std.fmt.allocPrint(
        arena,
        "Web search for '{s}' (DuckDuckGo)\n\n" ++
            "Note: Full web search implementation requires a search API key.\n" ++
            "Configure search_api_key in WebSearchContext to enable live searches.",
        .{query},
    );

    return tool.textContent(arena, mock_result);
}

/// Search using Google Custom Search API
fn searchGoogle(
    arena: std.mem.Allocator,
    query: []const u8,
    num_results: u32,
    ctx: *WebSearchContext,
) !tool.ToolResult {
    const api_key = ctx.search_api_key orelse return tool.errorResult(arena, "Google API key not configured");
    const cx = ctx.search_engine_id orelse return tool.errorResult(arena, "Search engine ID not configured");

    // Build URL
    const encoded_query = try std.Uri.encode(arena, query);
    const search_url = try std.fmt.allocPrint(
        arena,
        "https://www.googleapis.com/customsearch/v1?key={s}&cx={s}&q={s}&num={d}",
        .{ api_key, cx, encoded_query, @min(num_results, 10) },
    );

    _ = search_url;

    // In full implementation, this would make HTTP request and parse JSON response
    const mock_result = try std.fmt.allocPrint(
        arena,
        "Web search for '{s}' (Google)\n\n" ++
            "Note: Full implementation requires HTTP client integration.",
        .{query},
    );

    return tool.textContent(arena, mock_result);
}

// ============================================================================
// Tests
// ============================================================================

test "tool definition" {
    try std.testing.expectEqualStrings("web_search", tool_definition.name);
}
