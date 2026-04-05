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
    const api_key = core.getApiKey(http_client.allocator, .anthropic) orelse return core.AiError.ApiKeyNotFound;
    defer http_client.allocator.free(api_key);

    const request_body = try serializeRequest(http_client.allocator, ctx);
    defer http_client.allocator.free(request_body);

    var headers: std.ArrayList(std.http.Header) = .empty;
    defer headers.deinit(http_client.allocator);
    try headers.append(http_client.allocator, .{
        .name = "x-api-key",
        .value = api_key,
    });
    try headers.append(http_client.allocator, .{
        .name = "anthropic-version",
        .value = core.ANTHROPIC_API_VERSION,
    });
    try headers.append(http_client.allocator, .{
        .name = "Content-Type",
        .value = "application/json",
    });

    const url = core.ANTHROPIC_BASE_URL ++ "/v1/messages";

    var response = try http_client.postJson(url, headers.items, request_body);
    defer response.deinit();

    return try parseResponse(http_client.allocator, response.body);
}

// ============================================================================
// Streaming Completion
// ============================================================================

pub fn stream(
    http_client: *HttpClient,
    ctx: core.Context,
    callback: *const fn (event: ai.SseEvent) void,
) !void {
    const api_key = core.getApiKey(http_client.allocator, .anthropic) orelse return core.AiError.ApiKeyNotFound;
    defer http_client.allocator.free(api_key);

    var streaming_ctx = ctx;
    streaming_ctx.stream = true;

    const request_body = try serializeRequest(http_client.allocator, streaming_ctx);
    defer http_client.allocator.free(request_body);

    var headers: std.ArrayList(std.http.Header) = .empty;
    defer headers.deinit(http_client.allocator);
    try headers.append(http_client.allocator, .{
        .name = "x-api-key",
        .value = api_key,
    });
    try headers.append(http_client.allocator, .{
        .name = "anthropic-version",
        .value = core.ANTHROPIC_API_VERSION,
    });
    try headers.append(http_client.allocator, .{
        .name = "Content-Type",
        .value = "application/json",
    });
    try headers.append(http_client.allocator, .{
        .name = "Accept",
        .value = "text/event-stream",
    });

    const url = core.ANTHROPIC_BASE_URL ++ "/v1/messages";

    const stream_ctx = StreamContext{
        .callback = callback,
        .current_block_type = null,
        .current_block_index = 0,
        .allocator = http_client.allocator,
    };
    _ = stream_ctx;

    try http_client.postStream(url, headers.items, request_body, struct {
        fn onLine(line: []const u8, ctx_ptr: *StreamContext) void {
            ctx_ptr.processLine(line) catch |err| {
                std.log.err("Failed to process SSE line: {s}", .{@errorName(err)});
            };
        }
    }.onLine);
}

const StreamContext = struct {
    callback: *const fn (event: ai.SseEvent) void,
    current_block_type: ?[]const u8,
    current_block_index: u32,
    allocator: std.mem.Allocator,

    fn processLine(self: *StreamContext, line: []const u8) !void {
        if (line.len == 0) return;
        
        // Handle SSE data lines
        if (!std.mem.startsWith(u8, line, "data: ")) return;

        const data = line[6..]; // Skip "data: "
        
        // Check for stream end
        if (std.mem.eql(u8, data, "[DONE]")) {
            self.callback(.{ .done = .stop });
            return;
        }

        // Parse the event data
        const parsed = try std.json.parseFromSlice(AnthropicStreamEvent, self.allocator, data, .{
            .ignore_unknown_fields = true,
        });
        defer parsed.deinit(self.allocator);

        const event = parsed.value;
        
        switch (event) {
            .content_block_start => |block| {
                self.current_block_index = block.index;
                switch (block.content_block) {
                    .text => |t| {
                        self.callback(.{ .text_delta = t.text });
                    },
                    .thinking => |t| {
                        self.callback(.{ .thinking_delta = t.thinking });
                    },
                    .tool_use => |t| {
                        self.callback(.{ .toolcall_start = .{
                            .id = t.id,
                            .name = t.name,
                        } });
                    },
                }
            },
            .content_block_delta => |delta| {
                switch (delta.delta) {
                    .text_delta => |td| {
                        self.callback(.{ .text_delta = td.text });
                    },
                    .thinking_delta => |td| {
                        self.callback(.{ .thinking_delta = td.thinking });
                    },
                    .input_json_delta => |jd| {
                        self.callback(.{ .toolcall_delta = .{
                            .arguments_json_chunk = jd.partial_json,
                        } });
                    },
                }
            },
            .message_stop => {
                self.callback(.{ .done = .stop });
            },
            .message_delta => |md| {
                if (md.delta.stop_reason) |reason| {
                    const stop_reason = mapStopReason(reason);
                    self.callback(.{ .done = stop_reason });
                }
            },
            .err => |e| {
                std.log.err("Anthropic API error: {s} - {s}", .{ e.err.type, e.err.message });
                self.callback(.{ .done = .stop });
            },
            else => {},
        }
    }
};

