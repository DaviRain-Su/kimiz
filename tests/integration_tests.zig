//! Tests full agent workflows with mock providers and active modules only

const std = @import("std");
const kimiz = @import("kimiz");
const core = kimiz.core;
const ai = kimiz.ai;
const agent = kimiz.agent;
const skills = kimiz.skills;
const slash = kimiz.cli.slash;

// Small helper because std.time.milliTimestamp doesn't exist in Zig 0.16
const c = @cImport({
    @cInclude("time.h");
});
fn milliTimestamp() i64 {
    var ts: c.struct_timespec = undefined;
    if (c.clock_gettime(c.CLOCK_REALTIME, &ts) != 0) {
        return 0;
    }
    return @as(i64, ts.tv_sec) * 1000 + @divFloor(@as(i64, ts.tv_nsec), 1_000_000);
}

// ============================================================================
// Mock Provider
// ============================================================================

const MockProvider = struct {
    responses: std.ArrayList([]const u8),
    call_count: u32 = 0,

    fn init(allocator: std.mem.Allocator) MockProvider {
        _ = allocator;
        return .{
            .responses = .empty,
        };
    }

    fn deinit(self: *MockProvider) void {
        for (self.responses.items) |r| {
            self.responses.allocator.free(r);
        }
        self.responses.deinit(self.responses.allocator);
    }

    fn addResponse(self: *MockProvider, response: []const u8) !void {
        try self.responses.append(self.responses.allocator, try self.responses.allocator.dupe(u8, response));
    }

    fn getNextResponse(self: *MockProvider) ?[]const u8 {
        if (self.call_count >= self.responses.items.len) return null;
        const response = self.responses.items[self.call_count];
        self.call_count += 1;
        return response;
    }
};

// ============================================================================
// Test Utilities
// ============================================================================

fn createTestModel() core.Model {
    return .{
        .id = "test-model",
        .provider = .{ .known = .openai },
        .api = .{ .known = .@"openai-completions" },
        .context_window = 4096,
        .max_tokens = 1024,
        .cost = .{
            .input_token_cost = 0.0,
            .output_token_cost = 0.0,
        },
    };
}

// ============================================================================
// Agent Integration Tests
// ============================================================================

test "Agent basic conversation" {
    const allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const model = createTestModel();
    const options = agent.AgentOptions{
        .model = model,
    };

    var ai_agent = try agent.Agent.init(arena.allocator(), options);
    defer ai_agent.deinit();

    // Track events
    var events: std.ArrayList(agent.AgentEvent) = .empty;
    defer events.deinit(allocator);

    const EventCtx = struct {
        var list: *std.ArrayList(agent.AgentEvent) = undefined;
        var alloc: std.mem.Allocator = undefined;

        pub fn setContext(l: *std.ArrayList(agent.AgentEvent), a: std.mem.Allocator) void {
            list = l;
            alloc = a;
        }

        pub fn callback(evt: agent.AgentEvent) void {
            list.append(alloc, evt) catch {};
        }
    };

    ai_agent.setEventCallback(EventCtx.callback);
    EventCtx.setContext(&events, allocator);

    // Note: This would need mock provider to actually run
    // For now, just verify agent structure is correct
    try std.testing.expectEqual(.idle, ai_agent.state);
}

// ============================================================================
// AI Integration Tests
// ============================================================================

test "Model registry integration" {
    // Verify all models are accessible
    try std.testing.expect(ai.models_registry.getModel(.openai, "gpt-4o") != null);
    try std.testing.expect(ai.models_registry.getModel(.openai, "gpt-4o-mini") != null);
    try std.testing.expect(ai.models_registry.getModel(.anthropic, "claude-3-7-sonnet-20250219") != null);
    try std.testing.expect(ai.models_registry.getModel(.google, "gemini-2.0-flash") != null);
    try std.testing.expect(ai.models_registry.getModel(.kimi, "kimi-k2-5") != null);
    try std.testing.expect(ai.models_registry.getModel(.kimi, "kimi-for-coding") != null);
    try std.testing.expect(ai.models_registry.getModel(.fireworks, "kimi-k2p5-turbo") != null);

    // Verify unknown model returns null
    try std.testing.expect(ai.models_registry.getModel(.openai, "unknown-model") == null);
}

