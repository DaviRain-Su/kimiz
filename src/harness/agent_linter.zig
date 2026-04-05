//! Agent Linter - FEAT-015 Agent Linter
//! Validates agent outputs against defined rules and best practices

const std = @import("std");

/// Severity level for lint issues
pub const Severity = enum {
    /// Informational, not a problem
    info,
    /// Warning, should be addressed
    warning,
    /// Error, must be fixed
    err,
    /// Critical, execution should stop
    critical,

    /// Convert severity to string
    pub fn toString(self: Severity) []const u8 {
        return switch (self) {
            .info => "info",
            .warning => "warning",
            .err => "error",
            .critical => "critical",
        };
    }
};

/// A single lint issue
pub const LintIssue = struct {
    /// Severity of the issue
    severity: Severity,
    /// Rule code (e.g., "AGENT-001")
    rule_code: []const u8,
    /// Human-readable message
    message: []const u8,
    /// Line number if applicable
    line: ?usize,
    /// Column number if applicable
    column: ?usize,
    /// Suggested fix
    suggestion: ?[]const u8,

    const Self = @This();

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.rule_code);
        allocator.free(self.message);
        if (self.suggestion) |s| allocator.free(s);
    }
};

/// Result of linting
pub const LintResult = struct {
    allocator: std.mem.Allocator,
    /// All issues found
    issues: std.ArrayList(LintIssue),
    /// Whether the output passes all checks
    passed: bool,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .issues = std.ArrayList(LintIssue).init(allocator),
            .passed = true,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.issues.items) |issue| {
            issue.deinit(self.allocator);
        }
        self.issues.deinit();
    }

    /// Add an issue to the result
    pub fn addIssue(
        self: *Self,
        severity: Severity,
        rule_code: []const u8,
        message: []const u8,
        line: ?usize,
        column: ?usize,
        suggestion: ?[]const u8,
    ) !void {
        const issue = LintIssue{
            .severity = severity,
            .rule_code = try self.allocator.dupe(u8, rule_code),
            .message = try self.allocator.dupe(u8, message),
            .line = line,
            .column = column,
            .suggestion = if (suggestion) |s| try self.allocator.dupe(u8, s) else null,
        };

        try self.issues.append(issue);

        // Update passed status based on severity
        if (severity == .err or severity == .critical) {
            self.passed = false;
        }
    }

    /// Get count of issues by severity
    pub fn getIssueCount(self: Self, severity: Severity) usize {
        var count: usize = 0;
        for (self.issues.items) |issue| {
            if (issue.severity == severity) count += 1;
        }
        return count;
    }

    /// Get total number of issues
    pub fn getTotalIssues(self: Self) usize {
        return self.issues.items.len;
    }

    /// Format result as string
    pub fn format(self: Self, allocator: std.mem.Allocator) ![]const u8 {
        var buf = std.ArrayList(u8).init(allocator);
        defer buf.deinit();

        const writer = buf.writer();

        if (self.passed) {
            try writer.writeAll("✓ Lint passed\n");
        } else {
            try writer.writeAll("✗ Lint failed\n");
        }

        try writer.print("Total issues: {d}\n", .{self.getTotalIssues()});
        try writer.print("  Critical: {d}\n", .{self.getIssueCount(.critical)});
        try writer.print("  Errors: {d}\n", .{self.getIssueCount(.err)});
        try writer.print("  Warnings: {d}\n", .{self.getIssueCount(.warning)});
        try writer.print("  Info: {d}\n", .{self.getIssueCount(.info)});

        if (self.issues.items.len > 0) {
            try writer.writeAll("\nIssues:\n");
            for (self.issues.items) |issue| {
                try writer.print("  [{s}] {s}: {s}", .{
                    issue.severity.toString(),
                    issue.rule_code,
                    issue.message,
                });
                if (issue.line) |line| {
                    try writer.print(" (line {d})", .{line});
                }
                try writer.writeAll("\n");
                if (issue.suggestion) |suggestion| {
                    try writer.print("    Suggestion: {s}\n", .{suggestion});
                }
            }
        }

        return buf.toOwnedSlice();
    }
};

/// Validation rule definition
pub const ValidationRule = struct {
    /// Unique rule code
    code: []const u8,
    /// Short description
    description: []const u8,
    /// Severity if violated
    severity: Severity,
    /// Function to check the rule
    check_fn: *const fn (output: []const u8, context: ?*anyopaque) ?[]const u8,

    const Self = @This();

    /// Check if this rule is violated
    pub fn check(self: Self, output: []const u8, context: ?*anyopaque) ?[]const u8 {
        return self.check_fn(output, context);
    }
};

/// Type of output being linted
pub const OutputType = enum {
    /// Code output
    code,
    /// Documentation/text
    text,
    /// Configuration file
    config,
    /// Shell command
    command,
    /// General agent output
    general,
};

