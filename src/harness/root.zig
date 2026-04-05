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

// Reasoning Trace
pub const reasoning_trace = @import("reasoning_trace.zig");
pub const Trace = reasoning_trace.Trace;
pub const ReasoningStep = reasoning_trace.ReasoningStep;
pub const TraceManager = reasoning_trace.TraceManager;

// Phase 2/3 Core Modules
// Resource Limits - FEAT-013
pub const resource_limits = @import("resource_limits.zig");
pub const ResourceLimits = resource_limits.ResourceLimits;
pub const ResourceUsage = resource_limits.ResourceUsage;
pub const ResourceTracker = resource_limits.ResourceTracker;
pub const LimitCheckResult = resource_limits.LimitCheckResult;
pub const LimitViolation = resource_limits.LimitViolation;
pub const LimitType = resource_limits.LimitType;

// Knowledge Base - FEAT-014
pub const knowledge_base = @import("knowledge_base.zig");
pub const KnowledgeBase = knowledge_base.KnowledgeBase;
pub const KnowledgeSection = knowledge_base.KnowledgeSection;
pub const findAgentsMd = knowledge_base.findAgentsMd;
pub const loadNearest = knowledge_base.loadNearest;

// Agent Linter - FEAT-015
pub const agent_linter = @import("agent_linter.zig");
pub const Linter = agent_linter.Linter;
pub const LintResult = agent_linter.LintResult;
pub const LintIssue = agent_linter.LintIssue;
pub const Severity = agent_linter.Severity;
pub const ValidationRule = agent_linter.ValidationRule;
pub const OutputType = agent_linter.OutputType;
pub const lintOutput = agent_linter.lintOutput;

// Slop Collector - FEAT-016
pub const slop_collector = @import("slop_collector.zig");
pub const SlopCollector = slop_collector.SlopCollector;
pub const SlopAnalysis = slop_collector.SlopAnalysis;
pub const SlopEntry = slop_collector.SlopEntry;
pub const SlopLevel = slop_collector.SlopLevel;
pub const SlopPattern = slop_collector.SlopPattern;
pub const checkQuality = slop_collector.checkQuality;

// Self Review - FEAT-017
pub const self_review = @import("self_review.zig");
pub const SelfReview = self_review.SelfReview;
pub const SelfReviewResult = self_review.SelfReviewResult;
pub const ReviewFinding = self_review.ReviewFinding;
pub const ImprovementSuggestion = self_review.ImprovementSuggestion;
pub const ReviewConfig = self_review.ReviewConfig;
pub const FindingSeverity = self_review.FindingSeverity;

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
    
    // Phase 2/3 modules
    _ = ResourceLimits;
    _ = ResourceTracker;
    _ = KnowledgeBase;
    _ = Linter;
    _ = SlopCollector;
    _ = SelfReview;
}
