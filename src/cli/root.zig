//! kimiz-cli - Command line interface
//! Provides REPL and TUI modes

const std = @import("std");
const core = @import("../core/root.zig");
const ai = @import("../ai/root.zig");
const agent = @import("../agent/root.zig");
const config_mod = @import("../utils/config.zig");

const Commands = enum {
    repl,
    tui,
    run,
    config,
    help,
    version,
};

pub const CliOptions = struct {
    command: Commands = .repl,
    model: ?[]const u8 = null,
    api_key: ?[]const u8 = null,
    yolo: bool = false,
    plan: bool = false,
    thinking: core.ThinkingLevel = .off,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var options = CliOptions{};

    // Parse command line arguments
    if (args.len > 1) {
        const cmd = args[1];
        if (std.mem.eql(u8, cmd, "repl")) {
            options.command = .repl;
        } else if (std.mem.eql(u8, cmd, "tui")) {
            options.command = .tui;
        } else if (std.mem.eql(u8, cmd, "run")) {
            options.command = .run;
        } else if (std.mem.eql(u8, cmd, "config")) {
            options.command = .config;
        } else if (std.mem.eql(u8, cmd, "help") or std.mem.eql(u8, cmd, "--help") or std.mem.eql(u8, cmd, "-h")) {
            options.command = .help;
        } else if (std.mem.eql(u8, cmd, "version") or std.mem.eql(u8, cmd, "--version") or std.mem.eql(u8, cmd, "-v")) {
            options.command = .version;
        } else {
            // Unknown command, default to run with the command as prompt
            options.command = .run;
        }

        // Parse flags
        var i: usize = 2;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (std.mem.eql(u8, arg, "--model")) {
                if (i + 1 < args.len) {
                    options.model = args[i + 1];
                    i += 1;
                }
            } else if (std.mem.eql(u8, arg, "--api-key")) {
                if (i + 1 < args.len) {
                    options.api_key = args[i + 1];
                    i += 1;
                }
            } else if (std.mem.eql(u8, arg, "--yolo")) {
                options.yolo = true;
            } else if (std.mem.eql(u8, arg, "--plan")) {
                options.plan = true;
            } else if (std.mem.eql(u8, arg, "--thinking")) {
                if (i + 1 < args.len) {
                    options.thinking = parseThinkingLevel(args[i + 1]);
                    i += 1;
                }
            }
        }
    }

    // Execute command
    switch (options.command) {
        .repl => try runRepl(allocator, options),
        .tui => try runTui(allocator, options),
        .run => try runOnce(allocator, options, if (args.len > 1) args[1] else null),
        .config => {
            // Pass remaining args after "config" to runConfig
            const config_args = if (args.len > 2) args[2..] else &[_][]const u8{};
            try runConfig(allocator, config_args);
        },
        .help => printHelp(),
        .version => printVersion(),
    }
}

fn parseThinkingLevel(level: []const u8) core.ThinkingLevel {
    if (std.mem.eql(u8, level, "off")) return .off;
    if (std.mem.eql(u8, level, "minimal")) return .minimal;
    if (std.mem.eql(u8, level, "low")) return .low;
    if (std.mem.eql(u8, level, "medium")) return .medium;
    if (std.mem.eql(u8, level, "high")) return .high;
    if (std.mem.eql(u8, level, "xhigh")) return .xhigh;
    return .off;
}

fn detectProvider(model_id: []const u8) core.KnownProvider {
    if (std.mem.startsWith(u8, model_id, "gpt-") or std.mem.startsWith(u8, model_id, "o")) return .openai;
    if (std.mem.startsWith(u8, model_id, "claude-")) return .anthropic;
    if (std.mem.startsWith(u8, model_id, "gemini-")) return .google;
    if (std.mem.startsWith(u8, model_id, "kimi-")) return .kimi;
    if (std.mem.eql(u8, model_id, "kimi-for-coding")) return .kimi;
    if (std.mem.startsWith(u8, model_id, "accounts/fireworks")) return .fireworks;
    return .openai; // default
}

