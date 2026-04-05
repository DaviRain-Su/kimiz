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

    var headers = std.http.Headers{ .allocator = std.heap.page_allocator };
    defer headers.deinit();
    try headers.append("Content-Type", "application/json");

    const url = try std.fmt.allocPrint(
        std.heap.page_allocator,
        "{s}/v1beta/models/{s}:generateContent?key={s}",
        .{ core.GOOGLE_BASE_URL, ctx.model.id, api_key },
    );
    defer std.heap.page_allocator.free(url);

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
    const api_key = core.getApiKey(.google) orelse return core.AiError.ApiKeyNotFound;

    var streaming_ctx = ctx;
    streaming_ctx.stream = true;

    const request_body = try serializeRequest(streaming_ctx);
    defer std.heap.page_allocator.free(request_body);

    var headers = std.http.Headers{ .allocator = std.heap.page_allocator };
    defer headers.deinit();
    try headers.append("Content-Type", "application/json");

    const url = try std.fmt.allocPrint(
        std.heap.page_allocator,
        "{s}/v1beta/models/{s}:streamGenerateContent?key={s}",
        .{ core.GOOGLE_BASE_URL, ctx.model.id, api_key },
    );
    defer std.heap.page_allocator.free(url);

    try http_client.postStream(url, headers, request_body, struct {
        fn onLine(line: []const u8) void {
            processLine(line, callback) catch {};
        }
    }.onLine);
}

fn processLine(line: []const u8, callback: *const fn (event: ai.SseEvent) void) !void {
    if (line.len == 0) return;

    const parsed = try std.json.parseFromSlice(GoogleStreamChunk, std.heap.page_allocator, line, .{});
    defer parsed.deinit();

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
    var contents = std.ArrayList(GoogleContent).init(std.heap.page_allocator);
    defer contents.deinit();

    for (ctx.messages) |msg| {
        switch (msg) {
            .user => |user_msg| {
                var parts = std.ArrayList(GooglePart).init(std.heap.page_allocator);
                defer parts.deinit();

                for (user_msg.content) |block| {
                    switch (block) {
                        .text => |text| try parts.append(.{ .text = .{ .text = text } }),
                        .image => |img| try parts.append(.{ .inlineData = .{
                            .mimeType = img.mime_type,
                            .data = img.data,
                        } }),
                        .image_url => {},
                    }
                }

                try contents.append(.{
                    .role = "user",
                    .parts = try parts.toOwnedSlice(),
                });
            },
            .assistant => |assistant_msg| {
                var parts = std.ArrayList(GooglePart).init(std.heap.page_allocator);
                defer parts.deinit();

                for (assistant_msg.content) |block| {
                    switch (block) {
                        .text => |text| try parts.append(.{ .text = .{ .text = text.text } }),
                        .tool_call => |tc| {
                            const args = try std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, tc.tool_call.arguments, .{});
                            try parts.append(.{ .functionCall = .{
                                .name = tc.tool_call.name,
                                .args = args.value,
                            } });
                        },
                        .thinking => {},
                    }
                }

                try contents.append(.{
                    .role = "model",
                    .parts = try parts.toOwnedSlice(),
                });
            },
            .tool_result => |tool_result| {
                var result_text = std.ArrayList(u8).init(std.heap.page_allocator);
                defer result_text.deinit();

                for (tool_result.content) |block| {
                    switch (block) {
                        .text => |text| try result_text.appendSlice(text),
                        .image => {},
                    }
                }

                try contents.append(.{
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
        tools = std.ArrayList(GoogleTool).init(std.heap.page_allocator);
        for (ctx.tools) |tool| {
            const schema = try std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, tool.parameters_json, .{});
            try tools.?.append(.{
                .functionDeclarations = &[_]GoogleFunctionDeclaration{.{
                    .name = tool.name,
                    .description = tool.description,
                    .parameters = schema.value,
                }},
            });
        }
    }

    const request = GoogleRequest{
        .contents = try contents.toOwnedSlice(),
        .generationConfig = .{
            .temperature = ctx.temperature,
            .maxOutputTokens = ctx.max_tokens,
        },
        .tools = if (tools) |t| t.items else null,
    };

    return try std.json.stringifyAlloc(std.heap.page_allocator, request, .{});
}

// ============================================================================
// Response Parsing
// ============================================================================

fn parseResponse(body: []const u8) !core.AssistantMessage {
    const parsed = try std.json.parseFromSlice(GoogleResponse, std.heap.page_allocator, body, .{});
    defer parsed.deinit();

    const response = parsed.value;
    if (response.candidates.len == 0) return error.ApiUnexpectedResponse;

    const candidate = response.candidates[0];

    // Convert content
    var content = std.ArrayList(core.AssistantContentBlock).init(std.heap.page_allocator);
    defer content.deinit();

    for (candidate.content.parts) |part| {
        switch (part) {
            .text => |t| try content.append(.{ .text = .{ .text = t.text } }),
            .functionCall => |fc| {
                const args = try std.json.stringifyAlloc(std.heap.page_allocator, fc.args, .{});
                try content.append(.{ .tool_call = .{
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
