//! Slash Command Framework for kimiz CLI
//! Provides product-grade slash commands similar to Claude/Codex

const std = @import("std");
const agent = @import("../agent/root.zig");
const ai = @import("../ai/root.zig");
const config = @import("../config.zig");

/// Slash command handler function signature
pub const SlashHandler = *const fn (
    ctx: *SlashContext,
    args: []const u8,
) anyerror!void;

/// Slash command metadata
pub const SlashCommand = struct {
    name: []const u8,
    description: []const u8,
    usage: []const u8,
    handler: SlashHandler,
    hidden: bool = false, // If true, won't show in /help unless --all
};

/// Execution context passed to slash command handlers
pub const SlashContext = struct {
    allocator: std.mem.Allocator,
    agent: *agent.Agent,
    cfg: *config.Config,
    print_fn: *const fn ([]const u8) void,
    print_line_fn: *const fn ([]const u8) void,
    should_exit: bool = false,

    pub fn print(self: *SlashContext, msg: []const u8) void {
        self.print_fn(msg);
    }

    pub fn printLine(self: *SlashContext, msg: []const u8) void {
        self.print_line_fn(msg);
    }
};

/// Parse a raw input line to detect and extract slash command info
pub fn parse(input: []const u8) ?struct { name: []const u8, args: []const u8 } {
    if (input.len < 2 or input[0] != '/') return null;

    // Find first space to separate command name from args
    const space_idx = std.mem.indexOfScalar(u8, input, ' ') orelse input.len;
    const name = input[1..space_idx];
    const args = if (space_idx < input.len)
        std.mem.trim(u8, input[space_idx + 1 ..], " \t")
    else
        "";

    return .{ .name = name, .args = args };
}

/// Built-in slash command registry
pub const registry = &[_]SlashCommand{
    .{
        .name = "help",
        .description = "Show available slash commands",
        .usage = "/help [--all]",
        .handler = cmdHelp,
    },
    .{
        .name = "clear",
        .description = "Clear the screen",
        .usage = "/clear",
        .handler = cmdClear,
    },
    .{
        .name = "exit",
        .description = "Exit the program",
        .usage = "/exit",
        .handler = cmdExit,
    },
    .{
        .name = "model",
        .description = "Switch the active AI model",
        .usage = "/model <model_id>",
        .handler = cmdModel,
    },
    .{
        .name = "yolo",
        .description = "Toggle YOLO mode (auto-approve tools)",
        .usage = "/yolo [on|off]",
        .handler = cmdYolo,
    },
    .{
        .name = "token",
        .description = "Configure token optimization settings",
        .usage = "/token [on|off|strategy <name>]",
        .handler = cmdToken,
    },
    .{
        .name = "skill",
        .description = "Execute a skill directly",
        .usage = "/skill <skill_id> [param=value...]",
        .handler = cmdSkill,
    },
};

/// Look up a slash command by name
pub fn find(name: []const u8) ?SlashCommand {
    for (registry) |cmd| {
        if (std.mem.eql(u8, cmd.name, name)) {
            return cmd;
        }
    }
    return null;
}

// ============================================================================
// Command Handlers
// ============================================================================

fn cmdHelp(ctx: *SlashContext, args: []const u8) !void {
    const show_all = std.mem.eql(u8, args, "--all");

    ctx.printLine("\n╔════════════════════════════════════════════════════════════╗");
    ctx.printLine("║                 Available Slash Commands                   ║");
    ctx.printLine("╚════════════════════════════════════════════════════════════╝");
    ctx.printLine("");

    for (registry) |cmd| {
        if (cmd.hidden and !show_all) continue;
        const line = try std.fmt.allocPrint(ctx.allocator, "  /{s:<12} {s}", .{ cmd.name, cmd.description });
        defer ctx.allocator.free(line);
        ctx.printLine(line);
    }

    ctx.printLine("");
    ctx.printLine("You can also type regular messages to chat with the agent.");
    ctx.printLine("Use 'exit' or '/exit' to quit.\n");
}

fn cmdClear(ctx: *SlashContext, _: []const u8) !void {
    ctx.print("\x1b[2J\x1b[H");
}

fn cmdExit(ctx: *SlashContext, _: []const u8) !void {
    ctx.should_exit = true;
    ctx.printLine("\n👋 Goodbye!");
}

fn cmdModel(ctx: *SlashContext, args: []const u8) !void {
    if (args.len == 0) {
        const current = ctx.agent.options.model.id;
        const msg = try std.fmt.allocPrint(ctx.allocator, "Current model: {s}", .{current});
        defer ctx.allocator.free(msg);
        ctx.printLine(msg);
        ctx.printLine("Usage: /model <model_id>");
        return;
    }

    const model_id = args;
    const model = ai.models_registry.getModelById(model_id) orelse {
        const err = try std.fmt.allocPrint(ctx.allocator, "❌ Unknown model: {s}", .{model_id});
        defer ctx.allocator.free(err);
        ctx.printLine(err);
        return;
    };

    // Hot-swap model by updating config
    if (ctx.cfg.default_model.len > 0) ctx.cfg.allocator.free(ctx.cfg.default_model);
    ctx.cfg.default_model = try ctx.cfg.allocator.dupe(u8, model_id);

    const msg = try std.fmt.allocPrint(ctx.allocator, "✅ Model switched to: {s}", .{model.id});
    defer ctx.allocator.free(msg);
    ctx.printLine(msg);

    ctx.printLine("⚠️  Restart the session to apply the new model.");
}