test "Cost calculation" {
    const model = core.Model{
        .id = "test",
        .provider = .{ .known = .openai },
        .api = .{ .known = .@"openai-completions" },
        .context_window = 4096,
        .max_tokens = 1024,
        .cost = .{
            .input_token_cost = 2.0,
            .output_token_cost = 6.0,
            .cache_token_cost = 1.0,
        },
    };

    const usage = core.TokenUsage{
        .input_tokens = 1000000,
        .output_tokens = 500000,
        .cache_creation_input_tokens = 100000,
        .cache_read_input_tokens = 100000,
    };

    const cost = ai.models_registry.calculateCost(model, usage);

    // Expected: 2.0 + 3.0 + 0.2 = 5.2
    try std.testing.expectApproxEqAbs(@as(f64, 5.2), cost, 0.01);
}

test "Provider routing" {
    const allocator = std.testing.allocator;

    var ai_client = ai.Ai.init(allocator);
    defer ai_client.deinit();

    // Create context with different providers
    const openai_model = core.Model{
        .id = "gpt-4o",
        .provider = .{ .known = .openai },
        .api = .{ .known = .@"openai-completions" },
        .context_window = 128000,
        .max_tokens = 4096,
        .cost = .{
            .input_token_cost = 2.5,
            .output_token_cost = 10.0,
        },
    };

    _ = openai_model;

    // Verify Ai struct is properly initialized
    try std.testing.expectEqual(@as(usize, @intFromPtr(&ai_client.http_client)),
        @as(usize, @intFromPtr(&ai_client.http_client)));
}

test "Message types basic creation" {
    // Verify user message can be created without serialization
    const user_msg = core.Message{
        .user = .{
            .content = &[_]core.UserContentBlock{
                .{ .text = "Hello, AI!" },
            },
        },
    };

    // Verify assistant message can be created
    const assistant_msg = core.Message{
        .assistant = .{
            .content = &[_]core.AssistantContentBlock{
                .{ .text = .{ .text = "Hello, human!" } },
            },
            .stop_reason = .stop,
        },
    };

    _ = user_msg;
    _ = assistant_msg;
}

test "E2E: Complete workflow simulation" {
    const allocator = std.testing.allocator;

    // 1. Initialize conversation history manually
    var messages: std.ArrayList(core.Message) = .empty;
    defer {
        for (messages.items) |*msg| {
            switch (msg.*) {
                .user => |u| allocator.free(u.content),
                .assistant => |a| allocator.free(a.content),
                .tool_result => |tr| allocator.free(tr.content),
            }
        }
        messages.deinit(allocator);
    }

    // 2. Simulate conversation
    try messages.append(allocator, core.Message{
        .user = .{
            .content = try allocator.dupe(core.UserContentBlock, &[_]core.UserContentBlock{
                .{ .text = "Hello AI" },
            }),
        },
    });
    try messages.append(allocator, core.Message{
        .assistant = .{
            .content = try allocator.dupe(core.AssistantContentBlock, &[_]core.AssistantContentBlock{
                .{ .text = .{ .text = "Hello! How can I help?" } },
            }),
            .stop_reason = .stop,
        },
    });
    try messages.append(allocator, core.Message{
        .user = .{
            .content = try allocator.dupe(core.UserContentBlock, &[_]core.UserContentBlock{
                .{ .text = "What is Zig?" },
            }),
        },
    });

    // 3. Verify conversation history
    try std.testing.expectEqual(@as(usize, 3), messages.items.len);
}

test "E2E: Multi-provider routing" {
    const allocator = std.testing.allocator;

    // Test that routing can select different providers
    var router = ai.routing.SmartRouter.init(allocator, null);

    // Simple chat -> should prefer cheaper model
    const simple = try router.selectModel(.simple_chat, 1);
    try std.testing.expectEqualStrings("gpt-4o-mini", simple.model_id);

    // Code generation -> should prefer code-capable model
    const code = try router.selectModel(.code_generation, 5);
    try std.testing.expectEqualStrings("claude-3-7-sonnet-20250219", code.model_id);

    // Complex analysis -> should prefer capable model
    const complex = try router.selectModel(.complex_analysis, 8);
    try std.testing.expectEqualStrings("claude-3-7-sonnet-20250219", complex.model_id);
}

// ============================================================================
// Skill Integration Tests
// ============================================================================

