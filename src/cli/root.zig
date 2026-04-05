//! kimiz-cli - Command line interface with full Agent integration

const std = @import("std");
const core = @import("../core/root.zig");
const ai = @import("../ai/root.zig");
const agent = @import("../agent/root.zig");
const extension = @import("../extension/root.zig");
const harness = @import("../harness/root.zig");
const workspace = @import("../workspace/root.zig");
const config = @import("../config.zig");

// Use linux syscalls directly
const STDOUT_FILENO = 1;
const STDIN_FILENO = 0;

fn sysWrite(fd: usize, buf: []const u8) usize {
    return std.os.linux.syscall3(.write, fd, @intFromPtr(buf.ptr), buf.len);
}

fn sysRead(fd: usize, buf: []u8) usize {
    return std.os.linux.syscall3(.read, fd, @intFromPtr(buf.ptr), buf.len);
}

fn print(msg: []const u8) void {
    _ = sysWrite(STDOUT_FILENO, msg);
}

fn printLine(msg: []const u8) void {
    print(msg);
    print("\n");
}

// Global agent instance for callbacks
var g_agent: ?*agent.Agent = null;

fn handleAgentEvent(evt: agent.AgentEvent) void {
    switch (evt) {
        .message_start => {
            print("\n🤔 Thinking...\n");
        },
        .message_delta => |text| {
            print(text);
        },
        .message_complete => {
            print("\n");
        },
        .tool_call_start => |info| {
            print("\n🔧 Calling tool: ");
            print(info.name);
            print("\n");
        },
        .tool_call_complete => {},
        .tool_call_delta => {},
        .tool_executing => {},
        .tool_result => |result| {
            if (result.result.is_error) {
                print("❌ Tool failed: ");
            } else {
                print("✅ Tool result: ");
            }
            if (result.result.content.len > 0) {
                const content = result.result.content[0];
                switch (content) {
                    .text => |text| {
                        // Print first 100 chars
                        const preview = if (text.len > 100) text[0..100] else text;
                        print(preview);
                        if (text.len > 100) print("...");
                    },
                    .image => print("[image]"),
                    .image_url => print("[image_url]"),
                }
            }
            print("\n");
        },
        .done => {
            print("\n✨ Done!\n\n");
        },
        .err => |e| {
            print("\n❌ Error: ");
            print(e);
            print("\n");
        },
    }
}

// Global environment map storage
var g_environ_map: ?*std.process.Environ.Map = null;

/// Initialize environment variable access
pub fn initEnvVars(environ_map: *std.process.Environ.Map) void {
    g_environ_map = environ_map;
}

/// Get environment variable value
pub fn getEnvVar(allocator: std.mem.Allocator, name: []const u8) error{NotFound, OutOfMemory}![]const u8 {
    const env_map = g_environ_map orelse return error.NotFound;
    const value = env_map.get(name) orelse return error.NotFound;
    return allocator.dupe(u8, value);
}

pub fn run(
    allocator: std.mem.Allocator,
    environ_map: *std.process.Environ.Map,
    args: std.process.Args,
) !void {
    // Initialize environment variables
    initEnvVars(environ_map);
    // Parse simple args using iterator
    var it = args.iterate();
    
    // Collect args into a list for easier handling
    var args_list: std.ArrayList([]const u8) = .empty;
    defer args_list.deinit(allocator);
    
    while (it.next()) |arg| {
        try args_list.append(allocator, arg);
    }
    
    const args_slice = args_list.items;

    // Check for help
    if (args_slice.len > 1 and (std.mem.eql(u8, args_slice[1], "--help") or std.mem.eql(u8, args_slice[1], "-h"))) {
        printHelp();
        return;
    }

    // Check for skill command
    if (args_slice.len > 1 and std.mem.eql(u8, args_slice[1], "skill")) {
        if (args_slice.len < 3) {
            printLine("Usage: kimiz skill <skill_id> [param=value...]");
            return;
        }
        try runSkillCommand(allocator, args_slice[2..]);
        return;
    }

    // Interactive mode
    try runInteractive(allocator);
}

