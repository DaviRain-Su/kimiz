//! Google Provider - Generative AI API implementation

const std = @import("std");
const core = @import("../../core/root.zig");
const ai = @import("../root.zig");
const HttpClient = @import("../../http.zig").HttpClient;

// ============================================================================
// Request Types
// ============================================================================

const GoogleRequest = struct {
    contents: []const GoogleContent,
    generationConfig: GoogleGenerationConfig,
    tools: ?[]const GoogleTool = null,
    systemInstruction: ?GoogleContent = null,
};

const GoogleContent = struct {
    role: []const u8,
    parts: []const GooglePart,
};

const GooglePart = union(enum) {
    text: struct { text: []const u8 },
    inlineData: struct {
        mimeType: []const u8,
        data: []const u8,
    },
    functionCall: struct {
        name: []const u8,
        args: std.json.Value,
    },
    functionResponse: struct {
        name: []const u8,
        response: struct { result: []const u8 },
    },
};

const GoogleGenerationConfig = struct {
    temperature: f32,
    maxOutputTokens: u32,
};

const GoogleTool = struct {
    functionDeclarations: []const GoogleFunctionDeclaration,
};

const GoogleFunctionDeclaration = struct {
    name: []const u8,
    description: []const u8,
    parameters: std.json.Value,
};

// ============================================================================
// Response Types
// ============================================================================

const GoogleResponse = struct {
    candidates: []const GoogleCandidate,
    usageMetadata: ?GoogleUsage = null,
};

const GoogleCandidate = struct {
    content: GoogleContent,
    finishReason: ?[]const u8 = null,
};

const GoogleUsage = struct {
    promptTokenCount: u32,
    candidatesTokenCount: u32,
    totalTokenCount: u32,
};

// ============================================================================
// SSE Types
// ============================================================================

const GoogleStreamChunk = struct {
    candidates: []const GoogleStreamCandidate,
    usageMetadata: ?GoogleUsage = null,
};

const GoogleStreamCandidate = struct {
    content: struct { parts: []const GoogleStreamPart },
    finishReason: ?[]const u8 = null,
};

const GoogleStreamPart = union(enum) {
    text: struct { text: []const u8 },
    functionCall: struct {
        name: []const u8,
        args: std.json.Value,
    },
};

// ============================================================================
// Non-streaming Completion
// ============================================================================

pub fn complete(http_client: *HttpClient, ctx: core.Context) !core.AssistantMessage {
    const api_key = core.getApiKey(.google) orelse return core.AiError.ApiKeyNotFound;

    const request_body = try serializeRequest(ctx);
    defer std.heap.page_allocator.free(request_body);

    var headers: std.ArrayList(std.http.Header) = .empty;
    defer headers.deinit(std.heap.page_allocator);
    try headers.append(std.heap.page_allocator, .{
        .name = "Content-Type",
        .value = "application/json",
    });

    const url = try std.fmt.allocPrint(
        std.heap.page_allocator,
        "{s}/v1beta/models/{s}:generateContent?key={s}",
        .{ core.GOOGLE_BASE_URL, ctx.model.id, api_key },
    );
    defer std.heap.page_allocator.free(url);

    var response = try http_client.postJson(url, headers.items, request_body);
    defer response.deinit(std.heap.page_allocator);

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
    const api_key = core.getApiKey(.google) orelse return core.AiError.ApiKeyNotFound;

    var streaming_ctx = ctx;
    streaming_ctx.stream = true;

    const request_body = try serializeRequest(streaming_ctx);
    defer std.heap.page_allocator.free(request_body);

    var headers: std.ArrayList(std.http.Header) = .empty;
    defer headers.deinit(std.heap.page_allocator);
    try headers.append(std.heap.page_allocator, .{
        .name = "Content-Type",
        .value = "application/json",
    });

    const url = try std.fmt.allocPrint(
        std.heap.page_allocator,
        "{s}/v1beta/models/{s}:streamGenerateContent?key={s}",
        .{ core.GOOGLE_BASE_URL, ctx.model.id, api_key },
    );
    defer std.heap.page_allocator.free(url);

    try http_client.postStream(url, headers.items, request_body, struct {
        fn onLine(line: []const u8) void {
            processLine(line, callback) catch {};
        }
    }.onLine);
}

fn processLine(line: []const u8, callback: *const fn (event: ai.SseEvent) void) !void {
    if (line.len == 0) return;

    const parsed = try std.json.parseFromSlice(GoogleStreamChunk, std.heap.page_allocator, line, .{});
    defer parsed.deinit(std.heap.page_allocator);

    const chunk = parsed.value;
    if (chunk.candidates.len == 0) return;

    const candidate = chunk.candidates[0];
    for (candidate.content.parts) |part| {
        switch (part) {
            .text => |t| callback(.{ .text_delta = t.text }),
            .functionCall => |fc| {
                callback(.{ .toolcall_start = .{
                    .id = fc.name, // Google uses function name as ID
                    .name = fc.name,
                } });
                const args = try std.json.stringifyAlloc(std.heap.page_allocator, fc.args, .{});
                callback(.{ .toolcall_delta = .{ .arguments_json_chunk = args } });
            },
        }
    }

    if (candidate.finishReason) |reason| {
        callback(.{ .done = mapFinishReason(reason) });
    }
}

// ============================================================================
// Serialization
// ============================================================================

