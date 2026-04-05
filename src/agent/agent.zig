//! kimiz-agent - Agent runtime with loop and state machine
//! Handles conversation flow, tool calling, and event management

const std = @import("std");
const utils = @import("../utils/root.zig");
const tool_mod = @import("tool.zig");
const Tool = tool_mod.Tool;
const AgentTool = tool_mod.AgentTool;
const ToolResult = tool_mod.ToolResult;
const core = @import("../core/root.zig");
const ai = @import("../ai/root.zig");
const skills = @import("../skills/root.zig");
const memory = @import("../memory/root.zig");
const learning = @import("../learning/root.zig");
const Message = core.Message;
const Context = core.Context;
const AssistantMessage = core.AssistantMessage;

// ============================================================================
// Agent Events
// ============================================================================

pub const AgentEvent = union(enum) {
    message_start,
    message_delta: []const u8,
    message_complete: AssistantMessage,
    tool_call_start: ToolCallInfo,
    tool_call_delta: []const u8,
    tool_call_complete: ToolCallInfo,
    tool_executing: ToolCallInfo,
    tool_result: ToolCallResult,
    err: []const u8,
    done,
};

pub const ToolCallInfo = struct {
    id: []const u8,
    name: []const u8,
};

pub const ToolCallResult = struct {
    tool_call_id: []const u8,
    tool_name: []const u8,
    result: ToolResult,
    execution_time_ms: u64,
};

// ============================================================================
// Agent State
// ============================================================================

pub const AgentState = enum {
    idle,
    thinking,
    tool_calling,
    executing_tool,
    completed,
    err,
};

// ============================================================================
// Agent Options
// ============================================================================

pub const AgentOptions = struct {
    model: core.Model,
    tools: []const AgentTool = &.{},
    temperature: f32 = 1.0,
    max_tokens: u32 = 8192,
    thinking_level: core.ThinkingLevel = .off,
    yolo_mode: bool = false,
    plan_mode: bool = false,
    max_iterations: u32 = 50,
    project_path: ?[]const u8 = null,
    memory_db_path: ?[]const u8 = null,
};

// ============================================================================
// Agent
// ============================================================================

