//! ReadFile Tool - Read file contents

const std = @import("std");
const tool = @import("../tool.zig");

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
    const content = std.fs.cwd().readFileAlloc(arena, parsed_args.path, 10 * 1024 * 1024) catch |err| {
        const err_msg = try std.fmt.allocPrint(arena, "Failed to read file: {s}", .{@errorName(err)});
        return tool.errorResult(arena, err_msg);
    };

    // Handle offset and limit if specified
    if (parsed_args.offset != null or parsed_args.limit != null) {
        const offset = parsed_args.offset orelse 0;
        const limit = parsed_args.limit orelse std.math.maxInt(usize);

        var lines = std.ArrayList([]const u8).init(arena);
        defer lines.deinit();

        var iter = std.mem.splitScalar(u8, content, '\n');
        var line_num: usize = 0;
        while (iter.next()) |line| {
            if (line_num >= offset and lines.items.len < limit) {
                try lines.append(line);
            }
            line_num += 1;
            if (lines.items.len >= limit) break;
        }

        // Reconstruct content
        const limited_content = try std.mem.join(arena, "\n", lines.items);
        return tool.textContent(arena, limited_content);
    }

    return tool.textContent(arena, content);
}

// ============================================================================
// Tests
// ============================================================================

test "tool definition" {
    try std.testing.expectEqualStrings("read_file", tool_definition.name);
}
