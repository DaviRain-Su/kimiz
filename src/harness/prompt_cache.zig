//! Prompt Caching - Stable prefix caching for API efficiency
//! Reduces token usage by caching static context parts

const std = @import("std");
const workspace = @import("../workspace/root.zig");
const WorkspaceInfo = workspace.WorkspaceInfo;
const core = @import("../core/root.zig");
const Tool = core.Tool;
const log = @import("../utils/log.zig");

/// Hash computation for cache invalidation
fn computeHash(data: []const u8) u32 {
    return std.hash.Crc32.hash(data);
}

/// Prompt cache for stable prefix management
pub const PromptCache = struct {
    allocator: std.mem.Allocator,
    stable_prefix: ?[]const u8,
    workspace_hash: u32,
    tools_hash: u32,
    last_updated: i64,
    cache_hits: u64,
    cache_misses: u64,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .stable_prefix = null,
            .workspace_hash = 0,
            .tools_hash = 0,
            .last_updated = 0,
            .cache_hits = 0,
            .cache_misses = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.stable_prefix) |prefix| {
            self.allocator.free(prefix);
        }
    }

    /// Get or build stable prefix
    pub fn getOrBuild(
        self: *Self,
        workspace_info: *WorkspaceInfo,
        tools: []const Tool,
    ) ![]const u8 {
        // Compute current hashes
        const workspace_context = try workspace_info.formatContext(self.allocator);
        defer self.allocator.free(workspace_context);
        const current_workspace_hash = computeHash(workspace_context);
        
        var tools_buf = std.ArrayList(u8).init(self.allocator);
        defer tools_buf.deinit();
        for (tools) |tool| {
            try tools_buf.appendSlice(tool.name);
            try tools_buf.appendSlice(tool.description);
        }
        const current_tools_hash = computeHash(tools_buf.items);

        // Check if cache is valid
        if (self.isValid(current_workspace_hash, current_tools_hash)) {
            self.cache_hits += 1;
            log.debug("Prompt cache hit (hits: {d}, misses: {d})", .{ self.cache_hits, self.cache_misses });
            return self.stable_prefix.?;
        }

        // Cache miss - rebuild
        self.cache_misses += 1;
        log.debug("Prompt cache miss (hits: {d}, misses: {d})", .{ self.cache_hits, self.cache_misses });
        
        return try self.buildPrefix(workspace_info, tools, current_workspace_hash, current_tools_hash);
    }

    /// Check if cached prefix is still valid
    fn isValid(self: Self, workspace_hash: u32, tools_hash: u32) bool {
        if (self.stable_prefix == null) return false;
        return self.workspace_hash == workspace_hash and self.tools_hash == tools_hash;
    }

    /// Build stable prefix from workspace and tools
    fn buildPrefix(
        self: *Self,
        workspace_info: *WorkspaceInfo,
        tools: []const Tool,
        workspace_hash: u32,
        tools_hash: u32,
    ) ![]const u8 {
        // Free old prefix if exists
        if (self.stable_prefix) |old| {
            self.allocator.free(old);
        }

        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        const writer = buf.writer();

        // System instruction
        try writer.print(
            \\You are kimiz, an AI coding assistant. Help the user with their coding tasks.
            \\
            \\You have access to the following tools:
            \\
        , .{});

        // Tool descriptions
        for (tools) |tool| {
            try writer.print("- {s}: {s}\n", .{ tool.name, tool.description });
        }

        try writer.print("\n", .{});

        // Workspace context
        const workspace_context = try workspace_info.formatContext(self.allocator);
        defer self.allocator.free(workspace_context);
        try writer.print("{s}\n", .{workspace_context});

        // Memory guidelines
        try writer.print(
            \\n            \\n            \\Guidelines:
            \\- Be concise and helpful
            \\- Use tools when appropriate
            \\- Ask clarifying questions if needed
            \\
        , .{});

        // Update cache state
        self.stable_prefix = try buf.toOwnedSlice();
        self.workspace_hash = workspace_hash;
        self.tools_hash = tools_hash;
        self.last_updated = std.time.timestamp();

        return self.stable_prefix.?;
    }

    /// Get cache statistics
    pub fn getStats(self: Self) struct { hits: u64, misses: u64, hit_rate: f64 } {
        const total = self.cache_hits + self.cache_misses;
        const hit_rate = if (total > 0) @as(f64, @floatFromInt(self.cache_hits)) / @as(f64, @floatFromInt(total)) else 0.0;
        return .{
            .hits = self.cache_hits,
            .misses = self.cache_misses,
            .hit_rate = hit_rate,
        };
    }

    /// Invalidate cache (force rebuild on next use)
    pub fn invalidate(self: *Self) void {
        if (self.stable_prefix) |prefix| {
            self.allocator.free(prefix);
            self.stable_prefix = null;
        }
        self.workspace_hash = 0;
        self.tools_hash = 0;
        log.debug("Prompt cache invalidated", .{});
    }
};

/// Provider-specific prompt formatting
pub const PromptFormatter = struct {
    /// Format for OpenAI (system message + user messages)
    pub fn formatOpenAI(
        allocator: std.mem.Allocator,
        stable_prefix: []const u8,
        user_messages: []const core.Message,
    ) ![]const u8 {
        var buf = std.ArrayList(u8).init(allocator);
        defer buf.deinit();
        const writer = buf.writer();

        // OpenAI uses system role for stable prefix
        try writer.print("{{\"role\":\"system\",\"content\":\"{s}\"}},", .{stable_prefix});
        
        // Add user messages
        for (user_messages) |msg| {
            // Format message...
            _ = msg;
        }

        return buf.toOwnedSlice();
    }

    /// Format for Anthropic (system field + messages)
    pub fn formatAnthropic(
        allocator: std.mem.Allocator,
        stable_prefix: []const u8,
        user_messages: []const core.Message,
    ) ![]const u8 {
        _ = allocator;
        _ = stable_prefix;
        _ = user_messages;
        // Anthropic uses separate system field
        return "";
    }
};

// ============================================================================
// Tests
// ============================================================================

test "PromptCache init/deinit" {
    const allocator = std.testing.allocator;
    var cache = PromptCache.init(allocator);
    defer cache.deinit();
    
    try std.testing.expect(cache.stable_prefix == null);
    try std.testing.expectEqual(@as(u64, 0), cache.cache_hits);
    try std.testing.expectEqual(@as(u64, 0), cache.cache_misses);
}

test "PromptCache computeHash" {
    const hash1 = computeHash("test");
    const hash2 = computeHash("test");
    const hash3 = computeHash("different");
    
    try std.testing.expectEqual(hash1, hash2);
    try std.testing.expect(hash1 != hash3);
}

test "PromptCache stats" {
    const allocator = std.testing.allocator;
    var cache = PromptCache.init(allocator);
    defer cache.deinit();
    
    // Simulate some hits and misses
    cache.cache_hits = 8;
    cache.cache_misses = 2;
    
    const stats = cache.getStats();
    try std.testing.expectEqual(@as(u64, 8), stats.hits);
    try std.testing.expectEqual(@as(u64, 2), stats.misses);
    try std.testing.expectApproxEqAbs(@as(f64, 0.8), stats.hit_rate, 0.01);
}