/// Agent linter for validating outputs
pub const Linter = struct {
    allocator: std.mem.Allocator,
    /// Rules to apply
    rules: std.ArrayList(ValidationRule),
    /// Whether to fail on warnings
    fail_on_warnings: bool,
    /// Maximum issues to report
    max_issues: usize,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .rules = std.ArrayList(ValidationRule).init(allocator),
            .fail_on_warnings = false,
            .max_issues = 100,
        };
    }

    pub fn deinit(self: *Self) void {
        self.rules.deinit();
    }

    /// Add a validation rule
    pub fn addRule(self: *Self, rule: ValidationRule) !void {
        try self.rules.append(rule);
    }

    /// Add default rules
    pub fn addDefaultRules(self: *Self) !void {
        // Rule: No TODO markers in final output
        try self.addRule(.{
            .code = "AGENT-001",
            .description = "TODO markers should not be in final output",
            .severity = .warning,
            .check_fn = struct {
                fn check(output: []const u8, _: ?*anyopaque) ?[]const u8 {
                    if (std.mem.indexOf(u8, output, "TODO:") != null or
                        std.mem.indexOf(u8, output, "TODO(") != null)
                    {
                        return "Output contains TODO markers";
                    }
                    return null;
                }
            }.check,
        });

        // Rule: No FIXME markers
        try self.addRule(.{
            .code = "AGENT-002",
            .description = "FIXME markers should not be in final output",
            .severity = .warning,
            .check_fn = struct {
                fn check(output: []const u8, _: ?*anyopaque) ?[]const u8 {
                    if (std.mem.indexOf(u8, output, "FIXME:") != null or
                        std.mem.indexOf(u8, output, "FIXME(") != null)
                    {
                        return "Output contains FIXME markers";
                    }
                    return null;
                }
            }.check,
        });

        // Rule: No placeholder text
        try self.addRule(.{
            .code = "AGENT-003",
            .description = "Placeholder text should be replaced",
            .severity = .err,
            .check_fn = struct {
                fn check(output: []const u8, _: ?*anyopaque) ?[]const u8 {
                    const placeholders = &[_][]const u8{
                        "<placeholder>",
                        "[PLACEHOLDER]",
                        "XXX",
                        "your_code_here",
                        "TODO implement",
                    };
                    for (placeholders) |placeholder| {
                        if (std.mem.indexOf(u8, output, placeholder) != null) {
                            return "Output contains placeholder text";
                        }
                    }
                    return null;
                }
            }.check,
        });

        // Rule: No excessive whitespace
        try self.addRule(.{
            .code = "AGENT-004",
            .description = "Excessive trailing whitespace",
            .severity = .info,
            .check_fn = struct {
                fn check(output: []const u8, _: ?*anyopaque) ?[]const u8 {
                    if (std.mem.indexOf(u8, output, "  \n") != null or
                        std.mem.indexOf(u8, output, "\n\n\n\n") != null)
                    {
                        return "Output contains excessive whitespace";
                    }
                    return null;
                }
            }.check,
        });

        // Rule: No debug print statements
        try self.addRule(.{
            .code = "AGENT-005",
            .description = "Debug print statements should be removed",
            .severity = .warning,
            .check_fn = struct {
                fn check(output: []const u8, _: ?*anyopaque) ?[]const u8 {
                    const debug_patterns = &[_][]const u8{
                        "console.log(",
                        "print(",
                        "printf(",
                        "std.debug.print(",
                        "dbg!(",
                    };
                    for (debug_patterns) |pattern| {
                        if (std.mem.indexOf(u8, output, pattern) != null) {
                            return "Output may contain debug print statements";
                        }
                    }
                    return null;
                }
            }.check,
        });
    }

    /// Check output against all rules
    pub fn checkOutput(self: *Self, output: []const u8, output_type: OutputType) !LintResult {
        var result = LintResult.init(self.allocator);

        // Apply type-specific rules
        try self.checkTypeSpecificRules(output, output_type, &result);

        // Apply general rules
        for (self.rules.items) |rule| {
            if (result.issues.items.len >= self.max_issues) {
                break;
            }

            if (rule.check(output, null)) |message| {
                try result.addIssue(
                    rule.severity,
                    rule.code,
                    message,
                    null,
                    null,
                    null,
                );
            }
        }

        // Update passed status based on fail_on_warnings
        if (self.fail_on_warnings and result.getIssueCount(.warning) > 0) {
            result.passed = false;
        }

        return result;
    }

    /// Check type-specific rules
    fn checkTypeSpecificRules(
        _: *Self,
        output: []const u8,
        output_type: OutputType,
        result: *LintResult,
    ) !void {
        switch (output_type) {
            .code => {
                // Check for syntax-like issues
                if (std.mem.indexOf(u8, output, "};")) |idx| {
                    // Check if semicolon after brace is likely a mistake
                    if (idx > 0 and output[idx - 1] == '}') {
                        // This is a simple heuristic
                    }
                }
            },
            .command => {
                // Check for dangerous commands
                const dangerous = &[_][]const u8{
                    "rm -rf /",
                    "> /dev/sda",
                    "dd if=/dev/zero",
                };
                for (dangerous) |cmd| {
                    if (std.mem.indexOf(u8, output, cmd) != null) {
                        try result.addIssue(
                            .critical,
                            "CMD-001",
                            "Potentially dangerous command detected",
                            null,
                            null,
                            "Review command before execution",
                        );
                    }
                }
            },
            .config => {
                // Check for common config issues
                if (std.mem.indexOf(u8, output, "password = ") != null or
                    std.mem.indexOf(u8, output, "secret = ") != null)
                {
                    try result.addIssue(
                        .warning,
                        "CFG-001",
                        "Config may contain hardcoded secrets",
                        null,
                        null,
                        "Use environment variables for secrets",
                    );
                }
            },
            else => {},
        }
    }

    /// Quick check for critical issues only
    pub fn checkCriticalOnly(self: *Self, output: []const u8) !bool {
        var result = try self.checkOutput(output, .general);
        defer result.deinit();

        return result.getIssueCount(.critical) == 0;
    }

    /// Set whether to fail on warnings
    pub fn setFailOnWarnings(self: *Self, fail: bool) void {
        self.fail_on_warnings = fail;
    }

    /// Set maximum issues to report
    pub fn setMaxIssues(self: *Self, max: usize) void {
        self.max_issues = max;
    }
};

