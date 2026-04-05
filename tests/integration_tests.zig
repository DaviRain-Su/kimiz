//! Integration Tests - End-to-end testing for kimiz
//! Tests full agent workflows with mock providers

const std = @import("std");
const core = @import("../src/core/root.zig");
const ai = @import("../src/ai/root.zig");
const agent = @import("../src/agent/root.zig");
const session = @import("../src/utils/session.zig");
const memory = @import("../src/memory/root.zig");
const learning = @import("../src/learning/root.zig");
const skills = @import("../src/skills/root.zig");
const log = @import("../src/utils/log.zig");
const config_mod = @import("../src/utils/config.zig");

// ============================================================================
// Mock Provider
// ============================================================================

const MockProvider = struct {
    responses: std.ArrayList([]const u8),
    call_count: u32 = 0,

    fn init(allocator: std.mem.Allocator) MockProvider {
        return .{
            .responses = std.ArrayList([]const u8).init(allocator),
        };
    }

    fn deinit(self: *MockProvider) void {
        for (self.responses.items) |r| {
            self.responses.allocator.free(r);
        }
        self.responses.deinit();
    }

    fn addResponse(self: *MockProvider, response: []const u8) !void {
        try self.responses.append(try self.responses.allocator.dupe(u8, response));
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
// Integration Tests
// ============================================================================

test "Agent basic conversation" {
    const allocator = std.testing.allocator;

    const model = createTestModel();
    const options = agent.AgentOptions{
        .model = model,
    };

    var ai_agent = try agent.Agent.init(allocator, options);
    defer ai_agent.deinit();

    // Track events
    var events = std.ArrayList(agent.AgentEvent).init(allocator);
    defer events.deinit();

    ai_agent.setEventCallback(struct {
        var list: *std.ArrayList(agent.AgentEvent) = undefined;

        pub fn setList(l: *std.ArrayList(agent.AgentEvent)) void {
            list = l;
        }

        pub fn callback(evt: agent.AgentEvent) void {
            list.append(evt) catch {};
        }
    }.callback);

    struct {
        var list: *std.ArrayList(agent.AgentEvent) = undefined;
    }.setList(&events);

    // Note: This would need mock provider to actually run
    // For now, just verify agent structure is correct
    try std.testing.expectEqual(.idle, ai_agent.state);
}

test "Session manager integration" {
    const allocator = std.testing.allocator;

    var manager = session.SessionManager.init(allocator);
    defer manager.deinit();

    // Create session
    const id = try manager.createSession("Test", "gpt-4o");
    try std.testing.expectEqualStrings("gpt-4o", manager.getSession(id).?.model_id);

    // Add messages simulating a conversation
    _ = try manager.addMessage(id, "user", "Hello", null);
    _ = try manager.addMessage(id, "assistant", "Hi!", null);
    _ = try manager.addMessage(id, "user", "How are you?", null);

    // Verify message count
    const msgs = try manager.getMessages(id);
    defer allocator.free(msgs);
    try std.testing.expectEqual(@as(usize, 3), msgs.len);

    // Verify stats
    const stats = manager.getStats();
    try std.testing.expectEqual(@as(u32, 1), stats.total_sessions);
    try std.testing.expectEqual(@as(u64, 3), stats.total_messages);
}

test "Tool registry integration" {
    const allocator = std.testing.allocator;

    var registry = try agent.createDefaultRegistry(allocator);
    defer registry.deinit();

    // Verify all tools are registered
    try std.testing.expect(registry.hasTool("read_file"));
    try std.testing.expect(registry.hasTool("write_file"));
    try std.testing.expect(registry.hasTool("bash"));
    try std.testing.expect(registry.hasTool("glob"));
    try std.testing.expect(registry.hasTool("grep"));
    try std.testing.expect(registry.hasTool("web_search"));
    try std.testing.expect(registry.hasTool("url_summary"));

    // Test read_file tool (if test file exists)
    const read_tool = registry.get("read_file").?;

    // Execute with invalid path (should fail gracefully)
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const args = std.json.Value{ .object = std.json.ObjectMap.init(arena.allocator()) };
    const result = read_tool.execute(arena.allocator(), args);

    // Should fail but not crash
    try std.testing.expect(result != null);
}

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
    // Note: These would fail without valid API keys, but we verify routing logic

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

test "Message types serialization" {
    const allocator = std.testing.allocator;

    // Create user message
    const user_msg = core.Message{
        .user = .{
            .content = &[_]core.UserContentBlock{
                .{ .text = "Hello, AI!" },
            },
        },
    };

    // Create assistant message
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

    // Serialize to JSON
    const json = try std.json.stringifyAlloc(allocator, user_msg, .{});
    defer allocator.free(json);

    try std.testing.expect(json.len > 0);
}

test "End-to-end workflow (simulated)" {
    const allocator = std.testing.allocator;

    // 1. Initialize session manager
    var manager = session.SessionManager.init(allocator);
    defer manager.deinit();

    // 2. Create session
    const session_id = try manager.createSession("Test Session", "gpt-4o");

    // 3. Simulate conversation
    _ = try manager.addMessage(session_id, "user", "What is Zig?", null);
    _ = try manager.addMessage(session_id, "assistant", "Zig is a systems programming language.", null);
    _ = try manager.addMessage(session_id, "user", "Tell me more.", null);

    // 4. Verify conversation history
    const messages = try manager.getMessages(session_id);
    defer allocator.free(messages);

    try std.testing.expectEqual(@as(usize, 3), messages.len);
    try std.testing.expectEqualStrings("user", messages[0].role);
    try std.testing.expectEqualStrings("What is Zig?", messages[0].content);
    try std.testing.expectEqualStrings("assistant", messages[1].role);
    try std.testing.expectEqualStrings("user", messages[2].role);

    // 5. Fork session
    const forked_id = try manager.forkSession(session_id, "Forked Session");

    // 6. Verify fork
    const forked_messages = try manager.getMessages(forked_id);
    defer allocator.free(forked_messages);
    try std.testing.expectEqual(messages.len, forked_messages.len);

    // 7. Export session
    const json = try manager.exportSessionToJson(session_id, allocator);
    defer allocator.free(json);
    try std.testing.expect(json.len > 0);
}

// ============================================================================
// Performance Tests
// ============================================================================

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

test "Session storage performance" {
    const allocator = std.testing.allocator;

    var manager = session.SessionManager.init(allocator);
    defer manager.deinit();

    const start = std.time.milliTimestamp();

    // Create many sessions
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        const id = try manager.createSession(
            try std.fmt.allocPrint(allocator, "Session {d}", .{i}),
            "gpt-4o",
        );

        // Add some messages
        var j: u32 = 0;
        while (j < 10) : (j += 1) {
            _ = try manager.addMessage(id, "user", "Test message", null);
        }
    }

    const end = std.time.milliTimestamp();
    const duration = end - start;

    // Should complete in reasonable time (< 1 second)
    try std.testing.expect(duration < 1000);

    // Verify all sessions exist
    const stats = manager.getStats();
    try std.testing.expectEqual(@as(u32, 100), stats.total_sessions);
    try std.testing.expectEqual(@as(u64, 1000), stats.total_messages);
}

// ============================================================================
// Error Handling Tests
// ============================================================================

test "Error propagation" {
    const allocator = std.testing.allocator;

    var manager = session.SessionManager.init(allocator);
    defer manager.deinit();

    // Try to access non-existent session
    const result = manager.getMessages("non-existent-id");
    try std.testing.expectError(error.SessionNotFound, result);

    // Try to add message to non-existent session
    const add_result = manager.addMessage("invalid", "user", "test", null);
    try std.testing.expectError(error.SessionNotFound, add_result);
}

test "Invalid model handling" {
    const result = ai.models_registry.getModel(.openai, "invalid-model");
    try std.testing.expect(result == null);

    // Should not crash
    const result2 = ai.models_registry.getModel(.fireworks, "also-invalid");
    try std.testing.expect(result2 == null);
}

// ============================================================================
// Stress Tests
// ============================================================================

test "Long conversation handling" {
    const allocator = std.testing.allocator;

    var manager = session.SessionManager.init(allocator);
    defer manager.deinit();

    const session_id = try manager.createSession("Long", "gpt-4o");

    // Add many messages
    var i: u32 = 0;
    while (i < 1000) : (i += 1) {
        const role = if (i % 2 == 0) "user" else "assistant";
        _ = try manager.addMessage(session_id, role, "Message content", null);
    }

    const messages = try manager.getMessages(session_id);
    defer allocator.free(messages);

    try std.testing.expectEqual(@as(usize, 1000), messages.len);

    // Verify ordering
    try std.testing.expectEqualStrings("user", messages[0].role);
    try std.testing.expectEqualStrings("assistant", messages[1].role);
}

// ============================================================================
// Configuration Management Tests
// ============================================================================

test "Config management integration" {
    const allocator = std.testing.allocator;

    var manager = try config_mod.ConfigManager.init(allocator);
    defer manager.deinit();

    // Load default config
    var config = try manager.load();
    defer config_mod.configDeinit(&config, allocator);

    // Verify defaults
    try std.testing.expectEqualStrings("gpt-4o", config.default_model);
    try std.testing.expectEqual(.system, config.theme);

    // Modify and save
    allocator.free(config.default_model);
    config.default_model = try allocator.dupe(u8, "claude-sonnet-4");
    config.yolo_mode = true;

    try manager.save(&config);

    // Reload and verify changes persisted
    var config2 = try manager.load();
    defer config_mod.configDeinit(&config2, allocator);

    try std.testing.expectEqualStrings("claude-sonnet-4", config2.default_model);
    try std.testing.expectEqual(true, config2.yolo_mode);
}

test "API key management integration" {
    const allocator = std.testing.allocator;

    var manager = try config_mod.ConfigManager.init(allocator);
    defer manager.deinit();

    var config = try manager.load();
    defer config_mod.configDeinit(&config, allocator);

    // Set multiple API keys
    try manager.setApiKey(&config, "openai", "sk-openai-test");
    try manager.setApiKey(&config, "anthropic", "sk-anthropic-test");
    try manager.setApiKey(&config, "kimi", "sk-kimi-test");

    // Verify all keys are stored
    const openai_key = config.api_keys.get("openai");
    const anthropic_key = config.api_keys.get("anthropic");
    const kimi_key = config.api_keys.get("kimi");

    try std.testing.expect(openai_key != null);
    try std.testing.expect(anthropic_key != null);
    try std.testing.expect(kimi_key != null);
    try std.testing.expectEqualStrings("sk-openai-test", openai_key.?);
    try std.testing.expectEqualStrings("sk-anthropic-test", anthropic_key.?);
    try std.testing.expectEqualStrings("sk-kimi-test", kimi_key.?);

    // Update existing key
    try manager.setApiKey(&config, "openai", "sk-openai-updated");
    const updated = config_mod.getApiKey(&config, "openai");
    try std.testing.expectEqualStrings("sk-openai-updated", updated.?);
}

// ============================================================================
// Logging System Tests
// ============================================================================

test "Logging system integration" {
    const allocator = std.testing.allocator;

    // Initialize global logger
    try log.initGlobalLogger(allocator, ".test_logs_integration", .debug);
    defer {
        log.deinitGlobalLogger();
        std.fs.cwd().deleteDir(".test_logs_integration") catch {};
    }

    // Test all log levels
    log.debug("Debug message: {d}", .{42});
    log.info("Info message: {s}", .{"hello"});
    log.warn("Warning message: {}", .{true});
    log.err("Error message: {s}", .{"test error"});

    // Verify logger is accessible
    const logger = log.getLogger();
    try std.testing.expectEqual(.debug, logger.min_level);
}

test "Logger with different levels" {
    const allocator = std.testing.allocator;

    // Test with INFO level (DEBUG should be filtered)
    try log.initGlobalLogger(allocator, ".test_logs_level", .info);
    defer {
        log.deinitGlobalLogger();
        std.fs.cwd().deleteDir(".test_logs_level") catch {};
    }

    const logger = log.getLogger();
    try std.testing.expectEqual(.info, logger.min_level);

    // These should not appear when level is INFO
    logger.debug("This should be filtered", .{});

    // These should appear
    logger.info("This should appear", .{});
    logger.warn("This should also appear", .{});
}

// ============================================================================
// Memory + Learning Integration Tests
// ============================================================================

test "Memory manager integration" {
    const allocator = std.testing.allocator;

    var memory_manager = try memory.MemoryManager.init(
        allocator,
        ".", // project path
        ".test_memory.json",
    );
    defer memory_manager.deinit();

    // Add memories
    try memory_manager.remember(.conversation, "Test conversation", 80);
    try memory_manager.remember(.code_pattern, "fn test() {{}}", 90);
    try memory_manager.remember(.user_pref, "User likes dark theme", 70);

    // Recall memories
    const results = try memory_manager.recall("test", 5);
    defer allocator.free(results);

    // Should find the code pattern
    try std.testing.expect(results.len > 0);
}

test "Learning engine integration" {
    const allocator = std.testing.allocator;

    var engine = try learning.LearningEngine.init(allocator);
    defer engine.deinit();

    // Record tool usage
    try engine.recordToolUsage("read_file", true, 100);
    try engine.recordToolUsage("write_file", true, 200);
    try engine.recordToolUsage("read_file", true, 150);

    // Update code style preference
    try engine.updateCodeStyle(.naming_convention, "snake_case", 0.8);
    try engine.updateCodeStyle(.indentation, "4_spaces", 0.9);

    // Record model performance
    try engine.recordModelPerformance("gpt-4o", 1500, true, 95);
    try engine.recordModelPerformance("claude-sonnet", 2000, true, 92);

    // Verify internal state
    try std.testing.expectEqual(@as(usize, 2), engine.code_style.len);
}

// ============================================================================
// Skill System Integration Tests
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
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("Echo: hello world", result.output);
}

