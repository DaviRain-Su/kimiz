//! kimiz-learning - Adaptive Learning System
//! "The AI Coding Agent that learns you"
//! Core differentiating feature from PRD

const std = @import("std");
const utils = @import("../utils/root.zig");

// ============================================================================
// User Preferences
// ============================================================================

/// User code style preferences
pub const CodeStyle = struct {
    // Naming conventions
    variable_case: NamingCase = .snake_case,
    function_case: NamingCase = .snake_case,
    constant_case: NamingCase = .screaming_snake_case,
    type_case: NamingCase = .pascal_case,

    // Indentation
    indent_style: IndentStyle = .spaces,
    indent_size: u8 = 4,
    max_line_length: u16 = 100,

    // Language preferences
    preferred_language: ?[]const u8 = null,
    preferred_frameworks: []const []const u8 = &.{},

    pub const NamingCase = enum {
        snake_case,
        camel_case,
        pascal_case,
        screaming_snake_case,
        kebab_case,
    };

    pub const IndentStyle = enum {
        spaces,
        tabs,
    };
};

/// User behavior preferences
pub const UserPreferences = struct {
    code_style: CodeStyle = .{},

    // Communication style
    explanation_verbosity: VerbosityLevel = .medium,
    include_code_examples: bool = true,
    prefer_shortcuts: bool = false,

    // Tool preferences
    auto_approve_tools: []const []const u8 = &.{}, // Tool IDs that don't need confirmation
    preferred_tools: []const []const u8 = &.{},

    // Model preferences
    preferred_model: ?[]const u8 = null,
    cost_sensitive: bool = true,

    pub const VerbosityLevel = enum {
        minimal,
        low,
        medium,
        high,
        maximum,
    };
};

// ============================================================================
// Tool Usage Patterns
// ============================================================================

/// Tool usage statistics
pub const ToolUsagePattern = struct {
    tool_id: []const u8,
    total_invocations: u32,
    success_count: u32,
    failure_count: u32,
    average_execution_time_ms: i64,
    common_params: std.StringHashMap(u32), // Param value -> frequency
    last_used: i64,

    pub fn init(allocator: std.mem.Allocator, tool_id: []const u8) ToolUsagePattern {
        return .{
            .tool_id = tool_id,
            .total_invocations = 0,
            .success_count = 0,
            .failure_count = 0,
            .average_execution_time_ms = 0,
            .common_params = std.StringHashMap(u32).init(allocator),
            .last_used = 0,
        };
    }

    pub fn deinit(self: *ToolUsagePattern) void {
        self.common_params.deinit();
    }

    pub fn recordUsage(self: *ToolUsagePattern, success: bool, execution_time_ms: i64) void {
        self.total_invocations += 1;
        if (success) {
            self.success_count += 1;
        } else {
            self.failure_count += 1;
        }

        // Update average execution time
        const total_time = self.average_execution_time_ms * @as(i64, @intCast(self.total_invocations - 1)) + execution_time_ms;
        self.average_execution_time_ms = @divFloor(total_time, @as(i64, @intCast(self.total_invocations)));

        self.last_used = utils.milliTimestamp();
    }
};

// ============================================================================
// Model Performance Tracking
// ============================================================================

/// Model performance metrics for smart routing
pub const ModelMetrics = struct {
    model_id: []const u8,
    total_requests: u32,
    success_count: u32,
    failure_count: u32,
    average_latency_ms: i64,
    average_token_cost: f64,
    user_satisfaction_score: f64, // 0.0 - 5.0

    // Task type performance
    task_performance: std.StringHashMap(TaskMetrics),

    pub const TaskMetrics = struct {
        task_type: []const u8,
        requests: u32,
        avg_latency_ms: i64,
        success_rate: f64,
    };

    pub fn init(allocator: std.mem.Allocator, model_id: []const u8) ModelMetrics {
        return .{
            .model_id = model_id,
            .total_requests = 0,
            .success_count = 0,
            .failure_count = 0,
            .average_latency_ms = 0,
            .average_token_cost = 0.0,
            .user_satisfaction_score = 3.0,
            .task_performance = std.StringHashMap(TaskMetrics).init(allocator),
        };
    }

    pub fn deinit(self: *ModelMetrics) void {
        self.task_performance.deinit();
    }

    pub fn recordRequest(
        self: *ModelMetrics,
        success: bool,
        latency_ms: i64,
        token_cost: f64,
        task_type: []const u8,
    ) void {
        self.total_requests += 1;
        if (success) {
            self.success_count += 1;
        } else {
            self.failure_count += 1;
        }

        // Update average latency
        const total_latency = self.average_latency_ms * @as(i64, @intCast(self.total_requests - 1)) + latency_ms;
        self.average_latency_ms = @divFloor(total_latency, @as(i64, @intCast(self.total_requests)));

        // Update average cost
        const total_cost = self.average_token_cost * @as(f64, @floatFromInt(self.total_requests - 1)) + token_cost;
        self.average_token_cost = total_cost / @as(f64, @floatFromInt(self.total_requests));

        // Update task-specific metrics
        _ = task_type;
        // TODO: Implement task-specific tracking
    }
};

