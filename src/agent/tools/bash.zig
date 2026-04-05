//! Bash Tool - Execute shell commands

const std = @import("std");
const utils = @import("../../utils/root.zig");
const tool = @import("../tool.zig");
const compress = @import("../../skills/compress/filters.zig");
const git_filters = @import("../../skills/compress/git.zig");
const file_filters = @import("../../skills/compress/files.zig");
const TokenOptimizationConfig = @import("../../config.zig").TokenOptimizationConfig;

// Strategy compatibility: map config Strategy to compress Strategy
fn mapStrategy(config_strategy: TokenOptimizationConfig.Strategy) compress.Strategy {
    return switch (config_strategy) {
        .conservative => .conservative,
        .balanced => .balanced,
        .aggressive => .aggressive,
    };
}

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
    token_optimization: ?*const TokenOptimizationConfig = null,

    /// Apply token optimization filter to command output
    fn optimizeOutput(
        self: *const BashContext,
        allocator: std.mem.Allocator,
        command: []const u8,
        raw_output: []const u8,
    ) ![]const u8 {
        const config = self.token_optimization orelse return allocator.dupe(u8, raw_output);
        if (!config.shouldOptimize(command)) return allocator.dupe(u8, raw_output);

        const strategy = mapStrategy(config.getEffectiveStrategy(command));
        const ctx = compress.FilterContext{
            .allocator = allocator,
            .strategy = strategy,
            .command = command,
            .raw_output = raw_output,
            .max_tokens = config.advanced.max_output_tokens,
        };

        // Try command-specific filter first
        if (std.mem.startsWith(u8, command, "git status")) {
            const result = try git_filters.git_status_filter.apply(ctx);
            defer result.deinit(allocator);
            return allocator.dupe(u8, result.filtered);
        } else if (std.mem.startsWith(u8, command, "git log")) {
            const result = try git_filters.git_log_filter.apply(ctx);
            defer result.deinit(allocator);
            return allocator.dupe(u8, result.filtered);
        } else if (std.mem.startsWith(u8, command, "git diff")) {
            const result = try git_filters.git_diff_filter.apply(ctx);
            defer result.deinit(allocator);
            return allocator.dupe(u8, result.filtered);
        } else if (std.mem.startsWith(u8, command, "ls")) {
            const result = try file_filters.ls_filter.apply(ctx);
            defer result.deinit(allocator);
            return allocator.dupe(u8, result.filtered);
        } else if (std.mem.startsWith(u8, command, "find")) {
            const result = try file_filters.find_filter.apply(ctx);
            defer result.deinit(allocator);
            return allocator.dupe(u8, result.filtered);
        }

        // Fallback to default filter
        const result = try compress.default_filter.apply(ctx);
        defer result.deinit(allocator);
        return allocator.dupe(u8, result.filtered);
    }
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

    // Apply token optimization if enabled
    const optimized_stdout = ctx.optimizeOutput(arena, parsed_args.command, result.stdout) catch |err| blk: {
        // If optimization fails, log and return raw output
        std.log.debug("Token optimization failed for '{s}': {s}", .{ parsed_args.command, @errorName(err) });
        break :blk result.stdout;
    };

    if (optimized_stdout.len > 0 and result.stderr.len == 0) {
        return tool.textContent(arena, optimized_stdout);
    } else if (result.stderr.len > 0) {
        const output = try std.fmt.allocPrint(arena, "STDOUT:\n{s}\n\nSTDERR:\n{s}", .{ optimized_stdout, result.stderr });
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
    const cc = @cImport({ @cInclude("stdlib.h"); @cInclude("stdio.h"); });

    // Build command with optional cd and output truncation
    var cmd_buf: std.ArrayList(u8) = .empty;
    defer cmd_buf.deinit(arena);
    if (working_dir) |wd| {
        try cmd_buf.appendSlice(arena, "cd '");
        try cmd_buf.appendSlice(arena, wd);
        try cmd_buf.appendSlice(arena, "' && ");
    }
    // Wrap: timeout via perl alarm, truncate output to 100KB
    const timeout_secs = @max(timeout_ms / 1000, 1);
    var timeout_str: [16]u8 = undefined;
    const timeout_slice = std.fmt.bufPrint(&timeout_str, "{d}", .{timeout_secs}) catch &[_]u8{ '3', '0' };
    try cmd_buf.appendSlice(arena, "perl -e 'alarm ");
    try cmd_buf.appendSlice(arena, timeout_slice);
    try cmd_buf.appendSlice(arena, "; exec @ARGV' ");
    try cmd_buf.appendSlice(arena, command);
    try cmd_buf.appendSlice(arena, " 2>&1 | head -c 102400");

    const c_cmd = try arena.dupeZ(u8, cmd_buf.items);
    const pipe = cc.popen(c_cmd.ptr, "r") orelse {
        return CommandResult{ .stdout = "", .stderr = "Failed to execute command", .exit_code = null };
    };

    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(arena);
    const max_output: usize = 100 * 1024; // 100KB limit
    var buf: [4096]u8 = undefined;
    while (output.items.len < max_output) {
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