// ============================================================================
// Serialization
// ============================================================================

fn serializeRequest(allocator: std.mem.Allocator, ctx: core.Context) ![]u8 {
    // Convert messages
    var messages: std.ArrayList(AnthropicMessage) = .empty;
    defer messages.deinit(allocator);

    for (ctx.messages) |msg| {
        switch (msg) {
            .user => |user_msg| {
                var content: std.ArrayList(AnthropicContent) = .empty;
                defer content.deinit(allocator);

                for (user_msg.content) |block| {
                    switch (block) {
                        .text => |text| {
                            try content.append(allocator, .{ .text = .{ .text = text } });
                        },
                        .image => |img| {
                            try content.append(allocator, .{ .image = .{
                                .source = .{
                                    .media_type = img.mime_type,
                                    .data = img.data,
                                },
                            } });
                        },
                        .image_url => {}, // Anthropic doesn't support image URLs directly
                    }
                }

                try messages.append(allocator, .{
                    .role = "user",
                    .content = try content.toOwnedSlice(allocator),
                });
            },
            .assistant => |assistant_msg| {
                var content: std.ArrayList(AnthropicContent) = .empty;
                defer content.deinit(allocator);

                for (assistant_msg.content) |block| {
                    switch (block) {
                        .text => |text| {
                            try content.append(allocator, .{ .text = .{ .text = text.text } });
                        },
                        .thinking => {}, // Anthropic handles thinking separately via API
                        .tool_call => |tc| {
                            const parsed = try std.json.parseFromSlice(std.json.Value, allocator, tc.tool_call.arguments, .{});
                            try content.append(allocator, .{ .tool_use = .{
                                .id = tc.tool_call.id,
                                .name = tc.tool_call.name,
                                .input = parsed.value,
                            } });
                        },
                    }
                }

                try messages.append(allocator, .{
                    .role = "assistant",
                    .content = try content.toOwnedSlice(allocator),
                });
            },
            .tool_result => |tool_result| {
                var content: std.ArrayList(ContentBlock) = .empty;
                defer content.deinit(allocator);

                for (tool_result.content) |block| {
                    switch (block) {
                        .text => |text| try content.append(allocator, .{ .text = text }),
                        .image => {}, // Skip images in tool results for now
                        .image_url => {}, // Skip image URLs in tool results for now
                    }
                }

                try messages.append(allocator, .{
                    .role = "user",
                    .content = &[_]AnthropicContent{.{
                        .tool_result = .{
                            .tool_use_id = tool_result.tool_call_id,
                            .content = try content.toOwnedSlice(allocator),
                        },
                    }},
                });
            },
        }
    }

    // Convert tools
    var tools: ?std.ArrayList(AnthropicTool) = null;
    if (ctx.tools.len > 0) {
        tools = std.ArrayList(AnthropicTool){ .items = &.{}, .capacity = 0 };
        for (ctx.tools) |tool| {
            const schema = try std.json.parseFromSlice(std.json.Value, allocator, tool.parameters_json, .{});
            try tools.?.append(allocator, .{
                .name = tool.name,
                .description = tool.description,
                .input_schema = schema.value,
            });
        }
    }

    // Thinking configuration
    var thinking: ?AnthropicThinking = null;
    if (ctx.thinking_level != .off) {
        const budget: u32 = switch (ctx.thinking_level) {
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

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(allocator);
    // TODO: Implement proper JSON serialization for Zig 0.16
    // For now, return a placeholder to allow compilation
    _ = request;
    try buf.appendSlice(allocator, "{\"placeholder\":true}");
    return try buf.toOwnedSlice(allocator);
}

// ============================================================================
// Response Parsing
// ============================================================================

fn parseResponse(allocator: std.mem.Allocator, body: []const u8) !core.AssistantMessage {
    const parsed = try std.json.parseFromSlice(AnthropicResponse, allocator, body, .{});
    defer parsed.deinit();

    const response = parsed.value;

    // Convert content blocks
    var content: std.ArrayList(core.AssistantContentBlock) = .empty;
    defer content.deinit(allocator);

    for (response.content) |block| {
        switch (block) {
            .text => |t| {
                try content.append(allocator, .{ .text = .{ .text = t.text } });
            },
            .thinking => |t| {
                try content.append(allocator, .{ .thinking = .{
                    .thinking = t.thinking,
                    .thinking_signature = t.signature,
                } });
            },
            .tool_use => |t| {
                // TODO: Fix JSON serialization for Zig 0.16
                // For now, use placeholder arguments
                const args = try std.fmt.allocPrint(allocator, "{{}}", .{});
                try content.append(allocator, .{ .tool_call = .{
                    .tool_call = .{
                        .id = t.id,
                        .name = t.name,
                        .arguments = args,
                    },
                } });
            },
        }
    }

    return core.AssistantMessage{
        .content = try content.toOwnedSlice(allocator),
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
