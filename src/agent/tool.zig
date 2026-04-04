//! Agent Tool Definitions
//! Following the architecture from docs/03-technical-spec.md

const std = @import("std");

/// Tool definition for LLM tool calling
/// Matches the Tool struct from technical spec Section 3.7
pub const Tool = struct {
    name: []const u8,
    description: []const u8,
    parameters_json: []const u8, // JSON schema string
};

/// Content block for user messages
pub const UserContentBlock = union(enum) {
    text: []const u8,
    image: []const u8, // base64 encoded
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
    args: std.json.Value,
    comptime T: type,
) !T {
    const parsed = try std.json.parseFromValue(
        T,
        std.heap.page_allocator,
        args,
        .{ .ignore_unknown_fields = true },
    );
    return parsed.value;
}

/// Create text content block
pub fn textContent(arena: std.mem.Allocator, text: []const u8) !ToolResult {
    const content = try arena.dupe(u8, text);
    return ToolResult{
        .content = &[_]UserContentBlock{.{ .text = content }},
        .is_error = false,
    };
}

/// Create error result
pub fn errorResult(arena: std.mem.Allocator, err_msg: []const u8) !ToolResult {
    const content = try arena.dupe(u8, err_msg);
    return ToolResult{
        .content = &[_]UserContentBlock{.{ .text = content }},
        .is_error = true,
    };
}
