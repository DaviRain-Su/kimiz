//! Slop Collector - FEAT-016 Slop Collector
//! Detects and cleans up low-quality or problematic agent outputs

const std = @import("std");
const agent_linter = @import("agent_linter.zig");
const LintResult = agent_linter.LintResult;
const Severity = agent_linter.Severity;

/// Classification of output quality
pub const SlopLevel = enum {
    /// High quality output
    clean,
    /// Minor issues, acceptable
    minor_issues,
    /// Moderate issues, needs review
    needs_review,
    /// Significant issues, likely problematic
    problematic,
    /// Critical issues, discard
    slop,

    /// Convert to string representation
    pub fn toString(self: SlopLevel) []const u8 {
        return switch (self) {
            .clean => "clean",
            .minor_issues => "minor_issues",
            .needs_review => "needs_review",
            .problematic => "problematic",
            .slop => "slop",
        };
    }

    /// Get numeric score (0-100, higher is better)
    pub fn toScore(self: SlopLevel) u8 {
        return switch (self) {
            .clean => 95,
            .minor_issues => 80,
            .needs_review => 60,
            .problematic => 40,
            .slop => 20,
        };
    }
};

/// A slop entry for tracking bad outputs
pub const SlopEntry = struct {
    /// Unique identifier
    id: []const u8,
    /// Original output content
    original_content: []const u8,
    /// Detected slop level
    slop_level: SlopLevel,
    /// Issues found
    issues: std.ArrayList([]const u8),
    /// Timestamp
    timestamp: i64,
    /// Source (e.g., agent name, task id)
    source: []const u8,
    /// Whether it was cleaned
    was_cleaned: bool,
    /// Cleaned content if available
    cleaned_content: ?[]const u8,

    const Self = @This();

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.original_content);
        for (self.issues.items) |issue| {
            allocator.free(issue);
        }
        self.issues.deinit();
        allocator.free(self.source);
        if (self.cleaned_content) |content| {
            allocator.free(content);
        }
    }
};

/// Slop detection pattern
pub const SlopPattern = struct {
    /// Pattern name
    name: []const u8,
    /// Pattern description
    description: []const u8,
    /// String to search for
    pattern: []const u8,
    /// Slop level if found
    slop_level: SlopLevel,
    /// Whether this pattern can be auto-fixed
    auto_fixable: bool,
    /// Replacement string for auto-fix (null = remove)
    replacement: ?[]const u8,
};

/// Default slop patterns
pub const DEFAULT_PATTERNS = &[_]SlopPattern{
    .{
        .name = "excessive_flattery",
        .description = "Excessive flattery or self-praise",
        .pattern = "I'm an excellent",
        .slop_level = .minor_issues,
        .auto_fixable = true,
        .replacement = "",
    },
    .{
        .name = "over_confidence",
        .description = "Overly confident statements without basis",
        .pattern = "This is definitely the best solution",
        .slop_level = .minor_issues,
        .auto_fixable = true,
        .replacement = "",
    },
    .{
        .name = "hallucinated_references",
        .description = "References to non-existent documentation",
        .pattern = "According to the official documentation",
        .slop_level = .needs_review,
        .auto_fixable = false,
        .replacement = null,
    },
    .{
        .name = "vague_explanations",
        .description = "Vague or unhelpful explanations",
        .pattern = "It depends on various factors",
        .slop_level = .needs_review,
        .auto_fixable = false,
        .replacement = null,
    },
    .{
        .name = "repetitive_content",
        .description = "Excessive repetition of content",
        .pattern = "As I mentioned before, as I mentioned before",
        .slop_level = .problematic,
        .auto_fixable = true,
        .replacement = "",
    },
    .{
        .name = "incomplete_code",
        .description = "Incomplete code blocks",
        .pattern = "// ... (rest of the code)",
        .slop_level = .problematic,
        .auto_fixable = false,
        .replacement = null,
    },
    .{
        .name = "placeholder_code",
        .description = "Code with obvious placeholders",
        .pattern = "your_code_here",
        .slop_level = .slop,
        .auto_fixable = false,
        .replacement = null,
    },
    .{
        .name = "fabricated_errors",
        .description = "Made up error messages",
        .pattern = "Error 0xDEADBEEF",
        .slop_level = .slop,
        .auto_fixable = false,
        .replacement = null,
    },
};

