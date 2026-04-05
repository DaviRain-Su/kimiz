//! Resource Limits - FEAT-013 Resource Limits
//! Track and enforce resource usage limits for agent execution

const std = @import("std");

/// Resource limits configuration
pub const ResourceLimits = struct {
    /// Maximum tokens allowed for the session
    max_tokens: ?u64,
    /// Maximum number of execution steps
    max_steps: ?u32,
    /// Maximum cost in USD (e.g., 0.50 for 50 cents)
    max_cost: ?f64,
    /// Maximum execution time in milliseconds
    timeout_ms: ?u64,

    const Self = @This();

    /// Create default resource limits (no limits)
    pub fn default() Self {
        return .{
            .max_tokens = null,
            .max_steps = null,
            .max_cost = null,
            .timeout_ms = null,
        };
    }

    /// Create conservative limits for safe execution
    pub fn conservative() Self {
        return .{
            .max_tokens = 100_000,
            .max_steps = 100,
            .max_cost = 1.00,
            .timeout_ms = 300_000, // 5 minutes
        };
    }

    /// Create strict limits for testing
    pub fn strict() Self {
        return .{
            .max_tokens = 10_000,
            .max_steps = 20,
            .max_cost = 0.10,
            .timeout_ms = 60_000, // 1 minute
        };
    }
};

/// Current resource usage
pub const ResourceUsage = struct {
    /// Tokens used so far
    tokens_used: u64 = 0,
    /// Steps executed so far
    steps_executed: u32 = 0,
    /// Cost incurred so far in USD
    cost_incurred: f64 = 0.0,
    /// Execution time elapsed in milliseconds
    elapsed_ms: u64 = 0,
    /// Start time for calculating elapsed time
    start_time_ms: u64,

    const Self = @This();

    pub fn init() Self {
        return .{
            .start_time_ms = @intCast(std.time.milliTimestamp()),
        };
    }

    /// Update elapsed time based on current time
    pub fn updateElapsed(self: *Self) void {
        const now: u64 = @intCast(std.time.milliTimestamp());
        self.elapsed_ms = now - self.start_time_ms;
    }

    /// Record token usage
    pub fn recordTokens(self: *Self, tokens: u64) void {
        self.tokens_used += tokens;
    }

    /// Record a step
    pub fn recordStep(self: *Self) void {
        self.steps_executed += 1;
    }

    /// Record cost
    pub fn recordCost(self: *Self, cost: f64) void {
        self.cost_incurred += cost;
    }
};

/// Resource limit check result
pub const LimitCheckResult = union(enum) {
    /// All limits are within bounds
    within_limits,
    /// One or more limits exceeded
    limit_exceeded: LimitViolation,
};

/// Specific limit violation
pub const LimitViolation = struct {
    /// Type of limit that was exceeded
    limit_type: LimitType,
    /// Current value
    current: u64,
    /// Maximum allowed value
    maximum: u64,
    /// Human-readable message
    message: []const u8,
};

/// Types of resource limits
pub const LimitType = enum {
    tokens,
    steps,
    cost,
    timeout,
};

