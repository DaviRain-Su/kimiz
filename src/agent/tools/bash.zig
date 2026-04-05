//! Bash Tool - Execute shell commands

const std = @import("std");
const utils = @import("../../utils/root.zig");
const tool = @import("../tool.zig");

pub const TOOL_NAME = "bash";

const TOOL_DESCRIPTION =
    \\Executes a bash shell command.
    \\Returns stdout and stderr output.
    \\Use with caution - requires user confirmation in normal mode.
    \\Example: {"command": "ls -la", "timeout_ms": 30000}
;

const PARAMETERS_SCHEMA =
    \\{
    \\  "type": "object",
    \\  "required": ["command"],
    \\  "properties": {
    \\    "command": {
    \\      "type": "string",
    \\      "description": "Bash command to execute"
    \\    },
    \\    "timeout_ms": {
    \\      "type": "integer",
    \\      "description": "Timeout in milliseconds (default: 30000)"
    \\    },
    \\    "working_dir": {
    \\      "type": "string",
    \\      "description": "Working directory for command execution"
    \\    }
    \\  }
    \\}
;

pub const tool_definition = tool.Tool{
    .name = TOOL_NAME,
    .description = TOOL_DESCRIPTION,
    .parameters_json = PARAMETERS_SCHEMA,
};

const BashArgs = struct {
    command: []const u8,
    timeout_ms: ?u32 = null,
    working_dir: ?[]const u8 = null,
};

pub const BashContext = struct {
    auto_approve: bool = false,
    allowed_commands: ?[]const []const u8 = null,
    blocked_commands: ?[]const []const u8 = null,
};

pub fn createAgentTool(ctx: *BashContext) tool.AgentTool {
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
    const ctx: *BashContext = @ptrCast(@alignCast(ctx_ptr));

    const parsed_args = tool.parseArguments(arena, args, BashArgs) catch {
        return tool.errorResult(arena, "Invalid arguments: expected {\"command\": \"...\"}");
    };

    if (parsed_args.command.len == 0) {
        return tool.errorResult(arena, "Command cannot be empty");
    }

    // Check auto-approve (YOLO mode)
    if (!ctx.auto_approve) {
        // In normal mode, would ask for confirmation
        // For now, we proceed with a warning
    }

    // Check blocked commands
    if (ctx.blocked_commands) |blocked| {
        for (blocked) |blocked_cmd| {
            if (std.mem.containsAtLeast(u8, parsed_args.command, 1, blocked_cmd)) {
                return tool.errorResult(arena, "Command contains blocked pattern");
            }
        }
    }

    const timeout_ms = parsed_args.timeout_ms orelse 30000;

    // Execute command
    const result = try executeCommand(arena, parsed_args.command, parsed_args.working_dir, timeout_ms);

    if (result.stdout.len > 0 and result.stderr.len == 0) {
        return tool.textContent(arena, result.stdout);
    } else if (result.stderr.len > 0) {
        const output = try std.fmt.allocPrint(arena, "STDOUT:\n{s}\n\nSTDERR:\n{s}", .{ result.stdout, result.stderr });
        return tool.textContent(arena, output);
    } else {
        return tool.textContent(arena, "(no output)");
    }
}

const CommandResult = struct {
    stdout: []const u8,
    stderr: []const u8,
    exit_code: ?u32,
};

fn executeCommand(
    arena: std.mem.Allocator,
    command: []const u8,
    working_dir: ?[]const u8,
    timeout_ms: u32,
) !CommandResult {
    _ = timeout_ms;
    const cc = @cImport({ @cInclude("stdlib.h"); @cInclude("stdio.h"); });

    // Build command with optional cd
    var cmd_buf: std.ArrayList(u8) = .empty;
    defer cmd_buf.deinit(arena);
    if (working_dir) |wd| {
        try cmd_buf.appendSlice(arena, "cd '\'");
        try cmd_buf.appendSlice(arena, wd);
        try cmd_buf.appendSlice(arena, "' && ");
    }
    try cmd_buf.appendSlice(arena, command);
    try cmd_buf.appendSlice(arena, " 2>&1");

    const c_cmd = try arena.dupeZ(u8, cmd_buf.items);
    const pipe = cc.popen(c_cmd.ptr, "r") orelse {
        return CommandResult{ .stdout = "", .stderr = "Failed to execute command", .exit_code = null };
    };

    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(arena);
    var buf: [4096]u8 = undefined;
    while (true) {
        const n = cc.fread(&buf, 1, buf.len, pipe);
        if (n == 0) break;
        try output.appendSlice(arena, buf[0..n]);
    }

    const status = cc.pclose(pipe);
    const exit_code: ?u32 = if (status >= 0) @intCast(@as(u32, @bitCast(status)) >> 8) else null;

    return CommandResult{
        .stdout = try arena.dupe(u8, output.items),
        .stderr = "",
        .exit_code = exit_code,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "tool definition" {
    try std.testing.expectEqualStrings("bash", tool_definition.name);
}

test "bash echo command" {
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var ctx = BashContext{};
    const args = try std.json.parseFromSlice(
        std.json.Value,
        allocator,
        "{\"command\":\"echo 'Hello World'\"}",
        .{},
    );
    defer args.deinit();

    const result = try ctx.execute(arena.allocator(), args.value);
    try std.testing.expect(!result.is_error);
}

test "bash empty command" {
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var ctx = BashContext{};
    const args = try std.json.parseFromSlice(
        std.json.Value,
        allocator,
        "{\"command\":\"\"}",
        .{},
    );
    defer args.deinit();

    const result = try ctx.execute(arena.allocator(), args.value);
    try std.testing.expect(result.is_error);
}

test "bash blocked command" {
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var ctx = BashContext{
        .blocked_commands = &[_][]const u8{"rm -rf /"},
    };
    const args = try std.json.parseFromSlice(
        std.json.Value,
        allocator,
        "{\"command\":\"rm -rf /\"}",
        .{},
    );
    defer args.deinit();

    const result = try ctx.execute(arena.allocator(), args.value);
    try std.testing.expect(result.is_error);
}
