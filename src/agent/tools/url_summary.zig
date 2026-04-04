//! URL Summary Tool
//! Takes a URL and outputs its content in markdown format
//! Similar to FetchURL but with markdown output format

const std = @import("std");
const tool = @import("../tool.zig");
const Tool = tool.Tool;
const AgentTool = tool.AgentTool;
const ToolResult = tool.ToolResult;
const ToolError = tool.ToolError;
const UserContentBlock = tool.UserContentBlock;

/// Tool name constant
pub const TOOL_NAME = "url_summary";

/// Tool description
const TOOL_DESCRIPTION =
    \\Fetches content from a URL and converts it to markdown format.
    \\Returns the extracted text content formatted as markdown.
    \\Supports HTML pages and plain text.
    \\Example: {"url": "https://example.com/article"}
;

/// JSON schema for tool parameters
const PARAMETERS_SCHEMA =
    \\{
    \\  "type": "object",
    \\  "required": ["url"],
    \\  "properties": {
    \\    "url": {
    \\      "type": "string",
    \\      "description": "The URL to fetch and summarize"
    \\    }
    \\  }
    \\}
;

/// Tool definition instance
pub const tool_definition = Tool{
    .name = TOOL_NAME,
    .description = TOOL_DESCRIPTION,
    .parameters_json = PARAMETERS_SCHEMA,
};

/// Arguments structure for the tool
const UrlSummaryArgs = struct {
    url: []const u8,
};

/// URL Summary tool context
pub const UrlSummaryContext = struct {
    // Can be extended with configuration like:
    // - timeout settings
    // - max content size
    // - user agent string
};

/// Create an AgentTool instance for URL Summary
pub fn createAgentTool(ctx: *UrlSummaryContext) AgentTool {
    return AgentTool{
        .tool = tool_definition,
        .execute_fn = execute,
        .ctx = ctx,
    };
}

/// Main execution function for URL Summary tool
fn execute(
    ctx: *anyopaque,
    arena: std.mem.Allocator,
    args: std.json.Value,
) anyerror!ToolResult {
    _ = ctx; // Context available for future extensions

    // Parse arguments
    const parsed_args = tool.parseArguments(args, UrlSummaryArgs) catch |err| {
        std.log.err("Failed to parse URL Summary arguments: {s}", .{@errorName(err)});
        return tool.errorResult(arena, "Invalid arguments: expected {\"url\": \"https://...\"}");
    };

    // Validate URL
    if (parsed_args.url.len == 0) {
        return tool.errorResult(arena, "URL cannot be empty");
    }

    // Basic URL validation (must start with http:// or https://)
    if (!std.mem.startsWith(u8, parsed_args.url, "http://") and
        !std.mem.startsWith(u8, parsed_args.url, "https://"))
    {
        return tool.errorResult(arena, "URL must start with http:// or https://");
    }

    // Fetch the URL content
    const content = fetchUrlContent(arena, parsed_args.url) catch |err| {
        std.log.err("Failed to fetch URL {s}: {s}", .{ parsed_args.url, @errorName(err) });
        return tool.errorResult(arena, try std.fmt.allocPrint(arena, "Failed to fetch URL: {s}", .{@errorName(err)}));
    };
    defer arena.free(content);

    // Convert to markdown
    const markdown = htmlToMarkdown(arena, content) catch |err| {
        std.log.err("Failed to convert content to markdown: {s}", .{@errorName(err)});
        return tool.errorResult(arena, "Failed to convert content to markdown");
    };

    return tool.textContent(arena, markdown);
}

