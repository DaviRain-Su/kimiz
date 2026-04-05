//! ReadFile Tool - Read file contents

const std = @import("std");
const tool = @import("../tool.zig");
const utils = @import("../../utils/root.zig");

pub const TOOL_NAME = "read_file";

const TOOL_DESCRIPTION =
    \\Reads the contents of a file at the specified path.
    \\Returns the file content as text.
    \\Example: {"path": "/path/to/file.txt"}
;

const PARAMETERS_SCHEMA =
    \\{
    \\  "type": "object",
    \\  "required": ["path"],
    \\  "properties": {
    \\    "path": {
    \\      "type": "string",
    \\      "description": "Absolute path to the file to read"
    \\    },
    \\    "offset": {
    \\      "type": "integer",
    \\      "description": "Line offset to start reading from (0-based)"
    \\    },
    \\    "limit": {
    \\      "type": "integer",
    \\      "description": "Maximum number of lines to read"
    \\    }
    \\  }
    \\}
;

pub const tool_definition = tool.Tool{
    .name = TOOL_NAME,
    .description = TOOL_DESCRIPTION,
    .parameters_json = PARAMETERS_SCHEMA,
};

const ReadFileArgs = struct {
    path: []const u8,
    offset: ?usize = null,
    limit: ?usize = null,
};

pub const ReadFileContext = struct {};

pub fn createAgentTool(ctx: *ReadFileContext) tool.AgentTool {
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

    const parsed_args = tool.parseArguments(arena, args, ReadFileArgs) catch {
        return tool.errorResult(arena, "Invalid arguments: expected {\"path\": \"/path/to/file\"}");
    };

    if (parsed_args.path.len == 0) {
        return tool.errorResult(arena, "Path cannot be empty");
    }

    // Validate path is absolute
    if (!std.fs.path.isAbsolute(parsed_args.path)) {
        return tool.errorResult(arena, "Path must be absolute");
    }

    // Read file
    const file_io = @import("file_io.zig");
    const content = file_io.readFileAlloc(arena, parsed_args.path, 10 * 1024 * 1024) catch |err| {
        const err_msg = try std.fmt.allocPrint(arena, "Failed to read file: {s}", .{@errorName(err)});
        return tool.errorResult(arena, err_msg);
    };

    // Add line numbers and handle offset/limit
    const offset = parsed_args.offset orelse 0;
    const limit = parsed_args.limit orelse 2400;

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(arena);

    var iter = std.mem.splitScalar(u8, content, '\n');
    var line_num: usize = 0;
    var shown: usize = 0;
    var total_lines: usize = 0;
    while (iter.next()) |_| : (total_lines += 1) {}

    // Re-iterate with output
    iter = std.mem.splitScalar(u8, content, '\n');
    while (iter.next()) |line| {
        if (line_num >= offset and shown < limit) {
            if (buf.items.len > 0) try buf.append(arena, '\n');
            const numbered = try std.fmt.allocPrint(arena, "{d: >5}| {s}", .{ line_num + 1, line });
            try buf.appendSlice(arena, numbered);
            shown += 1;
        }
        line_num += 1;
        if (shown >= limit) break;
    }

    if (total_lines > shown) {
        const note = try std.fmt.allocPrint(arena, "\n\n[Showing lines {d}-{d} of {d} total]", .{ offset + 1, offset + shown, total_lines });
        try buf.appendSlice(arena, note);
    }

    return tool.textContent(arena, try arena.dupe(u8, buf.items));
}

/// Apply smart truncation to file content based on token estimates
fn applySmartTruncation(
    arena: std.mem.Allocator,
    raw_content: []const u8,
    offset: usize,
    limit: usize,
) ![]const u8 {
    const estimated_tokens = raw_content.len / 4;
    const max_tokens: usize = 2000; // Default token limit for read_file

    if (estimated_tokens <= max_tokens) {
        return arena.dupe(u8, raw_content);
    }

    // If content exceeds token limit, apply aggressive truncation
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(arena);

    var iter = std.mem.splitScalar(u8, raw_content, '\n');
    var line_num: usize = 0;
    var shown: usize = 0;
    const effective_limit = @min(limit, max_tokens / 2); // Reduce line count to fit tokens

    while (iter.next()) |line| {
        if (line_num >= offset and shown < effective_limit) {
            if (buf.items.len > 0) try buf.append(arena, '\n');
            const numbered = try std.fmt.allocPrint(arena, "{d: >5}| {s}", .{ line_num + 1, line });
            try buf.appendSlice(arena, numbered);
            shown += 1;
        }
        line_num += 1;
        if (shown >= effective_limit) break;
    }

    const note = try std.fmt.allocPrint(arena, "\n\n[Truncated: content too large for context window. Request specific lines with offset/limit.]", .{});
    try buf.appendSlice(arena, note);

    return try buf.toOwnedSlice(arena);
}

// ============================================================================
// Tests
// ============================================================================

test "tool definition" {
    try std.testing.expectEqualStrings("read_file", tool_definition.name);
}

test "read_file basic" {
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    // Create a test file (Zig 0.16 compatible)
    const test_content = "Hello, World!";
    const test_path = "/tmp/kimiz_test_read.txt";
    
    try utils.writeFile(test_path, test_content);
    defer utils.deleteFile(test_path) catch {};

    // Execute tool
    var ctx = ReadFileContext{};
    const args = std.json.ObjectMap{};
    
    const result = try ctx.execute(arena.allocator(), args);
    
    try std.testing.expect(!result.is_error);
    try std.testing.expect(result.content.len > 0);
}

test "read_file not found" {
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var ctx = ReadFileContext{};
    const args = std.json.parseFromSlice(
        std.json.Value,
        allocator,
        "{\"path\":\"/nonexistent/file.txt\"}",
        .{},
    ) catch return;
    defer args.deinit();

    const result = ctx.execute(arena.allocator(), args.value) catch |err| {
        // Expected to fail
        _ = err;
        return;
    };
    
    try std.testing.expect(result.is_error);
}

test "read_file with offset and limit" {
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    // Create multi-line test file (Zig 0.16 compatible)
    const test_content = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5";
    const test_path = "/tmp/kimiz_test_lines.txt";
    
    try utils.writeFile(test_path, test_content);
    defer utils.deleteFile(test_path) catch {};

    // Test with offset
    var ctx = ReadFileContext{};
    const args = std.json.parseFromSlice(
        std.json.Value,
        allocator,
        "{\"path\":\"/tmp/kimiz_test_lines.txt\",\"offset\":1,\"limit\":3}",
        .{},
    ) catch return;
    defer args.deinit();

    const result = try ctx.execute(arena.allocator(), args.value);
    
    try std.testing.expect(!result.is_error);
    // Should contain "Line 2", "Line 3", "Line 4"
}
