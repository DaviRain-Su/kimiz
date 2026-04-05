//! Self Review - FEAT-017 Self Review
//! Automated self-review system for agent outputs

const std = @import("std");
const agent_linter = @import("agent_linter.zig");
const slop_collector = @import("slop_collector.zig");
const LintResult = agent_linter.LintResult;
const SlopAnalysis = slop_collector.SlopAnalysis;
const SlopLevel = slop_collector.SlopLevel;

/// Review finding severity
pub const FindingSeverity = enum {
    /// Minor suggestion
    suggestion,
    /// Should be addressed
    recommendation,
    /// Important issue
    important,
    /// Critical problem
    critical,

    /// Convert to string
    pub fn toString(self: FindingSeverity) []const u8 {
        return switch (self) {
            .suggestion => "suggestion",
            .recommendation => "recommendation",
            .important => "important",
            .critical => "critical",
        };
    }
};

/// A single review finding
pub const ReviewFinding = struct {
    /// Severity of the finding
    severity: FindingSeverity,
    /// Category (e.g., "code-quality", "security", "performance")
    category: []const u8,
    /// Title of the finding
    title: []const u8,
    /// Detailed description
    description: []const u8,
    /// Location in the output (if applicable)
    location: ?[]const u8,
    /// Suggested improvement
    suggestion: ?[]const u8,
    /// Confidence level (0-100)
    confidence: u8,

    const Self = @This();

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.category);
        allocator.free(self.title);
        allocator.free(self.description);
        if (self.location) |loc| allocator.free(loc);
        if (self.suggestion) |sugg| allocator.free(sugg);
    }
};

/// Improvement suggestion
pub const ImprovementSuggestion = struct {
    /// Area for improvement
    area: []const u8,
    /// Current state
    current: []const u8,
    /// Suggested improvement
    suggestion: []const u8,
    /// Expected benefit
    benefit: []const u8,
    /// Difficulty of implementation (1-5)
    difficulty: u8,

    const Self = @This();

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.area);
        allocator.free(self.current);
        allocator.free(self.suggestion);
        allocator.free(self.benefit);
    }
};

/// Review result summary
pub const ReviewSummary = struct {
    /// Overall quality score (0-100)
    quality_score: u8,
    /// Whether the output passes review
    passed: bool,
    /// Number of findings by severity
    finding_counts: struct {
        suggestions: usize,
        recommendations: usize,
        important: usize,
        critical: usize,
    },
    /// Key strengths
    strengths: []const []const u8,
    /// Main concerns
    concerns: []const []const u8,
};

