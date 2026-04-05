//! kimiz-agent - Agent runtime with loop and state machine
//! Handles conversation flow, tool calling, and event management

const std = @import("std");
const utils = @import("../utils/root.zig");
const error_handler = @import("../utils/error_handler.zig");
const tool_mod = @import("tool.zig");
const Tool = tool_mod.Tool;
const AgentTool = tool_mod.AgentTool;
const ToolResult = tool_mod.ToolResult;
const core = @import("../core/root.zig");
const ai = @import("../ai/root.zig");
const skills = @import("../skills/root.zig");
const memory = @import("../memory/root.zig");
const learning = @import("../learning/root.zig");
const harness_tool_approval = @import("../harness/tool_approval.zig");
const session_mgmt = @import("../utils/session.zig");
const subagent = @import("subagent.zig");
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

fn ensureDirExists(path: []const u8) !void {
    if (path.len == 0) return;
    utils.makeDirRecursive(path) catch |err| {
        if (err == error.PathAlreadyExists) return;
        return err;
    };
}

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
    tool_defs_cache: []const core.Tool = &.{},
    skill_registry: skills.SkillRegistry,
    skill_engine: skills.SkillEngine,
    memory_manager: ?memory.MemoryManager,
    learning_engine: ?learning.LearningEngine,
    approval_manager: harness_tool_approval.ApprovalManager,
    session_manager: session_mgmt.SessionManager,
    session_store_dir: ?[]const u8,
    session_id: ?[]const u8,
    subagent_delegate_ctx: ?*subagent.DelegateContext,
    subagent_tools_owned: bool,

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
        
        const approval_policy: harness_tool_approval.ApprovalPolicy = if (options.yolo_mode)
            .auto
        else
            .moderate;

        // Session persistence (experimental feature - currently not exposed in CLI)
        const session_manager = session_mgmt.SessionManager.init(allocator);
        const home_dir_maybe: ?[]const u8 = if (std.c.getenv("HOME")) |ptr| std.mem.sliceTo(ptr, 0) else null;
        const store_dir = if (home_dir_maybe) |h| try std.fs.path.join(allocator, &.{ h, ".kimiz", "sessions" }) else null;
        if (store_dir) |dir| { try ensureDirExists(dir); }
        const session_store_dir = if (store_dir) |d| blk: {
            const copy = try allocator.dupe(u8, d);
            allocator.free(d);
            break :blk copy;
        } else null;
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
            .approval_manager = harness_tool_approval.ApprovalManager.init(allocator, approval_policy),
            .session_manager = session_manager,
            .session_store_dir = session_store_dir,
            .session_id = null,
            .subagent_delegate_ctx = null,
            .subagent_tools_owned = false,
        };
    }

    pub fn deinit(self: *Self) void {
        self.saveSession() catch |err| { std.log.warn("Failed to save session: {s}", .{@errorName(err)}); };
        for (self.messages.items) |msg| { msg.deinit(self.allocator); }
        self.messages.deinit(self.allocator);
        if (self.tool_defs_cache.len > 0) self.allocator.free(self.tool_defs_cache);
        self.ai_client.deinit();
        self.skill_registry.deinit();
        if (self.memory_manager) |*mm| { mm.deinit(); }
        if (self.learning_engine) |*le| { le.deinit(); }
        self.approval_manager.deinit();
        self.session_manager.deinit();
        if (self.session_store_dir) |dir| self.allocator.free(dir);
        if (self.session_id) |id| self.allocator.free(id);
        if (self.subagent_tools_owned and self.options.tools.len > 0) {
            self.allocator.free(self.options.tools);
        }
        if (self.subagent_delegate_ctx) |ctx| {
            self.allocator.destroy(ctx);
        }
    }

    /// Set event callback for receiving agent events
    pub fn setEventCallback(self: *Self, callback: *const fn (event: AgentEvent) void) void {
        self.event_callback = callback;
    }

    /// Register the subagent delegate tool to this agent
    pub fn registerSubAgentTool(self: *Self) !void {
        if (self.subagent_delegate_ctx != null) return;

        const ctx = try self.allocator.create(subagent.DelegateContext);
        errdefer self.allocator.destroy(ctx);
        ctx.* = .{
            .allocator = self.allocator,
            .parent_agent = self,
            .base_options = self.options,
        };

        const new_tools = try self.allocator.alloc(AgentTool, self.options.tools.len + 1);
        @memcpy(new_tools[0..self.options.tools.len], self.options.tools);
        new_tools[self.options.tools.len] = subagent.createAgentTool(ctx);

        self.options.tools = new_tools;
        self.subagent_tools_owned = true;
        self.subagent_delegate_ctx = ctx;
        self.clearToolDefsCache();
    }

    pub fn saveSession(self: *Self) !void {
        if (self.messages.items.len == 0) return;
        const sid = if (self.session_id) |id| id else blk: {
            const new_id = try self.session_manager.createSession("Unnamed Session", self.options.model.id);
            const id_copy = try self.allocator.dupe(u8, new_id);
            self.session_id = id_copy;
            self.session_manager.setCurrentSession(new_id) catch {};
            break :blk new_id;
        };
        defer if (self.session_id == null) self.allocator.free(sid);
        try self.session_manager.clearMessages(sid);
        for (self.messages.items) |msg| {
            switch (msg) {
                .user => |m| {
                    const text = try self.userMessageToText(m);
                    defer self.allocator.free(text);
                    _ = try self.session_manager.addMessage(sid, "user", text, null);
                },
                .assistant => |m| {
                    const text = try self.assistantMessageToText(m);
                    defer self.allocator.free(text);
                    _ = try self.session_manager.addMessage(sid, "assistant", text, null);
                },
                .tool_result => |m| {
                    const text = try self.toolResultMessageToText(m);
                    defer self.allocator.free(text);
                    _ = try self.session_manager.addMessage(sid, "tool", text, null);
                },
            }
        }
        if (self.session_store_dir) |dir| {
            const path = try std.fmt.allocPrint(self.allocator, "{s}/{s}.json", .{ dir, sid });
            defer self.allocator.free(path);
            const json = try self.session_manager.exportSessionToJson(sid, self.allocator);
            defer self.allocator.free(json);
            try utils.writeFile(path, json);
        }
    }

    pub fn restoreSession(self: *Self, session_id: []const u8) !void {
        if (self.session_store_dir == null) return error.NoSessionStore;
        const path = try std.fmt.allocPrint(self.allocator, "{s}/{s}.json", .{ self.session_store_dir.?, session_id });
        defer self.allocator.free(path);
        const buf = utils.readFileAlloc(self.allocator, path, 1024 * 1024) catch |err| {
            if (err == error.FileNotFound) return error.SessionNotFound;
            return err;
        };
        defer self.allocator.free(buf);
        if (buf.len == 0) return error.EmptySession;
        const loaded_id = try self.session_manager.restoreSessionFromJson(buf);
        self.session_id = try self.allocator.dupe(u8, loaded_id);
        const messages = try self.session_manager.getMessages(loaded_id);
        defer self.allocator.free(messages);
        for (messages) |msg| {
            if (std.mem.eql(u8, msg.role, "system")) continue;
            if (std.mem.eql(u8, msg.role, "user")) {
                const text = try self.allocator.dupe(u8, msg.content);
                const content = try self.allocator.alloc(core.UserContentBlock, 1);
                content[0] = .{ .text = text };
                try self.messages.append(self.allocator, Message{ .user = .{ .content = content } });
            } else if (std.mem.eql(u8, msg.role, "assistant")) {
                const text = try self.allocator.dupe(u8, msg.content);
                const content = try self.allocator.alloc(core.AssistantContentBlock, 1);
                content[0] = .{ .text = .{ .text = text } };
                try self.messages.append(self.allocator, Message{ .assistant = .{ .content = content, .stop_reason = .stop } });
            } else if (std.mem.eql(u8, msg.role, "tool")) {
                const text = try self.allocator.dupe(u8, msg.content);
                const content = try self.allocator.alloc(core.UserContentBlock, 1);
                content[0] = .{ .text = text };
                try self.messages.append(self.allocator, Message{ .tool_result = .{ .tool_call_id = "restored", .tool_name = "restored", .content = content } });
            }
        }
    }

    fn userMessageToText(self: *Self, msg: core.UserMessage) ![]u8 {
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(self.allocator);
        for (msg.content) |block| {
            switch (block) {
                .text => |t| try buf.appendSlice(self.allocator, t),
                .image => try buf.appendSlice(self.allocator, "[image]"),
                .image_url => try buf.appendSlice(self.allocator, "[image_url]"),
            }
        }
        return try self.allocator.dupe(u8, buf.items);
    }

    fn assistantMessageToText(self: *Self, msg: core.AssistantMessage) ![]u8 {
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(self.allocator);
        for (msg.content) |block| {
            switch (block) {
                .text => |t| try buf.appendSlice(self.allocator, t.text),
                .thinking => try buf.appendSlice(self.allocator, "[thinking]"),
                .tool_call => try buf.appendSlice(self.allocator, "[tool_call]"),
            }
        }
        return try self.allocator.dupe(u8, buf.items);
    }

    fn toolResultMessageToText(self: *Self, msg: core.ToolResultMessage) ![]u8 {
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(self.allocator);
        for (msg.content) |block| {
            switch (block) {
                .text => |t| try buf.appendSlice(self.allocator, t),
                .image => try buf.appendSlice(self.allocator, "[image]"),
                .image_url => try buf.appendSlice(self.allocator, "[image_url]"),
            }
        }
        return try self.allocator.dupe(u8, buf.items);
    }

    /// Emit an event
    fn emit(self: *Self, event: AgentEvent) void {
        if (self.event_callback) |callback| {
            callback(event);
        }
    }

    /// Send a user prompt and run the agent loop
    pub fn prompt(self: *Self, user_content: []const u8) !void {
        // Inject system prompt on first message
        if (self.messages.items.len == 0) {
            const system_text = if (self.options.plan_mode)
                try std.fmt.allocPrint(self.allocator,
                    \\You are Kimiz in PLAN MODE. Your job is to EXPLORE the codebase using ONLY read-only tools.
                    \\Allowed tools: read_file, fff_grep, fff_file_search, git_status, git_diff, git_log.
                    \\You MUST NOT use write_file, edit, or bash.
                    \\After exploring, provide a detailed step-by-step Markdown plan.
                    \\Working directory: {s}
                    \\\n\nUser request: {s}
                , .{ self.options.project_path orelse ".", user_content })
            else
                try std.fmt.allocPrint(self.allocator,
                    \\You are Kimiz, an AI coding assistant. You have access to tools for reading, writing, and editing files, running shell commands, and searching code.
                    \\When asked to modify code, use the edit tool with exact old_string/new_string matches.
                    \\When asked to read files, use absolute paths.
                    \\Working directory: {s}
                    \\\n\n{s}
                , .{ self.options.project_path orelse ".", user_content });
            const content = try self.allocator.alloc(core.UserContentBlock, 1);
            content[0] = .{ .text = system_text };
            const user_msg = Message{
                .user = .{
                    .content = content,
                },
            };
            try self.messages.append(self.allocator, user_msg);
        } else {
            const text = try self.allocator.dupe(u8, user_content);
            const content = try self.allocator.alloc(core.UserContentBlock, 1);
            content[0] = .{ .text = text };
            const user_msg = Message{
                .user = .{
                    .content = content,
                },
            };
            try self.messages.append(self.allocator, user_msg);
        }

        // Run the agent loop
        try self.runLoop();
    }

    /// Main agent loop - Fixed version with proper iteration handling
    fn runLoop(self: *Self) !void {
        self.iteration_count = 0;

        while (self.iteration_count < self.options.max_iterations) {
            // Create arena for this iteration's temporary allocations
            var loop_arena = std.heap.ArenaAllocator.init(self.allocator);
            defer loop_arena.deinit();
            const loop_alloc = loop_arena.allocator();
            
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
                const err_msg = error_handler.formatError(loop_alloc, err) catch
                    try std.fmt.allocPrint(loop_alloc, "AI call failed: {s}", .{@errorName(err)});
                // No defer needed - arena will clean up
                self.emit(.{ .err = err_msg });

                // Abort immediately - do not auto-retry LLM calls
                return err;
            };

            // Add assistant message to history
            const assistant_msg = Message{
                .assistant = response,
            };
            try self.messages.append(self.allocator, assistant_msg);

            self.emit(.{ .message_complete = response });

            // Check for tool calls and execute them
            const num_tool_calls = countToolCalls(response);

            if (num_tool_calls > 0) {
                self.state = .tool_calling;

                // Execute tool calls from content blocks
                for (response.content) |block| {
                    const tc = switch (block) {
                        .tool_call => |t| t.tool_call,
                        else => continue,
                    };

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
                                .text = try loop_alloc.dupe(u8, @errorName(err)),
                            }},
                            .is_error = true,
                        };

                        self.emit(.{ .tool_call_complete = .{
                            .id = tc.id,
                            .name = tc.name,
                        } });

                        // Add tool result to messages and continue
                        try self.addToolResultToMessages(tc.id, tc.name, err_result);
                        self.freeToolResultContent(err_result);
                        
                        // Continue to next tool call if any
                        continue;
                    };

                    self.emit(.{ .tool_call_complete = .{
                        .id = tc.id,
                        .name = tc.name,
                    } });

                    // Add tool result to messages
                    try self.addToolResultToMessages(tc.id, tc.name, result);
                    self.freeToolResultContent(result);
                }
                
                // Continue to next iteration to let AI process the tool results
                continue;
            } else {
                // No tool calls, we're done
                self.state = .completed;
                self.savePlan() catch |err| {
                    std.log.warn("Failed to save plan: {s}", .{@errorName(err)});
                };
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

    /// Extract tool calls from assistant message content blocks
    fn countToolCalls(message: AssistantMessage) usize {
        var count: usize = 0;
        for (message.content) |block| {
            switch (block) {
                .tool_call => count += 1,
                else => {},
            }
        }
        return count;
    }

    /// Execute tool with error recovery
    fn executeToolWithRecovery(self: *Self, tool_call: core.ToolCall) !ToolResult {
        const start_time = utils.milliTimestamp();

        // Approval check
        const risk = harness_tool_approval.getToolRisk(tool_call.name);
        if (self.approval_manager.needsApproval(tool_call.name, risk)) {
            // For now, in non-interactive mode, deny if not auto-approved
            // TODO: emit approval request event for interactive UI
            const denied_msg = try std.fmt.allocPrint(self.allocator, "Tool '{s}' requires approval. Enable YOLO mode to auto-approve.", .{tool_call.name});
            // Keep using self.allocator since this is returned and needs to outlive the function
            return ToolResult{
                .content = &[_]tool_mod.UserContentBlock{.{ .text = denied_msg }},
                .is_error = true,
            };
        }

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

                const result = agent_tool.execute(arena.allocator(), parsed.value) catch |err| {
                    arena.deinit();
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

                // Deep copy result content before destroying arena
                const copied_content = try self.allocator.alloc(tool_mod.UserContentBlock, result.content.len);
                errdefer self.allocator.free(copied_content);
                for (result.content, 0..) |block, i| {
                    copied_content[i] = switch (block) {
                        .text => |text| .{ .text = try self.allocator.dupe(u8, text) },
                        .image => |img| .{ .image = try self.allocator.dupe(u8, img) },
                        .image_url => |img_url| blk: {
                            const url = try self.allocator.dupe(u8, img_url.url);
                            break :blk .{ .image_url = .{
                                .url = url,
                                .detail = img_url.detail,
                            }};
                        },
                    };
                }
                arena.deinit();
                return ToolResult{
                    .content = copied_content,
                    .is_error = result.is_error,
                };
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

    /// Free content blocks allocated for a ToolResult
    fn freeToolResultContent(self: *Self, result: ToolResult) void {
        for (result.content) |block| {
            switch (block) {
                .text => |text| self.allocator.free(text),
                .image => |img| self.allocator.free(img),
                .image_url => |img_url| {
                    self.allocator.free(img_url.url);
                    if (img_url.detail) |d| self.allocator.free(d);
                },
            }
        }
        self.allocator.free(@constCast(result.content));
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

    /// Get tool definitions from registered tools (returns borrowed references)
    fn getToolDefinitions(self: *Self) []const core.Tool {
        // Build a static array of core.Tool from the agent tools
        // Since options.tools is stable, we can return pointers into it
        if (self.tool_defs_cache.len > 0) return self.tool_defs_cache;

        var defs: std.ArrayList(core.Tool) = .empty;
        for (self.options.tools) |agent_tool| {
            if (self.options.plan_mode) {
                const is_readonly = std.mem.eql(u8, agent_tool.tool.name, "read_file") or
                    std.mem.eql(u8, agent_tool.tool.name, "fff_grep") or
                    std.mem.eql(u8, agent_tool.tool.name, "fff_file_search") or
                    std.mem.eql(u8, agent_tool.tool.name, "git_status") or
                    std.mem.eql(u8, agent_tool.tool.name, "git_diff") or
                    std.mem.eql(u8, agent_tool.tool.name, "git_log");
                if (!is_readonly) continue;
            }
            defs.append(self.allocator, .{
                .name = agent_tool.tool.name,
                .description = agent_tool.tool.description,
                .parameters_json = agent_tool.tool.parameters_json,
            }) catch continue;
        }
        self.tool_defs_cache = defs.toOwnedSlice(self.allocator) catch &[_]core.Tool{};
        return self.tool_defs_cache;
    }

    /// Clear cached tool definitions (call after changing plan_mode or yolo_mode)
    pub fn clearToolDefsCache(self: *Self) void {
        if (self.tool_defs_cache.len > 0) {
            self.allocator.free(self.tool_defs_cache);
            self.tool_defs_cache = &[_]core.Tool{};
        }
    }

    /// Save the final assistant message to plan.md when in plan mode
    pub fn savePlan(self: *Self) !void {
        if (!self.options.plan_mode) return;
        if (self.messages.items.len == 0) return;
        const last_msg = self.messages.items[self.messages.items.len - 1];
        const plan_text = switch (last_msg) {
            .assistant => |m| try self.assistantMessageToText(m),
            else => return,
        };
        defer self.allocator.free(plan_text);
        const path = try std.fmt.allocPrint(self.allocator, "{s}/plan.md", .{self.options.project_path orelse "."});
        defer self.allocator.free(path);
        try utils.writeFile(path, plan_text);
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

test "Agent registerSubAgentTool" {
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

    var a = try Agent.init(allocator, .{ .model = model });
    defer a.deinit();

    try std.testing.expectEqual(@as(usize, 0), a.options.tools.len);

    try a.registerSubAgentTool();
    try std.testing.expectEqual(@as(usize, 1), a.options.tools.len);
    try std.testing.expectEqualStrings("delegate", a.options.tools[0].tool.name);
}