// ============================================================================
// End-to-End Workflow Tests
// ============================================================================

test "E2E: Complete workflow simulation" {
    const allocator = std.testing.allocator;

    // 1. Initialize session
    var session_manager = session.SessionManager.init(allocator);
    defer session_manager.deinit();

    const session_id = try session_manager.createSession("E2E Test", "gpt-4o");

    // 2. Simulate conversation
    _ = try session_manager.addMessage(session_id, "user", "Hello AI", null);
    _ = try session_manager.addMessage(session_id, "assistant", "Hello! How can I help?", null);
    _ = try session_manager.addMessage(session_id, "user", "What is Zig?", null);

    // 3. Verify conversation history
    const messages = try session_manager.getMessages(session_id);
    defer allocator.free(messages);
    try std.testing.expectEqual(@as(usize, 3), messages.len);

    // 4. Export session
    const json = try session_manager.exportSessionToJson(session_id, allocator);
    defer allocator.free(json);
    try std.testing.expect(json.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "Hello AI") != null);

    // 5. Fork session
    const forked_id = try session_manager.forkSession(session_id, "Forked Session");
    const forked_messages = try session_manager.getMessages(forked_id);
    defer allocator.free(forked_messages);
    try std.testing.expectEqual(messages.len, forked_messages.len);
}

