//! kimiz-cli - Command line interface
//! Provides REPL and TUI modes

const std = @import("std");

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
    thinking: ?[]const u8 = null,
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
                    options.thinking = args[i + 1];
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
        .config => try runConfig(allocator),
        .help => printHelp(),
        .version => printVersion(),
    }
}

fn runRepl(allocator: std.mem.Allocator, options: CliOptions) !void {
    _ = options;
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    try stdout.print("kimiz v0.1.0 - AI Coding Agent\n", .{});
    try stdout.print("Type 'exit' or 'quit' to exit, 'help' for commands.\n\n", .{});

    var buf: [4096]u8 = undefined;

    while (true) {
        try stdout.print("> ", .{});

        const line = try stdin.readUntilDelimiterOrEof(&buf, '\n');
        if (line == null) break;

        const input = std.mem.trim(u8, line.?, " \t\r\n");

        if (input.len == 0) continue;
        if (std.mem.eql(u8, input, "exit") or std.mem.eql(u8, input, "quit")) break;
        if (std.mem.eql(u8, input, "help")) {
            printReplHelp();
            continue;
        }

        // Process the input
        try processInput(allocator, input);
    }

    try stdout.print("Goodbye!\n", .{});
}

fn runTui(allocator: std.mem.Allocator, options: CliOptions) !void {
    _ = allocator;
    _ = options;
    const stdout = std.io.getStdOut().writer();
    try stdout.print("TUI mode not yet implemented. Use 'repl' mode instead.\n", .{});
}

fn runOnce(allocator: std.mem.Allocator, options: CliOptions, prompt_arg: ?[]const u8) !void {
    _ = options;
    const stdout = std.io.getStdOut().writer();

    if (prompt_arg) |prompt_text| {
        try processInput(allocator, prompt_text);
    } else {
        try stdout.print("Error: No prompt provided for 'run' command.\n", .{});
    }
}

fn runConfig(allocator: std.mem.Allocator) !void {
    _ = allocator;
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Config management not yet implemented.\n", .{});
}

fn processInput(allocator: std.mem.Allocator, input: []const u8) !void {
    const stdout = std.io.getStdOut().writer();

    // For now, just echo back
    // In full implementation, this would use the Agent to process the input
    try stdout.print("Processing: {s}\n", .{input});
    try stdout.print("(Full agent integration coming soon)\n\n", .{});

    // Simulate some processing time
    std.time.sleep(100 * std.time.ns_per_ms);

    _ = allocator;
}

fn printHelp() void {
    const stdout = std.io.getStdOut().writer();
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
}

fn printReplHelp() void {
    const stdout = std.io.getStdOut().writer();
    stdout.print("REPL Commands:\n", .{}) catch {};
    stdout.print("  help    Show this help\n", .{}) catch {};
    stdout.print("  exit    Exit the REPL\n\n", .{}) catch {};
    stdout.print("Just type your message to chat with the AI.\n", .{}) catch {};
}

fn printVersion() void {
    const stdout = std.io.getStdOut().writer();
    stdout.print("kimiz version 0.1.0\n", .{}) catch {};
}
