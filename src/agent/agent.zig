//! kimiz-agent - Agent runtime with loop and state machine
//! Handles conversation flow, tool calling, and event management

const std = @import("std");
const tool_mod = @import("tool.zig");
const Tool = tool_mod.Tool;
const AgentTool = tool_mod.AgentTool;
const ToolResult = tool_mod.ToolResult;
const core = @import("../core/root.zig");
const ai = @import("../ai/root.zig");
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

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, options: AgentOptions) !Self {
        return .{
            .allocator = allocator,
            .options = options,
            .state = .idle,
            .messages = std.ArrayList(Message).init(allocator),
            .event_callback = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.messages.deinit();
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
        try self.messages.append(user_msg);

        // Run the agent loop
        try self.runLoop();
    }

    /// Continue from a tool result
    pub fn continueFromToolResult(
        self: *Self,
        tool_call_id: []const u8,
        tool_name: []const u8,
        result: ToolResult,
    ) !void {
        // Add tool result message
        const content = try self.allocator.alloc(core.UserContentBlock, result.content.len);
        for (result.content, 0..) |block, i| {
            content[i] = block;
        }

        const tool_result_msg = Message{
            .tool_result = .{
                .tool_call_id = try self.allocator.dupe(u8, tool_call_id),
                .tool_name = try self.allocator.dupe(u8, tool_name),
                .content = content,
                .is_error = result.is_error,
            },
        };
        try self.messages.append(tool_result_msg);

        // Continue the loop
        try self.runLoop();
    }

    /// Main agent loop
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

            // Call AI
            var ai_client = ai.Ai.init(self.allocator);
            defer ai_client.deinit();

            const response = ai_client.complete(ctx) catch |err| {
                self.state = .err;
                self.emit(.{ .err = @errorName(err) });
                return err;
            };

            // Add assistant message to history
            const assistant_msg = Message{
                .assistant = response,
            };
            try self.messages.append(assistant_msg);

            self.emit(.{ .message_complete = response });

            // Check for tool calls
            const has_tool_calls = self.hasToolCalls(response);

            if (has_tool_calls) {
                self.state = .tool_calling;

                // Execute tools
                for (response.content) |block| {
                    switch (block) {
                        .tool_call => |tc| {
                            self.emit(.{ .tool_call_start = .{
                                .id = tc.tool_call.id,
                                .name = tc.tool_call.name,
                            } });

                            // Find and execute the tool
                            const result = try self.executeTool(tc.tool_call);

                            self.emit(.{ .tool_call_complete = .{
                                .id = tc.tool_call.id,
                                .name = tc.tool_call.name,
                            } });

                            // Continue loop with tool result
                            try self.continueFromToolResult(
                                tc.tool_call.id,
                                tc.tool_call.name,
                                result,
                            );

                            // Only handle one tool call at a time for now
                            return;
                        },
                        else => {},
                    }
                }
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
        }
    }

    /// Check if response has tool calls
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
    fn getToolDefinitions(self: *Self) []const Tool {
        var tools = std.ArrayList(Tool).init(self.allocator);
        defer tools.deinit();

        for (self.options.tools) |agent_tool| {
            tools.append(agent_tool.tool) catch {};
        }

        return tools.toOwnedSlice() catch &[]Tool{};
    }

    /// Execute a tool
    fn executeTool(self: *Self, tool_call: core.ToolCall) !ToolResult {
        self.state = .executing_tool;

        const start_time = std.time.milliTimestamp();

        // Find the tool
        for (self.options.tools) |agent_tool| {
            if (std.mem.eql(u8, agent_tool.tool.name, tool_call.name)) {
                // Parse arguments
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

                // Execute the tool
                const arena = std.heap.ArenaAllocator.init(self.allocator);
                defer arena.deinit();

                const result = agent_tool.execute(arena.allocator(), parsed.value) catch |err| {
                    return ToolResult{
                        .content = &[_]tool_mod.UserContentBlock{.{ .text = @errorName(err) }},
                        .is_error = true,
                    };
                };

                const end_time = std.time.milliTimestamp();

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

    /// Get conversation history
    pub fn getMessages(self: *Self) []const Message {
        return self.messages.items;
    }

    /// Clear conversation history
    pub fn clearHistory(self: *Self) void {
        self.messages.clearAndFree();
    }

    /// Export conversation to JSON
    pub fn exportToJson(self: *Self, allocator: std.mem.Allocator) ![]u8 {
        return std.json.stringifyAlloc(allocator, self.messages.items, .{ .pretty = true });
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