/// Fetch content from a URL
/// Uses std.http.Client for the HTTP request
fn fetchUrlContent(arena: std.mem.Allocator, url: []const u8) ![]u8 {
    // Parse the URL
    const uri = std.Uri.parse(url) catch |err| {
        std.log.err("Failed to parse URL {s}: {s}", .{ url, @errorName(err) });
        return ToolError.NetworkError;
    };

    // Create HTTP client
    var client = std.http.Client{ .allocator = arena };
    defer client.deinit();

    // Setup connection headers
    var headers = std.http.Headers{ .allocator = arena };
    defer headers.deinit();
    try headers.append("User-Agent", "kimiz-url-summary/0.1.0");
    try headers.append("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");

    // Make the request
    var request = client.request(uri, .{
        .method = .GET,
        .headers = headers,
    }, .{}) catch |err| {
        std.log.err("HTTP request failed: {s}", .{@errorName(err)});
        return ToolError.NetworkError;
    };
    defer request.deinit();

    // Check response status
    if (request.response.status != .ok) {
        std.log.err("HTTP request returned status: {d}", .{@intFromEnum(request.response.status)});
        return ToolError.NetworkError;
    }

    // Read response body with size limit (1MB max)
    const max_size = 1 * 1024 * 1024; // 1MB
    var body = std.ArrayList(u8).init(arena);
    defer body.deinit();

    var buf: [4096]u8 = undefined;
    var total_read: usize = 0;

    while (true) {
        const bytes_read = request.read(&buf) catch |err| {
            std.log.err("Failed to read response: {s}", .{@errorName(err)});
            return ToolError.NetworkError;
        };
        if (bytes_read == 0) break;

        total_read += bytes_read;
        if (total_read > max_size) {
            std.log.warn("Content exceeds 1MB limit, truncating");
            break;
        }

        try body.appendSlice(buf[0..bytes_read]);
    }

    return body.toOwnedSlice();
}

/// Convert HTML content to markdown format
/// This is a simple implementation that extracts text and adds basic formatting
fn htmlToMarkdown(arena: std.mem.Allocator, html: []const u8) ![]u8 {
    // For now, implement a simple HTML-to-text converter
    // In production, this could use a proper HTML parser

    var result = std.ArrayList(u8).init(arena);
    defer result.deinit();

    var i: usize = 0;
    var in_tag = false;
    var in_script = false;
    var last_was_space = true; // Track to avoid double spaces

    // Simple state machine to extract text from HTML
    while (i < html.len) {
        const c = html[i];

        // Check for script/style tags to skip
        if (i + 7 < html.len and std.mem.eql(u8, html[i..i + 7], "<script")) {
            in_script = true;
        } else if (i + 9 < html.len and std.mem.eql(u8, html[i..i + 9], "</script>")) {
            in_script = false;
            i += 9;
            continue;
        } else if (i + 6 < html.len and std.mem.eql(u8, html[i..i + 6], "<style")) {
            in_script = true;
        } else if (i + 8 < html.len and std.mem.eql(u8, html[i..i + 8], "</style>")) {
            in_script = false;
            i += 8;
            continue;
        }

        if (in_script) {
            i += 1;
            continue;
        }

        // Handle HTML tags
        if (c == '<') {
            in_tag = true;
            // Check for block-level tags that need newlines
            if (i + 2 < html.len and (html[i + 1] == 'p' or html[i + 1] == 'P') and
                (html[i + 2] == '>' or html[i + 2] == ' '))
            {
                if (!last_was_space) {
                    try result.append('\n');
                    last_was_space = true;
                }
            }
            if (i + 3 < html.len and (std.mem.eql(u8, html[i..i + 3], "<br") or
                std.mem.eql(u8, html[i..i + 3], "<BR") or
                std.mem.eql(u8, html[i..i + 3], "<h1") or
                std.mem.eql(u8, html[i..i + 3], "<H1") or
                std.mem.eql(u8, html[i..i + 3], "<h2") or
                std.mem.eql(u8, html[i..i + 3], "<H2") or
                std.mem.eql(u8, html[i..i + 3], "<h3") or
                std.mem.eql(u8, html[i..i + 3], "<H3") or
                std.mem.eql(u8, html[i..i + 3], "<li") or
                std.mem.eql(u8, html[i..i + 3], "<LI") or
                std.mem.eql(u8, html[i..i + 3], "<tr") or
                std.mem.eql(u8, html[i..i + 3], "<TR")))
            {
                if (!last_was_space) {
                    try result.append('\n');
                    last_was_space = true;
                }
            }
            if (i + 4 < html.len and (std.mem.eql(u8, html[i..i + 4], "<div") or
                std.mem.eql(u8, html[i..i + 4], "<DIV")))
            {
                if (!last_was_space) {
                    try result.append('\n');
                    last_was_space = true;
                }
            }
        } else if (c == '>') {
            in_tag = false;
        } else if (!in_tag) {
            // Convert HTML entities (basic ones)
            if (c == '&') {
                if (i + 4 < html.len and std.mem.eql(u8, html[i..i + 4], "&lt;")) {
                    try result.append('<');
                    i += 4;
                    last_was_space = false;
                    continue;
                } else if (i + 4 < html.len and std.mem.eql(u8, html[i..i + 4], "&gt;")) {
                    try result.append('>');
                    i += 4;
                    last_was_space = false;
                    continue;
                } else if (i + 5 < html.len and std.mem.eql(u8, html[i..i + 5], "&amp;")) {
                    try result.append('&');
                    i += 5;
                    last_was_space = false;
                    continue;
                } else if (i + 6 < html.len and std.mem.eql(u8, html[i..i + 6], "&nbsp;")) {
                    try result.append(' ');
                    i += 6;
                    last_was_space = true;
                    continue;
                }
            }

            // Normalize whitespace
            if (c == ' ' or c == '\t' or c == '\r' or c == '\n') {
                if (!last_was_space) {
                    try result.append(' ');
                    last_was_space = true;
                }
            } else {
                try result.append(c);
                last_was_space = false;
            }
        }

        i += 1;
    }

    // Trim trailing whitespace
    const output = try result.toOwnedSlice();
    var end = output.len;
    while (end > 0 and (output[end - 1] == ' ' or output[end - 1] == '\n')) {
        end -= 1;
    }

    // Add final newline
    if (end > 0) {
        const trimmed = try arena.dupe(u8, output[0..end]);
        return trimmed;
    }

    return "";
}