/// Analysis result for slop detection
pub const SlopAnalysis = struct {
    allocator: std.mem.Allocator,
    /// Detected slop level
    slop_level: SlopLevel,
    /// Patterns matched
    matched_patterns: std.ArrayList([]const u8),
    /// Quality score (0-100)
    quality_score: u8,
    /// Whether auto-cleanup is possible
    can_auto_cleanup: bool,
    /// Suggested cleanup actions
    suggestions: std.ArrayList([]const u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .slop_level = .clean,
            .matched_patterns = std.ArrayList([]const u8).init(allocator),
            .quality_score = 100,
            .can_auto_cleanup = true,
            .suggestions = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.matched_patterns.items) |pattern| {
            self.allocator.free(pattern);
        }
        self.matched_patterns.deinit();

        for (self.suggestions.items) |suggestion| {
            self.allocator.free(suggestion);
        }
        self.suggestions.deinit();
    }

    /// Add a matched pattern
    pub fn addPattern(self: *Self, pattern_name: []const u8) !void {
        const copy = try self.allocator.dupe(u8, pattern_name);
        try self.matched_patterns.append(copy);
    }

    /// Add a suggestion
    pub fn addSuggestion(self: *Self, suggestion: []const u8) !void {
        const copy = try self.allocator.dupe(u8, suggestion);
        try self.suggestions.append(copy);
    }
};