fn serializeRequest(ctx: core.Context) ![]u8 {
    var contents: std.ArrayList(GoogleContent) = .empty;
    defer contents.deinit(std.heap.page_allocator);

    for (ctx.messages) |msg| {
        switch (msg) {
            .user => |user_msg| {
                var parts: std.ArrayList(GooglePart) = .empty;
                defer parts.deinit(std.heap.page_allocator);

                for (user_msg.content) |block| {
                    switch (block) {
                        .text => |text| try parts.append(std.heap.page_allocator, .{ .text = .{ .text = text } }),
                        .image => |img| try parts.append(std.heap.page_allocator, .{ .inlineData = .{
                            .mimeType = img.mime_type,
                            .data = img.data,
                        } }),
                        .image_url => {},
                    }
                }

                try contents.append(std.heap.page_allocator, .{
                    .role = "user",
                    .parts = try parts.toOwnedSlice(std.heap.page_allocator),
                });
            },
            .assistant => |assistant_msg| {
                var parts: std.ArrayList(GooglePart) = .empty;
                defer parts.deinit(std.heap.page_allocator);

                for (assistant_msg.content) |block| {
                    switch (block) {
                        .text => |text| try parts.append(std.heap.page_allocator, .{ .text = .{ .text = text.text } }),
                        .tool_call => |tc| {
                            const args = try std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, tc.tool_call.arguments, .{});
                            try parts.append(std.heap.page_allocator, .{ .functionCall = .{
                                .name = tc.tool_call.name,
                                .args = args.value,
                            } });
                        },
                        .thinking => {},
                    }
                }

                try contents.append(std.heap.page_allocator, .{
                    .role = "model",
                    .parts = try parts.toOwnedSlice(std.heap.page_allocator),
                });
            },
            .tool_result => |tool_result| {
                var result_text: std.ArrayList(u8) = .empty;
                defer result_text.deinit(std.heap.page_allocator);

                for (tool_result.content) |block| {
                    switch (block) {
                        .text => |text| try result_text.appendSlice(std.heap.page_allocator, text),
                        .image => {},
                        .image_url => {},
                    }
                }

                try contents.append(std.heap.page_allocator, .{
                    .role = "user",
                    .parts = &[_]GooglePart{.{
                        .functionResponse = .{
                            .name = tool_result.tool_name,
                            .response = .{ .result = result_text.items },
                        },
                    }},
                });
            },
        }
    }

    // Convert tools
    var tools: ?std.ArrayList(GoogleTool) = null;
    if (ctx.tools.len > 0) {
        tools = std.ArrayList(GoogleTool){ .items = &.{}, .capacity = 0 };
        for (ctx.tools) |tool| {
            const schema = try std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, tool.parameters_json, .{});
            try tools.?.append(std.heap.page_allocator, .{
                .functionDeclarations = &[_]GoogleFunctionDeclaration{.{
                    .name = tool.name,
                    .description = tool.description,
                    .parameters = schema.value,
                }},
            });
        }
    }

    const request = GoogleRequest{
        .contents = try contents.toOwnedSlice(std.heap.page_allocator),
        .generationConfig = .{
            .temperature = ctx.temperature,
            .maxOutputTokens = ctx.max_tokens,
        },
        .tools = if (tools) |t| t.items else null,
    };

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(std.heap.page_allocator);
    try std.fmt.format(buf.writer(std.heap.page_allocator), "{f}", .{std.json.fmt(request, .{})});
    return try buf.toOwnedSlice(std.heap.page_allocator);
}

// ============================================================================
// Response Parsing
// ============================================================================

fn parseResponse(body: []const u8) !core.AssistantMessage {
    const parsed = try std.json.parseFromSlice(GoogleResponse, std.heap.page_allocator, body, .{});
    defer parsed.deinit(std.heap.page_allocator);

    const response = parsed.value;
    if (response.candidates.len == 0) return error.ApiUnexpectedResponse;

    const candidate = response.candidates[0];

    // Convert content
    var content: std.ArrayList(core.AssistantContentBlock) = .empty;
    defer content.deinit(std.heap.page_allocator);

    for (candidate.content.parts) |part| {
        switch (part) {
            .text => |t| try content.append(std.heap.page_allocator, .{ .text = .{ .text = t.text } }),
            .functionCall => |fc| {
                const args = try std.json.stringifyAlloc(std.heap.page_allocator, fc.args, .{});
                try content.append(std.heap.page_allocator, .{ .tool_call = .{
                    .tool_call = .{
                        .id = fc.name,
                        .name = fc.name,
                        .arguments = args,
                    },
                } });
            },
            .functionResponse => {},
            .inlineData => {},
        }
    }

    var usage: ?core.TokenUsage = null;
    if (response.usageMetadata) |u| {
        usage = .{
            .input_tokens = u.promptTokenCount,
            .output_tokens = u.candidatesTokenCount,
        };
    }

    return core.AssistantMessage{
        .content = try content.toOwnedSlice(),
        .stop_reason = mapFinishReason(candidate.finishReason),
        .usage = usage,
    };
}

fn mapFinishReason(reason: ?[]const u8) core.StopReason {
    const r = reason orelse return .stop;
    if (std.mem.eql(u8, r, "STOP")) return .stop;
    if (std.mem.eql(u8, r, "MAX_TOKENS")) return .length;
    if (std.mem.eql(u8, r, "OTHER")) return .stop;
    return .stop;
}