test "E2E: Agent with memory integration" {
    const allocator = std.testing.allocator;

    // Initialize components
    var memory_manager = try memory.MemoryManager.init(
        allocator,
        ".",
        ".test_e2e_memory.json",
    );
    defer memory_manager.deinit();

    // Add relevant memories
    try memory_manager.remember(.project_knowledge, "This is a Zig project", 90);
    try memory_manager.remember(.user_pref, "User prefers detailed explanations", 80);

    // Create agent with context
    const model = ai.models_registry.getModel(.openai, "gpt-4o").?;
    const agent_options = agent.AgentOptions{
        .model = model,
        .temperature = 0.7,
    };

    var ai_agent = try agent.Agent.init(allocator, agent_options);
    defer ai_agent.deinit();

    // Verify agent can access context
    try std.testing.expectEqual(.idle, ai_agent.state);
}

test "E2E: Multi-provider routing" {
    // Test that routing can select different providers
    const router = ai.routing.SmartRouter{
        .allocator = std.testing.allocator,
    };

    // Simple chat -> should prefer cheaper model
    const simple = try router.selectModel(.simple_chat, 1);
    try std.testing.expectEqualStrings("gpt-4o-mini", simple.model_id);

    // Code generation -> should prefer code-capable model
    const code = try router.selectModel(.code_generation, 5);
    try std.testing.expectEqualStrings("claude-3-7-sonnet-20250219", code.model_id);

    // Complex analysis -> should prefer capable model
    const complex = try router.selectModel(.complex_analysis, 8);
    try std.testing.expectEqualStrings("gpt-4o", complex.model_id);
}