/// Slop collector for managing low-quality outputs
pub const SlopCollector = struct {
    allocator: std.mem.Allocator,
    /// Patterns to check
    patterns: []const SlopPattern,
    /// Collected slop entries
    entries: std.ArrayList(SlopEntry),
    /// Quality threshold (minimum acceptable score)
    quality_threshold: u8,
    /// Whether to auto-clean when possible
    auto_clean: bool,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .patterns = DEFAULT_PATTERNS,
            .entries = std.ArrayList(SlopEntry).init(allocator),
            .quality_threshold = 70,
            .auto_clean = false,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.entries.items) |*entry| {
            entry.deinit(self.allocator);
        }
        self.entries.deinit();
    }

    /// Analyze content for slop
    pub fn analyze(self: *Self, content: []const u8) !SlopAnalysis {
        var analysis = SlopAnalysis.init(self.allocator);

        var worst_level: SlopLevel = .clean;
        var all_auto_fixable = true;

        // Check each pattern
        for (self.patterns) |pattern| {
            if (std.mem.indexOf(u8, content, pattern.pattern) != null) {
                try analysis.addPattern(pattern.name);

                // Update worst level
                if (@intFromEnum(pattern.slop_level) > @intFromEnum(worst_level)) {
                    worst_level = pattern.slop_level;
                }

                // Check if auto-fixable
                if (!pattern.auto_fixable) {
                    all_auto_fixable = false;
                }

                // Add suggestion
                const suggestion = try std.fmt.allocPrint(
                    self.allocator,
                    "Found '{s}': {s}",
                    .{ pattern.name, pattern.description },
                );
                try analysis.addSuggestion(suggestion);
            }
        }

        analysis.slop_level = worst_level;
        analysis.quality_score = worst_level.toScore();
        analysis.can_auto_cleanup = all_auto_fixable;

        return analysis;
    }

    /// Collect slop from output
    pub fn collectSlop(
        self: *Self,
        content: []const u8,
        source: []const u8,
    ) !SlopAnalysis {
        const analysis = try self.analyze(content);

        // Create entry if slop detected
        if (analysis.slop_level != .clean) {
            var entry = SlopEntry{
                .id = try std.fmt.allocPrint(self.allocator, "slop-{d}", .{self.entries.items.len}),
                .original_content = try self.allocator.dupe(u8, content),
                .slop_level = analysis.slop_level,
                .issues = std.ArrayList([]const u8).init(self.allocator),
                .timestamp = std.time.timestamp(),
                .source = try self.allocator.dupe(u8, source),
                .was_cleaned = false,
                .cleaned_content = null,
            };

            // Copy issues
            for (analysis.suggestions.items) |suggestion| {
                const issue_copy = try self.allocator.dupe(u8, suggestion);
                try entry.issues.append(issue_copy);
            }

            try self.entries.append(entry);
        }

        return analysis;
    }

    /// Attempt to clean up slop
    pub fn cleanup(self: *Self, content: []const u8) !?[]const u8 {
        var cleaned = try self.allocator.dupe(u8, content);
        var was_modified = false;

        for (self.patterns) |pattern| {
            if (pattern.auto_fixable) {
                if (std.mem.indexOf(u8, cleaned, pattern.pattern)) |_| {
                    // Apply replacement
                    if (pattern.replacement) |replacement| {
                        // Simple replacement (not handling multiple occurrences efficiently)
                        const new_content = try std.mem.replaceOwned(
                            u8,
                            self.allocator,
                            cleaned,
                            pattern.pattern,
                            replacement,
                        );
                        self.allocator.free(cleaned);
                        cleaned = new_content;
                    } else {
                        // Remove the pattern
                        const new_content = try std.mem.replaceOwned(
                            u8,
                            self.allocator,
                            cleaned,
                            pattern.pattern,
                            "",
                        );
                        self.allocator.free(cleaned);
                        cleaned = new_content;
                    }
                    was_modified = true;
                }
            }
        }

        if (was_modified) {
            return cleaned;
        }

        self.allocator.free(cleaned);
        return null;
    }

    /// Check if content passes quality threshold
    pub fn passesQualityCheck(self: *Self, content: []const u8) !bool {
        const analysis = try self.analyze(content);
        defer analysis.deinit();

        return analysis.quality_score >= self.quality_threshold;
    }

    /// Get all entries
    pub fn getEntries(self: Self) []const SlopEntry {
        return self.entries.items;
    }

    /// Get entries by slop level
    pub fn getEntriesByLevel(
        self: Self,
        level: SlopLevel,
        allocator: std.mem.Allocator,
    ) ![]SlopEntry {
        var filtered = std.ArrayList(SlopEntry).init(allocator);
        errdefer filtered.deinit();

        for (self.entries.items) |entry| {
            if (entry.slop_level == level) {
                try filtered.append(entry);
            }
        }

        return filtered.toOwnedSlice();
    }

    /// Clear all entries
    pub fn clearEntries(self: *Self) void {
        for (self.entries.items) |*entry| {
            entry.deinit(self.allocator);
        }
        self.entries.clearRetainingCapacity();
    }

    /// Set quality threshold
    pub fn setQualityThreshold(self: *Self, threshold: u8) void {
        self.quality_threshold = @min(threshold, 100);
    }

    /// Enable/disable auto-clean
    pub fn setAutoClean(self: *Self, enabled: bool) void {
        self.auto_clean = enabled;
    }

    /// Get statistics
    pub fn getStats(self: Self) struct {
        total_entries: usize,
        clean_count: usize,
        minor_issues_count: usize,
        needs_review_count: usize,
        problematic_count: usize,
        slop_count: usize,
    } {
        var stats = .{
            .total_entries = self.entries.items.len,
            .clean_count = @as(usize, 0),
            .minor_issues_count = @as(usize, 0),
            .needs_review_count = @as(usize, 0),
            .problematic_count = @as(usize, 0),
            .slop_count = @as(usize, 0),
        };

        for (self.entries.items) |entry| {
            switch (entry.slop_level) {
                .clean => stats.clean_count += 1,
                .minor_issues => stats.minor_issues_count += 1,
                .needs_review => stats.needs_review_count += 1,
                .problematic => stats.problematic_count += 1,
                .slop => stats.slop_count += 1,
            }
        }

        return stats;
    }
};