fn runRepl(allocator: std.mem.Allocator, options: CliOptions) !void {
    var stdout_buf: [4096]u8 = undefined;
    var stdout_file = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_file.interface;
    var stdin_file = std.fs.File.stdin();

    try stdout.print("kimiz v0.1.0 - AI Coding Agent\n", .{});
    try stdout.print("Type 'exit' or 'quit' to exit, 'help' for commands.\n\n", .{});
    try stdout.flush();

    // Initialize AI client
    var ai_client = ai.Ai.init(allocator);
    defer ai_client.deinit();

    // Get model
    const model_id = options.model orelse "gpt-4o";
    const provider = detectProvider(model_id);
    const model = ai.models_registry.getModel(provider, model_id) orelse {
        try stdout.print("Error: Unknown model '{s}'\n", .{model_id});
        try stdout.flush();
        return error.ModelNotFound;
    };

    // Initialize agent
    const agent_options = agent.AgentOptions{
        .model = model,
        .yolo_mode = options.yolo,
        .plan_mode = options.plan,
        .thinking_level = options.thinking,
    };

    var ai_agent = try agent.Agent.init(allocator, agent_options);
    defer ai_agent.deinit();

    // Set event callback
    ai_agent.setEventCallback(struct {
        fn onEvent(evt: agent.AgentEvent) void {
            var sbuf: [4096]u8 = undefined;
            var sfile = std.fs.File.stdout().writer(&sbuf);
            const w = &sfile.interface;
            switch (evt) {
                .message_start => w.print("\n[Assistant] ", .{}) catch {},
                .message_delta => |delta| w.print("{s}", .{delta}) catch {},
                .message_complete => w.print("\n", .{}) catch {},
                .tool_call_start => |info| w.print("\n[Tool: {s}]\n", .{info.name}) catch {},
                .tool_call_delta => {},
                .tool_call_complete => {},
                .tool_executing => {},
                .tool_result => |result| {
                    if (result.result.is_error) {
                        w.print("[Error: tool failed]\n", .{}) catch {};
                    } else {
                        w.print("[Tool result received]\n", .{}) catch {};
                    }
                },
                .err => |err| w.print("\n[Error: {s}]\n", .{err}) catch {},
                .done => w.print("\n[Done]\n", .{}) catch {},
            }
            w.flush() catch {};
        }
    }.onEvent);

    var buf: [4096]u8 = undefined;

    while (true) {
        try stdout.print("> ", .{});
        try stdout.flush();

        // Read line using std.fs.File.read
        const bytes_read = stdin_file.read(&buf) catch break;
        if (bytes_read == 0) break;

        // Find newline
        var line_end: usize = bytes_read;
        for (buf[0..bytes_read], 0..) |byte, i| {
            if (byte == '\n') {
                line_end = i;
                break;
            }
        }

        const input = std.mem.trim(u8, buf[0..line_end], " \t\r\n");

        if (input.len == 0) continue;
        if (std.mem.eql(u8, input, "exit") or std.mem.eql(u8, input, "quit")) break;
        if (std.mem.eql(u8, input, "help")) {
            printReplHelp();
            continue;
        }

        // Process the input through the agent
        ai_agent.prompt(input) catch |err| {
            try stdout.print("Error: {s}\n", .{@errorName(err)});
            try stdout.flush();
        };
    }

    try stdout.print("Goodbye!\n", .{});
    try stdout.flush();
}

fn runTui(allocator: std.mem.Allocator, options: CliOptions) !void {
    _ = allocator;
    _ = options;
    var stdout_buf: [4096]u8 = undefined;
    var stdout_file = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_file.interface;
    try stdout.print("TUI mode not yet implemented. Use 'repl' mode instead.\n", .{});
    try stdout.flush();
}

fn runOnce(allocator: std.mem.Allocator, options: CliOptions, prompt_arg: ?[]const u8) !void {
    _ = options;
    var stdout_buf: [4096]u8 = undefined;
    var stdout_file = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_file.interface;

    if (prompt_arg) |prompt_text| {
        try processInput(allocator, prompt_text);
    } else {
        try stdout.print("Error: No prompt provided for 'run' command.\n", .{});
        try stdout.flush();
    }
}