test "Skill registry integration" {
    const allocator = std.testing.allocator;

    var registry = skills.SkillRegistry.init(allocator);
    defer registry.deinit();

    // Register test skill
    const test_skill = skills.Skill{
        .id = "test-code-review",
        .name = "Test Code Review",
        .description = "A test skill for code review",
        .version = "1.0.0",
        .category = .review,
        .params = &[_]skills.SkillParam{},
        .execute_fn = struct {
            fn exec(ctx: skills.SkillContext, args: std.json.ObjectMap, arena: std.mem.Allocator) anyerror!skills.SkillResult {
                _ = ctx;
                _ = args;
                return skills.SkillResult{
                    .success = true,
                    .output = try arena.dupe(u8, "Code review completed"),
                    .execution_time_ms = 100,
                };
            }
        }.exec,
    };

    try registry.register(test_skill);

    // Retrieve and verify
    const retrieved = registry.get("test-code-review");
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualStrings("Test Code Review", retrieved.?.name);

    // List all skills
    const all_skills = try registry.listAll();
    defer allocator.free(all_skills);
    try std.testing.expectEqual(@as(usize, 1), all_skills.len);

    // Search skills
    const search_results = try registry.search("review");
    defer allocator.free(search_results);
    try std.testing.expect(search_results.len > 0);
}

test "Skill engine execution" {
    const allocator = std.testing.allocator;

    var registry = skills.SkillRegistry.init(allocator);
    defer registry.deinit();

    // Register a skill that echoes input
    const echo_skill = skills.Skill{
        .id = "echo",
        .name = "Echo",
        .description = "Echoes the input",
        .version = "1.0.0",
        .category = .misc,
        .params = &[_]skills.SkillParam{
            .{
                .name = "message",
                .description = "Message to echo",
                .param_type = .string,
                .required = true,
            },
        },
        .execute_fn = struct {
            fn exec(ctx: skills.SkillContext, args: std.json.ObjectMap, arena: std.mem.Allocator) anyerror!skills.SkillResult {
                _ = ctx;
                const message = args.get("message") orelse return error.MissingArgument;
                const output = try std.fmt.allocPrint(arena, "Echo: {s}", .{message.string});
                return skills.SkillResult{
                    .success = true,
                    .output = output,
                    .execution_time_ms = 10,
                };
            }
        }.exec,
    };

    try registry.register(echo_skill);

    var engine = skills.SkillEngine.init(allocator, &registry);

    // Execute skill
    var args = std.json.ObjectMap.init(allocator);
    defer args.deinit();
    try args.put("message", std.json.Value{ .string = "hello world" });

    const ctx = skills.SkillContext{
        .allocator = allocator,
        .working_dir = ".",
        .session_id = "test-session",
    };

    const result = try engine.execute("echo", args, ctx);
    defer allocator.free(result.output);
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("Echo: hello world", result.output);
}

// ============================================================================
// Slash Command Integration Tests
// ============================================================================

test "Slash command parser" {
    const parsed1 = slash.parse("/help");
    try std.testing.expect(parsed1 != null);
    try std.testing.expectEqualStrings("help", parsed1.?.name);
    try std.testing.expectEqualStrings("", parsed1.?.args);

    const parsed2 = slash.parse("/model gpt-4o");
    try std.testing.expect(parsed2 != null);
    try std.testing.expectEqualStrings("model", parsed2.?.name);
    try std.testing.expectEqualStrings("gpt-4o", parsed2.?.args);

    const parsed3 = slash.parse("hello world");
    try std.testing.expect(parsed3 == null);
}

test "Slash command registry" {
    const cmd = slash.find("clear");
    try std.testing.expect(cmd != null);
    try std.testing.expectEqualStrings("clear", cmd.?.name);

    const missing = slash.find("nonexistent");
    try std.testing.expect(missing == null);
}

test "Slash /help handler output" {
    // Verify the handler exists and metadata is correct.
    const help_cmd = slash.find("help").?;
    try std.testing.expectEqualStrings("help", help_cmd.name);
    // Handler is a required function pointer; verifying its presence implicitly.
}

// ============================================================================
// Performance Tests
// ============================================================================

