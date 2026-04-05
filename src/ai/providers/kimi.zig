//! Kimi Provider - Moonshot AI API implementation
//! Supports both standard OpenAI-compatible API and Kimi Code API

const std = @import("std");
const core = @import("../../core/root.zig");
const ai = @import("../root.zig");
const HttpClient = @import("../../http.zig").HttpClient;

// ============================================================================
// Agent Mode
// ============================================================================

pub const AgentMode = enum {
    normal,
    plan,
};

// ============================================================================
// Kimi Code Options
// ============================================================================

pub const KimiCodeOptions = struct {
    mode: AgentMode = .normal,
    thinking_budget: u32 = 8192,
    tools: ?[]const core.Tool = null,
};

// ============================================================================
// Request Types (Kimi Code API)
// ============================================================================

const KimiCodeRequest = struct {
    model: []const u8,
    messages: []const KimiMessage,
    thinking_budget: u32,
    tools: ?[]const KimiTool = null,
    stream: bool,
};

const KimiMessage = struct {
    role: []const u8,
    content: ?[]const u8 = null,
    tool_calls: ?[]const KimiToolCall = null,
    tool_call_id: ?[]const u8 = null,
};

const KimiTool = struct {
    type: []const u8 = "builtin_function",
    builtin_function: KimiBuiltinFunction,
};

const KimiBuiltinFunction = struct {
    name: []const u8,
};

const KimiToolCall = struct {
    id: []const u8,
    type: []const u8 = "function",
    function: KimiFunctionCall,
};

const KimiFunctionCall = struct {
    name: []const u8,
    arguments: []const u8,
};

// ============================================================================
// Response Types
// ============================================================================

const KimiCodeResponse = struct {
    id: []const u8,
    choices: []const KimiChoice,
    usage: ?KimiUsage = null,
};

const KimiChoice = struct {
    message: ?KimiMessage = null,
    delta: ?KimiDelta = null,
    finish_reason: ?[]const u8 = null,
};

const KimiDelta = struct {
    content: ?[]const u8 = null,
    tool_calls: ?[]const KimiToolCall = null,
};

const KimiUsage = struct {
    prompt_tokens: u32,
    completion_tokens: u32,
    total_tokens: u32,
    completion_tokens_details: ?KimiCompletionDetails = null,
};

const KimiCompletionDetails = struct {
    reasoning_tokens: u32,
};

// ============================================================================
// Standard API (OpenAI-compatible)
// ============================================================================

pub fn complete(http_client: *HttpClient, ctx: core.Context) !core.AssistantMessage {
    // Delegate to OpenAI provider since Kimi standard API is OpenAI-compatible
    return @import("openai.zig").complete(http_client, ctx);
}

pub fn stream(
    http_client: *HttpClient,
    ctx: core.Context,
    callback: *const fn (event: ai.SseEvent) void,
) !void {
    // Delegate to OpenAI provider
    return @import("openai.zig").stream(http_client, ctx, callback);
}

// ============================================================================
// Kimi Code API
// ============================================================================

pub fn completeCode(http_client: *HttpClient, ctx: core.Context) !core.AssistantMessage {
    const api_key = core.getApiKey(.kimi) orelse return core.AiError.ApiKeyNotFound;

    const request_body = try serializeCodeRequest(ctx);
    defer std.heap.page_allocator.free(request_body);

    var headers = std.http.Headers{ .allocator = std.heap.page_allocator };
    defer headers.deinit();
    try headers.append("Authorization", try std.fmt.allocPrint(std.heap.page_allocator, "Bearer {s}", .{api_key}));
    try headers.append("Content-Type", "application/json");

    const url = core.KIMI_CODE_BASE_URL ++ "/chat/completions";

    var response = try http_client.postJson(url, headers, request_body);
    defer response.deinit();

    return try parseCodeResponse(response.body);
}

