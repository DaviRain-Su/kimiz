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
    const provider_key = ctx.model.provider.known;
    const api_key = core.getApiKey(http_client.allocator, provider_key) orelse return core.AiError.ApiKeyNotFound;
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

    const base_url = getBaseUrl(ctx);
    const url = try std.fmt.allocPrint(http_client.allocator, "{s}/v1/messages", .{base_url});
    defer http_client.allocator.free(url);

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
    const provider_key = ctx.model.provider.known;
    const api_key = core.getApiKey(http_client.allocator, provider_key) orelse return core.AiError.ApiKeyNotFound;
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

    const base_url = getBaseUrl(ctx);
    const url = try std.fmt.allocPrint(http_client.allocator, "{s}/v1/messages", .{base_url});
    defer http_client.allocator.free(url);

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
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(allocator);

    try buf.appendSlice(allocator, "{\"model\":");
    try appendJsonString(&buf, allocator, ctx.model.id);

    // Messages
    try buf.appendSlice(allocator, ",\"messages\":[");
    for (ctx.messages, 0..) |msg, msg_i| {
        if (msg_i > 0) try buf.appendSlice(allocator, ",");
        switch (msg) {
            .user => |user_msg| {
                try buf.appendSlice(allocator, "{\"role\":\"user\",\"content\":[");
                var first = true;
                for (user_msg.content) |block| {
                    switch (block) {
                        .text => |text| {
                            if (!first) try buf.appendSlice(allocator, ",");
                            first = false;
                            try buf.appendSlice(allocator, "{\"type\":\"text\",\"text\":");
                            try appendJsonString(&buf, allocator, text);
                            try buf.appendSlice(allocator, "}");
                        },
                        .image => |img| {
                            if (!first) try buf.appendSlice(allocator, ",");
                            first = false;
                            try buf.appendSlice(allocator, "{\"type\":\"image\",\"source\":{\"type\":\"base64\",\"media_type\":");
                            try appendJsonString(&buf, allocator, img.mime_type);
                            try buf.appendSlice(allocator, ",\"data\":");
                            try appendJsonString(&buf, allocator, img.data);
                            try buf.appendSlice(allocator, "}}");
                        },
                        .image_url => {},
                    }
                }
                try buf.appendSlice(allocator, "]}");
            },
            .assistant => |assistant_msg| {
                try buf.appendSlice(allocator, "{\"role\":\"assistant\",\"content\":[");
                var first = true;
                for (assistant_msg.content) |block| {
                    switch (block) {
                        .text => |text| {
                            if (!first) try buf.appendSlice(allocator, ",");
                            first = false;
                            try buf.appendSlice(allocator, "{\"type\":\"text\",\"text\":");
                            try appendJsonString(&buf, allocator, text.text);
                            try buf.appendSlice(allocator, "}");
                        },
                        .thinking => {},
                        .tool_call => |tc| {
                            if (!first) try buf.appendSlice(allocator, ",");
                            first = false;
                            try buf.appendSlice(allocator, "{\"type\":\"tool_use\",\"id\":");
                            try appendJsonString(&buf, allocator, tc.tool_call.id);
                            try buf.appendSlice(allocator, ",\"name\":");
                            try appendJsonString(&buf, allocator, tc.tool_call.name);
                            try buf.appendSlice(allocator, ",\"input\":");
                            try buf.appendSlice(allocator, tc.tool_call.arguments);
                            try buf.appendSlice(allocator, "}");
                        },
                    }
                }
                try buf.appendSlice(allocator, "]}");
            },
            .tool_result => |tool_result| {
                try buf.appendSlice(allocator, "{\"role\":\"user\",\"content\":[");
                try buf.appendSlice(allocator, "{\"type\":\"tool_result\",\"tool_use_id\":");
                try appendJsonString(&buf, allocator, tool_result.tool_call_id);
                try buf.appendSlice(allocator, ",\"content\":[");
                var first = true;
                for (tool_result.content) |block| {
                    switch (block) {
                        .text => |text| {
                            if (!first) try buf.appendSlice(allocator, ",");
                            first = false;
                            try buf.appendSlice(allocator, "{\"type\":\"text\",\"text\":");
                            try appendJsonString(&buf, allocator, text);
                            try buf.appendSlice(allocator, "}");
                        },
                        .image => {},
                        .image_url => {},
                    }
                }
                try buf.appendSlice(allocator, "]}]}");
            },
        }
    }
    try buf.appendSlice(allocator, "]");

    // Temperature and max_tokens
    try buf.appendSlice(allocator, ",\"temperature\":");
    var temp_str: [32]u8 = undefined;
    const temp_len = (try std.fmt.bufPrint(&temp_str, "{d}", .{ctx.temperature})).len;
    try buf.appendSlice(allocator, temp_str[0..temp_len]);

    try buf.appendSlice(allocator, ",\"max_tokens\":");
    var mt_str: [16]u8 = undefined;
    const mt_len = (try std.fmt.bufPrint(&mt_str, "{d}", .{ctx.max_tokens})).len;
    try buf.appendSlice(allocator, mt_str[0..mt_len]);

    // Stream
    if (ctx.stream) {
        try buf.appendSlice(allocator, ",\"stream\":true");
    }

    // Thinking
    if (ctx.thinking_level != .off) {
        const budget: u32 = switch (ctx.thinking_level) {
            .off => 0,
            .minimal => 1024,
            .low => 4096,
            .medium => 8192,
            .high => 16384,
            .xhigh => 32768,
        };
        try buf.appendSlice(allocator, ",\"thinking\":{\"type\":\"enabled\",\"budget_tokens\":");
        var budget_str: [16]u8 = undefined;
        const budget_len = (try std.fmt.bufPrint(&budget_str, "{d}", .{budget})).len;
        try buf.appendSlice(allocator, budget_str[0..budget_len]);
        try buf.appendSlice(allocator, "}");
    }

    // Tools
    if (ctx.tools.len > 0) {
        try buf.appendSlice(allocator, ",\"tools\":[");
        for (ctx.tools, 0..) |tool, i| {
            if (i > 0) try buf.appendSlice(allocator, ",");
            try buf.appendSlice(allocator, "{\"name\":");
            try appendJsonString(&buf, allocator, tool.name);
            try buf.appendSlice(allocator, ",\"description\":");
            try appendJsonString(&buf, allocator, tool.description);
            try buf.appendSlice(allocator, ",\"input_schema\":");
            try buf.appendSlice(allocator, tool.parameters_json);
            try buf.appendSlice(allocator, "}");
        }
        try buf.appendSlice(allocator, "]");
    }

    try buf.appendSlice(allocator, "}");
    return try buf.toOwnedSlice(allocator);
}

