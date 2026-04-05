//! kimiz-ai - AI module types and model registry
//! Unified LLM API layer

const std = @import("std");
const core = @import("../core/root.zig");
const Model = core.Model;
const ModelCost = core.ModelCost;
const Provider = core.Provider;
const KnownProvider = core.KnownProvider;
const Api = core.Api;
const KnownApi = core.KnownApi;

// Re-export core types
pub const types = core;

// ============================================================================
// Model Registry
// ============================================================================

pub const model_table = &[_]Model{
    // OpenAI Models
    .{
        .id = "gpt-4o",
        .provider = .{ .known = .openai },
        .api = .{ .known = .@"openai-completions" },
        .context_window = 128000,
        .max_tokens = 4096,
        .cost = .{
            .input_token_cost = 2.50,
            .output_token_cost = 10.00,
            .cache_token_cost = 1.25,
        },
        .supports_multimodal = true,
    },
    .{
        .id = "gpt-4o-mini",
        .provider = .{ .known = .openai },
        .api = .{ .known = .@"openai-completions" },
        .context_window = 128000,
        .max_tokens = 16384,
        .cost = .{
            .input_token_cost = 0.15,
            .output_token_cost = 0.60,
            .cache_token_cost = 0.075,
        },
        .supports_multimodal = true,
    },
    .{
        .id = "o1",
        .provider = .{ .known = .openai },
        .api = .{ .known = .@"openai-completions" },
        .context_window = 200000,
        .max_tokens = 100000,
        .cost = .{
            .input_token_cost = 15.00,
            .output_token_cost = 60.00,
            .cache_token_cost = 7.50,
        },
        .supports_thinking = true,
    },
    // Anthropic Models
    .{
        .id = "claude-3-7-sonnet-20250219",
        .provider = .{ .known = .anthropic },
        .api = .{ .known = .@"anthropic-messages" },
        .context_window = 200000,
        .max_tokens = 8192,
        .cost = .{
            .input_token_cost = 3.00,
            .output_token_cost = 15.00,
            .cache_token_cost = 0.30,
        },
        .supports_thinking = true,
        .supports_multimodal = true,
    },
    .{
        .id = "claude-3-5-haiku-20241022",
        .provider = .{ .known = .anthropic },
        .api = .{ .known = .@"anthropic-messages" },
        .context_window = 200000,
        .max_tokens = 8192,
        .cost = .{
            .input_token_cost = 0.80,
            .output_token_cost = 4.00,
            .cache_token_cost = 0.08,
        },
        .supports_multimodal = true,
    },
    // Google Models
    .{
        .id = "gemini-2.0-flash",
        .provider = .{ .known = .google },
        .api = .{ .known = .@"google-generative-ai" },
        .context_window = 1048576,
        .max_tokens = 8192,
        .cost = .{
            .input_token_cost = 0.35,
            .output_token_cost = 0.53,
        },
        .supports_multimodal = true,
    },
    // Kimi Models
    .{
        .id = "kimi-k2-5",
        .provider = .{ .known = .kimi },
        .api = .{ .known = .@"openai-completions" },
        .context_window = 256000,
        .max_tokens = 8192,
        .cost = .{
            .input_token_cost = 2.00,
            .output_token_cost = 8.00,
        },
    },
    .{
        .id = "kimi-for-coding",
        .provider = .{ .known = .kimi },
        .api = .{ .known = .@"kimi-code-openai" },
        .context_window = 262144,
        .max_tokens = 32768,
        .cost = .{
            .input_token_cost = 2.00,
            .output_token_cost = 8.00,
        },
        .supports_thinking = true,
    },
    .{
        .id = "kimi-for-coding-anthropic",
        .provider = .{ .known = .kimi },
        .api = .{ .known = .@"kimi-code-anthropic" },
        .context_window = 262144,
        .max_tokens = 32768,
        .cost = .{
            .input_token_cost = 2.00,
            .output_token_cost = 8.00,
        },
        .supports_thinking = true,
    },
    // Fireworks AI
    .{
        .id = "kimi-k2p5-turbo",
        .provider = .{ .known = .fireworks },
        .api = .{ .known = .@"openai-completions" },
        .context_window = 256000,
        .max_tokens = 8192,
        .cost = .{
            .input_token_cost = 0.80,
            .output_token_cost = 0.80,
        },
    },
};

/// Get model by provider and id
pub fn getModel(provider: KnownProvider, id: []const u8) ?Model {
    for (model_table) |model| {
        switch (model.provider) {
            .known => |p| {
                if (p == provider and std.mem.eql(u8, model.id, id)) {
                    return model;
                }
            },
            .custom => {},
        }
    }
    return null;
}

/// Get model by id (searches all providers)
pub fn getModelById(id: []const u8) ?Model {
    for (model_table) |model| {
        if (std.mem.eql(u8, model.id, id)) {
            return model;
        }
    }
    return null;
}

/// Get all models for a provider
pub fn getModelsByProvider(allocator: std.mem.Allocator, provider: KnownProvider) ![]Model {
    var list = std.ArrayList(Model).init(allocator);
    defer list.deinit();

    for (model_table) |model| {
        switch (model.provider) {
            .known => |p| {
                if (p == provider) {
                    try list.append(model);
                }
            },
            .custom => {},
        }
    }

    return list.toOwnedSlice();
}

/// Calculate cost for token usage
pub fn calculateCost(model: Model, usage: core.TokenUsage) f64 {
    const cost_per_1m: f64 = 1000000.0;

    var total: f64 = 0;

    // Input tokens
    total += @as(f64, @floatFromInt(usage.input_tokens)) * model.cost.input_token_cost / cost_per_1m;

    // Output tokens
    total += @as(f64, @floatFromInt(usage.output_tokens)) * model.cost.output_token_cost / cost_per_1m;

    // Cache tokens (if available)
    if (model.cost.cache_token_cost) |cache_cost| {
        const cache_tokens = (usage.cache_creation_input_tokens orelse 0) +
            (usage.cache_read_input_tokens orelse 0);
        total += @as(f64, @floatFromInt(cache_tokens)) * cache_cost / cost_per_1m;
    }

    return total;
}

// ============================================================================
// Tests
// ============================================================================

test "getModel finds existing model" {
    const model = getModel(.openai, "gpt-4o");
    try std.testing.expect(model != null);
    try std.testing.expectEqual(.openai, model.?.provider.known);
}

test "getModel returns null for unknown model" {
    const model = getModel(.openai, "unknown-model");
    try std.testing.expect(model == null);
}

test "calculateCost computes correctly" {
    const model = getModel(.openai, "gpt-4o").?;
    const usage = core.TokenUsage{
        .input_tokens = 1000000,
        .output_tokens = 500000,
    };

    const cost = calculateCost(model, usage);
    // 2.50 + 5.00 = 7.50
    try std.testing.expectApproxEqAbs(@as(f64, 7.50), cost, 0.01);
}