/// Self review result
pub const SelfReviewResult = struct {
    allocator: std.mem.Allocator,
    /// All findings
    findings: std.ArrayList(ReviewFinding),
    /// Improvement suggestions
    improvements: std.ArrayList(ImprovementSuggestion),
    /// Lint result
    lint_result: ?LintResult,
    /// Slop analysis
    slop_analysis: ?SlopAnalysis,
    /// Review summary
    summary: ReviewSummary,
    /// Review timestamp
    timestamp: i64,
    /// Content that was reviewed
    content: []const u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, content: []const u8) !Self {
        return .{
            .allocator = allocator,
            .findings = std.ArrayList(ReviewFinding).init(allocator),
            .improvements = std.ArrayList(ImprovementSuggestion).init(allocator),
            .lint_result = null,
            .slop_analysis = null,
            .summary = .{
                .quality_score = 100,
                .passed = true,
                .finding_counts = .{
                    .suggestions = 0,
                    .recommendations = 0,
                    .important = 0,
                    .critical = 0,
                },
                .strengths = &.{},
                .concerns = &.{},
            },
            .timestamp = std.time.timestamp(),
            .content = try allocator.dupe(u8, content),
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.findings.items) |finding| {
            finding.deinit(self.allocator);
        }
        self.findings.deinit();

        for (self.improvements.items) |improvement| {
            improvement.deinit(self.allocator);
        }
        self.improvements.deinit();

        if (self.lint_result) |*lint| {
            lint.deinit();
        }

        if (self.slop_analysis) |*slop| {
            slop.deinit();
        }

        self.allocator.free(self.content);

        // Free summary arrays
        for (self.summary.strengths) |strength| {
            self.allocator.free(strength);
        }
        self.allocator.free(self.summary.strengths);

        for (self.summary.concerns) |concern| {
            self.allocator.free(concern);
        }
        self.allocator.free(self.summary.concerns);
    }

    /// Add a finding
    pub fn addFinding(
        self: *Self,
        severity: FindingSeverity,
        category: []const u8,
        title: []const u8,
        description: []const u8,
        location: ?[]const u8,
        suggestion: ?[]const u8,
        confidence: u8,
    ) !void {
        const finding = ReviewFinding{
            .severity = severity,
            .category = try self.allocator.dupe(u8, category),
            .title = try self.allocator.dupe(u8, title),
            .description = try self.allocator.dupe(u8, description),
            .location = if (location) |loc| try self.allocator.dupe(u8, loc) else null,
            .suggestion = if (suggestion) |sugg| try self.allocator.dupe(u8, sugg) else null,
            .confidence = confidence,
        };

        try self.findings.append(finding);

        // Update summary counts
        switch (severity) {
            .suggestion => self.summary.finding_counts.suggestions += 1,
            .recommendation => self.summary.finding_counts.recommendations += 1,
            .important => self.summary.finding_counts.important += 1,
            .critical => self.summary.finding_counts.critical += 1,
        }

        // Update passed status
        if (severity == .critical or severity == .important) {
            self.summary.passed = false;
        }
    }

    /// Add an improvement suggestion
    pub fn addImprovement(
        self: *Self,
        area: []const u8,
        current: []const u8,
        suggestion: []const u8,
        benefit: []const u8,
        difficulty: u8,
    ) !void {
        const improvement = ImprovementSuggestion{
            .area = try self.allocator.dupe(u8, area),
            .current = try self.allocator.dupe(u8, current),
            .suggestion = try self.allocator.dupe(u8, suggestion),
            .benefit = try self.allocator.dupe(u8, benefit),
            .difficulty = difficulty,
        };

        try self.improvements.append(improvement);
    }

    /// Calculate quality score based on findings
    pub fn calculateScore(self: *Self) void {
        var score: i32 = 100;

        // Deduct points for findings
        score -= @as(i32, @intCast(self.summary.finding_counts.critical)) * 25;
        score -= @as(i32, @intCast(self.summary.finding_counts.important)) * 10;
        score -= @as(i32, @intCast(self.summary.finding_counts.recommendations)) * 5;
        score -= @as(i32, @intCast(self.summary.finding_counts.suggestions)) * 1;

        // Factor in slop analysis if available
        if (self.slop_analysis) |slop| {
            score = @divTrunc(score * @as(i32, slop.quality_score), 100);
        }

        // Ensure score is in valid range
        self.summary.quality_score = @intCast(@max(0, @min(100, score)));
    }

    /// Format review as human-readable text
    pub fn formatReview(self: Self, allocator: std.mem.Allocator) ![]const u8 {
        var buf = std.ArrayList(u8).init(allocator);
        defer buf.deinit();

        const writer = buf.writer();

        try writer.writeAll("# Self Review Report\n\n");

        // Summary
        try writer.writeAll("## Summary\n\n");
        try writer.print("**Quality Score:** {d}/100\n", .{self.summary.quality_score});
        try writer.print("**Status:** {s}\n\n", .{if (self.summary.passed) "✓ PASSED" else "✗ FAILED"});

        try writer.writeAll("### Finding Counts\n");
        try writer.print("- Suggestions: {d}\n", .{self.summary.finding_counts.suggestions});
        try writer.print("- Recommendations: {d}\n", .{self.summary.finding_counts.recommendations});
        try writer.print("- Important: {d}\n", .{self.summary.finding_counts.important});
        try writer.print("- Critical: {d}\n\n", .{self.summary.finding_counts.critical});

        // Findings
        if (self.findings.items.len > 0) {
            try writer.writeAll("## Findings\n\n");

            // Group by severity
            const severities = &[_]FindingSeverity{ .critical, .important, .recommendation, .suggestion };
            for (severities) |severity| {
                var has_findings = false;
                for (self.findings.items) |finding| {
                    if (finding.severity == severity) {
                        if (!has_findings) {
                            try writer.print("### {s}\n\n", .{severity.toString()});
                            has_findings = true;
                        }

                        try writer.print("**{s}** ({s}, confidence: {d}%)\n", .{
                            finding.title,
                            finding.category,
                            finding.confidence,
                        });
                        try writer.print("{s}\n", .{finding.description});
                        if (finding.location) |loc| {
                            try writer.print("Location: {s}\n", .{loc});
                        }
                        if (finding.suggestion) |sugg| {
                            try writer.print("Suggestion: {s}\n", .{sugg});
                        }
                        try writer.writeAll("\n");
                    }
                }
            }
        }

        // Improvements
        if (self.improvements.items.len > 0) {
            try writer.writeAll("## Improvement Suggestions\n\n");

            for (self.improvements.items) |improvement| {
                try writer.print("### {s} (Difficulty: {d}/5)\n", .{
                    improvement.area,
                    improvement.difficulty,
                });
                try writer.print("**Current:** {s}\n", .{improvement.current});
                try writer.print("**Suggestion:** {s}\n", .{improvement.suggestion});
                try writer.print("**Benefit:** {s}\n\n", .{improvement.benefit});
            }
        }

        return buf.toOwnedSlice();
    }
};

