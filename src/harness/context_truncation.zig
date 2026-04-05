//! Context Truncation - Manages context window limits
//! Provides intelligent message truncation when context exceeds limits

const std = @import("std");
const core = @import("../core/root.zig");

/// Context size limits
pub const ContextLimits = struct {
    /// Maximum tokens allowed in context
    max_tokens: u32,
    /// Reserve tokens for response
    reserve_tokens: u32,
    /// Threshold for triggering truncation (0.0-1.0)
    threshold: f32,

    pub fn init(max_tokens: u32) ContextLimits {
        return .{
            .max_tokens = max_tokens,
            .reserve_tokens = @divTrunc(max_tokens, 4), // 25% reserve
            .threshold = 0.8,
        };
    }

    pub fn effectiveLimit(self: ContextLimits) u32 {
        return self.max_tokens - self.reserve_tokens;
    }

    pub fn shouldTruncate(self: ContextLimits, current_tokens: u32) bool {
        const threshold_tokens = @as(f32, @floatFromInt(self.max_tokens)) * self.threshold;
        return @as(f32, @floatFromInt(current_tokens)) >= threshold_tokens;
    }
};

/// Message truncation strategies
pub const TruncationStrategy = enum {
    /// Remove oldest messages first
    oldest_first,
    /// Remove system messages first, then oldest
    system_first,
    /// Summarize old messages instead of removing
    summarize,
    /// Keep only N most recent messages
    recent_only,
};

/// Context truncator manages message history size
pub const ContextTruncator = struct {
    allocator: std.mem.Allocator,
    limits: ContextLimits,
    strategy: TruncationStrategy,
    stats: TruncationStats,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, limits: ContextLimits) Self {
        return .{
            .allocator = allocator,
            .limits = limits,
            .strategy = .oldest_first,
            .stats = .{},
        };
    }

    /// Calculate approximate size of a message in tokens
    fn messageSizeUser(self: *Self, user_msg: core.UserMessage) usize {
        _ = self;
        var size: usize = 0;
        for (user_msg.content) |block| {
            size += switch (block) {
                .text => |text| text.len,
                .image => |img| img.data.len / 4, // Approximate token count for base64
                .image_url => |img_url| img_url.url.len,
            };
        }
        return size / 4; // Rough approximation: 4 chars per token
    }

    /// Calculate total context size
    pub fn calculateSize(self: *Self, messages: []const core.Message) u32 {
        var total: usize = 0;
        for (messages) |msg| {
            total += switch (msg) {
                .user => |u| self.messageSizeUser(u),
                .assistant => |a| blk: {
                    var size: usize = 0;
                    for (a.content) |block| {
                        size += switch (block) {
                            .text => |t| t.text.len,
                            .thinking => |t| t.thinking.len,
                            .tool_call => |tc| tc.tool_call.name.len + tc.tool_call.arguments.len,
                        };
                    }
                    break :blk size / 4;
                },
                .tool_result => |tr| blk: {
                    var size: usize = 0;
                    for (tr.content) |block| {
                        size += switch (block) {
                            .text => |t| t.len,
                            .image => |img| img.data.len,
                            .image_url => |img_url| img_url.url.len,
                        };
                    }
                    break :blk size / 4;
                },
            };
        }
        return @intCast(total);
    }

    /// Check if truncation is needed
    pub fn needsTruncation(self: *Self, messages: []const core.Message) bool {
        const current_size = self.calculateSize(messages);
        return self.limits.shouldTruncate(current_size);
    }

    /// Truncate messages according to strategy
    pub fn truncate(self: *Self, messages: *std.ArrayList(core.Message)) !void {
        if (!self.needsTruncation(messages.items)) return;

        switch (self.strategy) {
            .oldest_first => try self.truncateOldestFirst(messages),
            .system_first => try self.truncateSystemFirst(messages),
            .summarize => try self.truncateWithSummarization(messages),
            .recent_only => try self.keepRecentOnly(messages),
        }
    }

    /// Truncate oldest messages first
    fn truncateOldestFirst(self: *Self, messages: *std.ArrayList(core.Message)) !void {
        while (self.needsTruncation(messages.items) and messages.items.len > 2) {
            // Remove oldest non-system message
            for (messages.items, 0..) |msg, i| {
                if (switch (msg) {
                    .user => true,
                    .assistant => true,
                    .tool_result => true,
                }) {
                    self.freeMessage(messages.items[i]);
                    _ = messages.orderedRemove(i);
                    self.stats.messages_removed += 1;
                    break;
                }
            }
        }
    }

    /// Remove system messages first, then oldest
    fn truncateSystemFirst(self: *Self, messages: *std.ArrayList(core.Message)) !void {
        // First pass: remove tool results
        var i: usize = 0;
        while (i < messages.items.len) {
            if (switch (messages.items[i]) {
                .tool_result => true,
                else => false,
            }) {
                self.freeMessage(messages.items[i]);
                _ = messages.orderedRemove(i);
                self.stats.messages_removed += 1;
            } else {
                i += 1;
            }
        }

        // Second pass: remove oldest if still needed
        try self.truncateOldestFirst(messages);
    }

    /// Truncate with summarization (placeholder)
    fn truncateWithSummarization(self: *Self, messages: *std.ArrayList(core.Message)) !void {
        // For now, fall back to oldest_first
        // TODO: Implement actual summarization using AI
        try self.truncateOldestFirst(messages);
    }

    /// Keep only N most recent messages
    fn keepRecentOnly(self: *Self, messages: *std.ArrayList(core.Message)) !void {
        const keep_count = 10; // Keep last 10 messages
        while (messages.items.len > keep_count) {
            self.freeMessage(messages.items[0]);
            _ = messages.orderedRemove(0);
            self.stats.messages_removed += 1;
        }
    }

    /// Free message resources
    fn freeMessage(self: *Self, msg: core.Message) void {
        // Note: In real implementation, we'd free any allocated memory
        // For now, most messages use arena allocator which is freed in bulk
        _ = self;
        _ = msg;
    }

    /// Get truncation statistics
    pub fn getStats(self: *Self) TruncationStats {
        return self.stats;
    }

    /// Reset statistics
    pub fn resetStats(self: *Self) void {
        self.stats = .{};
    }
};

/// Truncation statistics
pub const TruncationStats = struct {
    messages_removed: u32 = 0,
    messages_summarized: u32 = 0,
    tokens_saved: u32 = 0,
    truncations_performed: u32 = 0,
};

/// Convenience function to truncate messages
pub fn truncateMessages(
    allocator: std.mem.Allocator,
    messages: *std.ArrayList(core.Message),
    max_tokens: u32,
) !void {
    var truncator = ContextTruncator.init(allocator, ContextLimits.init(max_tokens));
    try truncator.truncate(messages);
}

// ============================================================================
// Tests
// ============================================================================

test "ContextLimits calculations" {
    const limits = ContextLimits.init(1000);
    try std.testing.expectEqual(@as(u32, 1000), limits.max_tokens);
    try std.testing.expectEqual(@as(u32, 250), limits.reserve_tokens);
    try std.testing.expectEqual(@as(u32, 750), limits.effectiveLimit());
    try std.testing.expect(limits.shouldTruncate(850));
    try std.testing.expect(!limits.shouldTruncate(500));
}
