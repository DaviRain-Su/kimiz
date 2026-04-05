//! kimiz-ai - Unified LLM API layer
//! Provides streaming and non-streaming completion APIs

const std = @import("std");
const core = @import("../core/root.zig");
const models = @import("models.zig");

pub const types = core;
pub const models_registry = models;

// Re-export common types
pub const Model = core.Model;
pub const Message = core.Message;
pub const Context = core.Context;
pub const Tool = core.Tool;
pub const StopReason = core.StopReason;
pub const TokenUsage = core.TokenUsage;

// ============================================================================
// SSE Events
// ============================================================================

pub const SseEvent = union(enum) {
    text_delta: []const u8,
    thinking_delta: []const u8,
    toolcall_start: ToolCallStart,
    toolcall_delta: ToolCallDelta,
    toolcall_end,
    done: StopReason,
    err: []const u8,
};

pub const ToolCallStart = struct {
    id: []const u8,
    name: []const u8,
};

pub const ToolCallDelta = struct {
    arguments_json_chunk: []const u8,
};

// ============================================================================
// Assistant Message Event
// ============================================================================

pub const AssistantMessageEvent = struct {
    message: core.AssistantMessage,
    usage: ?core.TokenUsage,
};

// ============================================================================
// AI Interface
// ============================================================================

pub const Ai = struct {
    allocator: std.mem.Allocator,
    http_client: @import("../http.zig").HttpClient,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .http_client = @import("../http.zig").HttpClient.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.http_client.deinit();
    }

    /// Non-streaming completion
    pub fn complete(self: *Self, ctx: core.Context) !core.AssistantMessage {
        switch (ctx.model.provider) {
            .known => |provider| {
                return switch (provider) {
                    .openai, .fireworks => @import("providers/openai.zig").complete(&self.http_client, ctx),
                    .anthropic => @import("providers/anthropic.zig").complete(&self.http_client, ctx),
                    .google => @import("providers/google.zig").complete(&self.http_client, ctx),
                    .kimi => {
                        switch (ctx.model.api) {
                            .known => |api| {
                                return switch (api) {
                                    .@"openai-completions" => @import("providers/openai.zig").complete(&self.http_client, ctx),
                                    .@"kimi-code" => @import("providers/kimi.zig").completeCode(&self.http_client, ctx),
                                    else => error.ProviderNotSupported,
                                };
                            },
                            .custom => error.ProviderNotSupported,
                        }
                    },
                    .openrouter => error.ProviderNotSupported,
                };
            },
            .custom => return error.ProviderNotSupported,
        }
    }

    /// Streaming completion
    pub fn stream(
        self: *Self,
        ctx: core.Context,
        callback: *const fn (event: SseEvent) void,
    ) !void {
        switch (ctx.model.provider) {
            .known => |provider| {
                return switch (provider) {
                    .openai, .fireworks => @import("providers/openai.zig").stream(&self.http_client, ctx, callback),
                    .anthropic => @import("providers/anthropic.zig").stream(&self.http_client, ctx, callback),
                    .google => @import("providers/google.zig").stream(&self.http_client, ctx, callback),
                    .kimi => {
                        switch (ctx.model.api) {
                            .known => |api| {
                                return switch (api) {
                                    .@"openai-completions" => @import("providers/openai.zig").stream(&self.http_client, ctx, callback),
                                    .@"kimi-code" => @import("providers/kimi.zig").streamCode(&self.http_client, ctx, callback),
                                    else => error.ProviderNotSupported,
                                };
                            },
                            .custom => error.ProviderNotSupported,
                        }
                    },
                    .openrouter => error.ProviderNotSupported,
                };
            },
            .custom => return error.ProviderNotSupported,
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Ai init/deinit" {
    const allocator = std.testing.allocator;
    var ai = Ai.init(allocator);
    defer ai.deinit();
}
