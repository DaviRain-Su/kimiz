//! Fireworks AI Provider
//! Uses OpenAI-compatible API format
//! Provides accelerated Kimi 2.5 Turbo model with repetition detection

const std = @import("std");
const core = @import("../../core/root.zig");
const ai = @import("../root.zig");
const HttpClient = @import("../../http.zig").HttpClient;
const openai = @import("openai.zig");

// ============================================================================
// Constants
// ============================================================================

/// Repetition detection configuration for Fireworks Kimi 2.5 Turbo
pub const REPETITION_WINDOW_SIZE = 5;
pub const REPETITION_THRESHOLD = 0.8; // 80% similarity
pub const REPETITION_MAX_CONSECUTIVE = 3;

// ============================================================================
// Stream Guard for Repetition Detection
// ============================================================================

pub const StreamGuard = struct {
    window: [REPETITION_WINDOW_SIZE][]const u8,
    window_pos: usize = 0,
    window_count: usize = 0,
    consecutive_repetitions: u32 = 0,
    accumulated_text: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .window = undefined,
            .window_pos = 0,
            .window_count = 0,
            .consecutive_repetitions = 0,
            .accumulated_text = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        // Free window strings
        for (0..self.window_count) |i| {
            const idx = (self.window_pos + i) % REPETITION_WINDOW_SIZE;
            if (self.window[idx].len > 0) {
                allocator.free(self.window[idx]);
            }
        }
        self.accumulated_text.deinit(allocator);
    }

    /// Add delta and check for repetition
    /// Returns true if repetition detected
    pub fn checkDelta(self: *Self, delta: []const u8) !bool {
        if (delta.len == 0) return false;

        // Add to accumulated text
        try self.accumulated_text.appendSlice(delta);

        // Store in window
        const idx = self.window_pos % REPETITION_WINDOW_SIZE;
        if (self.window_count == REPETITION_WINDOW_SIZE) {
            // Free old entry
            self.allocator.free(self.window[idx]);
        }
        self.window[idx] = try self.allocator.dupe(u8, delta);
        self.window_pos = (self.window_pos + 1) % REPETITION_WINDOW_SIZE;
        if (self.window_count < REPETITION_WINDOW_SIZE) {
            self.window_count += 1;
        }

        // Check repetition if window is full
        if (self.window_count == REPETITION_WINDOW_SIZE) {
            if (try self.isRepetitive(delta)) {
                self.consecutive_repetitions += 1;
                if (self.consecutive_repetitions >= REPETITION_MAX_CONSECUTIVE) {
                    return true; // Repetition detected
                }
            } else {
                self.consecutive_repetitions = 0;
            }
        }

        return false;
    }

    fn isRepetitive(self: *Self, delta: []const u8) !bool {
        // Calculate similarity with recent deltas
        var total_similarity: f64 = 0;
        var count: f64 = 0;

        for (0..self.window_count) |i| {
            const idx = (self.window_pos + i) % REPETITION_WINDOW_SIZE;
            const prev = self.window[idx];
            if (prev.len > 0) {
                const sim = try calculateSimilarity(self.allocator, delta, prev);
                total_similarity += sim;
                count += 1;
            }
        }

        if (count == 0) return false;
        const avg_similarity = total_similarity / count;
        return avg_similarity >= REPETITION_THRESHOLD;
    }

    /// Get accumulated text
    pub fn getAccumulatedText(self: *Self) []const u8 {
        return self.accumulated_text.items;
    }
};

/// Calculate similarity between two strings (0.0 - 1.0)
/// Uses simplified Levenshtein-based similarity
fn calculateSimilarity(allocator: std.mem.Allocator, a: []const u8, b: []const u8) !f64 {
    if (a.len == 0 and b.len == 0) return 1.0;
    if (a.len == 0 or b.len == 0) return 0.0;
    if (std.mem.eql(u8, a, b)) return 1.0;

    // Simple n-gram based similarity for performance
    const n = 3; // trigram
    if (a.len < n or b.len < n) {
        // Fall back to prefix matching for short strings
        const min_len = @min(a.len, b.len);
        var matches: usize = 0;
        for (0..min_len) |i| {
            if (a[i] == b[i]) matches += 1;
        }
        return @as(f64, @floatFromInt(matches)) / @as(f64, @floatFromInt(@max(a.len, b.len)));
    }

    // Count common trigrams
    var a_trigrams: std.StringHashMap(void) = .empty;
    defer a_trigrams.deinit(allocator);

    for (0..a.len - n + 1) |i| {
        try a_trigrams.put(a[i..][0..n], {});
    }

    var common: usize = 0;
    for (0..b.len - n + 1) |i| {
        if (a_trigrams.contains(b[i..][0..n])) {
            common += 1;
        }
    }

    const total_trigrams = (a.len - n + 1) + (b.len - n + 1);
    if (total_trigrams == 0) return 0.0;

    return @as(f64, @floatFromInt(common * 2)) / @as(f64, @floatFromInt(total_trigrams));
}