fn runConfig(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var stdout_buf: [4096]u8 = undefined;
    var stdout_file = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_file.interface;

    // Initialize config manager
    var config_manager = try config_mod.ConfigManager.init(allocator);
    defer config_manager.deinit();

    // Load or create config
    var config = try config_manager.load();
    defer config_mod.configDeinit(&config, allocator);

    if (args.len == 0) {
        // Show current config
        try stdout.print("Current Configuration:\n", .{});
        try stdout.print("  default_model: {s}\n", .{config.default_model});
        try stdout.print("  theme: {s}\n", .{@tagName(config.theme)});
        try stdout.print("  auto_approve_tools: {}\n", .{config.auto_approve_tools});
        try stdout.print("  yolo_mode: {}\n", .{config.yolo_mode});
        try stdout.print("\nConfig file: {s}\n", .{config_manager.config_path});
        try stdout.flush();
        return;
    }

    const subcommand = args[0];

    if (std.mem.eql(u8, subcommand, "get")) {
        if (args.len < 2) {
            try stdout.print("Usage: kimiz config get <key>\n", .{});
            try stdout.flush();
            return;
        }
        const key = args[1];
        if (std.mem.eql(u8, key, "default_model")) {
            try stdout.print("{s}\n", .{config.default_model});
        } else if (std.mem.eql(u8, key, "theme")) {
            try stdout.print("{s}\n", .{@tagName(config.theme)});
        } else if (std.mem.eql(u8, key, "auto_approve_tools")) {
            try stdout.print("{}\n", .{config.auto_approve_tools});
        } else if (std.mem.eql(u8, key, "yolo_mode")) {
            try stdout.print("{}\n", .{config.yolo_mode});
        } else {
            try stdout.print("Unknown key: {s}\n", .{key});
        }
        try stdout.flush();
    } else if (std.mem.eql(u8, subcommand, "set")) {
        if (args.len < 3) {
            try stdout.print("Usage: kimiz config set <key> <value>\n", .{});
            try stdout.flush();
            return;
        }
        const key = args[1];
        const value = args[2];

        if (std.mem.eql(u8, key, "default_model")) {
            allocator.free(config.default_model);
            config.default_model = try allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, key, "theme")) {
            config.theme = std.meta.stringToEnum(config_mod.Config.Theme, value) orelse .system;
        } else if (std.mem.eql(u8, key, "auto_approve_tools")) {
            config.auto_approve_tools = std.mem.eql(u8, value, "true");
        } else if (std.mem.eql(u8, key, "yolo_mode")) {
            config.yolo_mode = std.mem.eql(u8, value, "true");
        } else {
            try stdout.print("Unknown key: {s}\n", .{key});
            try stdout.flush();
            return;
        }

        try config_manager.save(&config);
        try stdout.print("Configuration updated.\n", .{});
        try stdout.flush();
    } else if (std.mem.eql(u8, subcommand, "list")) {
        try stdout.print("Configuration:\n", .{});
        try stdout.print("  default_model: {s}\n", .{config.default_model});
        try stdout.print("  theme: {s}\n", .{@tagName(config.theme)});
        try stdout.print("  auto_approve_tools: {}\n", .{config.auto_approve_tools});
        try stdout.print("  yolo_mode: {}\n", .{config.yolo_mode});
        try stdout.flush();
    } else if (std.mem.eql(u8, subcommand, "apikey")) {
        if (args.len < 3) {
            try stdout.print("Usage: kimiz config apikey <provider> <key>\n", .{});
            try stdout.print("  provider: openai, anthropic, google, kimi, fireworks\n", .{});
            try stdout.flush();
            return;
        }
        const provider = args[1];
        const key = args[2];
        try config_manager.setApiKey(&config, provider, key);
        try stdout.print("API key for {s} set.\n", .{provider});
        try stdout.flush();
    } else {
        try stdout.print("Unknown config command: {s}\n", .{subcommand});
        try stdout.print("Usage: kimiz config [get|set|list|apikey]\n", .{});
        try stdout.flush();
    }
}

fn processInput(allocator: std.mem.Allocator, input: []const u8) !void {
    var stdout_buf: [4096]u8 = undefined;
    var stdout_file = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_file.interface;

    try stdout.print("Processing: {s}\n", .{input});
    try stdout.print("(Full agent integration coming soon)\n\n", .{});
    try stdout.flush();

    std.time.sleep(100 * std.time.ns_per_ms);

    _ = allocator;
}

fn printHelp() void {
    var stdout_buf: [4096]u8 = undefined;
    var stdout_file = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_file.interface;
    stdout.print("kimiz - AI Coding Agent\n\n", .{}) catch {};
    stdout.print("Usage: kimiz [COMMAND] [OPTIONS]\n\n", .{}) catch {};
    stdout.print("Commands:\n", .{}) catch {};
    stdout.print("  repl          Start interactive REPL mode (default)\n", .{}) catch {};
    stdout.print("  tui           Start TUI mode\n", .{}) catch {};
    stdout.print("  run <prompt>  Run a single prompt\n", .{}) catch {};
    stdout.print("  config        Manage configuration\n", .{}) catch {};
    stdout.print("  help          Show this help message\n", .{}) catch {};
    stdout.print("  version       Show version information\n\n", .{}) catch {};
    stdout.print("Options:\n", .{}) catch {};
    stdout.print("  --model <id>       Specify the model to use\n", .{}) catch {};
    stdout.print("  --api-key <key>    Provide API key\n", .{}) catch {};
    stdout.print("  --yolo             Enable YOLO mode (auto-approve tools)\n", .{}) catch {};
    stdout.print("  --plan             Enable plan mode\n", .{}) catch {};
    stdout.print("  --thinking <level> Set thinking level (off/minimal/low/medium/high/xhigh)\n\n", .{}) catch {};
    stdout.print("Examples:\n", .{}) catch {};
    stdout.print("  kimiz repl\n", .{}) catch {};
    stdout.print("  kimiz run \"What is Zig?\"\n", .{}) catch {};
    stdout.print("  kimiz repl --model gpt-4o --yolo\n", .{}) catch {};
    stdout.flush() catch {};
}

fn printReplHelp() void {
    var stdout_buf: [4096]u8 = undefined;
    var stdout_file = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_file.interface;
    stdout.print("REPL Commands:\n", .{}) catch {};
    stdout.print("  help    Show this help\n", .{}) catch {};
    stdout.print("  exit    Exit the REPL\n\n", .{}) catch {};
    stdout.print("Just type your message to chat with the AI.\n", .{}) catch {};
    stdout.flush() catch {};
}

fn printVersion() void {
    var stdout_buf: [4096]u8 = undefined;
    var stdout_file = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_file.interface;
    stdout.print("kimiz version 0.1.0\n", .{}) catch {};
    stdout.flush() catch {};
}