/// Resource tracker for monitoring usage against limits
pub const ResourceTracker = struct {
    allocator: std.mem.Allocator,
    limits: ResourceLimits,
    usage: ResourceUsage,
    violations: std.ArrayList(LimitViolation),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, limits: ResourceLimits) Self {
        return .{
            .allocator = allocator,
            .limits = limits,
            .usage = ResourceUsage.init(),
            .violations = std.ArrayList(LimitViolation).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.violations.deinit();
    }

    /// Record token usage
    pub fn recordTokens(self: *Self, tokens: u64) void {
        self.usage.recordTokens(tokens);
    }

    /// Record a step execution
    pub fn recordStep(self: *Self) void {
        self.usage.recordStep();
    }

    /// Record cost
    pub fn recordCost(self: *Self, cost: f64) void {
        self.usage.recordCost(cost);
    }

    /// Update elapsed time
    pub fn updateElapsed(self: *Self) void {
        self.usage.updateElapsed();
    }

    /// Check if current usage is within limits
    pub fn checkLimits(self: *Self) !LimitCheckResult {
        self.updateElapsed();

        // Check token limit
        if (self.limits.max_tokens) |max| {
            if (self.usage.tokens_used > max) {
                const violation = LimitViolation{
                    .limit_type = .tokens,
                    .current = self.usage.tokens_used,
                    .maximum = max,
                    .message = try std.fmt.allocPrint(
                        self.allocator,
                        "Token limit exceeded: {d} > {d}",
                        .{ self.usage.tokens_used, max },
                    ),
                };
                try self.violations.append(violation);
                return LimitCheckResult{ .limit_exceeded = violation };
            }
        }

        // Check step limit
        if (self.limits.max_steps) |max| {
            if (self.usage.steps_executed > max) {
                const violation = LimitViolation{
                    .limit_type = .steps,
                    .current = self.usage.steps_executed,
                    .maximum = max,
                    .message = try std.fmt.allocPrint(
                        self.allocator,
                        "Step limit exceeded: {d} > {d}",
                        .{ self.usage.steps_executed, max },
                    ),
                };
                try self.violations.append(violation);
                return LimitCheckResult{ .limit_exceeded = violation };
            }
        }

        // Check cost limit
        if (self.limits.max_cost) |max| {
            const max_cost_u64: u64 = @intFromFloat(max * 10000); // Convert to cents * 100 for precision
            const current_cost_u64: u64 = @intFromFloat(self.usage.cost_incurred * 10000);
            if (current_cost_u64 > max_cost_u64) {
                const violation = LimitViolation{
                    .limit_type = .cost,
                    .current = current_cost_u64,
                    .maximum = max_cost_u64,
                    .message = try std.fmt.allocPrint(
                        self.allocator,
                        "Cost limit exceeded: ${d:.4} > ${d:.4}",
                        .{ self.usage.cost_incurred, max },
                    ),
                };
                try self.violations.append(violation);
                return LimitCheckResult{ .limit_exceeded = violation };
            }
        }

        // Check timeout
        if (self.limits.timeout_ms) |max| {
            if (self.usage.elapsed_ms > max) {
                const violation = LimitViolation{
                    .limit_type = .timeout,
                    .current = self.usage.elapsed_ms,
                    .maximum = max,
                    .message = try std.fmt.allocPrint(
                        self.allocator,
                        "Timeout exceeded: {d}ms > {d}ms",
                        .{ self.usage.elapsed_ms, max },
                    ),
                };
                try self.violations.append(violation);
                return LimitCheckResult{ .limit_exceeded = violation };
            }
        }

        return .within_limits;
    }

    /// Get current usage statistics
    pub fn getStats(self: Self) ResourceUsage {
        return self.usage;
    }

    /// Get percentage of limit used (0-100, or >100 if exceeded)
    pub fn getUsagePercentage(self: *Self, limit_type: LimitType) ?f64 {
        self.updateElapsed();

        switch (limit_type) {
            .tokens => {
                if (self.limits.max_tokens) |max| {
                    return (@as(f64, @floatFromInt(self.usage.tokens_used)) / @as(f64, @floatFromInt(max))) * 100.0;
                }
                return null;
            },
            .steps => {
                if (self.limits.max_steps) |max| {
                    return (@as(f64, @floatFromInt(self.usage.steps_executed)) / @as(f64, @floatFromInt(max))) * 100.0;
                }
                return null;
            },
            .cost => {
                if (self.limits.max_cost) |max| {
                    return (self.usage.cost_incurred / max) * 100.0;
                }
                return null;
            },
            .timeout => {
                if (self.limits.timeout_ms) |max| {
                    return (@as(f64, @floatFromInt(self.usage.elapsed_ms)) / @as(f64, @floatFromInt(max))) * 100.0;
                }
                return null;
            },
        }
    }

    /// Reset all usage counters
    pub fn reset(self: *Self) void {
        self.usage = ResourceUsage.init();
        self.violations.clearRetainingCapacity();
    }
};