/// Self review configuration
pub const ReviewConfig = struct {
    /// Minimum confidence threshold for findings (0-100)
    min_confidence: u8,
    /// Whether to include suggestions
    include_suggestions: bool,
    /// Whether to run lint checks
    run_lint: bool,
    /// Whether to run slop detection
    run_slop_check: bool,
    /// Quality threshold for passing (0-100)
    quality_threshold: u8,

    /// Default configuration
    pub fn default() ReviewConfig {
        return .{
            .min_confidence = 70,
            .include_suggestions = true,
            .run_lint = true,
            .run_slop_check = true,
            .quality_threshold = 75,
        };
    }

    /// Strict configuration
    pub fn strict() ReviewConfig {
        return .{
            .min_confidence = 80,
            .include_suggestions = true,
            .run_lint = true,
            .run_slop_check = true,
            .quality_threshold = 85,
        };
    }

    /// Lenient configuration
    pub fn lenient() ReviewConfig {
        return .{
            .min_confidence = 50,
            .include_suggestions = false,
            .run_lint = true,
            .run_slop_check = false,
            .quality_threshold = 60,
        };
    }
};

/// Self review system
pub const SelfReview = struct {
    allocator: std.mem.Allocator,
    config: ReviewConfig,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: ReviewConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    /// Review output and generate findings
    pub fn reviewOutput(self: Self, output: []const u8, output_type: agent_linter.OutputType) !SelfReviewResult {
        var result = try SelfReviewResult.init(self.allocator, output);

        // Run lint check if enabled
        if (self.config.run_lint) {
            const lint_result = try agent_linter.lintOutput(self.allocator, output, output_type);
            result.lint_result = lint_result;

            // Convert lint issues to findings
            for (lint_result.issues.items) |issue| {
                const severity: FindingSeverity = switch (issue.severity) {
                    .info => .suggestion,
                    .warning => .recommendation,
                    .err => .important,
                    .critical => .critical,
                };

                try result.addFinding(
                    severity,
                    "lint",
                    issue.rule_code,
                    issue.message,
                    if (issue.line) |line| try std.fmt.allocPrint(
                        self.allocator,
                        "line {d}",
                        .{line},
                    ) else null,
                    issue.suggestion,
                    90,
                );
            }
        }

        // Run slop check if enabled
        if (self.config.run_slop_check) {
            var slop_analysis = try slop_collector.checkQuality(self.allocator, output);
            result.slop_analysis = slop_analysis;

            // Add slop findings
            if (slop_analysis.slop_level != .clean) {
                try result.addFinding(
                    if (slop_analysis.slop_level == .slop)
                        FindingSeverity.critical
                    else if (slop_analysis.slop_level == .problematic)
                        FindingSeverity.important
                    else
                        FindingSeverity.recommendation,
                    "quality",
                    "Output Quality",
                    try std.fmt.allocPrint(
                        self.allocator,
                        "Output quality level: {s}",
                        .{slop_analysis.slop_level.toString()},
                    ),
                    null,
                    "Review and improve output quality",
                    @intCast(slop_analysis.quality_score),
                );
            }
        }

        // Add generic improvement suggestions
        if (self.config.include_suggestions) {
            try self.addGenericSuggestions(&result, output);
        }

        // Calculate final score
        result.calculateScore();

        // Update passed status based on quality threshold
        result.summary.passed = result.summary.quality_score >= self.config.quality_threshold;

        return result;
    }

    /// Add generic improvement suggestions based on content analysis
    fn addGenericSuggestions(_: Self, result: *SelfReviewResult, output: []const u8) !void {
        // Check for length
        if (output.len < 50) {
            try result.addImprovement(
                "Content Length",
                "Output is very short",
                "Consider expanding with more detail",
                "Better user understanding",
                2,
            );
        }

        // Check for code without comments
        if (std.mem.indexOf(u8, output, "fn ") != null or
            std.mem.indexOf(u8, output, "function ") != null)
        {
            if (std.mem.indexOf(u8, output, "//") == null and
                std.mem.indexOf(u8, output, "/*") == null)
            {
                try result.addImprovement(
                    "Documentation",
                    "Code lacks comments",
                    "Add explanatory comments to complex logic",
                    "Improved maintainability",
                    2,
                );
            }
        }

        // Check for error handling
        if (std.mem.indexOf(u8, output, "try ") != null or
            std.mem.indexOf(u8, output, "catch") != null)
        {
            if (std.mem.indexOf(u8, output, "error") == null) {
                try result.addImprovement(
                    "Error Handling",
                    "Consider documenting error cases",
                    "Document what errors can occur and how they're handled",
                    "Better error understanding",
                    3,
                );
            }
        }
    }

    /// Quick review for critical issues only
    pub fn quickReview(self: Self, output: []const u8) !bool {
        var result = try self.reviewOutput(output, .general);
        defer result.deinit();

        return result.summary.finding_counts.critical == 0 and
            result.summary.finding_counts.important == 0;
    }

    /// Get improvement suggestions only
    pub fn getSuggestions(self: Self, output: []const u8) ![]ImprovementSuggestion {
        var result = try self.reviewOutput(output, .general);
        defer result.deinit();

        // Copy suggestions to return
        var suggestions = try self.allocator.alloc(ImprovementSuggestion, result.improvements.items.len);
        for (result.improvements.items, 0..) |improvement, i| {
            suggestions[i] = .{
                .area = try self.allocator.dupe(u8, improvement.area),
                .current = try self.allocator.dupe(u8, improvement.current),
                .suggestion = try self.allocator.dupe(u8, improvement.suggestion),
                .benefit = try self.allocator.dupe(u8, improvement.benefit),
                .difficulty = improvement.difficulty,
            };
        }

        return suggestions;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "FindingSeverity toString" {
    try std.testing.expectEqualStrings("suggestion", FindingSeverity.suggestion.toString());
    try std.testing.expectEqualStrings("critical", FindingSeverity.critical.toString());
}

test "ReviewConfig default" {
    const config = ReviewConfig.default();
    try std.testing.expectEqual(@as(u8, 70), config.min_confidence);
    try std.testing.expect(config.include_suggestions);
    try std.testing.expect(config.run_lint);
}

test "ReviewConfig strict" {
    const config = ReviewConfig.strict();
    try std.testing.expectEqual(@as(u8, 80), config.min_confidence);
    try std.testing.expectEqual(@as(u8, 85), config.quality_threshold);
}

test "SelfReviewResult init/deinit" {
    const allocator = std.testing.allocator;
    const content = "Test content";
    var result = try SelfReviewResult.init(allocator, content);
    defer result.deinit();

    try std.testing.expectEqualStrings("Test content", result.content);
    try std.testing.expect(result.summary.passed);
}

test "SelfReviewResult addFinding" {
    const allocator = std.testing.allocator;
    var result = try SelfReviewResult.init(allocator, "test");
    defer result.deinit();

    try result.addFinding(
        .recommendation,
        "test-category",
        "Test Finding",
        "This is a test finding",
        "line 10",
        "Fix this issue",
        85,
    );

    try std.testing.expectEqual(@as(usize, 1), result.findings.items.len);
    try std.testing.expectEqual(@as(usize, 1), result.summary.finding_counts.recommendations);
}

test "SelfReviewResult calculateScore" {
    const allocator = std.testing.allocator;
    var result = try SelfReviewResult.init(allocator, "test");
    defer result.deinit();

    // Add some findings
    try result.addFinding(.suggestion, "cat", "S1", "Desc", null, null, 80);
    try result.addFinding(.recommendation, "cat", "R1", "Desc", null, null, 80);

    result.calculateScore();

    try std.testing.expect(result.summary.quality_score < 100);
}

test "SelfReview init" {
    const allocator = std.testing.allocator;
    const config = ReviewConfig.default();
    const review = SelfReview.init(allocator, config);

    try std.testing.expectEqual(@as(u8, 70), review.config.min_confidence);
}

test "SelfReview reviewOutput" {
    const allocator = std.testing.allocator;
    const config = ReviewConfig.lenient();
    const review = SelfReview.init(allocator, config);

    const output = "This is a simple test output.";
    var result = try review.reviewOutput(output, .text);
    defer result.deinit();

    try std.testing.expect(result.summary.quality_score > 0);
}

test "SelfReview quickReview" {
    const allocator = std.testing.allocator;
    const config = ReviewConfig.default();
    const review = SelfReview.init(allocator, config);

    const output = "Clean output without issues.";
    const passed = try review.quickReview(output);

    // Should pass as there are no critical issues
    try std.testing.expect(passed);
}