fn appendJsonString(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, s: []const u8) !void {
    try buf.append(allocator, '"');
    for (s) |c| {
        switch (c) {
            '"' => try buf.appendSlice(allocator, "\\\""),
            '\\' => try buf.appendSlice(allocator, "\\\\"),
            '\n' => try buf.appendSlice(allocator, "\\n"),
            '\r' => try buf.appendSlice(allocator, "\\r"),
            '\t' => try buf.appendSlice(allocator, "\\t"),
            else => {
                if (c < 0x20) {
                    var esc: [6]u8 = undefined;
                    _ = std.fmt.bufPrint(&esc, "\\u{X:0>4}", .{c}) catch unreachable;
                    try buf.appendSlice(allocator, &esc);
                } else {
                    try buf.append(allocator, c);
                }
            },
        }
    }
    try buf.append(allocator, '"');
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
                const args = try std.json.Stringify.valueAlloc(allocator, t.input, .{});
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

fn getBaseUrl(ctx: core.Context) []const u8 {
    switch (ctx.model.api) {
        .known => |api| switch (api) {
            .@"kimi-code-anthropic" => return core.KIMI_CODE_BASE_URL,
            else => {},
        },
        .custom => {},
    }
    return core.ANTHROPIC_BASE_URL;
}

fn mapStopReason(reason: ?[]const u8) core.StopReason {
    const r = reason orelse return .stop;
    if (std.mem.eql(u8, r, "end_turn")) return .stop;
    if (std.mem.eql(u8, r, "max_tokens")) return .length;
    if (std.mem.eql(u8, r, "tool_use")) return .tool_use;
    return .stop;
}

// ============================================================================
// Tests
// ============================================================================

test "mapStopReason" {
    try std.testing.expectEqual(.stop, mapStopReason("end_turn"));
    try std.testing.expectEqual(.length, mapStopReason("max_tokens"));
    try std.testing.expectEqual(.tool_use, mapStopReason("tool_use"));
    try std.testing.expectEqual(.stop, mapStopReason(null));
}

test "parseResponse text only" {
    const body =
        \\{"id":"msg_1","type":"message","role":"assistant","content":[{"type":"text","text":"Hello"}],"stop_reason":"end_turn","usage":{"input_tokens":10,"output_tokens":3}}
    ;
    const msg = try parseResponse(std.testing.allocator, body);
    defer std.testing.allocator.free(msg.content);
    try std.testing.expectEqual(@as(usize, 1), msg.content.len);
    try std.testing.expectEqualStrings("Hello", msg.content[0].text.text);
    try std.testing.expectEqual(.stop, msg.stop_reason);
}

test "parseResponse with tool_use" {
    const body =
        \\{"id":"msg_2","type":"message","role":"assistant","content":[{"type":"tool_use","id":"tu_1","name":"bash","input":{"command":"ls"}}],"stop_reason":"tool_use","usage":{"input_tokens":20,"output_tokens":10}}
    ;
    const msg = try parseResponse(std.testing.allocator, body);
    defer {
        for (msg.content) |block| {
            if (block == .tool_call) std.testing.allocator.free(block.tool_call.tool_call.arguments);
        }
        std.testing.allocator.free(msg.content);
    }
    try std.testing.expectEqual(@as(usize, 1), msg.content.len);
    try std.testing.expectEqualStrings("tu_1", msg.content[0].tool_call.tool_call.id);
    try std.testing.expectEqualStrings("bash", msg.content[0].tool_call.tool_call.name);
    try std.testing.expectEqual(.tool_use, msg.stop_reason);
}
