//! kimiz-cli - Command line interface with full Agent integration
//! Simplified for Zig 0.16 - removed yazap dependency

const std = @import("std");
// const yazap = @import("yazap");  // Disabled: not compatible with Zig 0.16
const core = @import("../core/root.zig");
const ai = @import("../ai/root.zig");
const agent = @import("../agent/root.zig");
const extension = @import("../extension/root.zig");
const harness = @import("../harness/root.zig");
const workspace = @import("../workspace/root.zig");
const config = @import("../config.zig");
const skills = @import("../skills/root.zig");
const daemon = @import("../daemon/supervisor.zig");
const engine = @import("../engine/root.zig");
const utils = @import("../utils/root.zig");
const tui = @import("../tui/root.zig");
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
    // Try the environ_map first
    if (g_environ_map) |env_map| {
        if (env_map.get(name)) |value| {
            return allocator.dupe(u8, value);
        }
    }
    
    // Fallback: use libc getenv directly
    const name_z = try allocator.dupeZ(u8, name);
    defer allocator.free(name_z);
    if (std.c.getenv(name_z)) |value_ptr| {
        const value = std.mem.sliceTo(value_ptr, 0);
        return allocator.dupe(u8, value);
    }
    
    return error.NotFound;
}

pub fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *std.process.Environ.Map,
    args: std.process.Args,
) !void {
    initEnvVars(environ_map);

    var app = yazap.App.init(allocator, "kimiz", "AI Coding Agent");
    defer app.deinit();
    try app.rootCommand().addArg(yazap.Arg.booleanOption("version", 'v', "Show version"));
    try app.rootCommand().addArg(yazap.Arg.booleanOption("autonomous", 'a', "Run in autonomous mode (T-128)"));

    // kimiz skill <skill_id> [params...]
    var skill_cmd = app.createCommand("skill", "Execute a skill directly");
    try skill_cmd.addArg(yazap.Arg.positional("SKILL_ID", "Skill identifier", null));
    try app.rootCommand().addSubcommand(skill_cmd);

    // kimiz generate-skill <name> <description>
    var gen_cmd = app.createCommand("generate-skill", "Generate a new skill");
    try gen_cmd.addArg(yazap.Arg.positional("NAME", "Skill name", null));
    try gen_cmd.addArg(yazap.Arg.positional("DESCRIPTION", "Skill description", null));
    try app.rootCommand().addSubcommand(gen_cmd);

    // kimiz metrics [action]
    var metrics_cmd = app.createCommand("metrics", "Observability metrics (show|list|history|export)");
    try metrics_cmd.addArg(yazap.Arg.positional("ACTION", "Action", null));
    try app.rootCommand().addSubcommand(metrics_cmd);

    // kimiz session create <name>
    var sess_cmd = app.createCommand("session", "Session management");
    var sess_create = app.createCommand("create", "Create a new session");
    try sess_create.addArg(yazap.Arg.positional("NAME", "Session name", null));
    const sess_list = app.createCommand("list", "List sessions");
    var sess_stop = app.createCommand("stop", "Stop a session");
    try sess_stop.addArg(yazap.Arg.positional("ID", "Session ID", null));
    try app.rootCommand().addSubcommand(sess_cmd);
    try sess_cmd.addSubcommand(sess_create);
    try sess_cmd.addSubcommand(sess_list);
    try sess_cmd.addSubcommand(sess_stop);

    // kimiz project create <name>
    var proj_cmd = app.createCommand("project", "Project management");
    var proj_create = app.createCommand("create", "Create a new project with 7-phase structure");
    try proj_create.addArg(yazap.Arg.positional("NAME", "Project name", null));
    try app.rootCommand().addSubcommand(proj_cmd);
    try proj_cmd.addSubcommand(proj_create);

    // kimiz task list / next
    var task_cmd = app.createCommand("task", "Task management");
    const task_list = app.createCommand("list", "List all tasks in current sprint");
    const task_next = app.createCommand("next", "Show the next executable task");
    try app.rootCommand().addSubcommand(task_cmd);
    try task_cmd.addSubcommand(task_list);
    try task_cmd.addSubcommand(task_next);

    // Parse arguments
    const matches = app.parseProcess(io, args) catch |err| {
        return err;
    };

    // Dispatch
    if (matches.containsArg("skill")) {
        const m = matches.subcommandMatches("skill").?;
        const skill_id = m.getSingleValue("SKILL_ID") orelse {
            printLine("Usage: kimiz skill <skill_id> [param=value...]");
            return;
        };
        const params_arr: [1][]const u8 = .{skill_id};
        try runSkillCommand(allocator, &params_arr);
        return;
    }

    if (matches.containsArg("generate-skill")) {
        const m = matches.subcommandMatches("generate-skill").?;
        const name = m.getSingleValue("NAME") orelse {
            printLine("Usage: kimiz generate-skill <name> <description>");
            return;
        };
        const desc = m.getSingleValue("DESCRIPTION") orelse {
            printLine("Usage: kimiz generate-skill <name> <description>");
            return;
        };
        try runGenerateSkillCommand(allocator, name, desc);
        return;
    }

    if (matches.containsArg("metrics")) {
        const m = matches.subcommandMatches("metrics").?;
        const action = m.getSingleValue("ACTION") orelse "show";
        const metrics_args: [1][]const u8 = .{action};
        try runMetricsCommand(allocator, &metrics_args);
        return;
    }

    if (matches.containsArg("session")) {
        const sm = matches.subcommandMatches("session").?;
        if (sm.containsArg("create")) {
            const cm = sm.subcommandMatches("create").?;
            const name = cm.getSingleValue("NAME") orelse "default";
            try runSessionCreateCommand(allocator, name);
            return;
        }
        if (sm.containsArg("list")) {
            try runSessionListCommand(allocator);
            return;
        }
        if (sm.containsArg("stop")) {
            const sm2 = sm.subcommandMatches("stop").?;
            const id = sm2.getSingleValue("ID") orelse {
                printLine("Usage: kimiz session stop <id>");
                return;
            };
            try runSessionStopCommand(allocator, id);
            return;
        }
    }

    if (matches.containsArg("project")) {
        const pm = matches.subcommandMatches("project").?;
        if (pm.containsArg("create")) {
            const m = pm.subcommandMatches("create").?;
            const name = m.getSingleValue("NAME") orelse {
                printLine("Usage: kimiz project create <name>");
                return;
            };
            var project = try engine.project.createProject(allocator, name, .{});
            defer project.deinit();
            print("✅ Created project ");
            print(project.id);
            print(" at ");
            print(project.dir_path);
            print("\n");

            if (matches.containsArg("autonomous")) {
                try runAutonomousProject(allocator, &project);
            }
            return;
        }
    }

    // TUI mode
    if (args_slice.len > 1 and (std.mem.eql(u8, args_slice[1], "--tui") or std.mem.eql(u8, args_slice[1], "-t"))) {
        try runTuiMode(allocator);
        return;
    }

    if (matches.containsArg("task")) {
        const tm = matches.subcommandMatches("task").?;
        if (tm.containsArg("list")) {
            try runTaskListCommand(allocator);
            return;
        }
        if (tm.containsArg("next")) {
            try runTaskNextCommand(allocator);
            return;
        }
    }

    // No subcommand = interactive mode
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
    var read_task_ctx = agent.doc_tools.ReadActiveTaskContext{};
    var update_log_ctx = agent.doc_tools.UpdateTaskLogContext{};
    var sync_spec_ctx = agent.doc_tools.SyncSpecWithCodeContext{};
    var add_lesson_ctx = agent.lesson_tools.AddLessonContext{};

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
        agent.doc_tools.createReadActiveTaskTool(&read_task_ctx),
        agent.doc_tools.createUpdateTaskLogTool(&update_log_ctx),
        agent.doc_tools.createSyncSpecWithCodeTool(&sync_spec_ctx),
        agent.lesson_tools.createAddLessonTool(&add_lesson_ctx),
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
    ai_agent.registerSubAgentTool() catch |err| {
        print("⚠️  Failed to register subagent tool: ");
        print(@errorName(err));
        print("\n");
    };
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

fn runTuiMode(allocator: std.mem.Allocator) !void {
    print("🚀 Starting KimiZ TUI...\n");
    
    // Initialize config and load env vars
    var cfg = try config.Config.init(allocator);
    defer cfg.deinit();
    try cfg.loadFromEnv();
    
    if (!cfg.hasAnyApiKey()) {
        print("⚠️  No API keys configured. Set KIMI_API_KEY.\n");
        return;
    }
    
    const model_id = cfg.default_model;
    const model = ai.models_registry.getModelById(model_id) orelse {
        print("❌ Model not found: ");
        print(model_id);
        print("\n");
        return error.ModelNotFound;
    };
    
    // Create agent options
    const options = agent.AgentOptions{
        .model = model,
    };
    
    try tui.runTui(allocator, model, options);
}

fn runGenerateSkillCommand(allocator: std.mem.Allocator, name: []const u8, description: []const u8) !void {
    var gen = try skills.generator.Generator.init(allocator);
    defer gen.deinit();

    gen.generate(name, description, 5) catch |err| {
        print("❌ Generation failed: ");
        print(@errorName(err));
        print("\n");
        return;
    };
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
    const io = utils.getIo() catch return error.ShellExecutionFailed;

    // Execute using Zig 0.16 native API
    const result = std.process.run(allocator, io, .{
        .argv = &.{ "sh", "-c", command },    }) catch return error.ShellExecutionFailed;
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    // Combine stdout and stderr
    const combined = if (result.stdout.len > 0 and result.stderr.len > 0)
        try std.mem.concat(allocator, u8, &.{ result.stdout, result.stderr })
    else if (result.stdout.len > 0)
        try allocator.dupe(u8, result.stdout)
    else if (result.stderr.len > 0)
        try allocator.dupe(u8, result.stderr)
    else
        try allocator.dupe(u8, "");
    defer allocator.free(combined);

    const trimmed = std.mem.trim(u8, combined, "\n");
    return try allocator.dupe(u8, trimmed);
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
        \\  kimiz                          Start interactive mode
        \\  kimiz skill <id>               Execute a skill
        \\  kimiz generate-skill <name> <description>
        \\                                 Generate a new skill via LLM
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

fn runMetricsCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const home_dir = if (std.c.getenv("HOME")) |ptr|
        try allocator.dupe(u8, std.mem.sliceTo(ptr, 0))
    else {
        printLine("❌ Could not determine HOME directory");
        return error.NoHomeDir;
    };
    defer allocator.free(home_dir);

    const metrics_dir = try std.fmt.allocPrint(allocator, "{s}/.kimiz/metrics", .{home_dir});
    defer allocator.free(metrics_dir);

    if (args.len == 0 or std.mem.eql(u8, args[0], "show") or std.mem.eql(u8, args[0], "list")) {
        const cmd = try std.fmt.allocPrint(allocator, "ls -t {s}/*.jsonl 2>/dev/null || echo 'NONE'", .{metrics_dir});
        defer allocator.free(cmd);

        const out = try executeShellCommand(allocator, cmd);
        defer allocator.free(out);

        const trimmed = std.mem.trim(u8, out, " \t\n\r");
        if (trimmed.len == 0 or std.mem.eql(u8, trimmed, "NONE")) {
            printLine("\n📊 No metrics data collected yet.");
            printLine("Metrics are collected automatically during Agent sessions.\n");
            return;
        }

        printLine("\n📊 Available metrics:");
        var files = std.mem.splitScalar(u8, trimmed, '\n');
        while (files.next()) |line| {
            const entry = std.mem.trim(u8, line, " \t\n\r");
            if (entry.len == 0) continue;
            const basename = std.fs.path.basename(entry);
            print("  - ");
            print(basename);
            print("\n");
        }
        print("\n");
    } else if (std.mem.eql(u8, args[0], "history")) {
        const count = if (args.len > 1) args[1] else "5";
        printLine("\n📋 Last ");
        print(count);
        printLine(" sessions:");
        printLine("(Metrics history available after running Agent sessions)");
    } else if (std.mem.eql(u8, args[0], "export")) {
        printLine("Usage: kimiz metrics export --session <id> [--format csv] > output.csv");
    } else {
        printLine("Usage: kimiz metrics [show|list|history|export]");
    }
}

// ============================================================================
// Session Management Commands (T-120)
// ============================================================================

fn runSessionCreateCommand(allocator: std.mem.Allocator, name: []const u8) !void {
    var mgr = daemon.SessionManager.init(allocator) catch |err| {
        print("❌ Failed to initialize session manager: ");
        print(@errorName(err));
        print("\n");
        return err;
    };
    defer mgr.deinit();

    const id = mgr.supervisor.createSession(name) catch |err| {
        print("❌ Failed to create session: ");
        print(@errorName(err));
        print("\n");
        return err;
    };
    defer allocator.free(id);

    print("✅ Session created: ");
    print(id);
    print("\n");
    try mgr.supervisor.saveState();
}

fn runSessionListCommand(allocator: std.mem.Allocator) !void {
    var mgr = daemon.SessionManager.init(allocator) catch |err| {
        print("❌ Failed to initialize session manager: ");
        print(@errorName(err));
        print("\n");
        return;
    };
    defer mgr.deinit();

    const sessions = mgr.supervisor.listSessions() catch |err| {
        print("❌ Failed to list sessions: ");
        print(@errorName(err));
        print("\n");
        return;
    };
    defer {
        for (sessions) |*s| s.deinit();
        allocator.free(sessions);
    }

    printLine("\n📋 Active Sessions:");
    printLine("-------------------");
    for (sessions) |s| {
        printLine("  ID:");
        print(s.id);
        print("\n");
        print("  State: ");
        print(@tagName(s.state));
        print("\n  Created: ");
        var buf: [32]u8 = undefined;
        const ts = try std.fmt.bufPrint(&buf, "{d}", .{s.created_at});
        print(ts);
        print("\n\n");
    }
    if (sessions.len == 0) {
        printLine("  No sessions found.");
    }
    printLine("");
}

fn runSessionStopCommand(allocator: std.mem.Allocator, id: []const u8) !void {
    var mgr = daemon.SessionManager.init(allocator) catch |err| {
        print("❌ Failed to initialize session manager: ");
        print(@errorName(err));
        print("\n");
        return;
    };
    defer mgr.deinit();

    mgr.supervisor.stopSession(id) catch |err| {
        print("❌ Failed to stop session: ");
        print(@errorName(err));
        print("\n");
        return;
    };

    print("⏹️  Session stopped: ");
    print(id);
    print("\n");
    try mgr.supervisor.saveState();
}

// ============================================================================
// Task Engine CLI Commands (T-128)
// ============================================================================

fn runProjectCreateCommand(allocator: std.mem.Allocator, name: []const u8) !void {
    var project = try engine.project.createProject(allocator, name, .{});
    defer project.deinit();

    var buf: [512]u8 = undefined;
    const msg = try std.fmt.bufPrint(&buf, "✅ Created project {s} at {s}", .{ project.id, project.dir_path });
    printLine(msg);
}

fn runTaskListCommand(allocator: std.mem.Allocator) !void {
    const sprint_dir = "tasks/active/sprint-2026-04";
    var queue = engine.task.TaskQueue.init(allocator);
    defer queue.deinit();

    const io = utils.getIo() catch |err| {
        var ebuf: [256]u8 = undefined;
        const emsg = try std.fmt.bufPrint(&ebuf, "❌ Failed to get Io instance: {s}", .{@errorName(err)});
        printLine(emsg);
        return;
    };
    const dir = utils.openDir(sprint_dir, .{ .iterate = true }) catch |err| {
        var ebuf: [256]u8 = undefined;
        const emsg = try std.fmt.bufPrint(&ebuf, "❌ Failed to open task directory: {s}", .{@errorName(err)});
        printLine(emsg);
        return;
    };

    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".md")) continue;
        if (std.mem.startsWith(u8, entry.name, "README")) continue;

        const path = try std.fs.path.join(allocator, &.{ sprint_dir, entry.name });
        defer allocator.free(path);

        const content = utils.readFileAlloc(allocator, path, 64 * 1024) catch |err| {
            var ebuf: [256]u8 = undefined;
            const emsg = try std.fmt.bufPrint(&ebuf, "  ⚠️  Failed to read {s}: {s}", .{ entry.name, @errorName(err) });
            printLine(emsg);
            continue;
        };
        defer allocator.free(content);

        if (try engine.task.parseTask(allocator, content, path)) |t| {
            var t_copy = t;
            errdefer t_copy.deinit(allocator);
            try queue.addTask(allocator, t_copy);
        }
    }

    printLine("\n📋 Tasks in current sprint:");
    printLine("---------------------------");
    for (queue.tasks.items) |t| {
        print("  ");
        print(t.id);
        print(" | ");
        print(@tagName(t.status));
        print(" | ");
        print(@tagName(t.priority));
        print(" | ");
        print(t.title);
        print("\n");
    }
    if (queue.isEmpty()) {
        printLine("  No tasks found.");
    }
    printLine("");
}