// ============================================================================
// Learning Engine
// ============================================================================

pub const LearningEngine = struct {
    allocator: std.mem.Allocator,
    user_preferences: UserPreferences,
    tool_patterns: std.StringHashMap(ToolUsagePattern),
    model_metrics: std.StringHashMap(ModelMetrics),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .user_preferences = .{},
            .tool_patterns = std.StringHashMap(ToolUsagePattern).init(allocator),
            .model_metrics = std.StringHashMap(ModelMetrics).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        // Free tool patterns
        var tool_iter = self.tool_patterns.valueIterator();
        while (tool_iter.next()) |pattern| {
            pattern.deinit();
        }
        self.tool_patterns.deinit();

        // Free model metrics
        var model_iter = self.model_metrics.valueIterator();
        while (model_iter.next()) |metrics| {
            metrics.deinit();
        }
        self.model_metrics.deinit();
    }

    // -------------------------------------------------------------------------
    // Learning Methods
    // -------------------------------------------------------------------------

    /// Learn from code changes
    pub fn learnFromCodeChange(self: *Self, before: []const u8, after: []const u8) !void {
        _ = self;
        _ = before;
        _ = after;
        // TODO: Analyze code changes to learn style preferences
    }

    /// Record tool usage
    pub fn recordToolUsage(
        self: *Self,
        tool_id: []const u8,
        success: bool,
        execution_time_ms: i64,
    ) !void {
        const gop = try self.tool_patterns.getOrPut(tool_id);
        if (!gop.found_existing) {
            gop.value_ptr.* = ToolUsagePattern.init(self.allocator, tool_id);
        }
        gop.value_ptr.recordUsage(success, execution_time_ms);
    }

    /// Record model performance
    pub fn recordModelPerformance(
        self: *Self,
        model_id: []const u8,
        success: bool,
        latency_ms: i64,
        token_cost: f64,
        task_type: []const u8,
    ) !void {
        const gop = try self.model_metrics.getOrPut(model_id);
        if (!gop.found_existing) {
            gop.value_ptr.* = ModelMetrics.init(self.allocator, model_id);
        }
        gop.value_ptr.recordRequest(success, latency_ms, token_cost, task_type);
    }

    /// Update user satisfaction score
    pub fn updateSatisfaction(self: *Self, model_id: []const u8, score: f64) !void {
        if (self.model_metrics.getPtr(model_id)) |metrics| {
            // Moving average
            const alpha = 0.3; // Learning rate
            metrics.user_satisfaction_score = (1.0 - alpha) * metrics.user_satisfaction_score + alpha * score;
        }
    }

    // -------------------------------------------------------------------------
    // Recommendation Methods
    // -------------------------------------------------------------------------

    /// Get best model for task type
    pub fn recommendModel(self: *Self, task_type: []const u8, cost_sensitive: bool) ?[]const u8 {
        _ = task_type;
        _ = cost_sensitive;
        _ = self;
        // TODO: Implement model recommendation logic
        return null;
    }

    /// Get commonly used parameters for a tool
    pub fn getCommonParams(self: *Self, tool_id: []const u8) ?std.StringHashMap(u32) {
        if (self.tool_patterns.get(tool_id)) |pattern| {
            return pattern.common_params;
        }
        return null;
    }

    /// Check if tool should be auto-approved
    pub fn shouldAutoApprove(self: *Self, tool_id: []const u8) bool {
        for (self.user_preferences.auto_approve_tools) |id| {
            if (std.mem.eql(u8, id, tool_id)) return true;
        }

        // Auto-approve if high success rate
        if (self.tool_patterns.get(tool_id)) |pattern| {
            if (pattern.total_invocations > 10) {
                const success_rate = @as(f64, @floatFromInt(pattern.success_count)) /
                    @as(f64, @floatFromInt(pattern.total_invocations));
                return success_rate > 0.95;
            }
        }

        return false;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "LearningEngine basic operations" {
    const allocator = std.testing.allocator;
    var engine = LearningEngine.init(allocator);
    defer engine.deinit();

    // Record some tool usage
    try engine.recordToolUsage("read_file", true, 100);
    try engine.recordToolUsage("read_file", true, 120);
    try engine.recordToolUsage("read_file", false, 200);

    // Check auto-approval (should be false with only 3 invocations)
    try std.testing.expect(!engine.shouldAutoApprove("read_file"));

    // Add more successful invocations
    var i: u32 = 0;
    while (i < 20) : (i += 1) {
        try engine.recordToolUsage("read_file", true, 100);
    }

    // Now should auto-approve
    try std.testing.expect(engine.shouldAutoApprove("read_file"));
}
