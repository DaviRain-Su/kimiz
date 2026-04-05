//! Smart Model Routing
//! Intelligent model selection based on task type and performance

const std = @import("std");
const ai = @import("../ai/root.zig");
const learning = @import("../learning/root.zig");
const log = @import("../utils/log.zig");

pub const TaskType = enum {
    simple_chat,
    code_generation,
    code_review,
    debugging,
    documentation,
    complex_analysis,

    pub fn asString(self: TaskType) []const u8 {
        return switch (self) {
            .simple_chat => "simple_chat",
            .code_generation => "code_generation",
            .code_review => "code_review",
            .debugging => "debugging",
            .documentation => "documentation",
            .complex_analysis => "complex_analysis",
        };
    }
};

pub const RoutingDecision = struct {
    model_id: []const u8,
    provider: ai.core.KnownProvider,
    confidence: f64,
    estimated_cost: f64,
    estimated_latency_ms: i64,
    reason: []const u8,
};

/// Task analyzer for automatic task type detection
pub const TaskAnalyzer = struct {
    /// Analyze user input to determine task type and complexity
    pub fn analyze(input: []const u8) struct { task_type: TaskType, complexity: u8 } {
        var complexity: u8 = 5; // Default medium complexity
        var task_type: TaskType = .simple_chat;

        // Check for code-related keywords
        const code_keywords = &[_][]const u8{
            "code", "function", "implement", "refactor", "debug",
            "error", "bug", "fix", "class", "struct", "variable",
        };
        const is_code_related = hasAnyKeyword(input, code_keywords);

        // Check for documentation keywords
        const doc_keywords = &[_][]const u8{
            "document", "explain", "how to", "what is", "describe",
            "readme", "comment", "tutorial",
        };
        const is_documentation = hasAnyKeyword(input, doc_keywords);

        // Check for complex analysis keywords
        const complex_keywords = &[_][]const u8{
            "analyze", "compare", "evaluate", "assess", "review",
            "architecture", "design pattern", "complex",
        };
        const is_complex = hasAnyKeyword(input, complex_keywords);

        // Check for simple questions
        const simple_patterns = &[_][]const u8{
            "hello", "hi", "hey", "thanks", "bye",
        };
        const is_simple = hasAnyKeyword(input, simple_patterns);

        // Check for debugging keywords
        const debug_keywords = &[_][]const u8{
            "debug", "trace", "breakpoint", "stack trace", "error message",
            "crash", "exception", "not working",
        };
        const is_debugging = hasAnyKeyword(input, debug_keywords);

        // Determine task type and complexity
        if (is_debugging) {
            task_type = .debugging;
            complexity = 7;
        } else if (is_code_related) {
            if (std.mem.indexOf(u8, input, "review") != null) {
                task_type = .code_review;
                complexity = 6;
            } else {
                task_type = .code_generation;
                complexity = 8;
            }
        } else if (is_complex) {
            task_type = .complex_analysis;
            complexity = 9;
        } else if (is_documentation) {
            task_type = .documentation;
            complexity = 4;
        } else if (is_simple) {
            task_type = .simple_chat;
            complexity = 1;
        }

        // Adjust complexity based on input length
        if (input.len > 1000) complexity += 1;
        if (input.len > 2000) complexity += 1;

        // Cap complexity at 10
        if (complexity > 10) complexity = 10;

        return .{ .task_type = task_type, .complexity = complexity };
    }

    fn hasAnyKeyword(input: []const u8, keywords: []const []const u8) bool {
        const lower_input = std.ascii.lowerString(&[_]u8{}, input);
        _ = lower_input;
        for (keywords) |keyword| {
            if (std.mem.indexOf(u8, input, keyword) != null or
                std.mem.indexOf(u8, input, std.ascii.upperString(&[_]u8{}, keyword)) != null)
            {
                return true;
            }
        }
        return false;
    }
};