fn runTaskNextCommand(allocator: std.mem.Allocator) !void {
    const sprint_dir = "tasks/active/sprint-2026-04";
    var queue = engine.task.TaskQueue.init(allocator);
    defer queue.deinit();

    const io = utils.getIo() catch |err| {
        var ebuf: [256]u8 = undefined;
        const emsg = try std.fmt.bufPrint(&ebuf, "❌ Failed to get Io instance: {s}", .{@errorName(err)});
        printLine(emsg);
        return;
    };
    const dir = utils.openDir(sprint_dir, .{ .iterate = true }) catch |err| {
        var ebuf: [256]u8 = undefined;
        const emsg = try std.fmt.bufPrint(&ebuf, "❌ Failed to open task directory: {s}", .{@errorName(err)});
        printLine(emsg);
        return;
    };

    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".md")) continue;
        if (std.mem.startsWith(u8, entry.name, "README")) continue;

        const path = try std.fs.path.join(allocator, &.{ sprint_dir, entry.name });
        defer allocator.free(path);

        const content = utils.readFileAlloc(allocator, path, 64 * 1024) catch |err| {
            var ebuf: [256]u8 = undefined;
            const emsg = try std.fmt.bufPrint(&ebuf, "  ⚠️  Failed to read {s}: {s}", .{ entry.name, @errorName(err) });
            printLine(emsg);
            continue;
        };
        defer allocator.free(content);

        if (try engine.task.parseTask(allocator, content, path)) |t| {
            var t_copy = t;
            errdefer t_copy.deinit(allocator);
            try queue.addTask(allocator, t_copy);
        }
    }

    if (queue.getNextTask()) |t| {
        printLine("\n➡️  Next task:");
        printLine("-------------");
        print("  ID: ");
        print(t.id);
        print("\n  Title: ");
        print(t.title);
        print("\n  Priority: ");
        print(@tagName(t.priority));
        print("\n  Status: ");
        print(@tagName(t.status));
        print("\n  Path: ");
        print(t.task_path);
        print("\n");
        if (t.dependencies.len > 0) {
            print("  Dependencies: ");
            for (t.dependencies, 0..) |dep, i| {
                if (i > 0) print(", ");
                print(dep);
            }
            print("\n");
        }
        printLine("");
    } else {
        printLine("\n✅ No executable tasks remaining.");
    }
}