/// Convenience function for quick lint check
pub fn lintOutput(
    allocator: std.mem.Allocator,
    output: []const u8,
    output_type: OutputType,
) !LintResult {
    var linter = Linter.init(allocator);
    defer linter.deinit();

    try linter.addDefaultRules();
    return linter.checkOutput(output, output_type);
}

// ============================================================================
// Tests
// ============================================================================

test "LintResult init/deinit" {
    const allocator = std.testing.allocator;
    var result = LintResult.init(allocator);
    defer result.deinit();

    try std.testing.expect(result.passed);
    try std.testing.expectEqual(@as(usize, 0), result.getTotalIssues());
}

test "LintResult addIssue" {
    const allocator = std.testing.allocator;
    var result = LintResult.init(allocator);
    defer result.deinit();

    try result.addIssue(.warning, "TEST-001", "Test warning", 1, 5, "Fix this");

    try std.testing.expectEqual(@as(usize, 1), result.getTotalIssues());
    try std.testing.expectEqual(@as(usize, 1), result.getIssueCount(.warning));
    try std.testing.expect(result.passed); // Still passes with warnings

    try result.addIssue(.err, "TEST-002", "Test error", 2, 10, null);

    try std.testing.expectEqual(@as(usize, 2), result.getTotalIssues());
    try std.testing.expectEqual(@as(usize, 1), result.getIssueCount(.err));
    try std.testing.expect(!result.passed); // Fails with errors
}

test "Linter init/deinit" {
    const allocator = std.testing.allocator;
    var linter = Linter.init(allocator);
    defer linter.deinit();

    try std.testing.expectEqual(@as(usize, 0), linter.rules.items.len);
}

test "Linter addDefaultRules" {
    const allocator = std.testing.allocator;
    var linter = Linter.init(allocator);
    defer linter.deinit();

    try linter.addDefaultRules();
    try std.testing.expect(linter.rules.items.len > 0);
}

test "Linter checkOutput with TODO" {
    const allocator = std.testing.allocator;
    var linter = Linter.init(allocator);
    defer linter.deinit();

    try linter.addDefaultRules();

    const output = "function test() {\n  // TODO: implement this\n}";
    var result = try linter.checkOutput(output, .code);
    defer result.deinit();

    try std.testing.expect(result.getIssueCount(.warning) > 0);
}

test "Linter checkOutput with placeholder" {
    const allocator = std.testing.allocator;
    var linter = Linter.init(allocator);
    defer linter.deinit();

    try linter.addDefaultRules();

    const output = "const value = <placeholder>;";
    var result = try linter.checkOutput(output, .code);
    defer result.deinit();

    try std.testing.expect(result.getIssueCount(.err) > 0);
    try std.testing.expect(!result.passed);
}

test "Linter checkOutput clean" {
    const allocator = std.testing.allocator;
    var linter = Linter.init(allocator);
    defer linter.deinit();

    try linter.addDefaultRules();

    const output = "function test() {\n  return 42;\n}";
    var result = try linter.checkOutput(output, .code);
    defer result.deinit();

    try std.testing.expect(result.passed);
}

test "lintOutput convenience function" {
    const allocator = std.testing.allocator;

    const output = "// TODO: fix this";
    var result = try lintOutput(allocator, output, .code);
    defer result.deinit();

    try std.testing.expect(result.getIssueCount(.warning) > 0);
}

test "Severity toString" {
    try std.testing.expectEqualStrings("info", Severity.info.toString());
    try std.testing.expectEqualStrings("warning", Severity.warning.toString());
    try std.testing.expectEqualStrings("error", Severity.err.toString());
    try std.testing.expectEqualStrings("critical", Severity.critical.toString());
}
