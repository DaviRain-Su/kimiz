//! Token Optimization Filters - Core Interface
//! Phase 2: Native Zig implementation of command output compression
//!
//! This module defines the filter interface and common utilities for
//! compressing command outputs to reduce LLM token consumption.

const std = @import("std");

// Re-export Strategy from config module (avoid import issues in standalone tests)
pub const Strategy = enum {
    conservative,  // Keep more detail (~60% compression)
    balanced,      // Default (~75% compression)
    aggressive,    // Maximum compression (~90% compression)
};

// ============================================================================
// Filter Interface
// ============================================================================

pub const FilterContext = struct {
    allocator: std.mem.Allocator,
    strategy: Strategy,
    command: []const u8,
    raw_output: []const u8,
    max_tokens: usize = 2000,
};

pub const FilterResult = struct {
    filtered: []const u8,
    tokens_saved: u32,
    compression_ratio: f32,

    pub fn deinit(self: FilterResult, allocator: std.mem.Allocator) void {
        allocator.free(self.filtered);
    }
};

pub const OutputFilter = struct {
    name: []const u8,
    description: []const u8,
    filter_fn: *const fn (ctx: FilterContext) anyerror!FilterResult,

    pub fn apply(self: OutputFilter, ctx: FilterContext) !FilterResult {
        return self.filter_fn(ctx);
    }
};

// ============================================================================
// Filter Registry
// ============================================================================

pub const FilterRegistry = struct {
    allocator: std.mem.Allocator,
    filters: std.StringHashMap(OutputFilter),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .filters = std.StringHashMap(OutputFilter).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.filters.deinit();
    }

    pub fn register(self: *Self, command_pattern: []const u8, filter: OutputFilter) !void {
        try self.filters.put(command_pattern, filter);
    }

    pub fn getFilter(self: *Self, command: []const u8) ?OutputFilter {
        // Try exact match first
        if (self.filters.get(command)) |f| return f;

        // Try prefix match
        var iter = self.filters.iterator();
        while (iter.next()) |entry| {
            if (std.mem.startsWith(u8, command, entry.key_ptr.*)) {
                return entry.value_ptr.*;
            }
        }

        return null;
    }
};

// ============================================================================
// Common Filter Utilities
// ============================================================================

/// Estimate token count (simple heuristic: ~4 chars per token)
pub fn estimateTokens(text: []const u8) u32 {
    return @intCast(@divTrunc(text.len, 4));
}

/// Calculate compression ratio
pub fn calcCompressionRatio(original: []const u8, compressed: []const u8) f32 {
    if (original.len == 0) return 0.0;
    const ratio: f32 = @as(f32, @floatFromInt(compressed.len)) / @as(f32, @floatFromInt(original.len));
    return 1.0 - ratio;  // Return as percentage reduction
}

/// Remove empty lines and excessive whitespace
pub fn removeEmptyLines(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len > 0) {
            try result.appendSlice(allocator, trimmed);
            try result.append(allocator, '\n');
        }
    }

    return try result.toOwnedSlice(allocator);
}

/// Truncate text to max lines
pub fn truncateLines(allocator: std.mem.Allocator, text: []const u8, max_lines: usize) ![]const u8 {
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    var lines = std.mem.splitScalar(u8, text, '\n');
    var count: usize = 0;

    while (lines.next()) |line| {
        if (count >= max_lines) {
            const remaining = std.mem.count(u8, lines.rest(), "\n");
            if (remaining > 0) {
                const msg = try std.fmt.allocPrint(allocator, "... +{d} more lines\n", .{remaining});
                defer allocator.free(msg);
                try result.appendSlice(allocator, msg);
            }
            break;
        }

        try result.appendSlice(allocator, line);
        try result.append(allocator, '\n');
        count += 1;
    }

    return try result.toOwnedSlice(allocator);
}

/// Truncate text to max tokens
pub fn truncateToTokens(allocator: std.mem.Allocator, text: []const u8, max_tokens: u32) ![]const u8 {
    const current_tokens = estimateTokens(text);
    if (current_tokens <= max_tokens) {
        return allocator.dupe(u8, text);
    }

    // Calculate target character count
    const target_chars: usize = @intCast(max_tokens * 4);
    if (target_chars >= text.len) {
        return allocator.dupe(u8, text);
    }

    // Truncate and add ellipsis
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    try result.appendSlice(allocator, text[0..target_chars]);
    try result.appendSlice(allocator, "\n... (truncated)");

    return try result.toOwnedSlice(allocator);
}