fn cmdYolo(ctx: *SlashContext, args: []const u8) !void {
    var new_state: ?bool = null;
    if (std.mem.eql(u8, args, "on")) new_state = true;
    if (std.mem.eql(u8, args, "off")) new_state = false;

    if (new_state) |state| {
        ctx.cfg.yolo_mode = state;
        ctx.agent.options.yolo_mode = state;
        ctx.agent.approval_manager.policy = if (state) .auto else .moderate;
        const msg = try std.fmt.allocPrint(ctx.allocator, "✅ YOLO mode {s}", .{if (state) "enabled" else "disabled"});
        defer ctx.allocator.free(msg);
        ctx.printLine(msg);
    } else {
        const msg = try std.fmt.allocPrint(ctx.allocator, "YOLO mode: {s}", .{if (ctx.cfg.yolo_mode) "ON" else "OFF"});
        defer ctx.allocator.free(msg);
        ctx.printLine(msg);
        ctx.printLine("Usage: /yolo [on|off]");
    }
}

fn cmdToken(ctx: *SlashContext, args: []const u8) !void {
    if (args.len == 0) {
        const msg = try std.fmt.allocPrint(
            ctx.allocator,
            "Token optimization: {s} (strategy: {s})",
            .{
                if (ctx.cfg.token_optimization.enabled) "ON" else "OFF",
                @tagName(ctx.cfg.token_optimization.strategy),
            },
        );
        defer ctx.allocator.free(msg);
        ctx.printLine(msg);
        ctx.printLine("Usage: /token [on|off|strategy conservative|balanced|aggressive]");
        return;
    }

    if (std.mem.eql(u8, args, "on")) {
        ctx.cfg.token_optimization.enabled = true;
        ctx.printLine("✅ Token optimization enabled");
    } else if (std.mem.eql(u8, args, "off")) {
        ctx.cfg.token_optimization.enabled = false;
        ctx.printLine("✅ Token optimization disabled");
    } else if (std.mem.startsWith(u8, args, "strategy ")) {
        const strategy_name = args["strategy ".len..];
        if (config.TokenOptimizationConfig.Strategy.fromString(strategy_name)) |strategy| {
            ctx.cfg.token_optimization.strategy = strategy;
            const msg = try std.fmt.allocPrint(ctx.allocator, "✅ Token strategy set to: {s}", .{@tagName(strategy)});
            defer ctx.allocator.free(msg);
            ctx.printLine(msg);
        } else {
            ctx.printLine("❌ Invalid strategy. Use: conservative, balanced, or aggressive");
        }
    } else {
        ctx.printLine("❌ Unknown /token subcommand");
        ctx.printLine("Usage: /token [on|off|strategy <name>]");
    }
}

fn cmdSkill(ctx: *SlashContext, args: []const u8) !void {
    if (args.len == 0) {
        ctx.printLine("Usage: /skill <skill_id> [param=value...]");
        return;
    }

    var parts = std.mem.splitScalar(u8, args, ' ');
    const skill_id = parts.next().?;

    var params = std.json.ObjectMap.init(ctx.allocator);
    defer params.deinit();

    while (parts.next()) |arg| {
        if (std.mem.indexOf(u8, arg, "=")) |eq| {
            const key = arg[0..eq];
            const value = arg[eq + 1 ..];
            try params.put(key, .{ .string = value });
        }
    }

    const result = ctx.agent.executeSkill(skill_id, params) catch |err| {
        const msg = try std.fmt.allocPrint(ctx.allocator, "❌ Skill execution failed: {s}", .{@errorName(err)});
        defer ctx.allocator.free(msg);
        ctx.printLine(msg);
        return;
    };
    defer {
        if (result.output.len > 0) ctx.allocator.free(result.output);
        if (result.error_message) |err_msg| ctx.allocator.free(err_msg);
    }

    if (result.success) {
        ctx.printLine("✅ Success!");
        if (result.output.len > 0) {
            ctx.print(result.output);
            ctx.printLine("");
        }
    } else {
        ctx.printLine("❌ Failed!");
        if (result.error_message) |err| {
            ctx.print("Error: ");
            ctx.printLine(err);
        }
    }
}

// ============================================================================
// Tests
// ============================================================================

test "parse basic slash command" {
    const parsed = parse("/help");
    try std.testing.expect(parsed != null);
    try std.testing.expectEqualStrings("help", parsed.?.name);
    try std.testing.expectEqualStrings("", parsed.?.args);
}

test "parse slash command with args" {
    const parsed = parse("/model gpt-4o");
    try std.testing.expect(parsed != null);
    try std.testing.expectEqualStrings("model", parsed.?.name);
    try std.testing.expectEqualStrings("gpt-4o", parsed.?.args);
}

test "parse ignores non-slash input" {
    const parsed = parse("hello world");
    try std.testing.expect(parsed == null);
}

test "registry lookup" {
    const cmd = find("clear");
    try std.testing.expect(cmd != null);
    try std.testing.expectEqualStrings("clear", cmd.?.name);

    const missing = find("nonexistent");
    try std.testing.expect(missing == null);
}