// ============================================================================
// Autonomous Mode (T-128-D)
// ============================================================================

fn runAutonomousProject(allocator: std.mem.Allocator, project: *engine.project.Project) !void {
    printLine("\n🤖 Starting autonomous mode...\n");

    const phases = [_]engine.project.Phase{
        .prd,
        .architecture,
        .technical_spec,
    };

    for (phases) |phase| {
        const current = try engine.project.getCurrentPhase(project.dir_path);
        if (@intFromEnum(current) > @intFromEnum(phase)) continue;

        if (try engine.project.validatePhaseDocument(allocator, project.dir_path, phase)) {
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "✅ Phase {s} validated", .{@tagName(phase)});
            printLine(msg);
            _ = project.advancePhase();
            continue;
        }

        // Generate stub document for missing phase
        try generatePhaseStub(allocator, project, phase);

        if (try engine.project.validatePhaseDocument(allocator, project.dir_path, phase)) {
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "✅ Phase {s} stub generated and validated", .{@tagName(phase)});
            printLine(msg);
            _ = project.advancePhase();
        } else {
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "❌ Phase {s} validation failed after stub generation", .{@tagName(phase)});
            printLine(msg);
            break;
        }
    }

    printLine("\n🏁 Autonomous mode finished.");
    const final_phase = try engine.project.getCurrentPhase(project.dir_path);
    var buf: [256]u8 = undefined;
    const msg = try std.fmt.bufPrint(&buf, "Current phase: {s}", .{@tagName(final_phase)});
    printLine(msg);
}

fn generatePhaseStub(allocator: std.mem.Allocator, project: *engine.project.Project, phase: engine.project.Phase) !void {
    const doc_path = try std.fs.path.join(allocator, &.{ project.dir_path, phase.docName() });
    defer allocator.free(doc_path);

    const content = switch (phase) {
        .architecture =>
            \\---
            \\name: Architecture
            \\phase: architecture
            \\status: in_progress
            \\---
            \\
            \\# Architecture
            \\
            \\## Overview
            \\
            \\TBD
            \\
            \\## Components
            \\
            \\- TBD
            ,
        .technical_spec =>
            \\---
            \\name: Technical Specification
            \\phase: technical_spec
            \\status: in_progress
            \\---
            \\
            \\# Technical Specification
            \\
            \\## Impact Files
            \\
            \\- TBD
            \\
            \\## Acceptance Criteria
            \\
            \\- [ ] TBD
            ,
        else => return,
    };

    try utils.writeFile(doc_path, content);
}
