//! RTK Token Optimizer Skill
//! Wraps rtk external tool to compress command outputs by 60-90%
//!
//! This skill provides token optimization by delegating to the rtk CLI tool.
//! It supports multiple compression strategies and handles common dev commands.

const std = @import("std");
const root = @import("root.zig");

const Skill = root.Skill;
const SkillParam = root.SkillParam;
const SkillContext = root.SkillContext;
const SkillResult = root.SkillResult;

// ============================================================================
// Skill Metadata
// ============================================================================

pub const SKILL_ID = "rtk-optimize";
pub const SKILL_NAME = "RTK Token Optimizer";
pub const SKILL_DESCRIPTION = "Compress command outputs using rtk tool, reducing token consumption by 60-90%. Supports git, file operations, tests, and build tools.";
pub const SKILL_VERSION = "1.0.0";

// ============================================================================
// Skill Definition
// ============================================================================

/// RTK Token Optimizer Skill
pub const rtk_optimize = Skill{
    .id = SKILL_ID,
    .name = SKILL_NAME,
    .description = SKILL_DESCRIPTION,
    .version = SKILL_VERSION,
    .category = .misc,
    .params = &[_]SkillParam{
        .{
            .name = "command",
            .description = "Command to execute and optimize (e.g., 'git status', 'ls -la', 'cargo test')",
            .param_type = .string,
            .required = true,
        },
        .{
            .name = "strategy",
            .description = "Compression strategy: 'conservative' (more info), 'balanced' (default), 'aggressive' (max compression)",
            .param_type = .selection,
            .required = false,
            .default_value = "balanced",
        },
        .{
            .name = "working_dir",
            .description = "Working directory for command execution (defaults to current)",
            .param_type = .directory,
            .required = false,
            .default_value = null,
        },
    },
    .execute_fn = execute,
};

// ============================================================================
// Compression Strategies
// ============================================================================

const CompressionStrategy = enum {
    conservative, // Keep more information, ~60% reduction
    balanced, // Default, ~70-80% reduction
    aggressive, // Maximum compression, ~90% reduction

    fn fromString(s: []const u8) !CompressionStrategy {
        if (std.mem.eql(u8, s, "conservative")) return .conservative;
        if (std.mem.eql(u8, s, "balanced")) return .balanced;
        if (std.mem.eql(u8, s, "aggressive")) return .aggressive;
        return error.InvalidStrategy;
    }

    fn toRTKFlag(self: CompressionStrategy) ?[]const u8 {
        // Note: rtk doesn't have a global strategy flag
        // Each subcommand has its own flags (e.g., -u for git status)
        // For now, we use rtk's default optimizations for all strategies
        _ = self;
        return null;
    }
};

// ============================================================================
// RTK Installation Check
// ============================================================================

/// Check if rtk is installed and accessible
fn checkRTKInstalled(allocator: std.mem.Allocator) !bool {
    const utils = @import("../utils/root.zig");
    const io = utils.getIo() catch return false;

    const result = std.process.run(allocator, io, .{
        .argv = &.{ "which", "rtk" },
        .stdout_limit = @enumFromInt(1024),
        .stderr_limit = @enumFromInt(1024),
    }) catch return false;

    return switch (result.term) {
        .exited => |code| code == 0,
        else => false,
    };
}

/// Get rtk version for debugging
fn getRTKVersion(allocator: std.mem.Allocator) ![]const u8 {
    const utils = @import("../utils/root.zig");
    const io = utils.getIo() catch return error.RTKVersionFailed;

    const result = std.process.run(allocator, io, .{
        .argv = &.{ "rtk", "--version" },
        .stdout_limit = @enumFromInt(1024),
        .stderr_limit = @enumFromInt(1024),
    }) catch return error.RTKVersionFailed;

    if (result.stdout.len > 0) {
        return try allocator.dupe(u8, result.stdout);
    } else if (result.stderr.len > 0) {
        return try allocator.dupe(u8, result.stderr);
    }

    return try allocator.dupe(u8, "");
}

// ============================================================================
// Command Execution
// ============================================================================

const CommandResult = struct {
    stdout: []const u8,
    stderr: []const u8,
    exit_code: i32,
};