// ============================================================================
// Non-streaming Completion
// ============================================================================

pub fn complete(http_client: *HttpClient, ctx: core.Context) !core.AssistantMessage {
    // Fireworks uses OpenAI-compatible API
    // Just route to openai provider with Fireworks base URL
    return openai.complete(http_client, ctx);
}

// ============================================================================
// Streaming Completion with Repetition Guard
// ============================================================================

pub fn stream(
    http_client: *HttpClient,
    ctx: core.Context,
    callback: *const fn (event: ai.SseEvent) void,
) !void {
    const allocator = http_client.allocator;
    const api_key = try core.getApiKey(allocator, .fireworks) orelse return core.AiError.ApiKeyNotFound;
    defer allocator.free(api_key);

    // Create streaming context with repetition guard
    var stream_ctx = StreamContext{
        .callback = callback,
        .guard = StreamGuard.init(allocator),
    };
    defer stream_ctx.guard.deinit(allocator);

    // Serialize request with stream=true
    var streaming_ctx = ctx;
    streaming_ctx.stream = true;
    const request_body = try serializeRequest(allocator, streaming_ctx);
    defer allocator.free(request_body);

    // Setup headers
    var headers: std.ArrayList(std.http.Header) = .empty;
    defer headers.deinit(allocator);
    try headers.append(allocator, .{
        .name = "Authorization",
        .value = try std.fmt.allocPrint(allocator, "Bearer {s}", .{api_key}),
    });
    try headers.append(allocator, .{
        .name = "Content-Type",
        .value = "application/json",
    });
    try headers.append(allocator, .{
        .name = "Accept",
        .value = "text/event-stream",
    });

    // Fireworks endpoint
    const url = "https://api.fireworks.ai/inference/v1/chat/completions";

    // Make streaming request with guard
    try http_client.postStream(url, headers.items, request_body, struct {
        fn onLine(line: []const u8, ctx_ptr: *StreamContext) void {
            const stream_allocator = ctx_ptr.guard.allocator;
            ctx_ptr.processLine(stream_allocator, line) catch |err| {
                std.log.err("Failed to process SSE line: {s}", .{@errorName(err)});
            };
        }
    }.onLine);
}

