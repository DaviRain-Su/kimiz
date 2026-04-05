//! OpenAI Provider - Completions API implementation
//! Supports both streaming and non-streaming completions

const std = @import("std");
const core = @import("../../core/root.zig");
const ai = @import("../root.zig");
const HttpClient = @import("../../http.zig").HttpClient;

// ============================================================================
// Request Types
// ============================================================================

const OpenAIRequest = struct {
    model: []const u8,
    messages: []const OpenAIMessage,
    temperature: f32,
    max_tokens: u32,
    stream: bool,
    tools: ?[]const OpenAITool = null,
};

const OpenAIMessage = struct {
    role: []const u8,
    content: ?[]const u8 = null,
    tool_calls: ?[]const OpenAIToolCall = null,
    tool_call_id: ?[]const u8 = null,
};

const OpenAITool = struct {
    type: []const u8 = "function",
    function: OpenAIFunction,
};

const OpenAIFunction = struct {
    name: []const u8,
    description: []const u8,
    parameters: []const u8, // JSON string directly
};

const OpenAIToolCall = struct {
    id: []const u8,
    type: []const u8 = "function",
    function: OpenAIFunctionCall,
};

const OpenAIFunctionCall = struct {
    name: []const u8,
    arguments: []const u8,
};

// ============================================================================
// Response Types
// ============================================================================

const OpenAIResponse = struct {
    id: []const u8,
    choices: []const OpenAIChoice,
    usage: ?OpenAIUsage = null,
};

const OpenAIChoice = struct {
    message: ?OpenAIResponseMessage = null,
    delta: ?OpenAIDelta = null,
    finish_reason: ?[]const u8,
    index: u32,
};

const OpenAIResponseMessage = struct {
    role: []const u8,
    content: ?[]const u8 = null,
    tool_calls: ?[]const OpenAIToolCall = null,
};

const OpenAIDelta = struct {
    role: ?[]const u8 = null,
    content: ?[]const u8 = null,
    tool_calls: ?[]const OpenAIToolCallDelta = null,
};

const OpenAIToolCallDelta = struct {
    index: u32,
    id: ?[]const u8 = null,
    type: ?[]const u8 = null,
    function: ?OpenAIFunctionCallDelta = null,
};

const OpenAIFunctionCallDelta = struct {
    name: ?[]const u8 = null,
    arguments: ?[]const u8 = null,
};

const OpenAIUsage = struct {
    prompt_tokens: u32,
    completion_tokens: u32,
    total_tokens: u32,
    prompt_tokens_details: ?OpenAITokenDetails = null,
};

const OpenAITokenDetails = struct {
    cached_tokens: ?u32 = null,
};

// ============================================================================
// Non-streaming Completion
// ============================================================================

pub fn complete(http_client: *HttpClient, ctx: core.Context) !core.AssistantMessage {
    const api_key = core.getApiKey(ctx.model.provider.known) orelse return core.AiError.ApiKeyNotFound;

    // Serialize request
    const request_body = try serializeRequest(ctx);
    defer std.heap.page_allocator.free(request_body);

    // Setup headers
    var headers: std.ArrayList(std.http.Header) = .empty;
    defer headers.deinit(std.heap.page_allocator);
    try headers.append(std.heap.page_allocator, .{
        .name = "Authorization",
        .value = try std.fmt.allocPrint(std.heap.page_allocator, "Bearer {s}", .{api_key}),
    });
    try headers.append(std.heap.page_allocator, .{
        .name = "Content-Type",
        .value = "application/json",
    });

    // Get base URL
    const base_url = getBaseUrl(ctx.model.provider.known);
    const url = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/v1/chat/completions", .{base_url});
    defer std.heap.page_allocator.free(url);

    // Make request
    var response = try http_client.postJson(url, headers.items, request_body);
    defer response.deinit(std.heap.page_allocator);

    // Parse response
    return try parseResponse(response.body);
}

// ============================================================================
// Streaming Completion
// ============================================================================

