//! Anthropic Provider - Messages API implementation

const std = @import("std");
const core = @import("../../core/root.zig");
const ai = @import("../root.zig");
const HttpClient = @import("../../http.zig").HttpClient;

// ============================================================================
// Request Types
// ============================================================================

const AnthropicRequest = struct {
    model: []const u8,
    messages: []const AnthropicMessage,
    temperature: f32,
    max_tokens: u32,
    stream: bool,
    thinking: ?AnthropicThinking = null,
    tools: ?[]const AnthropicTool = null,
    system: ?[]const SystemContent = null,
};

const AnthropicThinking = struct {
    type: []const u8 = "enabled",
    budget_tokens: u32,
};

const SystemContent = struct {
    type: []const u8 = "text",
    text: []const u8,
};

const AnthropicMessage = struct {
    role: []const u8,
    content: []const AnthropicContent,
};

const AnthropicContent = union(enum) {
    text: struct {
        type: []const u8 = "text",
        text: []const u8,
    },
    tool_use: struct {
        type: []const u8 = "tool_use",
        id: []const u8,
        name: []const u8,
        input: std.json.Value,
    },
    tool_result: struct {
        type: []const u8 = "tool_result",
        tool_use_id: []const u8,
        content: []const ContentBlock,
    },
    image: struct {
        type: []const u8 = "image",
        source: ImageSource,
    },
};

const ContentBlock = struct {
    type: []const u8 = "text",
    text: []const u8,
};

const ImageSource = struct {
    type: []const u8 = "base64",
    media_type: []const u8,
    data: []const u8,
};

const AnthropicTool = struct {
    name: []const u8,
    description: []const u8,
    input_schema: std.json.Value,
};

// ============================================================================
// Response Types
// ============================================================================

const AnthropicResponse = struct {
    id: []const u8,
    type: []const u8,
    role: []const u8,
    content: []const AnthropicResponseContent,
    model: []const u8,
    stop_reason: ?[]const u8,
    stop_sequence: ?[]const u8,
    usage: AnthropicUsage,
};

const AnthropicResponseContent = union(enum) {
    text: struct {
        type: []const u8 = "text",
        text: []const u8,
    },
    thinking: struct {
        type: []const u8 = "thinking",
        thinking: []const u8,
        signature: ?[]const u8,
    },
    tool_use: struct {
        type: []const u8 = "tool_use",
        id: []const u8,
        name: []const u8,
        input: std.json.Value,
    },
};

const AnthropicUsage = struct {
    input_tokens: u32,
    output_tokens: u32,
    cache_creation_input_tokens: ?u32 = null,
    cache_read_input_tokens: ?u32 = null,
};

// ============================================================================
// SSE Types
// ============================================================================

const AnthropicStreamEvent = union(enum) {
    message_start: struct {
        message: struct {
            id: []const u8,
            role: []const u8,
            content: []const std.json.Value,
            model: []const u8,
        },
    },
    content_block_start: struct {
        index: u32,
        content_block: AnthropicStreamContentBlock,
    },
    content_block_delta: struct {
        index: u32,
        delta: AnthropicDelta,
    },
    content_block_stop: struct {
        index: u32,
    },
    message_delta: struct {
        delta: struct {
            stop_reason: ?[]const u8 = null,
            stop_sequence: ?[]const u8 = null,
            usage: ?AnthropicUsage = null,
        },
    },
    message_stop,
    err: struct {
        err: struct {
            type: []const u8,
            message: []const u8,
        },
    },
};

const AnthropicStreamContentBlock = union(enum) {
    text: struct { type: []const u8 = "text", text: []const u8 },
    thinking: struct { type: []const u8 = "thinking", thinking: []const u8 },
    tool_use: struct {
        type: []const u8 = "tool_use",
        id: []const u8,
        name: []const u8,
        input: std.json.Value,
    },
};

const AnthropicDelta = union(enum) {
    text_delta: struct { text: []const u8 },
    thinking_delta: struct { thinking: []const u8 },
    input_json_delta: struct { partial_json: []const u8 },
};

