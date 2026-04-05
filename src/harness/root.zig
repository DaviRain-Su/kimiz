//! kimiz-harness - Harness Engineering Platform
//! Defines and executes agent harnesses

const std = @import("std");

pub const parser = @import("parser.zig");
pub const constraints = @import("constraints.zig");
pub const runtime = @import("runtime.zig");
pub const prompt_cache = @import("prompt_cache.zig");

// Re-export types
pub const Harness = parser.Harness;
pub const Behavior = parser.Behavior;
pub const CommunicationStyle = parser.CommunicationStyle;
pub const ThinkingPreference = parser.ThinkingPreference;
pub const ThinkingLevel = parser.ThinkingLevel;
pub const Constraints = parser.Constraints;
pub const ApprovalTrigger = parser.ApprovalTrigger;
pub const ToolConfig = parser.ToolConfig;
pub const BashConfig = parser.BashConfig;
pub const EditConfig = parser.EditConfig;
pub const Rules = parser.Rules;
pub const Rule = parser.Rule;

pub const ConstraintChecker = constraints.ConstraintChecker;
pub const ConstraintViolation = constraints.ConstraintViolation;
pub const ConstraintType = constraints.ConstraintType;
pub const ValidationResult = constraints.ValidationResult;
pub const ApprovalRequest = constraints.ApprovalRequest;
pub const Action = constraints.Action;
pub const ActionContext = constraints.ActionContext;

pub const HarnessRuntime = runtime.HarnessRuntime;
pub const HarnessInfo = runtime.HarnessInfo;
pub const createFromFile = runtime.createFromFile;
pub const createDefault = runtime.createDefault;

pub const PromptCache = prompt_cache.PromptCache;
pub const PromptFormatter = prompt_cache.PromptFormatter;
pub const ContextTruncator = @import("context_truncation.zig").ContextTruncator;
pub const ContextLimits = @import("context_truncation.zig").ContextLimits;
pub const truncateMessages = @import("context_truncation.zig").truncateMessages;
pub const tool_approval = @import("tool_approval.zig");
pub const ApprovalPolicy = tool_approval.ApprovalPolicy;
pub const ToolRisk = tool_approval.ToolRisk;
pub const ApprovalManager = tool_approval.ApprovalManager;
pub const getToolRisk = tool_approval.getToolRisk;

/// Parse AGENTS.md and create runtime
pub fn loadFromAgentsMd(allocator: std.mem.Allocator, content: []const u8) !HarnessRuntime {
    const harness = try parser.parseAgentsMd(allocator, content);
    return try HarnessRuntime.init(allocator, harness);
}

/// Find and load nearest AGENTS.md
pub fn findAndLoad(allocator: std.mem.Allocator, start_dir: []const u8) !?HarnessRuntime {
    if (try parser.findAndLoad(allocator, start_dir)) |harness| {
        return try HarnessRuntime.init(allocator, harness);
    }
    return null;
}

// ============================================================================
// Tests
// ============================================================================

test "harness module imports" {
    // Just verify all imports work
    _ = Harness;
    _ = ConstraintChecker;
    _ = HarnessRuntime;
}
