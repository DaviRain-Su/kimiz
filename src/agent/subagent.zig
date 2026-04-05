//! Subagent Delegation Module - FEAT-011
//! Provides subagent spawning with depth tracking, read-only mode, and step limiting

const std = @import("std");
const agent_mod = @import("agent.zig");
const tool = @import("tool.zig");
const Agent = agent_mod.Agent;
const AgentOptions = agent_mod.AgentOptions;
const Tool = tool.Tool;
const AgentTool = tool.AgentTool;
const ToolResult = tool.ToolResult;
const UserContentBlock = tool.UserContentBlock;

// ============================================================================
// Error Types
// ============================================================================

pub const SubAgentError = error{
    MaxDepthExceeded,
    MaxStepsExceeded,
    ReadOnlyViolation,
    ParentAgentNotFound,
    TaskExecutionFailed,
    InvalidConfiguration,
    OutOfMemory,
};

// ============================================================================
// Safe Tool Registry for Read-Only Mode
// ============================================================================

/// List of safe tools that can be used in read-only mode
pub const SAFE_TOOLS = &[_][]const u8{
    "read_file",
    "glob",
    "grep",
};

/// Check if a tool is safe for read-only mode
fn isSafeTool(tool_name: []const u8) bool {
    for (SAFE_TOOLS) |safe_tool| {
        if (std.mem.eql(u8, tool_name, safe_tool)) {
            return true;
        }
    }
    return false;
}

/// Filter tools for read-only mode
fn filterReadOnlyTools(allocator: std.mem.Allocator, tools: []const AgentTool) ![]AgentTool {
    var filtered: std.ArrayList(AgentTool) = .empty;
    errdefer filtered.deinit(allocator);

    for (tools) |t| {
        if (isSafeTool(t.tool.name)) {
            try filtered.append(allocator, t);
        }
    }

    return filtered.toOwnedSlice(allocator);
}

// ============================================================================
// SubAgent Structure
// ============================================================================

/// SubAgent configuration options
pub const SubAgentConfig = struct {
    max_depth: u32 = 3,
    max_steps: u32 = 50,
    read_only: bool = false,
    inherit_parent_tools: bool = true,
    custom_tools: []const AgentTool = &.{},
};