// ============================================================================
// Non-streaming Completion
// ============================================================================

pub fn complete(http_client: *HttpClient, ctx: core.Context) !core.AssistantMessage {
    const api_key = core.getApiKey(.anthropic) orelse return core.AiError.ApiKeyNotFound;

    const request_body = try serializeRequest(ctx);
    defer std.heap.page_allocator.free(request_body);

    var headers = std.http.Headers{ .allocator = std.heap.page_allocator };
    defer headers.deinit();
    try headers.append("x-api-key", api_key);
    try headers.append("anthropic-version", core.ANTHROPIC_API_VERSION);
    try headers.append("Content-Type", "application/json");

    const url = core.ANTHROPIC_BASE_URL ++ "/v1/messages";

    var response = try http_client.postJson(url, headers, request_body);
    defer response.deinit();

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
    const api_key = core.getApiKey(.anthropic) orelse return core.AiError.ApiKeyNotFound;

    var streaming_ctx = ctx;
    streaming_ctx.stream = true;

    const request_body = try serializeRequest(streaming_ctx);
    defer std.heap.page_allocator.free(request_body);

    var headers = std.http.Headers{ .allocator = std.heap.page_allocator };
    defer headers.deinit();
    try headers.append("x-api-key", api_key);
    try headers.append("anthropic-version", core.ANTHROPIC_API_VERSION);
    try headers.append("Content-Type", "application/json");
    try headers.append("Accept", "text/event-stream");

    const url = core.ANTHROPIC_BASE_URL ++ "/v1/messages";

    _ = StreamContext{ .callback = callback };

    try http_client.postStream(url, headers, request_body, struct {
        fn onLine(line: []const u8, ctx_ptr: *StreamContext) void {
            ctx_ptr.processLine(line) catch {};
        }
    }.onLine);
}

const StreamContext = struct {
    callback: *const fn (event: ai.SseEvent) void,

    fn processLine(self: *StreamContext, line: []const u8) !void {
        if (line.len == 0) return;
        if (!std.mem.startsWith(u8, line, "event: ")) return;

        const event_type = line[7..];
        // Next line should be "data: {...}"
        // For simplicity, just parse the data line

        if (std.mem.eql(u8, event_type, "content_block_delta")) {
            // Parse and handle delta
        } else if (std.mem.eql(u8, event_type, "message_stop")) {
            self.callback(.{ .done = .stop });
        }
    }
};

// ============================================================================
// Serialization
// ============================================================================