/// Convenience function to check limits with a single call
pub fn checkLimits(
    allocator: std.mem.Allocator,
    limits: ResourceLimits,
    usage: ResourceUsage,
) !LimitCheckResult {
    var tracker = ResourceTracker.init(allocator, limits);
    defer tracker.deinit();

    tracker.usage = usage;
    return tracker.checkLimits();
}

// ============================================================================
// Tests
// ============================================================================

test "ResourceLimits default" {
    const limits = ResourceLimits.default();
    try std.testing.expect(limits.max_tokens == null);
    try std.testing.expect(limits.max_steps == null);
    try std.testing.expect(limits.max_cost == null);
    try std.testing.expect(limits.timeout_ms == null);
}

test "ResourceLimits conservative" {
    const limits = ResourceLimits.conservative();
    try std.testing.expectEqual(@as(?u64, 100_000), limits.max_tokens);
    try std.testing.expectEqual(@as(?u32, 100), limits.max_steps);
    try std.testing.expectEqual(@as(?f64, 1.00), limits.max_cost);
    try std.testing.expectEqual(@as(?u64, 300_000), limits.timeout_ms);
}

test "ResourceUsage init" {
    const usage = ResourceUsage.init();
    try std.testing.expectEqual(@as(u64, 0), usage.tokens_used);
    try std.testing.expectEqual(@as(u32, 0), usage.steps_executed);
    try std.testing.expectEqual(@as(f64, 0.0), usage.cost_incurred);
}

test "ResourceUsage record operations" {
    var usage = ResourceUsage.init();

    usage.recordTokens(100);
    try std.testing.expectEqual(@as(u64, 100), usage.tokens_used);

    usage.recordStep();
    try std.testing.expectEqual(@as(u32, 1), usage.steps_executed);

    usage.recordCost(0.05);
    try std.testing.expectEqual(@as(f64, 0.05), usage.cost_incurred);
}

test "ResourceTracker init/deinit" {
    const allocator = std.testing.allocator;
    const limits = ResourceLimits.conservative();
    var tracker = ResourceTracker.init(allocator, limits);
    defer tracker.deinit();

    try std.testing.expectEqual(@as(u64, 0), tracker.usage.tokens_used);
}

test "ResourceTracker checkLimits within bounds" {
    const allocator = std.testing.allocator;
    const limits = ResourceLimits{
        .max_tokens = 1000,
        .max_steps = 10,
        .max_cost = 1.00,
        .timeout_ms = 60000,
    };
    var tracker = ResourceTracker.init(allocator, limits);
    defer tracker.deinit();

    tracker.recordTokens(100);
    tracker.recordStep();
    tracker.recordCost(0.01);

    const result = try tracker.checkLimits();
    try std.testing.expect(result == .within_limits);
}

test "ResourceTracker checkLimits exceeded" {
    const allocator = std.testing.allocator;
    const limits = ResourceLimits{
        .max_tokens = 100,
        .max_steps = null,
        .max_cost = null,
        .timeout_ms = null,
    };
    var tracker = ResourceTracker.init(allocator, limits);
    defer tracker.deinit();

    tracker.recordTokens(150);

    const result = try tracker.checkLimits();
    try std.testing.expect(result == .limit_exceeded);
    switch (result) {
        .limit_exceeded => |violation| {
            try std.testing.expectEqual(LimitType.tokens, violation.limit_type);
        },
        else => unreachable,
    }
}

test "ResourceTracker getUsagePercentage" {
    const allocator = std.testing.allocator;
    const limits = ResourceLimits{
        .max_tokens = 100,
        .max_steps = null,
        .max_cost = null,
        .timeout_ms = null,
    };
    var tracker = ResourceTracker.init(allocator, limits);
    defer tracker.deinit();

    tracker.recordTokens(50);

    const percentage = tracker.getUsagePercentage(.tokens);
    try std.testing.expect(percentage != null);
    try std.testing.expectApproxEqAbs(@as(f64, 50.0), percentage.?, 0.1);
}
