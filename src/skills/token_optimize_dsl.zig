//! RTK Token Optimizer Skill - DSL version
const std = @import("std");
const skills = @import("./root.zig");

const CompressionStrategy = enum {
    conservative,
    balanced,
    aggressive,
};

const CommandResult = struct {
    stdout: []const u8,
    stderr: []const u8,
    exit_code: i32,
};

fn checkRTKInstalled(allocator: std.mem.Allocator) !bool {
    const utils = @import("../utils/root.zig");
    const io = utils.getIo() catch return false;

    const result = std.process.run(allocator, io, .{
        .argv = &.{ "which", "rtk" },
        .stdout_limit = @enumFromInt(1024),
        .stderr_limit = @enumFromInt(1024),
    }) catch return false;
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    return switch (result.term) {
        .exited => |code| code == 0,
        else => false,
    };
}

fn executeRTKCommand(
    allocator: std.mem.Allocator,
    command: []const u8,
    strategy: CompressionStrategy,
    working_dir: []const u8,
) !CommandResult {
    var cmd_buf: std.ArrayList(u8) = .empty;
    defer cmd_buf.deinit(allocator);

    if (!std.mem.eql(u8, working_dir, ".")) {
        try cmd_buf.appendSlice(allocator, "cd '");
        try cmd_buf.appendSlice(allocator, working_dir);
        try cmd_buf.appendSlice(allocator, "' && ");
    }

    try cmd_buf.appendSlice(allocator, "rtk ");
    _ = strategy;
    try cmd_buf.appendSlice(allocator, command);

    const utils = @import("../utils/root.zig");
    const io = utils.getIo() catch return error.CommandExecutionFailed;

    const result = std.process.run(allocator, io, .{
        .argv = &.{ "sh", "-c", cmd_buf.items },
        .stdout_limit = @enumFromInt(100 * 1024),
        .stderr_limit = @enumFromInt(100 * 1024),
    }) catch return error.CommandExecutionFailed;

    const exit_code: i32 = switch (result.term) {
        .exited => |code| @intCast(code),
        else => -1,
    };

    return CommandResult{
        .stdout = result.stdout,
        .stderr = result.stderr,
        .exit_code = exit_code,
    };
}

fn estimateTokens(text: []const u8) u32 {
    return @intCast(@divTrunc(text.len, 4));
}

fn tokenOptimizeHandler(
    ctx: skills.SkillContext,
    input: struct {
        command: []const u8,
        strategy: CompressionStrategy = .balanced,
        working_dir: ?[]const u8 = null,
    },
    arena: std.mem.Allocator,
) struct {
    success: bool,
    output: []const u8,
    error_message: ?[]const u8 = null,
    tokens_used: ?u32 = null,
} {
    const start_time = @import("../utils/root.zig").milliTimestamp();

    if (!checkRTKInstalled(arena) catch false) {
        return .{
            .success = false,
            .output = "",
            .error_message =
                \\RTK is not installed.
                \\
                \\Install via:
                \\  brew install rtk
                \\  
                \\Or download from: https://github.com/rtk-ai/rtk/releases
            ,
        };
    }

    const working_dir = input.working_dir orelse ctx.working_dir;
    const result = executeRTKCommand(arena, input.command, input.strategy, working_dir) catch |err| {
        const elapsed = @import("../utils/root.zig").milliTimestamp() - start_time;
        const msg = std.fmt.allocPrint(arena, "RTK execution failed: {s}", .{@errorName(err)}) catch return .{ .success = false, .output = "" };
        return .{
            .success = false,
            .output = "",
            .error_message = msg,
            .tokens_used = null,
            .execution_time_ms = @intCast(elapsed),
        };
    };
    defer {
        arena.free(result.stdout);
        arena.free(result.stderr);
    }

    if (result.exit_code == 0) {
        const output_tokens = estimateTokens(result.stdout);
        // Duplicate stdout out of our local defer scope so it survives
        const output_copy = arena.dupe(u8, result.stdout) catch return .{ .success = false, .output = "" };
        return .{
            .success = true,
            .output = output_copy,
            .error_message = null,
            .tokens_used = output_tokens,
        };
    } else {
        const msg = std.fmt.allocPrint(arena, "RTK command failed with exit code: {d}", .{result.exit_code}) catch return .{ .success = false, .output = "" };
        return .{
            .success = false,
            .output = result.stdout,
            .error_message = msg,
            .tokens_used = null,
        };
    }
}

pub const TokenOptimizeDslSkill = skills.defineSkill(.{
    .name = "rtk-optimize",
    .description = "Compress command outputs using rtk tool, reducing token consumption by 60-90%.",
    .input = struct {
        command: []const u8,
        strategy: CompressionStrategy = .balanced,
        working_dir: ?[]const u8 = null,
    },
    .output = struct {
        success: bool,
        output: []const u8,
        error_message: ?[]const u8 = null,
        tokens_used: ?u32 = null,
    },
    .handler = tokenOptimizeHandler,
});

pub const SKILL_ID = TokenOptimizeDslSkill.id;
pub const SKILL_NAME = TokenOptimizeDslSkill.name;
pub const SKILL_DESCRIPTION = TokenOptimizeDslSkill.description;
pub const SKILL_VERSION = TokenOptimizeDslSkill.version;

pub fn getSkill() skills.Skill {
    return TokenOptimizeDslSkill.toSkill();
}
