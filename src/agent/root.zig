//! kimiz-agent - Agent runtime module
//! Provides tool definitions and agent execution capabilities

const std = @import("std");

pub const tool = @import("tool.zig");
pub const agent = @import("agent.zig");
pub const read_file = @import("tools/read_file.zig");
pub const write_file = @import("tools/write_file.zig");
pub const edit = @import("tools/edit.zig");
pub const grep = @import("tools/grep.zig");
pub const bash = @import("tools/bash.zig");

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

/// Built-in tool registry (5 core tools)
pub const builtin_tools = &[_]AgentTool{};

/// Create a ReadFile tool instance
pub fn createReadFileTool() read_file.ReadFileContext {
    return read_file.ReadFileContext{};
}

/// Create a WriteFile tool instance
pub fn createWriteFileTool() write_file.WriteFileContext {
    return write_file.WriteFileContext{};
}

/// Create an Edit tool instance
pub fn createEditTool() edit.EditContext {
    return edit.EditContext{};
}

/// Create a Grep tool instance
pub fn createGrepTool() grep.GrepContext {
    return grep.GrepContext{};
}

/// Create a Bash tool instance
pub fn createBashTool() bash.BashContext {
    return bash.BashContext{};
}

/// Get all built-in tool definitions (5 core tools)
pub fn getBuiltinToolDefinitions() []const Tool {
    return &[_]Tool{
        read_file.tool_definition,
        write_file.tool_definition,
        edit.tool_definition,
        grep.tool_definition,
        bash.tool_definition,
    };
}