pub fn streamCode(
    http_client: *HttpClient,
    ctx: core.Context,
    callback: *const fn (event: ai.SseEvent) void,
) !void {
    const api_key = core.getApiKey(.kimi) orelse return core.AiError.ApiKeyNotFound;

    var streaming_ctx = ctx;
    streaming_ctx.stream = true;

    const request_body = try serializeCodeRequest(streaming_ctx);
    defer std.heap.page_allocator.free(request_body);

    var headers = std.http.Headers{ .allocator = std.heap.page_allocator };
    defer headers.deinit();
    try headers.append("Authorization", try std.fmt.allocPrint(std.heap.page_allocator, "Bearer {s}", .{api_key}));
    try headers.append("Content-Type", "application/json");
    try headers.append("Accept", "text/event-stream");

    const url = core.KIMI_CODE_BASE_URL ++ "/chat/completions";

    try http_client.postStream(url, headers, request_body, struct {
        fn onLine(line: []const u8) void {
            processLine(line, callback) catch {};
        }
    }.onLine);
}

// ============================================================================
// Serialization
// ============================================================================

fn serializeCodeRequest(ctx: core.Context) ![]u8 {
    var messages = std.ArrayList(KimiMessage).init(std.heap.page_allocator);
    defer messages.deinit();

    for (ctx.messages) |msg| {
        switch (msg) {
            .user => |user_msg| {
                var content = std.ArrayList(u8).init(std.heap.page_allocator);
                defer content.deinit();

                for (user_msg.content) |block| {
                    switch (block) {
                        .text => |text| try content.appendSlice(text),
                        .image => {}, // Kimi Code may not support images
                        .image_url => {},
                    }
                }

                try messages.append(.{
                    .role = "user",
                    .content = try std.heap.page_allocator.dupe(u8, content.items),
                });
            },
            .assistant => |assistant_msg| {
                var content: ?[]const u8 = null;
                var tool_calls: ?std.ArrayList(KimiToolCall) = null;

                for (assistant_msg.content) |block| {
                    switch (block) {
                        .text => |text| content = text.text,
                        .thinking => {}, // Kimi uses separate reasoning tokens
                        .tool_call => |tc| {
                            if (tool_calls == null) {
                                tool_calls = std.ArrayList(KimiToolCall).init(std.heap.page_allocator);
                            }
                            try tool_calls.?.append(KimiToolCall{
                                .id = tc.tool_call.id,
                                .function = .{
                                    .name = tc.tool_call.name,
                                    .arguments = tc.tool_call.arguments,
                                },
                            });
                        },
                    }
                }

                try messages.append(.{
                    .role = "assistant",
                    .content = content,
                    .tool_calls = if (tool_calls) |tc| try tc.toOwnedSlice() else null,
                });
            },
            .tool_result => |tool_result| {
                var content = std.ArrayList(u8).init(std.heap.page_allocator);
                defer content.deinit();

                for (tool_result.content) |block| {
                    switch (block) {
                        .text => |text| try content.appendSlice(text),
                        .image => {},
                    }
                }

                try messages.append(.{
                    .role = "tool",
                    .content = try std.heap.page_allocator.dupe(u8, content.items),
                    .tool_call_id = tool_result.tool_call_id,
                });
            },
        }
    }

    // Filter tools based on mode
    var tools: ?std.ArrayList(KimiTool) = null;
    if (ctx.tools.len > 0) {
        tools = std.ArrayList(KimiTool).init(std.heap.page_allocator);
        for (ctx.tools) |tool| {
            // In plan mode, only allow read-only tools
            // For now, include all tools
            try tools.?.append(KimiTool{
                .builtin_function = .{ .name = tool.name },
            });
        }
    }

    // Thinking budget based on level
    const thinking_budget = switch (ctx.thinking_level) {
        .off => 0,
        .minimal => 1024,
        .low => 4096,
        .medium => 8192,
        .high => 16384,
        .xhigh => 32768,
    };

    const request = KimiCodeRequest{
        .model = ctx.model.id,
        .messages = messages.items,
        .thinking_budget = thinking_budget,
        .tools = if (tools) |t| t.items else null,
        .stream = ctx.stream,
    };

    return try std.json.stringifyAlloc(std.heap.page_allocator, request, .{});
}