/// Group lines by prefix pattern
pub fn groupByPrefix(
    allocator: std.mem.Allocator,
    text: []const u8,
    delimiter: []const u8,
) ![]const u8 {
    var groups = std.StringHashMap(std.ArrayList([]const u8)).init(allocator);
    defer {
        var iter = groups.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        groups.deinit();
    }

    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        // Find delimiter position
        const delim_pos = std.mem.indexOf(u8, line, delimiter) orelse line.len;
        const prefix = line[0..delim_pos];

        // Get or create group
        const entry = try groups.getOrPut(prefix);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList([]const u8).init(allocator);
        }

        try entry.value_ptr.append(line);
    }

    // Build output
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    var iter = groups.iterator();
    while (iter.next()) |entry| {
        try result.appendSlice(allocator, try std.fmt.allocPrint(
            allocator,
            "{s} ({d} items):\n",
            .{ entry.key_ptr.*, entry.value_ptr.items.len },
        ));

        for (entry.value_ptr.items) |item| {
            try result.appendSlice(allocator, "  ");
            try result.appendSlice(allocator, item);
            try result.append(allocator, '\n');
        }
    }

    return try result.toOwnedSlice(allocator);
}

// ============================================================================
// Default Fallback Filter
// ============================================================================

fn defaultFilter(ctx: FilterContext) !FilterResult {
    const allocator = ctx.allocator;
    const original_tokens = estimateTokens(ctx.raw_output);

    // Apply basic compression based on strategy
    var filtered: []const u8 = undefined;
    switch (ctx.strategy) {
        .aggressive => {
            // Aggressive: remove empty lines + truncate
            const no_empty = try removeEmptyLines(allocator, ctx.raw_output);
            defer allocator.free(no_empty);
            filtered = try truncateToTokens(allocator, no_empty, @intCast(ctx.max_tokens / 2));
        },
        .balanced => {
            // Balanced: remove empty lines
            filtered = try removeEmptyLines(allocator, ctx.raw_output);
        },
        .conservative => {
            // Conservative: just truncate if needed
            filtered = try truncateToTokens(allocator, ctx.raw_output, @intCast(ctx.max_tokens));
        },
    }

    const filtered_tokens = estimateTokens(filtered);
    const tokens_saved = if (original_tokens > filtered_tokens)
        original_tokens - filtered_tokens
    else
        0;

    return FilterResult{
        .filtered = filtered,
        .tokens_saved = tokens_saved,
        .compression_ratio = calcCompressionRatio(ctx.raw_output, filtered),
    };
}

pub const default_filter = OutputFilter{
    .name = "default",
    .description = "Basic compression: remove empty lines and truncate",
    .filter_fn = defaultFilter,
};

// ============================================================================
// Tests
// ============================================================================

test "estimateTokens" {
    try std.testing.expectEqual(@as(u32, 10), estimateTokens("x" ** 40));
    try std.testing.expectEqual(@as(u32, 0), estimateTokens(""));
    try std.testing.expectEqual(@as(u32, 1), estimateTokens("test"));
}

test "calcCompressionRatio" {
    try std.testing.expectEqual(@as(f32, 0.5), calcCompressionRatio("xxxx", "xx"));
    try std.testing.expectEqual(@as(f32, 0.75), calcCompressionRatio("xxxx", "x"));
    try std.testing.expectEqual(@as(f32, 0.0), calcCompressionRatio("xx", "xx"));
}

test "removeEmptyLines" {
    const allocator = std.testing.allocator;

    const input = "line1\n\nline2\n   \nline3\n";
    const result = try removeEmptyLines(allocator, input);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("line1\nline2\nline3\n", result);
}

test "truncateLines" {
    const allocator = std.testing.allocator;

    const input = "line1\nline2\nline3\nline4\nline5\n";
    const result = try truncateLines(allocator, input, 3);
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "line1") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "line2") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "line3") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "more lines") != null);
}

test "truncateToTokens" {
    const allocator = std.testing.allocator;

    const input = "x" ** 100;
    const result = try truncateToTokens(allocator, input, 10); // 10 tokens = 40 chars
    defer allocator.free(result);

    try std.testing.expect(result.len < input.len);
    try std.testing.expect(std.mem.indexOf(u8, result, "truncated") != null);
}

test "FilterRegistry basic" {
    const allocator = std.testing.allocator;
    var registry = FilterRegistry.init(allocator);
    defer registry.deinit();

    try registry.register("git status", default_filter);

    try std.testing.expect(registry.getFilter("git status") != null);
    try std.testing.expect(registry.getFilter("git log") == null);
}

test "default_filter aggressive" {
    const allocator = std.testing.allocator;

    const input = "line1\n\nline2\n   \nline3\n";
    const ctx = FilterContext{
        .allocator = allocator,
        .strategy = .aggressive,
        .command = "test",
        .raw_output = input,
        .max_tokens = 1000,
    };

    const result = try default_filter.apply(ctx);
    defer result.deinit(allocator);

    try std.testing.expect(result.filtered.len < input.len);
    try std.testing.expect(result.compression_ratio > 0);
}