/// SubAgent for delegated task execution
/// Tracks depth to prevent infinite recursion and supports read-only mode
pub const SubAgent = struct {
    allocator: std.mem.Allocator,
    parent: ?*Agent,
    depth: u32,
    max_depth: u32,
    max_steps: u32,
    read_only: bool,
    options: AgentOptions,
    agent: ?Agent,
    step_count: u32,
    config: SubAgentConfig,

    const Self = @This();

    /// Initialize a new SubAgent
    /// 
    /// Parameters:
    ///   - allocator: Memory allocator for the subagent
    ///   - parent: Optional parent agent reference for depth tracking
    ///   - options: AgentOptions for the underlying agent
    ///   - config: SubAgent-specific configuration
    ///
    /// Returns: Initialized SubAgent or error
    pub fn init(
        allocator: std.mem.Allocator,
        parent: ?*Agent,
        options: AgentOptions,
        config: SubAgentConfig,
    ) SubAgentError!Self {
        // Calculate depth based on parent
        const depth = if (parent) |p| p.iteration_count + 1 else 0;

        // Check max depth constraint
        if (depth > config.max_depth) {
            return SubAgentError.MaxDepthExceeded;
        }

        // Prepare tools based on read-only mode
        var final_tools: []AgentTool = undefined;
        var tools_owned = false;

        if (config.read_only) {
            // Filter to only safe tools
            final_tools = filterReadOnlyTools(allocator, options.tools) catch {
                return SubAgentError.OutOfMemory;
            };
            tools_owned = true;
        } else {
            final_tools = @constCast(options.tools);
        }

        // Create modified options with filtered tools
        var sub_options = options;
        sub_options.tools = final_tools;
        sub_options.max_iterations = config.max_steps;

        return .{
            .allocator = allocator,
            .parent = parent,
            .depth = depth,
            .max_depth = config.max_depth,
            .max_steps = config.max_steps,
            .read_only = config.read_only,
            .options = sub_options,
            .agent = null,
            .step_count = 0,
            .config = config,
        };
    }

    /// Clean up SubAgent resources
    pub fn deinit(self: *Self) void {
        // Clean up owned tools array if we allocated it
        if (self.read_only and self.options.tools.len > 0) {
            self.allocator.free(self.options.tools);
        }

        // Clean up the inner agent if initialized
        if (self.agent) |*agent| {
            agent.deinit();
        }
    }

    /// Run the subagent with a specific task
    /// 
    /// Parameters:
    ///   - task: The task description/prompt for the subagent
    ///
    /// Returns: Task result as a string (caller owns memory)
    pub fn run(self: *Self, task: []const u8) SubAgentError![]const u8 {
        // Check step limit
        if (self.step_count >= self.max_steps) {
            return SubAgentError.MaxStepsExceeded;
        }

        // Initialize the inner agent if not already done
        if (self.agent == null) {
            self.agent = Agent.init(self.allocator, self.options) catch {
                return SubAgentError.OutOfMemory;
            };
        }

        // Execute the task
        self.step_count += 1;

        // Run the agent loop with the task
        self.agent.?.prompt(task) catch {
            return SubAgentError.TaskExecutionFailed;
        };

        // Collect results from the agent's messages
        const result = self.collectResult() catch {
            return SubAgentError.TaskExecutionFailed;
        };

        return result;
    }

    /// Collect the result from the agent's conversation
    fn collectResult(self: *Self) ![]const u8 {
        const messages = self.agent.?.getMessages();

        if (messages.len == 0) {
            return try self.allocator.dupe(u8, "No response generated");
        }

        // Find the last assistant message
        var i: usize = messages.len;
        while (i > 0) {
            i -= 1;
            const msg = messages[i];
            switch (msg) {
                .assistant => |assistant| {
                    // Extract text content from assistant message
                    var result_text: std.ArrayList(u8) = .empty;
                    defer result_text.deinit(self.allocator);

                    for (assistant.content) |block| {
                        switch (block) {
                            .text => |text| {
                                try result_text.appendSlice(self.allocator, text.text);
                            },
                            else => {},
                        }
                    }

                    return result_text.toOwnedSlice(self.allocator);
                },
                else => {},
            }
        }

        return try self.allocator.dupe(u8, "No assistant response found");
    }

    /// Check if the subagent can delegate to another subagent
    pub fn canDelegate(self: *const Self) bool {
        return self.depth < self.max_depth;
    }

    /// Get remaining steps
    pub fn getRemainingSteps(self: *const Self) u32 {
        return self.max_steps - self.step_count;
    }

    /// Check if in read-only mode
    pub fn isReadOnly(self: *const Self) bool {
        return self.read_only;
    }
};

// ============================================================================
// Delegate Tool Definition
// ============================================================================

pub const TOOL_NAME = "delegate";

const TOOL_DESCRIPTION =
    \\Delegates a task to a subagent with optional constraints.
    \\The subagent runs with depth tracking to prevent infinite recursion.
    \\In read-only mode, only safe tools (read_file, glob, grep) are available.
    \\Example: {"task": "Analyze code structure", "read_only": true, "max_steps": 30}
;

const PARAMETERS_SCHEMA =
    \\{
    \\  "type": "object",
    \\  "required": ["task"],
    \\  "properties": {
    \\    "task": {
    \\      "type": "string",
    \\      "description": "The task description to delegate to the subagent"
    \\    },
    \\    "read_only": {
    \\      "type": "boolean",
    \\      "description": "If true, subagent can only use read-only tools (default: false)"
    \\    },
    \\    "max_steps": {
    \\      "type": "integer",
    \\      "description": "Maximum number of steps the subagent can take (default: 50)"
    \\    },
    \\    "max_depth": {
    \\      "type": "integer",
    \\      "description": "Maximum delegation depth (default: 3)"
    \\    }
    \\  }
    \\}
;

