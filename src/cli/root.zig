//! kimiz-cli - Command line interface with full Agent integration

const std = @import("std");
const core = @import("../core/root.zig");
const ai = @import("../ai/root.zig");
const agent = @import("../agent/root.zig");
const extension = @import("../extension/root.zig");
const harness = @import("../harness/root.zig");
const workspace = @import("../workspace/root.zig");
const config = @import("../config.zig");
pub const slash = @import("slash.zig");

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("unistd.h");
});

fn getStdout() *c.FILE {
    if (comptime @typeInfo(@TypeOf(c.stdout)) == .pointer)
        return c.stdout
    else
        return c.stdout();
}

fn getStdin() *c.FILE {
    if (comptime @typeInfo(@TypeOf(c.stdin)) == .pointer)
        return c.stdin
    else
        return c.stdin();
}

fn print(msg: []const u8) void {
    _ = c.fwrite(msg.ptr, 1, msg.len, getStdout());
    _ = c.fflush(getStdout());
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
        .message_complete => |msg| {
            // Print assistant text content
            for (msg.content) |block| {
                switch (block) {
                    .text => |t| {
                        print(t.text);
                        print("\n");
                    },
                    .thinking => |t| {
                        print("\n[Thinking] ");
                        const preview = if (t.thinking.len > 200) t.thinking[0..200] else t.thinking;
                        print(preview);
                        if (t.thinking.len > 200) print("...");
                        print("\n");
                    },
                    .tool_call => {},
                }
            }
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
            print("\n❌ ");
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
    if (args_slice.len > 1 and (std.mem.eql(u8, args_slice[1], "--help") or std.mem.eql(u8, args_slice[1], "-h") or std.mem.eql(u8, args_slice[1], "help"))) {
        printHelp();
        return;
    }

    // Check for version
    if (args_slice.len > 1 and (std.mem.eql(u8, args_slice[1], "--version") or std.mem.eql(u8, args_slice[1], "-v") or std.mem.eql(u8, args_slice[1], "version"))) {
        printLine("kimiz version 0.3.0");
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
    print("kimiz v0.3.0 - AI Coding Agent\n");
    print("Type 'exit' or 'quit' to exit, 'help' for commands.\n\n");

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
        print("\nUsing default: k2p5\n");
        _ = ai.models_registry.getModelById("k2p5") orelse {
            print("❌ Default model k2p5 not found\n");
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

    // Create tool contexts (must outlive Agent)
    var read_file_ctx = agent.createReadFileTool();
    var write_file_ctx = agent.createWriteFileTool();
    var edit_ctx = agent.createEditTool();
    var fff_ctx = agent.fff.FFFGrepContext{ .project_path = cwd };
    var bash_ctx = agent.bash.BashContext{ .auto_approve = cfg.yolo_mode };
    var git_status_ctx = agent.git.GitStatusContext{};
    var git_diff_ctx = agent.git.GitDiffContext{};
    var git_log_ctx = agent.git.GitLogContext{};

    const tools = [_]agent.AgentTool{
        agent.read_file.createAgentTool(&read_file_ctx),
        agent.write_file.createAgentTool(&write_file_ctx),
        agent.edit.createAgentTool(&edit_ctx),
        agent.fff.createAgentTool(&fff_ctx),
        agent.fff.createFileSearchTool(&fff_ctx),
        agent.bash.createAgentTool(&bash_ctx),
        agent.git.createGitStatusTool(&git_status_ctx),
        agent.git.createGitDiffTool(&git_diff_ctx),
        agent.git.createGitLogTool(&git_log_ctx),
    };

    // Initialize Agent
    var ai_agent = agent.Agent.init(allocator, .{
        .model = model,
        .tools = &tools,
        .temperature = cfg.default_temperature,
        .max_tokens = cfg.default_max_tokens,
        .thinking_level = .medium,
        .yolo_mode = cfg.yolo_mode,
        .max_iterations = 50,
        .project_path = cwd,
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

        const line = c.fgets(&buf, buf.len, getStdin());
        if (line == null) break;

        const raw = std.mem.sliceTo(&buf, 0);
        const input = std.mem.trim(u8, raw, " \t\r\n");
        if (input.len == 0) continue;
        if (std.mem.eql(u8, input, "exit") or std.mem.eql(u8, input, "quit")) break;

        if (std.mem.eql(u8, input, "help")) {
            printHelp();
            continue;
        }

        if (std.mem.eql(u8, input, "clear")) {
            print("\x1b[2J\x1b[H");
            continue;
        }

        // Shell mode: detect `$` prefix for direct shell execution
        if (input.len > 1 and input[0] == '$') {
            const shell_cmd = std.mem.trim(u8, input[1..], " \t");
            if (shell_cmd.len > 0) {
                const result = executeShellCommand(allocator, shell_cmd) catch |err| {
                    print("\n❌ Shell error: ");
                    print(@errorName(err));
                    print("\n");
                    continue;
                };
                defer allocator.free(result);
                print("\n$ ");
                print(shell_cmd);
                print("\n");
                print(result);
                print("\n");
            }
            continue;
        }

        // Slash command handling
        if (slash.parse(input)) |cmd_info| {
            if (slash.find(cmd_info.name)) |cmd| {
                var ctx = slash.SlashContext{
                    .allocator = allocator,
                    .agent = &ai_agent,
                    .cfg = &cfg,
                    .print_fn = print,
                    .print_line_fn = printLine,
                    .should_exit = false,
                };
                cmd.handler(&ctx, cmd_info.args) catch |err| {
                    const msg = std.fmt.allocPrint(allocator, "❌ Command failed: {s}\n", .{@errorName(err)}) catch "❌ Command failed\n";
                    defer allocator.free(msg);
                    print(msg);
                };
                if (ctx.should_exit) break;
            } else {
                print("Unknown slash command '/");
                print(cmd_info.name);
                print("'. Type /help for list.\n");
            }
            continue;
        }

        // Deep copy user input since buf will be overwritten
        const user_input = allocator.dupe(u8, input) catch {
            print("Out of memory\n");
            continue;
        };
        defer allocator.free(user_input);

        ai_agent.prompt(user_input) catch |err| {
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
    const model = ai.models_registry.getModelById("k2p5") orelse {
        printLine("❌ Failed to get default model k2p5");
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
    defer {
        if (result.output.len > 0) allocator.free(result.output);
        if (result.error_message) |err_msg| allocator.free(err_msg);
    }

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

fn executeShellCommand(allocator: std.mem.Allocator, command: []const u8) ![]u8 {
    const cc = @cImport({ @cInclude("stdlib.h"); @cInclude("stdio.h"); });

    // Build command with stderr redirected
    var cmd_buf: std.ArrayList(u8) = .empty;
    defer cmd_buf.deinit(allocator);
    try cmd_buf.appendSlice(allocator, command);
    try cmd_buf.appendSlice(allocator, " 2>&1");

    const c_cmd = try allocator.dupeZ(u8, cmd_buf.items);
    defer allocator.free(c_cmd);

    const pipe = cc.popen(c_cmd.ptr, "r") orelse return error.ShellExecutionFailed;
    defer _ = cc.pclose(pipe);

    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    const max_output: usize = 100 * 1024; // 100KB limit
    var buf: [4096]u8 = undefined;
    while (output.items.len < max_output) {
        const n = cc.fread(&buf, 1, buf.len, pipe);
        if (n == 0) break;
        try output.appendSlice(allocator, buf[0..n]);
    }

    return try allocator.dupe(u8, std.mem.trim(u8, output.items, "\n"));
}

fn printHelp() void {
    const help =
        \\kimiz - AI Coding Agent
        \\
        \\Commands:
        \\  help              Show this help
        \\  exit, quit        Exit the program
        \\  clear             Clear screen
        \\  $ <cmd>           Execute shell command directly
        \\
        \\Usage:
        \\  kimiz              Start interactive mode
        \\  kimiz skill <id>   Execute a skill
        \\
        \\Environment:
        \\  KIMIZ_MODEL        Default model (default: k2p5)
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