const StreamContext = struct {
    callback: *const fn (event: ai.SseEvent) void,
    guard: StreamGuard,

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
        const parsed = try std.json.parseFromSlice(FireworksStreamChunk, self.guard.allocator, data, .{});
        defer parsed.deinit(self.guard.allocator);

        const chunk = parsed.value;
        if (chunk.choices.len == 0) return;

        const choice = chunk.choices[0];

        // Handle finish reason
        if (choice.finish_reason) |reason| {
            const stop_reason = mapFinishReason(reason);
            self.callback(.{ .done = stop_reason });
            return;
        }

        // Handle delta with repetition guard
        if (choice.delta) |delta| {
            if (delta.content) |content| {
                // Check for repetition
                const is_repetitive = try self.guard.checkDelta(content);
                if (is_repetitive) {
                    // Repetition detected - emit error and stop
                    self.callback(.{ .err = "Repetition detected - stopping generation" });
                    self.callback(.{ .done = .stop });
                    return;
                }
                self.callback(.{ .text_delta = content });
            }

            if (delta.tool_calls) |tool_calls| {
                for (tool_calls) |tc| {
                    if (tc.id) |id| {
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

const FireworksStreamChunk = struct {
    id: []const u8,
    choices: []const FireworksChoice,
};

const FireworksChoice = struct {
    delta: ?FireworksDelta = null,
    finish_reason: ?[]const u8 = null,
    index: u32,
};

const FireworksDelta = struct {
    role: ?[]const u8 = null,
    content: ?[]const u8 = null,
    tool_calls: ?[]const FireworksToolCallDelta = null,
};

const FireworksToolCallDelta = struct {
    index: u32,
    id: ?[]const u8 = null,
    type: ?[]const u8 = null,
    function: ?FireworksFunctionCallDelta = null,
};

const FireworksFunctionCallDelta = struct {
    name: ?[]const u8 = null,
    arguments: ?[]const u8 = null,
};

// ============================================================================
// Serialization
// ============================================================================

fn serializeRequest(allocator: std.mem.Allocator, ctx: core.Context) ![]u8 {
    // Define local structs first (order matters!)
    const FireworksMessage = struct {
        role: []const u8,
        content: []const u8,
        tool_call_id: ?[]const u8 = null,
    };

    const FireworksTool = struct {
        type: []const u8 = "function",
        function: struct {
            name: []const u8,
            description: []const u8,
            parameters: std.json.Value,
        },
    };

    const FireworksRequest = struct {
        model: []const u8,
        messages: []const FireworksMessage,
        temperature: f32,
        max_tokens: u32,
        stream: bool,
        tools: ?[]const FireworksTool = null,
    };

    var messages: std.ArrayList(FireworksMessage) = .empty;
    defer messages.deinit(allocator);

    for (ctx.messages) |msg| {
        const fw_msg = switch (msg) {
            .user => |user_msg| blk: {
                var content: std.ArrayList(u8) = .empty;
                defer content.deinit(allocator);
                for (user_msg.content) |block| {
                    switch (block) {
                        .text => |text| try content.appendSlice(text),
                        .image => |img| try std.fmt.format(content.writer(), "[Image: {s}]", .{img.mime_type}),
                        .image_url => |img_url| try std.fmt.format(content.writer(), "[Image: {s}]", .{img_url.url}),
                    }
                }
                break :blk FireworksMessage{
                    .role = "user",
                    .content = try allocator.dupe(u8, content.items),
                };
            },
            .assistant => |assistant_msg| blk: {
                var content: std.ArrayList(u8) = .empty;
                defer content.deinit(allocator);
                for (assistant_msg.content) |block| {
                    switch (block) {
                        .text => |text| try content.appendSlice(text.text),
                        .thinking => {},
                        .tool_call => |tc| {
                            try std.fmt.format(content.writer(), "Calling tool: {s}", .{tc.tool_call.name});
                        },
                    }
                }
                break :blk FireworksMessage{
                    .role = "assistant",
                    .content = try content.toOwnedSlice(),
                };
            },
            .tool_result => |tool_result| blk: {
                var content: std.ArrayList(u8) = .empty;
                defer content.deinit(allocator);
                for (tool_result.content) |block| {
                    switch (block) {
                        .text => |text| try content.appendSlice(text),
                        .image => |img| try std.fmt.format(content.writer(), "[Image: {s}]", .{img.mime_type}),
                    }
                }
                break :blk FireworksMessage{
                    .role = "tool",
                    .content = try allocator.dupe(u8, content.items),
                    .tool_call_id = tool_result.tool_call_id,
                };
            },
        };
        try messages.append(allocator, fw_msg);
    }

    // Convert tools
    var tools: ?std.ArrayList(FireworksTool) = null;
    if (ctx.tools.len > 0) {
        tools = std.ArrayList(FireworksTool){ .items = &.{}, .capacity = 0 };
        for (ctx.tools) |tool| {
            const schema = try std.json.parseFromSlice(std.json.Value, allocator, tool.parameters_json, .{});
            defer allocator.free(schema.value);

            try tools.?.append(allocator, FireworksTool{
                .function = .{
                    .name = tool.name,
                    .description = tool.description,
                    .parameters = schema.value,
                },
            });
        }
    }

    // Map model ID for Fireworks
    const model_id = if (std.mem.eql(u8, ctx.model.id, "kimi-k2p5-turbo"))
        "accounts/fireworks/routers/kimi-k2p5-turbo"
    else
        ctx.model.id;

    const request = FireworksRequest{
        .model = model_id,
        .messages = messages.items,
        .temperature = ctx.temperature,
        .max_tokens = ctx.max_tokens,
        .stream = ctx.stream,
        .tools = if (tools) |t| t.items else null,
    };

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(allocator);
    try std.fmt.format(buf.writer(allocator), "{f}", .{std.json.fmt(request, .{})});
    return try buf.toOwnedSlice(allocator);
}

// ============================================================================
// Utilities
// ============================================================================

fn mapFinishReason(reason: []const u8) core.StopReason {
    if (std.mem.eql(u8, reason, "stop")) return .stop;
    if (std.mem.eql(u8, reason, "length")) return .length;
    if (std.mem.eql(u8, reason, "tool_calls")) return .tool_use;
    return .stop;
}

// ============================================================================
// Tests
// ============================================================================

test "calculateSimilarity" {
    const sim1 = try calculateSimilarity(std.testing.allocator, "hello world", "hello world");
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim1, 0.01);

    const sim2 = try calculateSimilarity(std.testing.allocator, "hello", "world");
    try std.testing.expect(sim2 < 0.5);

    const sim3 = try calculateSimilarity(std.testing.allocator, "", "");
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim3, 0.01);
}

test "StreamGuard repetition detection" {
    var guard = StreamGuard.init(std.testing.allocator);
    defer guard.deinit(std.testing.allocator);

    // Add similar deltas
    const d1 = "The quick brown fox";
    const d2 = "The quick brown fox";
    const d3 = "The quick brown fox";

    _ = try guard.checkDelta(d1);
    _ = try guard.checkDelta(d2);
    const detected = try guard.checkDelta(d3);

    // Should detect repetition after 3 similar deltas
    try std.testing.expect(detected);
}