fn runInteractive(allocator: std.mem.Allocator) !void {
    const welcome = 
        \\kimiz v0.2.0 - AI Coding Agent
        \\Type 'exit' or 'quit' to exit, 'help' for commands.
        \\n
    ;
    print(welcome);

    // Initialize configuration
    print("🚀 Initializing...\n");
    var cfg = try config.Config.init(allocator);
    defer cfg.deinit();
    try cfg.loadFromEnv();
    
    // Check if any API key is configured
    if (!cfg.hasAnyApiKey()) {
        print("⚠️  No API keys configured. Set at least one of:\n");
        print("   OPENAI_API_KEY, ANTHROPIC_API_KEY, GOOGLE_API_KEY,\n");
        print("   KIMI_API_KEY, FIREWORKS_API_KEY, OPENROUTER_API_KEY\n\n");
    }

    // Get model from config
    const model_id = cfg.default_model;
    const model = ai.models_registry.getModelById(model_id) orelse {
        print("❌ Unknown model: ");
        print(model_id);
        print("\nUsing default: kimi-for-coding\n");
        _ = ai.models_registry.getModelById("kimi-for-coding") orelse {
            print("❌ Default model kimi-for-coding not found\n");
            return error.ModelNotFound;
        };
        return error.ModelNotFound;
    };

    // Get working directory
    var cwd_buf: [std.fs.max_path_bytes]u8 = undefined;
    const cwd = if (std.c.getcwd(&cwd_buf, cwd_buf.len)) |ptr|
        std.mem.sliceTo(ptr, 0)
    else
        ".";

    // Collect workspace context
    print("📁 Collecting workspace context...\n");
    var workspace_ctx = workspace.WorkspaceInfo.init(allocator, cwd) catch |err| {
        print("⚠️  Failed to initialize workspace context: ");
        print(@errorName(err));
        print("\n");
        return err;
    };
    defer workspace_ctx.deinit();

    workspace_ctx.collect() catch |err| {
        print("⚠️  Failed to collect workspace context: ");
        print(@errorName(err));
        print("\n");
    };

    // Format and display workspace context
    const ctx_str = workspace_ctx.formatContext(allocator) catch |err| blk: {
        print("⚠️  Failed to format workspace context: ");
        print(@errorName(err));
        print("\n");
        break :blk null;
    };
    defer if (ctx_str) |s| allocator.free(s);

    if (ctx_str) |_| {
        print("✅ Workspace context collected\n");
    }

    // Initialize Agent
    var ai_agent = agent.Agent.init(allocator, .{
        .model = model,
        .temperature = cfg.default_temperature,
        .max_tokens = cfg.default_max_tokens,
        .thinking_level = .medium,
        .yolo_mode = cfg.yolo_mode,
        .max_iterations = 50,
    }) catch |err| {
        print("❌ Failed to initialize Agent: ");
        print(@errorName(err));
        print("\n");
        return err;
    };
    defer ai_agent.deinit();

    ai_agent.setEventCallback(handleAgentEvent);
    g_agent = &ai_agent;

    print("✅ Agent ready!\n\n");

    // REPL loop
    var buf: [4096]u8 = undefined;

    while (true) {
        print("> ");

        const n = sysRead(STDIN_FILENO, &buf);
        if (n == 0 or n > buf.len) break;

        // Find newline
        var len: usize = 0;
        while (len < n and buf[len] != '\n') : (len += 1) {}

        const input = std.mem.trim(u8, buf[0..len], " \t\r\n");
        if (input.len == 0) continue;
        if (std.mem.eql(u8, input, "exit") or std.mem.eql(u8, input, "quit")) break;

        if (std.mem.eql(u8, input, "help")) {
            printHelp();
            continue;
        }

        if (std.mem.eql(u8, input, "clear")) {
            print("\x1b[2J\x1b[H"); // ANSI clear screen
            continue;
        }

        // Process input with Agent
        ai_agent.prompt(input) catch |err| {
            print("\n❌ Agent error: ");
            print(@errorName(err));
            print("\n");
        };
    }

    print("\n👋 Goodbye!\n");
}

fn runSkillCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        printLine("Usage: kimiz skill <skill_id> [param=value...]");
        return;
    }

    const skill_id = args[0];

    // Parse parameters into JSON ObjectMap
    var params = std.json.ObjectMap.init(allocator);
    defer params.deinit();

    for (args[1..]) |arg| {
        if (std.mem.indexOf(u8, arg, "=")) |eq| {
            const key = arg[0..eq];
            const value = arg[eq + 1 ..];
            try params.put(key, .{ .string = value });
        }
    }

    // Initialize Agent
    const model = ai.models_registry.getModelById("kimi-for-coding") orelse {
        printLine("❌ Failed to get default model kimi-for-coding");
        return;
    };

    var ai_agent = agent.Agent.init(allocator, .{
        .model = model,
    }) catch |err| {
        print("❌ Failed to initialize Agent: ");
        print(@errorName(err));
        print("\n");
        return err;
    };
    defer ai_agent.deinit();

    // Execute skill
    print("🔧 Executing skill: ");
    print(skill_id);
    print("\n");

    const result = ai_agent.executeSkill(skill_id, params) catch |err| {
        print("❌ Skill execution failed: ");
        print(@errorName(err));
        print("\n");
        return;
    };

    if (result.success) {
        printLine("✅ Success!");
        print("Output:\n");
        print(result.output);
        print("\n");
    } else {
        printLine("❌ Failed!");
        if (result.error_message) |err| {
            print("Error: ");
            printLine(err);
        }
    }
}

fn printHelp() void {
    const help =
        \\kimiz - AI Coding Agent
        \\
        \\Commands:
        \\  help              Show this help
        \\  exit, quit        Exit the program
        \\  clear             Clear screen
        \\
        \\Usage:
        \\  kimiz              Start interactive mode
        \\  kimiz skill <id>   Execute a skill
        \\
        \\Environment:
        \\  KIMIZ_MODEL        Default model (default: kimi-for-coding)
        \\  KIMI_API_KEY       Kimi API key (recommended)
        \\  OPENAI_API_KEY     OpenAI API key
        \\  ANTHROPIC_API_KEY  Anthropic API key
        \\  GOOGLE_API_KEY     Google API key
        \\  FIREWORKS_API_KEY  Fireworks API key
        \\  OPENROUTER_API_KEY OpenRouter API key
        \\  KIMIZ_YOLO_MODE    Enable YOLO mode (1/true/yes)
        \\  
        \\Note: Kimi for Coding is the recommended default model with 262k context window.
        \\
    ;
    print(help);
}
