//! Agent Tool Definitions
//! Following the architecture from docs/03-technical-spec.md

const std = @import("std");
const core = @import("../core/root.zig");

/// Tool definition for LLM tool calling
/// Re-export from core module for consistency
pub const Tool = core.Tool;

/// Content block for user messages
pub const UserContentBlock = union(enum) {
    text: []const u8,
    image: []const u8, // base64 encoded
    image_url: struct {
        url: []const u8,
        detail: ?[]const u8 = null,
    },
};

/// Tool execution result
pub const ToolResult = struct {
    content: []const UserContentBlock,
    is_error: bool,
};

/// AgentTool wraps a Tool with execution capability
/// From technical spec Section 16
pub const AgentTool = struct {
    tool: Tool,

    /// Tool execution function
    /// args: parsed JSON arguments
    /// arena: allocator for return values
    execute_fn: *const fn (
        ctx: *anyopaque,
        arena: std.mem.Allocator,
        args: std.json.Value,
    ) anyerror!ToolResult,

    ctx: *anyopaque,

    /// Execute the tool with given arguments
    pub fn execute(
        self: *const AgentTool,
        arena: std.mem.Allocator,
        args: std.json.Value,
    ) !ToolResult {
        return self.execute_fn(self.ctx, arena, args);
    }
};

/// Tool execution error types
pub const ToolError = error{
    InvalidArguments,
    ExecutionFailed,
    NetworkError,
    ParseError,
    OutOfMemory,
};

/// Parse tool arguments from JSON Value
pub fn parseArguments(
    allocator: std.mem.Allocator,
    args: std.json.Value,
    comptime T: type,
) !T {
    return std.json.parseFromValueLeaky(
        T,
        allocator,
        args,
        .{ .ignore_unknown_fields = true },
    );
}

/// Create text content block
pub fn textContent(arena: std.mem.Allocator, text: []const u8) !ToolResult {
    const content = try arena.dupe(u8, text);
    const blocks = try arena.alloc(UserContentBlock, 1);
    blocks[0] = .{ .text = content };
    return ToolResult{
        .content = blocks,
        .is_error = false,
    };
}

/// Create error result
pub fn errorResult(arena: std.mem.Allocator, err_msg: []const u8) !ToolResult {
    const content = try arena.dupe(u8, err_msg);
    const blocks = try arena.alloc(UserContentBlock, 1);
    blocks[0] = .{ .text = content };
    return ToolResult{
        .content = blocks,
        .is_error = true,
    };
}
