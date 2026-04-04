//! kimiz-agent - Agent runtime module
//! Provides tool definitions and agent execution capabilities

const std = @import("std");

pub const tool = @import("tool.zig");
pub const url_summary = @import("tools/url_summary.zig");

// Re-export common types
pub const Tool = tool.Tool;
pub const AgentTool = tool.AgentTool;
pub const ToolResult = tool.ToolResult;
pub const ToolError = tool.ToolError;
pub const UserContentBlock = tool.UserContentBlock;

/// Built-in tool registry
/// This array contains all available built-in tools
pub const builtin_tools = &[_]AgentTool{
    // URL Summary tool instance
    // Can be registered with createAgentTool(&.{})
};

/// Create a URL Summary tool instance
pub fn createUrlSummaryTool() url_summary.UrlSummaryContext {
    return url_summary.UrlSummaryContext{};
}