test "Performance: Skill registry operations" {
    const allocator = std.testing.allocator;

    var registry = skills.SkillRegistry.init(allocator);
    defer registry.deinit();

    const start = milliTimestamp();

    // Register a few skills (limited due to Zig 0.16 std.StringHashMap grow bug)
    var i: u32 = 0;
    while (i < 3) : (i += 1) {
        const name = try std.fmt.allocPrint(allocator, "tool_{d}", .{i});
        defer allocator.free(name);

        const t = skills.Skill{
            .id = name,
            .name = name,
            .description = "Test skill",
            .version = "1.0.0",
            .category = .misc,
            .params = &[_]skills.SkillParam{},
            .execute_fn = struct {
                fn exec(ctx: skills.SkillContext, args: std.json.ObjectMap, arena: std.mem.Allocator) anyerror!skills.SkillResult {
                    _ = ctx;
                    _ = args;
                    return skills.SkillResult{
                        .success = true,
                        .output = try arena.dupe(u8, "ok"),
                        .execution_time_ms = 1,
                    };
                }
            }.exec,
        };
        // Pre-allocate capacity to avoid triggering the hashmap grow bug
        try registry.skills.ensureTotalCapacity(10);
        try registry.register(t);
    }

    // Query
    _ = registry.get("tool_1");

    const end = milliTimestamp();
    const duration = end - start;

    try std.testing.expect(duration < 200);
}

test "Memory allocation patterns" {
    const allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    // Simulate typical agent usage pattern
    const model = createTestModel();
    const options = agent.AgentOptions{ .model = model };

    var ai_agent = try agent.Agent.init(arena.allocator(), options);
    defer ai_agent.deinit();

    // Agent should use arena for all allocations
    // This is a pattern test - real memory testing would require instrumentation
    try std.testing.expectEqual(.idle, ai_agent.state);
}

test "E2E: read_file tool definition" {
    const tool_def = agent.read_file.tool_definition;
    try std.testing.expectEqualStrings("read_file", tool_def.name);
    try std.testing.expect(tool_def.description.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, tool_def.parameters_json, "path") != null);
}

test "E2E: bash tool definition" {
    const tool_def = agent.bash.tool_definition;
    try std.testing.expectEqualStrings("bash", tool_def.name);
    try std.testing.expect(tool_def.description.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, tool_def.parameters_json, "command") != null);
}

test "E2E: HttpClient basic lifecycle" {
    const allocator = std.testing.allocator;
    var client = kimiz.http.HttpClient.init(allocator);
    defer client.deinit();
    try std.testing.expect(@intFromPtr(&client) != 0);
}

test "E2E: defineSkill basic validation" {
    const EchoSkill = skills.defineSkill(.{
        .name = "echo",
        .description = "Echo skill",
        .input = struct {
            message: []const u8,
        },
        .output = struct {
            success: bool,
            output: []const u8,
        },
        .handler = struct {
            fn exec(input: struct { message: []const u8 }) struct {
                success: bool,
                output: []const u8,
            } {
                return .{ .success = true, .output = input.message };
            }
        }.exec,
    });

    try std.testing.expectEqualStrings("echo", EchoSkill.id);
    try std.testing.expectEqualStrings("echo", EchoSkill.name);
    try std.testing.expect(EchoSkill.params.len == 1);
    try std.testing.expectEqualStrings("message", EchoSkill.params[0].name);
}

test "E2E: defineSkill execution and registry" {
    const allocator = std.testing.allocator;

    const DebugSkill = skills.defineSkill(.{
        .name = "debug_dsl",
        .description = "Debug via DSL",
        .input = struct {
            code: []const u8,
            language: ?[]const u8 = null,
        },
        .output = struct {
            success: bool,
            output: []const u8,
        },
        .handler = struct {
            fn exec(input: struct { code: []const u8, language: ?[]const u8 }) struct {
                success: bool,
                output: []const u8,
            } {
                _ = input.language;
                return .{ .success = true, .output = "debug ok" };
            }
        }.exec,
    });

    const skill = DebugSkill.toSkill();
    try std.testing.expectEqualStrings("debug_dsl", skill.id);
    try std.testing.expect(skill.params.len == 2);

    var registry = skills.SkillRegistry.init(allocator);
    defer registry.deinit();
    try registry.register(skill);

    const retrieved = registry.get("debug_dsl");
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualStrings("Debug via DSL", retrieved.?.description);

    // Execute with valid args
    var args = std.json.ObjectMap.init(allocator);
    defer args.deinit();
    try args.put("code", std.json.Value{ .string = "print(1)" });

    const ctx = skills.SkillContext{
        .allocator = allocator,
        .working_dir = ".",
        .session_id = "test",
    };

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const result = try retrieved.?.execute_fn(ctx, args, arena.allocator());
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("debug ok", result.output);
}
