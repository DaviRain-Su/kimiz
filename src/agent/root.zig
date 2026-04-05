//! kimiz-agent - Agent runtime module
//! Provides tool definitions and agent execution capabilities

const std = @import("std");

pub const tool = @import("tool.zig");
pub const agent = @import("agent.zig");
pub const url_summary = @import("tools/url_summary.zig");
pub const read_file = @import("tools/read_file.zig");
pub const write_file = @import("tools/write_file.zig");
pub const glob = @import("tools/glob.zig");
pub const grep = @import("tools/grep.zig");
pub const bash = @import("tools/bash.zig");
pub const web_search = @import("tools/web_search.zig");

// Re-export common types
pub const Tool = tool.Tool;
pub const AgentTool = tool.AgentTool;
pub const ToolResult = tool.ToolResult;
pub const ToolError = tool.ToolError;
pub const UserContentBlock = tool.UserContentBlock;

// Re-export Agent types
pub const Agent = agent.Agent;
pub const AgentOptions = agent.AgentOptions;
pub const AgentState = agent.AgentState;
pub const AgentEvent = agent.AgentEvent;

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

/// Create a ReadFile tool instance
pub fn createReadFileTool() read_file.ReadFileContext {
    return read_file.ReadFileContext{};
}

/// Create a WriteFile tool instance
pub fn createWriteFileTool() write_file.WriteFileContext {
    return write_file.WriteFileContext{};
}

/// Create a Glob tool instance
pub fn createGlobTool() glob.GlobContext {
    return glob.GlobContext{};
}

/// Create a Grep tool instance
pub fn createGrepTool() grep.GrepContext {
    return grep.GrepContext{};
}

/// Create a Bash tool instance
pub fn createBashTool() bash.BashContext {
    return bash.BashContext{};
}

/// Create a WebSearch tool instance
pub fn createWebSearchTool() web_search.WebSearchContext {
    return web_search.WebSearchContext{};
}

/// Get all built-in tool definitions
pub fn getBuiltinToolDefinitions() []const Tool {
    return &[_]Tool{
        url_summary.tool_definition,
        read_file.tool_definition,
        write_file.tool_definition,
        glob.tool_definition,
        grep.tool_definition,
        bash.tool_definition,
        web_search.tool_definition,
    };
}