pub fn stream(
    http_client: *HttpClient,
    ctx: core.Context,
    callback: *const fn (event: ai.SseEvent) void,
) !void {
    const api_key = core.getApiKey(ctx.model.provider.known) orelse return core.AiError.ApiKeyNotFound;

    // Create streaming context with mutable state
    var stream_ctx = StreamContext{
        .callback = callback,
        .current_tool_call = null,
        .accumulated_text = .empty,
    };
    defer stream_ctx.accumulated_text.deinit(std.heap.page_allocator);

    // Serialize request with stream=true
    var streaming_ctx = ctx;
    streaming_ctx.stream = true;
    const request_body = try serializeRequest(streaming_ctx);
    defer std.heap.page_allocator.free(request_body);

    // Setup headers
    var headers: std.ArrayList(std.http.Header) = .empty;
    defer headers.deinit(std.heap.page_allocator);
    try headers.append(std.heap.page_allocator, .{
        .name = "Authorization",
        .value = try std.fmt.allocPrint(std.heap.page_allocator, "Bearer {s}", .{api_key}),
    });
    try headers.append(std.heap.page_allocator, .{
        .name = "Content-Type",
        .value = "application/json",
    });
    try headers.append(std.heap.page_allocator, .{
        .name = "Accept",
        .value = "text/event-stream",
    });

    // Get base URL
    const base_url = getBaseUrl(ctx.model.provider.known);
    const url = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/v1/chat/completions", .{base_url});
    defer std.heap.page_allocator.free(url);

    // Make streaming request
    try http_client.postStream(url, headers.items, request_body, struct {
        fn onLine(line: []const u8, ctx_ptr: *StreamContext) void {
            ctx_ptr.processLine(line) catch {};
        }
    }.onLine);
}

const StreamContext = struct {
    callback: *const fn (event: ai.SseEvent) void,
    current_tool_call: ?ToolCallState,
    accumulated_text: std.ArrayList(u8),

    const ToolCallState = struct {
        id: []const u8,
        name: []const u8,
        arguments: std.ArrayList(u8),
    };

    fn processLine(self: *StreamContext, line: []const u8) !void {
        // Parse SSE line
        if (line.len == 0) return;
        if (!std.mem.startsWith(u8, line, "data: ")) return;

        const data = line[6..]; // Skip "data: "
        if (std.mem.eql(u8, data, "[DONE]")) {
            self.callback(.{ .done = .stop });
            return;
        }

        // Parse JSON
        const parsed = try std.json.parseFromSlice(OpenAIStreamChunk, std.heap.page_allocator, data, .{});
        defer parsed.deinit(std.heap.page_allocator);

        const chunk = parsed.value;
        if (chunk.choices.len == 0) return;

        const choice = chunk.choices[0];

        // Handle finish reason
        if (choice.finish_reason) |reason| {
            const stop_reason = mapFinishReason(reason);
            self.callback(.{ .done = stop_reason });
            return;
        }

        // Handle delta
        if (choice.delta) |delta| {
            if (delta.content) |content| {
                self.callback(.{ .text_delta = content });
            }

            if (delta.tool_calls) |tool_calls| {
                for (tool_calls) |tc| {
                    if (tc.id) |id| {
                        // New tool call started
                        self.callback(.{ .toolcall_start = .{
                            .id = id,
                            .name = tc.function.?.name orelse "",
                        } });
                    }
                    if (tc.function) |func| {
                        if (func.arguments) |args| {
                            self.callback(.{ .toolcall_delta = .{
                                .arguments_json_chunk = args,
                            } });
                        }
                    }
                }
            }
        }
    }
};

const OpenAIStreamChunk = struct {
    id: []const u8,
    choices: []const OpenAIChoice,
};

// ============================================================================
// Serialization
// ============================================================================

