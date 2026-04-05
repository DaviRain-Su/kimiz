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
// Skill Definition
// ============================================================================

/// RTK Token Optimizer Skill
pub const rtk_optimize = Skill{
    .id = "rtk-optimize",
    .name = "RTK Token Optimizer",
    .description = "Compress command outputs using rtk tool, reducing token consumption by 60-90%. Supports git, file operations, tests, and build tools.",
    .version = "1.0.0",
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
        return switch (self) {
            .conservative => null, // rtk default
            .balanced => null, // rtk default
            .aggressive => "-l", // rtk aggressive flag
        };
    }
};

// ============================================================================
// RTK Installation Check
// ============================================================================

/// Check if rtk is installed and accessible
fn checkRTKInstalled(allocator: std.mem.Allocator) !bool {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "which", "rtk" },
    }) catch return false;
    
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    
    return result.term.Exited == 0;
}

/// Get rtk version for debugging
fn getRTKVersion(allocator: std.mem.Allocator) ![]const u8 {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "rtk", "--version" },
    });
    
    defer allocator.free(result.stderr);
    
    if (result.term.Exited == 0) {
        return result.stdout;
    } else {
        allocator.free(result.stdout);
        return error.RTKVersionFailed;
    }
}

// ============================================================================
// Command Execution
// ============================================================================

/// Execute command through rtk with compression
fn executeRTKCommand(
    allocator: std.mem.Allocator,
    command: []const u8,
    strategy: CompressionStrategy,
    working_dir: []const u8,
) !std.process.Child.RunResult {
    var argv = std.ArrayList([]const u8).init(allocator);
    defer argv.deinit();

    // Start with rtk
    try argv.append("rtk");

    // Add strategy flag if needed
    if (strategy.toRTKFlag()) |flag| {
        try argv.append(flag);
        if (std.mem.eql(u8, flag, "-l")) {
            try argv.append("aggressive");
        }
    }

    // Parse and add the command
    // Simple tokenization (TODO: improve for complex commands with quotes)
    var cmd_iter = std.mem.tokenizeAny(u8, command, " \t");
    while (cmd_iter.next()) |part| {
        try argv.append(part);
    }

    // Execute
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv.items,
        .cwd = working_dir,
    });

    return result;
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
    const start_time = std.time.milliTimestamp();

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
        const elapsed = std.time.milliTimestamp() - start_time;
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

    defer arena.free(result.stdout);
    defer arena.free(result.stderr);

    const elapsed = std.time.milliTimestamp() - start_time;

    // Step 4: Return result
    if (result.term.Exited == 0) {
        // Success - calculate token estimate
        const output_tokens = estimateTokens(result.stdout);
        
        return SkillResult{
            .success = true,
            .output = try arena.dupe(u8, result.stdout),
            .error_message = null,
            .execution_time_ms = @intCast(elapsed),
            .tokens_used = output_tokens,
        };
    } else {
        // Command failed
        const error_msg = if (result.stderr.len > 0)
            result.stderr
        else
            "Command execution failed (no error output)";

        return SkillResult{
            .success = false,
            .output = try arena.dupe(u8, result.stdout), // Include stdout for debugging
            .error_message = try std.fmt.allocPrint(arena,
                "RTK command failed:\n{s}",
                .{error_msg},
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