// ============================================================================
// Tests
// ============================================================================

test "htmlToMarkdown basic extraction" {
    const arena = std.testing.allocator;

    const html = "<html><body><h1>Title</h1><p>Hello World</p></body></html>";
    const result = try htmlToMarkdown(arena, html);
    defer arena.free(result);

    try std.testing.expect(std.mem.containsAtLeast(u8, result, 1, "Title"));
    try std.testing.expect(std.mem.containsAtLeast(u8, result, 1, "Hello World"));
}

test "htmlToMarkdown strips scripts" {
    const arena = std.testing.allocator;

    const html = "<p>Before</p><script>alert('test');</script><p>After</p>";
    const result = try htmlToMarkdown(arena, html);
    defer arena.free(result);

    try std.testing.expect(std.mem.containsAtLeast(u8, result, 1, "Before"));
    try std.testing.expect(std.mem.containsAtLeast(u8, result, 1, "After"));
    try std.testing.expect(!std.mem.containsAtLeast(u8, result, 1, "alert"));
    try std.testing.expect(!std.mem.containsAtLeast(u8, result, 1, "script"));
}

test "htmlToMarkdown handles entities" {
    const arena = std.testing.allocator;

    const html = "<p>A &amp; B &lt; C &gt; D</p>";
    const result = try htmlToMarkdown(arena, html);
    defer arena.free(result);

    try std.testing.expect(std.mem.containsAtLeast(u8, result, 1, "A & B < C > D"));
}

test "tool definition structure" {
    try std.testing.expectEqualStrings("url_summary", tool_definition.name);
    try std.testing.expect(tool_definition.description.len > 0);
    try std.testing.expect(tool_definition.parameters_json.len > 0);
}