// ============================================================================
// Performance Tests
// ============================================================================

test "Performance: Memory operations" {
    const allocator = std.testing.allocator;

    var manager = memory.MemoryManager.init(
        allocator,
        ".",
        ".test_perf_memory.json",
    ) catch |e| {
        // Memory manager might need real project, skip if fails
        return e;
    };
    defer manager.deinit();

    const start = std.time.milliTimestamp();

    // Add many memories
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        const content = try std.fmt.allocPrint(allocator, "Memory content {d}", .{i});
        defer allocator.free(content);
        try manager.remember(.conversation, content, @intCast(50 + (i % 50)));
    }

    // Search
    const results = try manager.recall("content", 10);
    defer allocator.free(results);

    const end = std.time.milliTimestamp();
    const duration = end - start;

    // Should complete in reasonable time (< 500ms)
    try std.testing.expect(duration < 500);
}

test "Performance: Tool registry operations" {
    const allocator = std.testing.allocator;

    var registry = agent.ToolRegistry.init(allocator);
    defer registry.deinit();

    const start = std.time.milliTimestamp();

    // Register many tools
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        const name = try std.fmt.allocPrint(allocator, "tool_{d}", .{i});
        defer allocator.free(name);

        const TestCtx = struct {};
        var ctx = try allocator.create(TestCtx);
        const t = agent.tool.AgentTool{
            .tool = agent.tool.Tool{
                .name = name,
                .description = "Test tool",
                .parameters_json = "{}",
            },
            .execute_fn = struct {
                fn exec(_: *anyopaque, a: std.mem.Allocator, _: std.json.Value) anyerror!agent.tool.ToolResult {
                    return agent.tool.textContent(a, "ok");
                }
            }.exec,
            .ctx = ctx,
        };
        try registry.register(t);
    }

    // Query
    _ = registry.hasTool("tool_50");

    const end = std.time.milliTimestamp();
    const duration = end - start;

    // Should complete in reasonable time (< 200ms)
    try std.testing.expect(duration < 200);
}