/// Convenience function to quickly check content quality
pub fn checkQuality(
    allocator: std.mem.Allocator,
    content: []const u8,
) !SlopAnalysis {
    var collector = SlopCollector.init(allocator);
    defer collector.deinit();

    return collector.analyze(content);
}

// ============================================================================
// Tests
// ============================================================================

test "SlopLevel toString" {
    try std.testing.expectEqualStrings("clean", SlopLevel.clean.toString());
    try std.testing.expectEqualStrings("slop", SlopLevel.slop.toString());
}

test "SlopLevel toScore" {
    try std.testing.expectEqual(@as(u8, 95), SlopLevel.clean.toScore());
    try std.testing.expectEqual(@as(u8, 20), SlopLevel.slop.toScore());
}

test "SlopAnalysis init/deinit" {
    const allocator = std.testing.allocator;
    var analysis = SlopAnalysis.init(allocator);
    defer analysis.deinit();

    try std.testing.expectEqual(SlopLevel.clean, analysis.slop_level);
    try std.testing.expectEqual(@as(u8, 100), analysis.quality_score);
}

test "SlopCollector init/deinit" {
    const allocator = std.testing.allocator;
    var collector = SlopCollector.init(allocator);
    defer collector.deinit();

    try std.testing.expectEqual(@as(usize, 0), collector.entries.items.len);
}

test "SlopCollector analyze clean" {
    const allocator = std.testing.allocator;
    var collector = SlopCollector.init(allocator);
    defer collector.deinit();

    const content = "This is a well-written response with no issues.";
    var analysis = try collector.analyze(content);
    defer analysis.deinit();

    try std.testing.expectEqual(SlopLevel.clean, analysis.slop_level);
    try std.testing.expectEqual(@as(usize, 0), analysis.matched_patterns.items.len);
}

test "SlopCollector analyze with slop" {
    const allocator = std.testing.allocator;
    var collector = SlopCollector.init(allocator);
    defer collector.deinit();

    const content = "This code has your_code_here which is a placeholder.";
    var analysis = try collector.analyze(content);
    defer analysis.deinit();

    try std.testing.expect(analysis.slop_level != .clean);
    try std.testing.expect(analysis.matched_patterns.items.len > 0);
}

test "SlopCollector collectSlop" {
    const allocator = std.testing.allocator;
    var collector = SlopCollector.init(allocator);
    defer collector.deinit();

    const content = "This has your_code_here placeholder.";
    var analysis = try collector.collectSlop(content, "test-agent");
    defer analysis.deinit();

    try std.testing.expectEqual(@as(usize, 1), collector.entries.items.len);
}

test "SlopCollector cleanup" {
    const allocator = std.testing.allocator;
    var collector = SlopCollector.init(allocator);
    defer collector.deinit();

    const content = "I'm an excellent programmer. Here is my code.";
    const cleaned = try collector.cleanup(content);

    if (cleaned) |c| {
        defer allocator.free(c);
        try std.testing.expect(std.mem.indexOf(u8, c, "I'm an excellent") == null);
    }
}

test "SlopCollector passesQualityCheck" {
    const allocator = std.testing.allocator;
    var collector = SlopCollector.init(allocator);
    defer collector.deinit();

    collector.setQualityThreshold(75);

    const good_content = "This is good content.";
    const passes = try collector.passesQualityCheck(good_content);
    try std.testing.expect(passes);
}

test "SlopCollector getStats" {
    const allocator = std.testing.allocator;
    var collector = SlopCollector.init(allocator);
    defer collector.deinit();

    // Add some entries
    _ = try collector.collectSlop("your_code_here", "agent-1");
    _ = try collector.collectSlop("clean content", "agent-2");

    const stats = collector.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats.total_entries);
}

test "checkQuality convenience function" {
    const allocator = std.testing.allocator;

    const content = "This has your_code_here.";
    var analysis = try checkQuality(allocator, content);
    defer analysis.deinit();

    try std.testing.expect(analysis.slop_level != .clean);
}
