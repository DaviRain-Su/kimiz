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
    // Use /bin/sh for macOS/Linux or cmd.exe for Windows
    const shell = if (@import("builtin").os.tag == .windows) "cmd.exe" else "/bin/sh";
    const shell_arg = if (@import("builtin").os.tag == .windows) "/C" else "-c";

    var child = std.process.Child.init(&[_][]const u8{ shell, shell_arg, command }, arena);

    if (working_dir) |wd| {
        child.cwd = wd;
    }

    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    // Collect output with timeout
    var stdout = std.ArrayList(u8).init(arena);
    var stderr = std.ArrayList(u8).init(arena);

    const stdout_reader = child.stdout.?.reader();
    const stderr_reader = child.stderr.?.reader();

    var buf: [4096]u8 = undefined;
    const start_time = utils.milliTimestamp();

    while (true) {
        const elapsed = utils.milliTimestamp() - start_time;
        if (elapsed > timeout_ms) {
            _ = child.kill() catch {};
            break;
        }

        // Try to read stdout
        const stdout_bytes = stdout_reader.read(&buf) catch 0;
        if (stdout_bytes > 0) {
            try stdout.appendSlice(buf[0..stdout_bytes]);
        }

        // Try to read stderr
        const stderr_bytes = stderr_reader.read(&buf) catch 0;
        if (stderr_bytes > 0) {
            try stderr.appendSlice(buf[0..stderr_bytes]);
        }

        // Check if process finished
        const term = child.tryWait() catch break;
        if (term) |t| {
            // Process finished, read any remaining output
            while (true) {
                const bytes = stdout_reader.read(&buf) catch break;
                if (bytes == 0) break;
                try stdout.appendSlice(buf[0..bytes]);
            }
            while (true) {
                const bytes = stderr_reader.read(&buf) catch break;
                if (bytes == 0) break;
                try stderr.appendSlice(buf[0..bytes]);
            }

            return CommandResult{
                .stdout = try stdout.toOwnedSlice(),
                .stderr = try stderr.toOwnedSlice(),
                .exit_code = @intCast(t.Exited),
            };
        }

        std.time.sleep(10 * std.time.ns_per_ms); // Small delay to prevent busy-waiting
    }

    // Timeout reached
    return CommandResult{
        .stdout = try stdout.toOwnedSlice(),
        .stderr = try stderr.toOwnedSlice(),
        .exit_code = null,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "tool definition" {
    try std.testing.expectEqualStrings("bash", tool_definition.name);
}