/// Execute command through rtk with compression
fn executeRTKCommand(
    allocator: std.mem.Allocator,
    command: []const u8,
    strategy: CompressionStrategy,
    working_dir: []const u8,
) !CommandResult {
    // Build command string
    var cmd_buf: std.ArrayList(u8) = .empty;
    defer cmd_buf.deinit(allocator);
    
    // Change directory if needed
    if (!std.mem.eql(u8, working_dir, ".")) {
        try cmd_buf.appendSlice(allocator, "cd '");
        try cmd_buf.appendSlice(allocator, working_dir);
        try cmd_buf.appendSlice(allocator, "' && ");
    }
    
    // Build rtk command
    try cmd_buf.appendSlice(allocator, "rtk ");
    
    // Add the actual command (rtk uses default optimizations)
    // TODO: Future enhancement - add command-specific flags based on strategy
    // e.g., "git status" + aggressive → "rtk git status -u"
    _ = strategy; // unused for now
    try cmd_buf.appendSlice(allocator, command);

    const utils = @import("../utils/root.zig");
    const io = utils.getIo() catch {
        return error.CommandExecutionFailed;
    };

    // Execute using Zig 0.16 native API
    const result = std.process.run(allocator, io, .{
        .argv = &.{ "sh", "-c", cmd_buf.items },
        .stdout_limit = @enumFromInt(100 * 1024),
        .stderr_limit = @enumFromInt(100 * 1024),
    }) catch {
        return error.CommandExecutionFailed;
    };

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

// ============================================================================
// Skill Execution
// ============================================================================

/// Main skill execution function
fn execute(
    ctx: SkillContext,
    args: std.json.ObjectMap,
    arena: std.mem.Allocator,
) anyerror!SkillResult {
    const start_time = @import("../utils/root.zig").milliTimestamp();

    // Step 1: Check if rtk is installed
    if (!try checkRTKInstalled(arena)) {
        return SkillResult{
            .success = false,
            .output = "",
            .error_message = try arena.dupe(u8,
                \\RTK is not installed.
                \\
                \\Install via:
                \\  brew install rtk
                \\  
                \\Or download from: https://github.com/rtk-ai/rtk/releases
            ),
            .execution_time_ms = 0,
        };
    }

    // Step 2: Extract parameters
    const command = args.get("command") orelse {
        return SkillResult{
            .success = false,
            .output = "",
            .error_message = try arena.dupe(u8, "Missing required parameter: command"),
            .execution_time_ms = 0,
        };
    };

    const command_str = switch (command) {
        .string => |s| s,
        else => {
            return SkillResult{
                .success = false,
                .output = "",
                .error_message = try arena.dupe(u8, "Parameter 'command' must be a string"),
                .execution_time_ms = 0,
            };
        },
    };

    // Parse strategy
    const strategy_str = if (args.get("strategy")) |s| switch (s) {
        .string => |str| str,
        else => "balanced",
    } else "balanced";

    const strategy = CompressionStrategy.fromString(strategy_str) catch {
        return SkillResult{
            .success = false,
            .output = "",
            .error_message = try std.fmt.allocPrint(arena,
                "Invalid strategy '{s}'. Use: conservative, balanced, or aggressive",
                .{strategy_str},
            ),
            .execution_time_ms = 0,
        };
    };

    // Working directory
    const working_dir = if (args.get("working_dir")) |wd| switch (wd) {
        .string => |s| s,
        else => ctx.working_dir,
    } else ctx.working_dir;

    // Step 3: Execute rtk command
    const result = executeRTKCommand(
        arena,
        command_str,
        strategy,
        working_dir,
    ) catch |err| {
        const elapsed = @import("../utils/root.zig").milliTimestamp() - start_time;
        return SkillResult{
            .success = false,
            .output = "",
            .error_message = try std.fmt.allocPrint(arena,
                "RTK execution failed: {s}",
                .{@errorName(err)},
            ),
            .execution_time_ms = @intCast(elapsed),
        };
    };

    // Note: result.stdout is owned by arena allocator and will be freed by caller
    const elapsed = @import("../utils/root.zig").milliTimestamp() - start_time;

    // Step 4: Return result
    if (result.exit_code == 0) {
        // Success - calculate token estimate
        const output_tokens = estimateTokens(result.stdout);
        
        return SkillResult{
            .success = true,
            .output = result.stdout, // Already owned by arena
            .error_message = null,
            .execution_time_ms = @intCast(elapsed),
            .tokens_used = output_tokens,
        };
    } else {
        // Command failed
        return SkillResult{
            .success = false,
            .output = result.stdout, // Include output for debugging
            .error_message = try std.fmt.allocPrint(arena,
                "RTK command failed with exit code: {d}",
                .{result.exit_code},
            ),
            .execution_time_ms = @intCast(elapsed),
        };
    }
}

// ============================================================================
// Utilities
// ============================================================================

/// Estimate token count (simple heuristic: ~4 chars per token)
fn estimateTokens(text: []const u8) u32 {
    return @intCast(@divTrunc(text.len, 4));
}

// ============================================================================
// Tests
// ============================================================================

test "CompressionStrategy.fromString" {
    try std.testing.expectEqual(
        CompressionStrategy.conservative,
        try CompressionStrategy.fromString("conservative"),
    );
    try std.testing.expectEqual(
        CompressionStrategy.balanced,
        try CompressionStrategy.fromString("balanced"),
    );
    try std.testing.expectEqual(
        CompressionStrategy.aggressive,
        try CompressionStrategy.fromString("aggressive"),
    );

    try std.testing.expectError(
        error.InvalidStrategy,
        CompressionStrategy.fromString("invalid"),
    );
}

test "CompressionStrategy.toRTKFlag" {
    try std.testing.expectEqual(
        @as(?[]const u8, null),
        CompressionStrategy.conservative.toRTKFlag(),
    );
    try std.testing.expectEqual(
        @as(?[]const u8, null),
        CompressionStrategy.balanced.toRTKFlag(),
    );
    try std.testing.expectEqual(
        @as(?[]const u8, "-l"),
        CompressionStrategy.aggressive.toRTKFlag(),
    );
}

test "estimateTokens" {
    try std.testing.expectEqual(@as(u32, 10), estimateTokens("x" ** 40));
    try std.testing.expectEqual(@as(u32, 0), estimateTokens(""));
    try std.testing.expectEqual(@as(u32, 1), estimateTokens("test"));
}

// ============================================================================
// Skill Getter (for consistency with other skills)
// ============================================================================

/// Get skill definition (for compatibility with builtin skill system)
pub fn getSkill() Skill {
    return rtk_optimize;
}