fn serializeRequest(ctx: core.Context) ![]u8 {
    var messages: std.ArrayList(OpenAIMessage) = .empty;
    defer messages.deinit(std.heap.page_allocator);

    for (ctx.messages) |msg| {
        const openai_msg = switch (msg) {
            .user => |user_msg| blk: {
                // Concatenate all content blocks
                var content: std.ArrayList(u8) = .empty;
                defer content.deinit(std.heap.page_allocator);
                for (user_msg.content) |block| {
                    switch (block) {
                        .text => |text| try content.appendSlice(std.heap.page_allocator, text),
                        .image => |img| try std.fmt.format(content.writer(std.heap.page_allocator), "[Image: {s}]", .{img.mime_type}),
                        .image_url => |img_url| try std.fmt.format(content.writer(std.heap.page_allocator), "[Image: {s}]", .{img_url.url}),
                    }
                }
                break :blk OpenAIMessage{
                    .role = "user",
                    .content = try std.heap.page_allocator.dupe(u8, content.items),
                };
            },
            .assistant => |assistant_msg| blk: {
                var content: ?[]const u8 = null;
                var tool_calls: ?std.ArrayList(OpenAIToolCall) = null;

                for (assistant_msg.content) |block| {
                    switch (block) {
                        .text => |text| content = text.text,
                        .tool_call => |tc| {
                            if (tool_calls == null) {
                                tool_calls = std.ArrayList(OpenAIToolCall){ .items = &.{}, .capacity = 0 };
                            }
                            try tool_calls.?.append(std.heap.page_allocator, OpenAIToolCall{
                                .id = tc.tool_call.id,
                                .function = .{
                                    .name = tc.tool_call.name,
                                    .arguments = tc.tool_call.arguments,
                                },
                            });
                        },
                        .thinking => {},
                    }
                }

                var tool_calls_slice: ?[]const OpenAIToolCall = null;
                if (tool_calls) |*tc| {
                    tool_calls_slice = try tc.toOwnedSlice(std.heap.page_allocator);
                }

                break :blk OpenAIMessage{
                    .role = "assistant",
                    .content = content,
                    .tool_calls = tool_calls_slice,
                };
            },
            .tool_result => |tool_result| blk: {
                var content: std.ArrayList(u8) = .empty;
                defer content.deinit(std.heap.page_allocator);
                for (tool_result.content) |block| {
                    switch (block) {
                        .text => |text| try content.appendSlice(std.heap.page_allocator, text),
                        .image => |img| try std.fmt.format(content.writer(std.heap.page_allocator), "[Image: {s}]", .{img.mime_type}),
                        .image_url => {},
                    }
                }
                break :blk OpenAIMessage{
                    .role = "tool",
                    .content = try std.heap.page_allocator.dupe(u8, content.items),
                    .tool_call_id = tool_result.tool_call_id,
                };
            },
        };
        try messages.append(std.heap.page_allocator, openai_msg);
    }

    // Convert tools - build JSON string manually for tools
    var tools_json: ?[]const u8 = null;
    if (ctx.tools.len > 0) {
        var tools_buf: std.ArrayList(u8) = .empty;
        defer tools_buf.deinit(std.heap.page_allocator);
        
        try tools_buf.appendSlice(std.heap.page_allocator, "[");
        for (ctx.tools, 0..) |tool, i| {
            if (i > 0) try tools_buf.appendSlice(std.heap.page_allocator, ",");
            
            // Build tool JSON manually
            try tools_buf.appendSlice(std.heap.page_allocator, "{\"type\":\"function\",\"function\":{\"name\":\"");
            try tools_buf.appendSlice(std.heap.page_allocator, tool.name);
            try tools_buf.appendSlice(std.heap.page_allocator, "\",\"description\":\"");
            try tools_buf.appendSlice(std.heap.page_allocator, tool.description);
            try tools_buf.appendSlice(std.heap.page_allocator, "\",\"parameters\":");
            try tools_buf.appendSlice(std.heap.page_allocator, tool.parameters_json);
            try tools_buf.appendSlice(std.heap.page_allocator, "}}");
        }
        try tools_buf.appendSlice(std.heap.page_allocator, "]");
        tools_json = try tools_buf.toOwnedSlice(std.heap.page_allocator);
    }

    // Build request JSON manually using simple string concatenation
    var req_buf: std.ArrayList(u8) = .empty;
    defer req_buf.deinit(std.heap.page_allocator);
    
    // Start JSON
    try req_buf.appendSlice(std.heap.page_allocator, "{\"model\":\"");
    try req_buf.appendSlice(std.heap.page_allocator, ctx.model.id);
    try req_buf.appendSlice(std.heap.page_allocator, "\",\"messages\":[");
    
    // Messages array
    for (messages.items, 0..) |msg, i| {
        if (i > 0) try req_buf.appendSlice(std.heap.page_allocator, ",");
        try req_buf.appendSlice(std.heap.page_allocator, "{\"role\":\"");
        try req_buf.appendSlice(std.heap.page_allocator, msg.role);
        try req_buf.appendSlice(std.heap.page_allocator, "\"");
        
        if (msg.content) |content| {
            try req_buf.appendSlice(std.heap.page_allocator, ",\"content\":\"");
            try req_buf.appendSlice(std.heap.page_allocator, content);
            try req_buf.appendSlice(std.heap.page_allocator, "\"");
        }
        
        if (msg.tool_call_id) |id| {
            try req_buf.appendSlice(std.heap.page_allocator, ",\"tool_call_id\":\"");
            try req_buf.appendSlice(std.heap.page_allocator, id);
            try req_buf.appendSlice(std.heap.page_allocator, "\"");
        }
        
        // TODO: Handle tool_calls serialization
        try req_buf.appendSlice(std.heap.page_allocator, "}");
    }
    
    // Close messages, add other params
    try req_buf.appendSlice(std.heap.page_allocator, "],\"temperature\":");
    
    // Convert temperature to string
    var temp_buf: [32]u8 = undefined;
    const temp_str = try std.fmt.bufPrint(&temp_buf, "{d}", .{ctx.temperature});
    try req_buf.appendSlice(std.heap.page_allocator, temp_str);
    
    try req_buf.appendSlice(std.heap.page_allocator, ",\"max_tokens\":");
    var max_tokens_buf: [16]u8 = undefined;
    const max_tokens_str = try std.fmt.bufPrint(&max_tokens_buf, "{d}", .{ctx.max_tokens});
    try req_buf.appendSlice(std.heap.page_allocator, max_tokens_str);
    
    // Stream flag
    if (ctx.stream) {
        try req_buf.appendSlice(std.heap.page_allocator, ",\"stream\":true");
    } else {
        try req_buf.appendSlice(std.heap.page_allocator, ",\"stream\":false");
    }
    
    // Tools
    if (tools_json) |tj| {
        try req_buf.appendSlice(std.heap.page_allocator, ",\"tools\":");
        try req_buf.appendSlice(std.heap.page_allocator, tj);
        std.heap.page_allocator.free(tj);
    }
    
    // Close JSON
    try req_buf.appendSlice(std.heap.page_allocator, "}");
    
    return try req_buf.toOwnedSlice(std.heap.page_allocator);
}

