//! Edit Tool - Edit file by replacing text

const std = @import("std");
const tool = @import("../tool.zig");

pub const TOOL_NAME = "edit";

const TOOL_DESCRIPTION =
    \\Edits a file by replacing a specific string with another.
    \\Useful for making precise changes without rewriting the entire file.
    \\Example: {"path": "/path/to/file.txt", "old_string": "foo", "new_string": "bar"}
;

const PARAMETERS_SCHEMA =
    \\{
    \\  "type": "object",
    \\  "required": ["path", "old_string", "new_string"],
    \\  "properties": {
    \\    "path": {
    \\      "type": "string",
    \\      "description": "Absolute path to the file to edit"
    \\    },
    \\    "old_string": {
    \\      "type": "string",
    \\      "description": "The exact text to replace"
    \\    },
    \\    "new_string": {
    \\      "type": "string",
    \\      "description": "The new text to insert"
    \\    }
    \\  }
    \\}
;

pub const tool_definition = tool.Tool{
    .name = TOOL_NAME,
    .description = TOOL_DESCRIPTION,
    .parameters_json = PARAMETERS_SCHEMA,
};

const EditArgs = struct {
    path: []const u8,
    old_string: []const u8,
    new_string: []const u8,
};

pub const EditContext = struct {};

pub fn createAgentTool(ctx: *EditContext) tool.AgentTool {
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
    _ = ctx_ptr;

    const parsed_args = tool.parseArguments(args, EditArgs) catch {
        return tool.errorResult(arena, "Invalid arguments: expected {\"path\": \"...\", \"old_string\": \"...\", \"new_string\": \"...\"}");
    };

    if (parsed_args.path.len == 0) {
        return tool.errorResult(arena, "Path cannot be empty");
    }

    if (parsed_args.old_string.len == 0) {
        return tool.errorResult(arena, "old_string cannot be empty");
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

    // Find old_string
    const idx = std.mem.indexOf(u8, content, parsed_args.old_string);
    if (idx == null) {
        return tool.errorResult(arena, "old_string not found in file");
    }

    // Count occurrences
    var count: usize = 0;
    var search_start: usize = 0;
    while (std.mem.indexOfPos(u8, content, search_start, parsed_args.old_string)) |pos| {
        count += 1;
        search_start = pos + parsed_args.old_string.len;
    }

    if (count > 1) {
        return tool.errorResult(arena, "old_string appears multiple times in file. Please provide more context to make a unique match.");
    }

    // Replace
    const new_content = try std.mem.concat(arena, u8, &[_][]const u8{
        content[0..idx.?],
        parsed_args.new_string,
        content[idx.? + parsed_args.old_string.len ..],
    });

    // Write back
    std.fs.cwd().writeFile(.{
        .sub_path = parsed_args.path,
        .data = new_content,
    }) catch |err| {
        const err_msg = try std.fmt.allocPrint(arena, "Failed to write file: {s}", .{@errorName(err)});
        return tool.errorResult(arena, err_msg);
    };

    const success_msg = try std.fmt.allocPrint(arena, "Successfully edited {s}", .{parsed_args.path});
    return tool.textContent(arena, success_msg);
}

// ============================================================================
// Tests
// ============================================================================

test "tool definition" {
    try std.testing.expectEqualStrings("edit", tool_definition.name);
}