/// Tool definition for the delegate tool
pub const definition = Tool{
    .name = TOOL_NAME,
    .description = TOOL_DESCRIPTION,
    .parameters_json = PARAMETERS_SCHEMA,
};

/// Context for the delegate tool execution
pub const DelegateContext = struct {
    allocator: std.mem.Allocator,
    parent_agent: ?*Agent,
    base_options: AgentOptions,
};

/// Create an AgentTool wrapper for the delegate tool
pub fn createAgentTool(ctx: *DelegateContext) AgentTool {
    return AgentTool{
        .tool = definition,
        .execute_fn = execute,
        .ctx = ctx,
    };
}

/// Delegate tool arguments
const DelegateArgs = struct {
    task: []const u8,
    read_only: bool = false,
    max_steps: u32 = 50,
    max_depth: u32 = 3,
};

/// Execute the delegate tool
fn execute(
    ctx: *anyopaque,
    arena: std.mem.Allocator,
    args: std.json.Value,
) anyerror!ToolResult {
    const delegate_ctx = @as(*DelegateContext, @ptrCast(@alignCast(ctx)));

    // Parse arguments
    const parsed_args = tool.parseArguments(arena, args, DelegateArgs) catch {
        return tool.errorResult(arena, "Invalid arguments: expected {\"task\": \"...\", \"read_only\": true/false, \"max_steps\": N, \"max_depth\": N}");
    };

    if (parsed_args.task.len == 0) {
        return tool.errorResult(arena, "Task cannot be empty");
    }

    // Validate constraints
    if (parsed_args.max_steps == 0 or parsed_args.max_steps > 1000) {
        return tool.errorResult(arena, "max_steps must be between 1 and 1000");
    }

    if (parsed_args.max_depth == 0 or parsed_args.max_depth > 10) {
        return tool.errorResult(arena, "max_depth must be between 1 and 10");
    }

    // Create subagent configuration
    const config = SubAgentConfig{
        .max_depth = parsed_args.max_depth,
        .max_steps = parsed_args.max_steps,
        .read_only = parsed_args.read_only,
        .inherit_parent_tools = true,
    };

    // Initialize subagent
    var subagent = SubAgent.init(
        delegate_ctx.allocator,
        delegate_ctx.parent_agent,
        delegate_ctx.base_options,
        config,
    ) catch |err| {
        const err_msg = try std.fmt.allocPrint(arena, "Failed to initialize subagent: {s}", .{@errorName(err)});
        return tool.errorResult(arena, err_msg);
    };
    defer subagent.deinit();

    // Check if delegation is allowed
    if (!subagent.canDelegate()) {
        return tool.errorResult(arena, "Maximum delegation depth exceeded");
    }

    // Run the subagent
    const result = subagent.run(parsed_args.task) catch |err| {
        const err_msg = try std.fmt.allocPrint(arena, "Subagent execution failed: {s}", .{@errorName(err)});
        return tool.errorResult(arena, err_msg);
    };
    defer delegate_ctx.allocator.free(result);

    // Return the result
    return tool.textContent(arena, result);
}

// ============================================================================
// Tests
// ============================================================================

test "SubAgent init/deinit" {
    const allocator = std.testing.allocator;

    const model = @import("../core/root.zig").Model{
        .id = "gpt-4o-mini",
        .provider = .{ .known = .openai },
        .api = .{ .known = .@"openai-completions" },
        .context_window = 128000,
        .max_tokens = 4096,
        .cost = .{
            .input_token_cost = 0.15,
            .output_token_cost = 0.60,
        },
    };

    const options = AgentOptions{
        .model = model,
        .tools = &.{},
        .max_iterations = 50,
    };

    const config = SubAgentConfig{
        .max_depth = 3,
        .max_steps = 50,
        .read_only = false,
    };

    var subagent = try SubAgent.init(allocator, null, options, config);
    defer subagent.deinit();

    try std.testing.expectEqual(@as(u32, 0), subagent.depth);
    try std.testing.expectEqual(@as(u32, 3), subagent.max_depth);
    try std.testing.expectEqual(@as(u32, 50), subagent.max_steps);
    try std.testing.expect(!subagent.read_only);
}