// ============================================================================
// Response Parsing
// ============================================================================

fn parseResponse(body: []const u8) !core.AssistantMessage {
    const parsed = try std.json.parseFromSlice(OpenAIResponse, std.heap.page_allocator, body, .{});
    defer parsed.deinit(std.heap.page_allocator);

    const response = parsed.value;
    if (response.choices.len == 0) return error.ApiUnexpectedResponse;

    const choice = response.choices[0];
    const message = choice.message orelse return error.ApiUnexpectedResponse;

    // Convert content blocks
    var content: std.ArrayList(core.AssistantContentBlock) = .empty;
    defer content.deinit(std.heap.page_allocator);

    if (message.content) |text| {
        try content.append(std.heap.page_allocator, .{ .text = .{ .text = text } });
    }

    if (message.tool_calls) |tool_calls| {
        for (tool_calls) |tc| {
            try content.append(std.heap.page_allocator, .{ .tool_call = .{
                .tool_call = .{
                    .id = tc.id,
                    .name = tc.function.name,
                    .arguments = tc.function.arguments,
                },
            } });
        }
    }

    // Convert usage
    var usage: ?core.TokenUsage = null;
    if (response.usage) |u| {
        usage = .{
            .input_tokens = u.prompt_tokens,
            .output_tokens = u.completion_tokens,
        };
        if (u.prompt_tokens_details) |details| {
            if (details.cached_tokens) |cached| {
                usage.?.cache_read_input_tokens = cached;
            }
        }
    }

    return core.AssistantMessage{
        .content = try content.toOwnedSlice(),
        .stop_reason = mapFinishReason(choice.finish_reason orelse "stop"),
        .usage = usage,
    };
}

// ============================================================================
// Utilities
// ============================================================================

fn getBaseUrl(provider: core.KnownProvider) []const u8 {
    return switch (provider) {
        .openai => core.OPENAI_BASE_URL,
        .fireworks => core.FIREWORKS_BASE_URL,
        else => core.OPENAI_BASE_URL,
    };
}

fn mapFinishReason(reason: []const u8) core.StopReason {
    if (std.mem.eql(u8, reason, "stop")) return .stop;
    if (std.mem.eql(u8, reason, "length")) return .length;
    if (std.mem.eql(u8, reason, "tool_calls")) return .tool_use;
    return .stop;
}

// ============================================================================
// Tests
// ============================================================================

test "mapFinishReason" {
    try std.testing.expectEqual(.stop, mapFinishReason("stop"));
    try std.testing.expectEqual(.length, mapFinishReason("length"));
    try std.testing.expectEqual(.tool_use, mapFinishReason("tool_calls"));
}