fn serializeRequest(ctx: core.Context) ![]u8 {
    // Convert messages
    var messages = std.ArrayList(AnthropicMessage).init(std.heap.page_allocator);
    defer messages.deinit();

    for (ctx.messages) |msg| {
        switch (msg) {
            .user => |user_msg| {
                var content = std.ArrayList(AnthropicContent).init(std.heap.page_allocator);
                defer content.deinit();

                for (user_msg.content) |block| {
                    switch (block) {
                        .text => |text| {
                            try content.append(.{ .text = .{ .text = text } });
                        },
                        .image => |img| {
                            try content.append(.{ .image = .{
                                .source = .{
                                    .media_type = img.mime_type,
                                    .data = img.data,
                                },
                            } });
                        },
                        .image_url => {}, // Anthropic doesn't support image URLs directly
                    }
                }

                try messages.append(.{
                    .role = "user",
                    .content = try content.toOwnedSlice(),
                });
            },
            .assistant => |assistant_msg| {
                var content = std.ArrayList(AnthropicContent).init(std.heap.page_allocator);
                defer content.deinit();

                for (assistant_msg.content) |block| {
                    switch (block) {
                        .text => |text| {
                            try content.append(.{ .text = .{ .text = text.text } });
                        },
                        .thinking => |thinking| {
                            try content.append(.{ .thinking = .{
                                .thinking = thinking.thinking,
                                .signature = thinking.thinking_signature,
                            } });
                        },
                        .tool_call => |tc| {
                            try content.append(.{ .tool_use = .{
                                .id = tc.tool_call.id,
                                .name = tc.tool_call.name,
                                .input = try std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, tc.tool_call.arguments, .{}),
                            } });
                        },
                    }
                }

                try messages.append(.{
                    .role = "assistant",
                    .content = try content.toOwnedSlice(),
                });
            },
            .tool_result => |tool_result| {
                var content = std.ArrayList(ContentBlock).init(std.heap.page_allocator);
                defer content.deinit();

                for (tool_result.content) |block| {
                    switch (block) {
                        .text => |text| try content.append(.{ .text = text }),
                        .image => {}, // Skip images in tool results for now
                    }
                }

                try messages.append(.{
                    .role = "user",
                    .content = &[_]AnthropicContent{.{
                        .tool_result = .{
                            .tool_use_id = tool_result.tool_call_id,
                            .content = try content.toOwnedSlice(),
                        },
                    }},
                });
            },
        }
    }

    // Convert tools
    var tools: ?std.ArrayList(AnthropicTool) = null;
    if (ctx.tools.len > 0) {
        tools = std.ArrayList(AnthropicTool).init(std.heap.page_allocator);
        for (ctx.tools) |tool| {
            const schema = try std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, tool.parameters_json, .{});
            try tools.?.append(.{
                .name = tool.name,
                .description = tool.description,
                .input_schema = schema.value,
            });
        }
    }

    // Thinking configuration
    var thinking: ?AnthropicThinking = null;
    if (ctx.thinking_level != .off) {
        const budget = switch (ctx.thinking_level) {
            .off => 0,
            .minimal => 1024,
            .low => 4096,
            .medium => 8192,
            .high => 16384,
            .xhigh => 32768,
        };
        thinking = .{ .budget_tokens = budget };
    }

    const request = AnthropicRequest{
        .model = ctx.model.id,
        .messages = messages.items,
        .temperature = ctx.temperature,
        .max_tokens = ctx.max_tokens,
        .stream = ctx.stream,
        .thinking = thinking,
        .tools = if (tools) |t| t.items else null,
    };

    return try std.json.stringifyAlloc(std.heap.page_allocator, request, .{});
}

// ============================================================================
// Response Parsing
// ============================================================================

fn parseResponse(body: []const u8) !core.AssistantMessage {
    const parsed = try std.json.parseFromSlice(AnthropicResponse, std.heap.page_allocator, body, .{});
    defer parsed.deinit();

    const response = parsed.value;

    // Convert content blocks
    var content = std.ArrayList(core.AssistantContentBlock).init(std.heap.page_allocator);
    defer content.deinit();

    for (response.content) |block| {
        switch (block) {
            .text => |t| {
                try content.append(.{ .text = .{ .text = t.text } });
            },
            .thinking => |t| {
                try content.append(.{ .thinking = .{
                    .thinking = t.thinking,
                    .thinking_signature = t.signature,
                } });
            },
            .tool_use => |t| {
                try content.append(.{ .tool_call = .{
                    .tool_call = .{
                        .id = t.id,
                        .name = t.name,
                        .arguments = try std.json.stringifyAlloc(std.heap.page_allocator, t.input, .{}),
                    },
                } });
            },
        }
    }

    return core.AssistantMessage{
        .content = try content.toOwnedSlice(),
        .stop_reason = mapStopReason(response.stop_reason),
        .usage = .{
            .input_tokens = response.usage.input_tokens,
            .output_tokens = response.usage.output_tokens,
            .cache_creation_input_tokens = response.usage.cache_creation_input_tokens,
            .cache_read_input_tokens = response.usage.cache_read_input_tokens,
        },
    };
}

fn mapStopReason(reason: ?[]const u8) core.StopReason {
    const r = reason orelse return .stop;
    if (std.mem.eql(u8, r, "end_turn")) return .stop;
    if (std.mem.eql(u8, r, "max_tokens")) return .length;
    if (std.mem.eql(u8, r, "tool_use")) return .tool_use;
    return .stop;
}