test "SubAgent depth tracking" {
    const allocator = std.testing.allocator;

    const model = @import("../core/root.zig").Model{
        .id = "gpt-4o-mini",
        .provider = .{ .known = .openai },
        .api = .{ .known = .@"openai-completions" },
        .context_window = 128000,
        .max_tokens = 4096,
        .cost = .{
            .input_token_cost = 0.15,
            .output_token_cost = 0.60,
        },
    };

    const options = AgentOptions{
        .model = model,
        .tools = &.{},
        .max_iterations = 50,
    };

    // Test max depth exceeded
    const config = SubAgentConfig{
        .max_depth = 0,
        .max_steps = 50,
        .read_only = false,
    };

    const result = SubAgent.init(allocator, null, options, config);
    try std.testing.expectError(SubAgentError.MaxDepthExceeded, result);
}

test "Safe tool filtering" {
    const allocator = std.testing.allocator;

    // Create mock tools for testing
    const mock_tool_1 = AgentTool{
        .tool = Tool{
            .name = "read_file",
            .description = "Read a file",
            .parameters_json = "{}",
        },
        .execute_fn = undefined,
        .ctx = undefined,
    };

    const mock_tool_2 = AgentTool{
        .tool = Tool{
            .name = "write_file",
            .description = "Write a file",
            .parameters_json = "{}",
        },
        .execute_fn = undefined,
        .ctx = undefined,
    };

    const mock_tool_3 = AgentTool{
        .tool = Tool{
            .name = "grep",
            .description = "Search files",
            .parameters_json = "{}",
        },
        .execute_fn = undefined,
        .ctx = undefined,
    };

    const tools = &[_]AgentTool{ mock_tool_1, mock_tool_2, mock_tool_3 };

    const filtered = try filterReadOnlyTools(allocator, tools);
    defer allocator.free(filtered);

    // Should only have read_file and grep
    try std.testing.expectEqual(@as(usize, 2), filtered.len);
    try std.testing.expectEqualStrings("read_file", filtered[0].tool.name);
    try std.testing.expectEqualStrings("grep", filtered[1].tool.name);
}

test "isSafeTool" {
    try std.testing.expect(isSafeTool("read_file"));
    try std.testing.expect(isSafeTool("glob"));
    try std.testing.expect(isSafeTool("grep"));
    try std.testing.expect(!isSafeTool("write_file"));
    try std.testing.expect(!isSafeTool("edit"));
    try std.testing.expect(!isSafeTool("bash"));
}

test "Delegate tool definition" {
    try std.testing.expectEqualStrings("delegate", definition.name);
    try std.testing.expect(definition.description.len > 0);
    try std.testing.expect(definition.parameters_json.len > 0);
}

test "SubAgent canDelegate" {
    const allocator = std.testing.allocator;

    const model = @import("../core/root.zig").Model{
        .id = "gpt-4o-mini",
        .provider = .{ .known = .openai },
        .api = .{ .known = .@"openai-completions" },
        .context_window = 128000,
        .max_tokens = 4096,
        .cost = .{
            .input_token_cost = 0.15,
            .output_token_cost = 0.60,
        },
    };

    const options = AgentOptions{
        .model = model,
        .tools = &.{},
        .max_iterations = 50,
    };

    const config = SubAgentConfig{
        .max_depth = 3,
        .max_steps = 50,
        .read_only = false,
    };

    var subagent = try SubAgent.init(allocator, null, options, config);
    defer subagent.deinit();

    try std.testing.expect(subagent.canDelegate());
    try std.testing.expectEqual(@as(u32, 50), subagent.getRemainingSteps());
}

test "SubAgentConfig defaults" {
    const config = SubAgentConfig{};

    try std.testing.expectEqual(@as(u32, 3), config.max_depth);
    try std.testing.expectEqual(@as(u32, 50), config.max_steps);
    try std.testing.expect(!config.read_only);
    try std.testing.expect(config.inherit_parent_tools);
    try std.testing.expectEqual(@as(usize, 0), config.custom_tools.len);
}