pub const Agent = struct {
    allocator: std.mem.Allocator,
    options: AgentOptions,
    state: AgentState = .idle,
    messages: std.ArrayList(Message),
    event_callback: ?*const fn (event: AgentEvent) void,
    iteration_count: u32 = 0,
    ai_client: ai.Ai,
    skill_registry: skills.SkillRegistry,
    skill_engine: skills.SkillEngine,
    memory_manager: ?memory.MemoryManager,
    learning_engine: ?learning.LearningEngine,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, options: AgentOptions) !Self {
        var skill_registry = skills.SkillRegistry.init(allocator);
        
        // Register built-in skills
        skills.registerBuiltinSkills(&skill_registry) catch |err| {
            std.log.warn("Failed to register some built-in skills: {s}", .{@errorName(err)});
        };

        // Initialize memory manager if db path provided
        var memory_manager: ?memory.MemoryManager = null;
        if (options.memory_db_path) |db_path| {
            memory_manager = try memory.MemoryManager.init(
                allocator,
                options.project_path,
                db_path,
            );
        }

        // Initialize learning engine
        var learning_engine: ?learning.LearningEngine = null;
        learning_engine = learning.LearningEngine.init(allocator);
        
        return .{
            .allocator = allocator,
            .options = options,
            .state = .idle,
            .messages = .empty,
            .event_callback = null,
            .ai_client = ai.Ai.init(allocator),
            .skill_registry = skill_registry,
            .skill_engine = skills.SkillEngine.init(allocator, &skill_registry),
            .memory_manager = memory_manager,
            .learning_engine = learning_engine,
        };
    }

    pub fn deinit(self: *Self) void {
        self.messages.deinit(self.allocator);
        self.ai_client.deinit();
        self.skill_registry.deinit();
        if (self.memory_manager) |*mm| {
            mm.deinit();
        }
        if (self.learning_engine) |*le| {
            le.deinit();
        }
    }

    /// Set event callback for receiving agent events
    pub fn setEventCallback(self: *Self, callback: *const fn (event: AgentEvent) void) void {
        self.event_callback = callback;
    }

    /// Emit an event
    fn emit(self: *Self, event: AgentEvent) void {
        if (self.event_callback) |callback| {
            callback(event);
        }
    }

    /// Send a user prompt and run the agent loop
    pub fn prompt(self: *Self, user_content: []const u8) !void {
        // Add user message
        const user_msg = Message{
            .user = .{
                .content = &[_]core.UserContentBlock{.{ .text = user_content }},
            },
        };
        try self.messages.append(self.allocator, user_msg);

        // Run the agent loop
        try self.runLoop();
    }

    /// Main agent loop - Fixed version with proper iteration handling
    fn runLoop(self: *Self) !void {
        self.iteration_count = 0;

        while (self.iteration_count < self.options.max_iterations) {
            self.iteration_count += 1;

            self.state = .thinking;
            self.emit(.message_start);

            // Prepare context for AI call
            const ctx = Context{
                .model = self.options.model,
                .messages = self.messages.items,
                .temperature = self.options.temperature,
                .max_tokens = self.options.max_tokens,
                .thinking_level = self.options.thinking_level,
                .tools = self.getToolDefinitions(),
            };

            // Call AI using the reused client with error recovery
            const response = self.ai_client.complete(ctx) catch |err| {
                self.state = .err;
                const err_msg = try std.fmt.allocPrint(self.allocator, "AI call failed: {s}", .{@errorName(err)});
                defer self.allocator.free(err_msg);
                self.emit(.{ .err = err_msg });
                
                // Add error message to history so the conversation can continue
                const error_assistant_msg = Message{
                    .assistant = .{
                        .content = &[_]core.AssistantContentBlock{.{
                            .text = .{ .text = "I encountered an error. Let me try again." },
                        }},
                        .stop_reason = .stop,
                    },
                };
                try self.messages.append(self.allocator, error_assistant_msg);
                
                // Continue loop instead of returning - allow retry
                if (self.iteration_count < self.options.max_iterations) {
                    continue;
                }
                return err;
            };

            // Add assistant message to history
            const assistant_msg = Message{
                .assistant = response,
            };
            try self.messages.append(self.allocator, assistant_msg);

            self.emit(.{ .message_complete = response });

            // Check for tool calls and execute them all
            const tool_calls = self.extractToolCalls(response);
            
            if (tool_calls.len > 0) {
                self.state = .tool_calling;

                // Execute all tool calls
                for (tool_calls, 0..) |tc, i| {
                    self.emit(.{ .tool_call_start = .{
                        .id = tc.id,
                        .name = tc.name,
                    } });

                    // Find and execute the tool with error recovery
                    const result = self.executeToolWithRecovery(tc) catch |err| {
                        const end_time = utils.milliTimestamp();
                        const execution_time = @as(i64, end_time - utils.milliTimestamp());

                        // Record failed tool execution (log error but don't fail)
                        self.recordToolExecution(tc.name, false, execution_time) catch |e| {
                            std.log.warn("Failed to record tool execution: {s}", .{@errorName(e)});
                        };

                        // Create error result that allows conversation to continue
                        const err_result = ToolResult{
                            .content = &[_]tool_mod.UserContentBlock{.{
                                .text = try self.allocator.dupe(u8, @errorName(err)),
                            }},
                            .is_error = true,
                        };

                        self.emit(.{ .tool_call_complete = .{
                            .id = tc.id,
                            .name = tc.name,
                        } });

                        // Add tool result to messages and continue
                        try self.addToolResultToMessages(tc.id, tc.name, err_result);
                        
                        // Continue to next tool call if any
                        continue;
                    };

                    self.emit(.{ .tool_call_complete = .{
                        .id = tc.id,
                        .name = tc.name,
                    } });

                    // Add tool result to messages
                    try self.addToolResultToMessages(tc.id, tc.name, result);

                    // Only the first tool call in this batch triggers a new AI call
                    // Subsequent tool calls will be processed in the next iteration
                    if (i == 0) {
                        break;
                    }
                }
                
                // Continue to next iteration to let AI process the tool results
                continue;
            } else {
                // No tool calls, we're done
                self.state = .completed;
                self.emit(.done);
                break;
            }
        }

        if (self.iteration_count >= self.options.max_iterations) {
            self.state = .err;
            self.emit(.{ .err = "Max iterations reached" });
            return error.MaxIterationsReached;
        }
    }

    /// Extract all tool calls from assistant message
    fn extractToolCalls(self: *Self, message: AssistantMessage) []const core.ToolCall {
        _ = self;
        var tool_calls: [16]core.ToolCall = undefined;
        var count: usize = 0;
        
        for (message.content) |block| {
            switch (block) {
                .tool_call => |tc| {
                    if (count < 16) {
                        tool_calls[count] = tc.tool_call;
                        count += 1;
                    }
                },
                else => {},
            }
        }
        
        // Return slice of the tool calls found
        return tool_calls[0..count];
    }

    /// Execute tool with error recovery
    fn executeToolWithRecovery(self: *Self, tool_call: core.ToolCall) !ToolResult {
        const start_time = utils.milliTimestamp();

        // Find the tool
        for (self.options.tools) |agent_tool| {
            if (std.mem.eql(u8, agent_tool.tool.name, tool_call.name)) {
                // Parse arguments with error recovery
                const parsed = std.json.parseFromSlice(
                    std.json.Value,
                    self.allocator,
                    tool_call.arguments,
                    .{},
                ) catch {
                    return ToolResult{
                        .content = &[_]tool_mod.UserContentBlock{.{ .text = "Failed to parse arguments" }},
                        .is_error = true,
                    };
                };
                defer parsed.deinit();

                // Execute the tool with arena
                var arena = std.heap.ArenaAllocator.init(self.allocator);
                defer arena.deinit();

                var arena_mut = arena;
                const result = agent_tool.execute(arena_mut.allocator(), parsed.value) catch |err| {
                    const end_time = utils.milliTimestamp();
                    const execution_time = @as(i64, end_time - start_time);
                    
                    // Record failed execution (log error but don't fail)
                    self.recordToolExecution(tool_call.name, false, execution_time) catch |e| {
                        std.log.warn("Failed to record tool execution: {s}", .{@errorName(e)});
                    };

                    return ToolResult{
                        .content = &[_]tool_mod.UserContentBlock{.{ .text = @errorName(err) }},
                        .is_error = true,
                    };
                };

                const end_time = utils.milliTimestamp();
                const execution_time = @as(i64, end_time - start_time);

                // Record successful execution (log error but don't fail)
                self.recordToolExecution(tool_call.name, true, execution_time) catch |e| {
                    std.log.warn("Failed to record tool execution: {s}", .{@errorName(e)});
                };

                self.emit(.{ .tool_result = .{
                    .tool_call_id = tool_call.id,
                    .tool_name = tool_call.name,
                    .result = result,
                    .execution_time_ms = @intCast(end_time - start_time),
                } });

                return result;
            }
        }

        return error.ToolNotFound;
    }

    /// Add tool result to messages
    fn addToolResultToMessages(self: *Self, tool_call_id: []const u8, tool_name: []const u8, result: ToolResult) !void {
        // Deep copy content blocks
        const content = try self.allocator.alloc(core.UserContentBlock, result.content.len);
        errdefer self.allocator.free(content);

        for (result.content, 0..) |block, i| {
            content[i] = switch (block) {
                .text => |text| .{ .text = try self.allocator.dupe(u8, text) },
                .image => |img| .{ .image = .{
                    .data = try self.allocator.dupe(u8, img),
                    .mime_type = "image/png",
                }},
                .image_url => |img_url| .{ .image_url = .{
                    .url = try self.allocator.dupe(u8, img_url.url),
                    .detail = .auto,
                }},
            };
        }

        const tool_result_msg = Message{
            .tool_result = .{
                .tool_call_id = try self.allocator.dupe(u8, tool_call_id),
                .tool_name = try self.allocator.dupe(u8, tool_name),
                .content = content,
                .is_error = result.is_error,
            },
        };
        try self.messages.append(self.allocator, tool_result_msg);
    }

    /// Record tool execution for analytics
    fn recordToolExecution(self: *Self, tool_name: []const u8, success: bool, execution_time_ms: i64) !void {
        // Record to memory manager
        if (self.memory_manager) |*mm| {
            const mem_content = try std.fmt.allocPrint(
                self.allocator,
                "Tool: {s}, Success: {}, Time: {d}ms",
                .{ tool_name, success, execution_time_ms },
            );
            defer self.allocator.free(mem_content);
            mm.remember(.tool_usage, mem_content, if (success) 50 else 60) catch |e| {
                std.log.debug("Failed to record to memory: {s}", .{@errorName(e)});
            };
        }

        // Track in learning engine
        if (self.learning_engine) |*le| {
            le.recordToolUsage(tool_name, success, execution_time_ms) catch |e| {
                std.log.debug("Failed to record to learning engine: {s}", .{@errorName(e)});
            };
        }
    }

    /// Check if response has tool calls (legacy, kept for compatibility)
    fn hasToolCalls(self: *Self, message: AssistantMessage) bool {
        _ = self;
        for (message.content) |block| {
            switch (block) {
                .tool_call => return true,
                else => {},
            }
        }
        return false;
    }

    /// Get tool definitions from registered tools
    fn getToolDefinitions(self: *Self) []const core.Tool {
        var tools: std.ArrayList(core.Tool) = .empty;
        defer tools.deinit(self.allocator);

        for (self.options.tools) |agent_tool| {
            const core_tool = core.Tool{
                .name = agent_tool.tool.name,
                .description = agent_tool.tool.description,
                .parameters_json = agent_tool.tool.parameters_json,
            };
            tools.append(self.allocator, core_tool) catch |e| {
                std.log.warn("Failed to append tool {s}: {s}", .{ agent_tool.tool.name, @errorName(e) });
                continue;
            };
        }

        return tools.toOwnedSlice(self.allocator) catch &[_]core.Tool{};
    }

    /// Execute a skill with given arguments
    pub fn executeSkill(
        self: *Self,
        skill_id: []const u8,
        args: std.json.ObjectMap,
    ) !skills.SkillResult {
        const ctx = skills.SkillContext{
            .allocator = self.allocator,
            .working_dir = self.options.project_path orelse ".",
            .session_id = "session-1", // TODO: Generate proper session ID
        };

        return self.skill_engine.execute(skill_id, args, ctx);
    }

    /// Track model performance for a request
    pub fn trackModelPerformance(
        self: *Self,
        success: bool,
        latency_ms: i64,
        token_cost: f64,
        task_type: []const u8,
    ) !void {
        if (self.learning_engine) |*le| {
            const model_id = self.options.model.id;
            try le.recordModelPerformance(model_id, success, latency_ms, token_cost, task_type);
        }
    }

    /// Record a memory entry
    pub fn recordMemory(
        self: *Self,
        mem_type: memory.MemoryType,
        content: []const u8,
        importance: u8,
    ) !void {
        if (self.memory_manager) |*mm| {
            try mm.remember(mem_type, content, importance);
        }
    }

    /// Recall relevant memories
    pub fn recallMemories(self: *Self, query: []const u8, limit: usize) ![]memory.MemoryEntry {
        if (self.memory_manager) |*mm| {
            return mm.recall(query, limit);
        }
        return &[_]memory.MemoryEntry{};
    }

    /// Get conversation history
    pub fn getMessages(self: *Self) []const Message {
        return self.messages.items;
    }

    /// Clear conversation history
    pub fn clearHistory(self: *Self) void {
        self.messages.clearAndFree(self.allocator);
    }

    /// Export conversation to JSON
    pub fn exportToJson(self: *Self, allocator: std.mem.Allocator) ![]u8 {
        return std.json.Stringify.valueAlloc(allocator, self.messages.items, .{});
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Agent init/deinit" {
    const allocator = std.testing.allocator;
    const model = core.Model{
        .id = "gpt-4o",
        .provider = .{ .known = .openai },
        .api = .{ .known = .@"openai-completions" },
        .context_window = 128000,
        .max_tokens = 4096,
        .cost = .{
            .input_token_cost = 2.50,
            .output_token_cost = 10.00,
        },
    };

    var agent = try Agent.init(allocator, .{ .model = model });
    defer agent.deinit();

    try std.testing.expectEqual(.idle, agent.state);
}