// ============================================================================
// Response Parsing
// ============================================================================

fn parseCodeResponse(body: []const u8) !core.AssistantMessage {
    const parsed = try std.json.parseFromSlice(KimiCodeResponse, std.heap.page_allocator, body, .{});
    defer parsed.deinit();

    const response = parsed.value;
    if (response.choices.len == 0) return error.ApiUnexpectedResponse;

    const choice = response.choices[0];
    const message = choice.message orelse return error.ApiUnexpectedResponse;

    // Convert content
    var content = std.ArrayList(core.AssistantContentBlock).init(std.heap.page_allocator);
    defer content.deinit();

    if (message.content) |text| {
        try content.append(.{ .text = .{ .text = text } });
    }

    if (message.tool_calls) |tool_calls| {
        for (tool_calls) |tc| {
            try content.append(.{ .tool_call = .{
                .tool_call = .{
                    .id = tc.id,
                    .name = tc.function.name,
                    .arguments = tc.function.arguments,
                },
            } });
        }
    }

    // Include thinking content if available
    var usage: ?core.TokenUsage = null;
    if (response.usage) |u| {
        usage = .{
            .input_tokens = u.prompt_tokens,
            .output_tokens = u.completion_tokens,
        };

        if (u.completion_tokens_details) |details| {
            // Add thinking as a separate content block
            if (details.reasoning_tokens > 0) {
                try content.insert(0, .{ .thinking = .{
                    .thinking = try std.fmt.allocPrint(
                        std.heap.page_allocator,
                        "[Thinking process used {d} tokens]",
                        .{details.reasoning_tokens},
                    ),
                } });
            }
        }
    }

    return core.AssistantMessage{
        .content = try content.toOwnedSlice(),
        .stop_reason = mapFinishReason(choice.finish_reason),
        .usage = usage,
    };
}

fn processLine(line: []const u8, callback: *const fn (event: ai.SseEvent) void) !void {
    if (line.len == 0) return;
    if (!std.mem.startsWith(u8, line, "data: ")) return;

    const data = line[6..];
    if (std.mem.eql(u8, data, "[DONE]")) {
        callback(.{ .done = .stop });
        return;
    }

    const parsed = try std.json.parseFromSlice(KimiCodeResponse, std.heap.page_allocator, data, .{});
    defer parsed.deinit();

    const chunk = parsed.value;
    if (chunk.choices.len == 0) return;

    const choice = chunk.choices[0];

    if (choice.delta) |delta| {
        if (delta.content) |content| {
            callback(.{ .text_delta = content });
        }

        if (delta.tool_calls) |tool_calls| {
            for (tool_calls) |tc| {
                callback(.{ .toolcall_start = .{
                    .id = tc.id,
                    .name = tc.function.name,
                } });
                callback(.{ .toolcall_delta = .{
                    .arguments_json_chunk = tc.function.arguments,
                } });
            }
        }
    }

    if (choice.finish_reason) |reason| {
        callback(.{ .done = mapFinishReason(reason) });
    }
}

fn mapFinishReason(reason: ?[]const u8) core.StopReason {
    const r = reason orelse return .stop;
    if (std.mem.eql(u8, r, "stop")) return .stop;
    if (std.mem.eql(u8, r, "length")) return .length;
    if (std.mem.eql(u8, r, "tool_calls")) return .tool_use;
    return .stop;
}

// ============================================================================
// Tests
// ============================================================================

test "AgentMode enum" {
    try std.testing.expectEqual(.normal, AgentMode.normal);
    try std.testing.expectEqual(.plan, AgentMode.plan);
}
