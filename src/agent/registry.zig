//! Tool Registry - Centralized tool management
//! Aggregates all built-in tools and provides registration/discovery

const std = @import("std");
const tool = @import("tool.zig");
const AgentTool = tool.AgentTool;

// Import all built-in tools
const read_file = @import("tools/read_file.zig");
const write_file = @import("tools/write_file.zig");
const bash = @import("tools/bash.zig");
const glob = @import("tools/glob.zig");
const grep = @import("tools/grep.zig");
const web_search = @import("tools/web_search.zig");
const url_summary = @import("tools/url_summary.zig");

// ============================================================================
// Tool Registry
// ============================================================================

pub const ToolRegistry = struct {
    tools: std.StringHashMap(AgentTool),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .tools = std.StringHashMap(AgentTool).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.tools.deinit();
    }

    /// Register a tool
    pub fn register(self: *Self, agent_tool: AgentTool) !void {
        try self.tools.put(agent_tool.tool.name, agent_tool);
    }

    /// Get a tool by name
    pub fn get(self: *Self, name: []const u8) ?AgentTool {
        return self.tools.get(name);
    }

    /// Get all tool definitions (for LLM API)
    pub fn getAllTools(self: *Self) []const tool.Tool {
        var list = std.ArrayList(tool.Tool).init(self.allocator);
        defer list.deinit();

        var iter = self.tools.valueIterator();
        while (iter.next()) |agent_tool| {
            list.append(agent_tool.tool) catch {};
        }

        return list.toOwnedSlice() catch &[]tool.Tool{};
    }

    /// Get tool names as list
    pub fn getToolNames(self: *Self) [][]const u8 {
        var list = std.ArrayList([]const u8).init(self.allocator);
        defer list.deinit();

        var iter = self.tools.keyIterator();
        while (iter.next()) |key| {
            list.append(key.*) catch {};
        }

        return list.toOwnedSlice() catch &[][]const u8{};
    }

    /// Check if tool exists
    pub fn hasTool(self: *Self, name: []const u8) bool {
        return self.tools.contains(name);
    }

    /// Execute a tool by name
    pub fn execute(
        self: *Self,
        name: []const u8,
        arena: std.mem.Allocator,
        args: std.json.Value,
    ) !tool.ToolResult {
        const agent_tool = self.get(name) orelse return error.ToolNotFound;
        return agent_tool.execute(arena, args);
    }
};

// ============================================================================
// Default Tool Set
// ============================================================================

/// Create a registry with all default tools
pub fn createDefaultRegistry(allocator: std.mem.Allocator) !ToolRegistry {
    var registry = ToolRegistry.init(allocator);

    // ReadFile
    var read_file_ctx = try allocator.create(read_file.ReadFileContext);
    try registry.register(read_file.createAgentTool(read_file_ctx));

    // WriteFile
    var write_file_ctx = try allocator.create(write_file.WriteFileContext);
    try registry.register(write_file.createAgentTool(write_file_ctx));

    // Bash
    var bash_ctx = try allocator.create(bash.BashContext);
    try registry.register(bash.createAgentTool(bash_ctx));

    // Glob
    var glob_ctx = try allocator.create(glob.GlobContext);
    try registry.register(glob.createAgentTool(glob_ctx));

    // Grep
    var grep_ctx = try allocator.create(grep.GrepContext);
    try registry.register(grep.createAgentTool(grep_ctx));

    // WebSearch
    var web_search_ctx = try allocator.create(web_search.WebSearchContext);
    try registry.register(web_search.createAgentTool(web_search_ctx));

    // URLSummary
    var url_summary_ctx = try allocator.create(url_summary.URLSummaryContext);
    try registry.register(url_summary.createAgentTool(url_summary_ctx));

    return registry;
}

// ============================================================================
// Plan Mode - Read-only Tools
// ============================================================================

const READONLY_TOOLS = [_][]const u8{
    "read_file",
    "glob",
    "grep",
    "web_search",
    "url_summary",
};

/// Filter tools for Plan Mode (read-only)
pub fn filterPlanModeTools(all_tools: []const tool.Tool) []const tool.Tool {
    var result: []const tool.Tool = &.{};
    for (all_tools) |t| {
        for (READONLY_TOOLS) |name| {
            if (std.mem.eql(u8, t.name, name)) {
                // Append to result (simplified - in real code use allocator)
                break;
            }
        }
    }
    return result;
}

/// Check if a tool is read-only (safe for Plan Mode)
pub fn isReadOnlyTool(name: []const u8) bool {
    for (READONLY_TOOLS) |readonly| {
        if (std.mem.eql(u8, name, readonly)) return true;
    }
    return false;
}

// ============================================================================
// Tests
// ============================================================================

test "ToolRegistry basic operations" {
    const allocator = std.testing.allocator;
    var registry = ToolRegistry.init(allocator);
    defer registry.deinit();

    // Create a test tool
    const TestCtx = struct {};
    var ctx = try allocator.create(TestCtx);
    const test_tool = tool.AgentTool{
        .tool = tool.Tool{
            .name = "test_tool",
            .description = "A test tool",
            .parameters_json = "{}",
        },
        .execute_fn = struct {
            fn exec(_: *anyopaque, arena: std.mem.Allocator, _: std.json.Value) anyerror!tool.ToolResult {
                return tool.textContent(arena, "test result");
            }
        }.exec,
        .ctx = ctx,
    };

    try registry.register(test_tool);

    // Test get
    const retrieved = registry.get("test_tool");
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualStrings("test_tool", retrieved.?.tool.name);

    // Test has
    try std.testing.expect(registry.hasTool("test_tool"));
    try std.testing.expect(!registry.hasTool("nonexistent"));
}

test "isReadOnlyTool" {
    try std.testing.expect(isReadOnlyTool("read_file"));
    try std.testing.expect(isReadOnlyTool("glob"));
    try std.testing.expect(!isReadOnlyTool("write_file"));
    try std.testing.expect(!isReadOnlyTool("bash"));
}
