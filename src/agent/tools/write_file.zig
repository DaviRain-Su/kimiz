//! WriteFile Tool - Write content to a file

const std = @import("std");
const tool = @import("../tool.zig");

pub const TOOL_NAME = "write_file";

const TOOL_DESCRIPTION =
    \\Writes content to a file at the specified path.
    \\Creates the file if it doesn't exist, overwrites if it does.
    \\Example: {"path": "/path/to/file.txt", "content": "Hello World"}
;

const PARAMETERS_SCHEMA =
    \\{
    \\  "type": "object",
    \\  "required": ["path", "content"],
    \\  "properties": {
    \\    "path": {
    \\      "type": "string",
    \\      "description": "Absolute path to the file to write"
    \\    },
    \\    "content": {
    \\      "type": "string",
    \\      "description": "Content to write to the file"
    \\    }
    \\  }
    \\}
;

pub const tool_definition = tool.Tool{
    .name = TOOL_NAME,
    .description = TOOL_DESCRIPTION,
    .parameters_json = PARAMETERS_SCHEMA,
};

const WriteFileArgs = struct {
    path: []const u8,
    content: []const u8,
};

pub const WriteFileContext = struct {
    // Can be extended with write confirmation callbacks
    auto_approve: bool = false,
};

pub fn createAgentTool(ctx: *WriteFileContext) tool.AgentTool {
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
    const ctx: *WriteFileContext = @ptrCast(@alignCast(ctx_ptr));

    const parsed_args = tool.parseArguments(arena, args, WriteFileArgs) catch {
        return tool.errorResult(arena, "Invalid arguments: expected {\"path\": \"...\", \"content\": \"...\"}");
    };

    if (parsed_args.path.len == 0) {
        return tool.errorResult(arena, "Path cannot be empty");
    }

    // Validate path is absolute
    if (!std.fs.path.isAbsolute(parsed_args.path)) {
        return tool.errorResult(arena, "Path must be absolute");
    }

    // Check if auto-approve is enabled (YOLO mode)
    if (!ctx.auto_approve) {
        // In normal mode, we would ask for confirmation here
        // For now, we proceed but could implement confirmation logic
    }

    // Create parent directories if needed
    const parent_dir = std.fs.path.dirname(parsed_args.path) orelse return tool.errorResult(arena, "Invalid path");
    std.fs.cwd().makePath(parent_dir) catch |err| {
        const err_msg = try std.fmt.allocPrint(arena, "Failed to create directory: {s}", .{@errorName(err)});
        return tool.errorResult(arena, err_msg);
    };

    // Write file
    const file = std.fs.cwd().createFile(parsed_args.path, .{}) catch |err| {
        const err_msg = try std.fmt.allocPrint(arena, "Failed to create file: {s}", .{@errorName(err)});
        return tool.errorResult(arena, err_msg);
    };
    defer file.close();

    file.writeAll(parsed_args.content) catch |err| {
        const err_msg = try std.fmt.allocPrint(arena, "Failed to write file: {s}", .{@errorName(err)});
        return tool.errorResult(arena, err_msg);
    };

    const success_msg = try std.fmt.allocPrint(arena, "Successfully wrote {d} bytes to {s}", .{ parsed_args.content.len, parsed_args.path });
    return tool.textContent(arena, success_msg);
}

// ============================================================================
// Tests
// ============================================================================

test "tool definition" {
    try std.testing.expectEqualStrings("write_file", tool_definition.name);
}