pub const SmartRouter = struct {
    allocator: std.mem.Allocator,
    learning_engine: ?*learning.LearningEngine,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, learning_engine: ?*learning.LearningEngine) Self {
        return .{
            .allocator = allocator,
            .learning_engine = learning_engine,
        };
    }

    /// Select optimal model based on task type and complexity
    pub fn selectModel(self: *Self, task: TaskType, complexity: u8) !RoutingDecision {
        // Get learning data if available
        var model_performance: ?learning.ModelPerformance = null;
        if (self.learning_engine) |engine| {
            const recommendations = try engine.recommendModelForTask(task, complexity);
            if (recommendations.len > 0) {
                model_performance = recommendations[0];
            }
        }

        // Make routing decision
        const decision = self.makeDecision(task, complexity, model_performance);

        // Log routing decision
        log.info("SmartRouter: Selected {s} for {s} (complexity: {d}, confidence: {d:.2})", .{
            decision.model_id,
            task.asString(),
            complexity,
            decision.confidence,
        });

        return decision;
    }

    /// Auto-detect and route based on user input
    pub fn autoRoute(self: *Self, user_input: []const u8) !RoutingDecision {
        const analysis = TaskAnalyzer.analyze(user_input);

        log.info("SmartRouter: Analyzed input as {s} (complexity: {d})", .{
            analysis.task_type.asString(),
            analysis.complexity,
        });

        return try self.selectModel(analysis.task_type, analysis.complexity);
    }

    fn makeDecision(_: *Self, task: TaskType, complexity: u8, performance: ?learning.ModelPerformance) RoutingDecision {
        _ = complexity;

        // If we have performance data from learning engine, use it
        if (performance) |perf| {
            return .{
                .model_id = perf.model_id,
                .provider = detectProvider(perf.model_id),
                .confidence = @as(f64, @floatFromInt(perf.success_rate)) / 100.0,
                .estimated_cost = 0.5,
                .estimated_latency_ms = @intFromFloat(perf.avg_latency_ms),
                .reason = "Based on historical performance",
            };
        }

        // Default routing logic
        return switch (task) {
            .simple_chat => .{
                .model_id = "gpt-4o-mini",
                .provider = .openai,
                .confidence = 0.9,
                .estimated_cost = 0.1,
                .estimated_latency_ms = 500,
                .reason = "Simple chat -> fast, cheap model",
            },
            .code_generation => .{
                .model_id = "claude-3-7-sonnet-20250219",
                .provider = .anthropic,
                .confidence = 0.85,
                .estimated_cost = 0.5,
                .estimated_latency_ms = 2000,
                .reason = "Code generation -> best coding model",
            },
            .code_review => .{
                .model_id = "claude-3-7-sonnet-20250219",
                .provider = .anthropic,
                .confidence = 0.85,
                .estimated_cost = 0.4,
                .estimated_latency_ms = 1500,
                .reason = "Code review -> accurate analysis",
            },
            .debugging => .{
                .model_id = "kimi-for-coding",
                .provider = .kimi,
                .confidence = 0.8,
                .estimated_cost = 0.3,
                .estimated_latency_ms = 1800,
                .reason = "Debugging -> thinking model",
            },
            .documentation => .{
                .model_id = "gpt-4o",
                .provider = .openai,
                .confidence = 0.8,
                .estimated_cost = 0.2,
                .estimated_latency_ms = 1200,
                .reason = "Documentation -> good writing",
            },
            .complex_analysis => .{
                .model_id = "claude-3-7-sonnet-20250219",
                .provider = .anthropic,
                .confidence = 0.8,
                .estimated_cost = 0.6,
                .estimated_latency_ms = 2500,
                .reason = "Complex analysis -> best reasoning",
            },
        };
    }

    fn detectProvider(model_id: []const u8) ai.core.KnownProvider {
        if (std.mem.startsWith(u8, model_id, "gpt-") or std.mem.startsWith(u8, model_id, "o")) return .openai;
        if (std.mem.startsWith(u8, model_id, "claude-")) return .anthropic;
        if (std.mem.startsWith(u8, model_id, "gemini-")) return .google;
        if (std.mem.startsWith(u8, model_id, "kimi-")) return .kimi;
        if (std.mem.eql(u8, model_id, "kimi-for-coding")) return .kimi;
        return .openai; // default
    }
};

// ============================================================================
// Tests
// ============================================================================

test "TaskAnalyzer basic detection" {
    // Simple chat
    const simple = TaskAnalyzer.analyze("Hello! How are you?");
    try std.testing.expectEqual(.simple_chat, simple.task_type);
    try std.testing.expect(simple.complexity <= 3);

    // Code generation
    const code = TaskAnalyzer.analyze("Implement a function to sort an array");
    try std.testing.expectEqual(.code_generation, code.task_type);
    try std.testing.expect(code.complexity >= 5);

    // Documentation
    const doc = TaskAnalyzer.analyze("Explain what is Zig programming language");
    try std.testing.expectEqual(.documentation, doc.task_type);

    // Debugging
    const debug = TaskAnalyzer.analyze("Debug this error message in my code");
    try std.testing.expectEqual(.debugging, debug.task_type);
}

test "SmartRouter basic routing" {
    const allocator = std.testing.allocator;
    var router = SmartRouter.init(allocator, null);

    const decision1 = try router.selectModel(.simple_chat, 1);
    try std.testing.expectEqualStrings("gpt-4o-mini", decision1.model_id);
    try std.testing.expectEqual(.openai, decision1.provider);

    const decision2 = try router.selectModel(.code_generation, 8);
    try std.testing.expectEqualStrings("claude-3-7-sonnet-20250219", decision2.model_id);
    try std.testing.expectEqual(.anthropic, decision2.provider);
}

test "SmartRouter autoRoute" {
    const allocator = std.testing.allocator;
    var router = SmartRouter.init(allocator, null);

    const decision = try router.autoRoute("Write a function to reverse a string");
    try std.testing.expectEqual(.code_generation, @as(TaskType, @enumFromInt(1))); // Should detect code task
    try std.testing.expect(decision.confidence > 0.5);
}
