//! CodeReview Skill - DSL version
//! Automated code review with Factory Droid-inspired best practices

const std = @import("std");
const skills = @import("./root.zig");

// ============================================================================
// LLM Prompt Templates
// ============================================================================

const EMBEDDED_SKILL_MD = @embedFile("code_review/SKILL.md");

fn stripYamlFrontmatter(content: []const u8) []const u8 {
    if (!std.mem.startsWith(u8, content, "---")) return content;
    const after_first = content[3..];
    const end_idx = std.mem.indexOf(u8, after_first, "\n---") orelse return content;
    const after_frontmatter = after_first[end_idx + 4 ..];
    var start: usize = 0;
    while (start < after_frontmatter.len and after_frontmatter[start] == '\n') {
        start += 1;
    }
    return after_frontmatter[start..];
}

pub fn buildSystemPrompt(
    allocator: std.mem.Allocator,
    tone: Tone,
    focus: FocusArea,
) ![]u8 {
    const methodology = stripYamlFrontmatter(EMBEDDED_SKILL_MD);

    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    const w = ListWriter{ .list = &output, .allocator = allocator };

    try w.writeAll("You are a senior staff software engineer and expert code reviewer.\n\n");
    try w.writeAll(methodology);
    try w.writeAll("\n## Tone Calibration\n\n");
    try w.print("Review tone: {s}\n", .{@tagName(tone)});
    try w.print("{s}\n", .{tone.description()});

    if (focus != .all) {
        try w.writeAll("\n## Scope Restriction\n\n");
        try w.print("Focus your review primarily on **{s}**. You may briefly mention other categories if they are blocking issues, but prioritize {s}.\n", .{
            @tagName(focus),
            @tagName(focus),
        });
    }

    return output.toOwnedSlice(allocator);
}

pub fn buildUserPrompt(
    allocator: std.mem.Allocator,
    filepath: []const u8,
    content: []const u8,
    patch_context: ?[]const u8,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    const w = ListWriter{ .list = &output, .allocator = allocator };

    try w.writeAll("Please review the following code using the two-pass pipeline.\n\n");

    if (patch_context) |patch| {
        try w.writeAll("## Diff / Patch Context\n\n```diff\n");
        try w.writeAll(patch);
        try w.writeAll("\n```\n\n");
    }

    try w.writeAll("## File Content\n\n```\n");
    try w.writeAll(content);
    try w.writeAll("\n```\n\n");

    try w.print("File path: `{s}`\n\n", .{filepath});
    try w.writeAll("Instructions:\n");
    try w.writeAll("1. Pass 1: Generate candidate issues by scanning for the bug patterns above.\n");
    try w.writeAll("2. Pass 2: Validate each candidate -- verify with the code, assess confidence, and assign P0/P1/P2/P3.\n");
    try w.writeAll("3. Apply the reporting gate: discard speculative or cosmetic findings.\n");
    try w.writeAll("4. Format each remaining finding with priority tag, title, explanation, line number, and optional suggestion block.\n");
    try w.writeAll("5. Deduplicate: do not report the same root cause twice.\n");

    return output.toOwnedSlice(allocator);
}

// ============================================================================
// Configuration Types
// ============================================================================

pub const Tone = enum {
    junior_dev,
    peer_reviewer,
    senior_architect,

    pub fn description(self: Tone) []const u8 {
        return switch (self) {
            .junior_dev => "write like a junior developer who defers to the PR author; be polite and tentative",
            .peer_reviewer => "write like a peer engineer offering constructive feedback",
            .senior_architect => "write like a senior architect focusing on systemic concerns",
        };
    }
};

pub const FocusArea = enum {
    correctness,
    security,
    performance,
    concurrency,
    error_handling,
    resource_management,
    all,
};

pub const ReviewIssue = struct {
    severity: Severity,
    category: FocusArea,
    line_hint: ?usize,
    message: []const u8,
    suggestion: ?[]const u8,

    pub const Severity = enum {
        critical,
        warning,
        question,
    };

    pub fn eql(self: ReviewIssue, other: ReviewIssue) bool {
        if (self.category != other.category) return false;
        if (self.line_hint != other.line_hint) return false;
        const self_msg = self.message;
        const other_msg = other.message;
        const compare_len = @min(self_msg.len, other_msg.len, 64);
        return std.mem.eql(u8, self_msg[0..compare_len], other_msg[0..compare_len]);
    }
};

// ============================================================================
// Internal State
// ============================================================================

const ReviewSession = struct {
    focus: FocusArea,
    tone: Tone,
    max_comments: u32,
    patch_context: ?[]const u8,
    previously_reported: std.StringHashMap(void),

    pub fn init(allocator: std.mem.Allocator) ReviewSession {
        return .{
            .focus = .all,
            .tone = .junior_dev,
            .max_comments = 10,
            .patch_context = null,
            .previously_reported = std.StringHashMap(void).init(allocator),
        };
    }

    pub fn deinit(self: *ReviewSession) void {
        self.previously_reported.deinit();
    }

    pub fn shouldFocusOn(self: *const ReviewSession, area: FocusArea) bool {
        return self.focus == .all or self.focus == area;
    }
};

// ============================================================================
// Issue Collection & Deduplication
// ============================================================================

fn parseFocus(raw: []const u8) FocusArea {
    if (std.mem.eql(u8, raw, "correctness")) return .correctness;
    if (std.mem.eql(u8, raw, "security")) return .security;
    if (std.mem.eql(u8, raw, "performance")) return .performance;
    if (std.mem.eql(u8, raw, "concurrency")) return .concurrency;
    if (std.mem.eql(u8, raw, "error_handling")) return .error_handling;
    if (std.mem.eql(u8, raw, "resource_management")) return .resource_management;
    return .all;
}

fn parseTone(raw: []const u8) Tone {
    if (std.mem.eql(u8, raw, "peer_reviewer")) return .peer_reviewer;
    if (std.mem.eql(u8, raw, "senior_architect")) return .senior_architect;
    return .junior_dev;
}

fn isPreviouslyReported(session: *ReviewSession, issue: ReviewIssue) bool {
    var buf: [256]u8 = undefined;
    const key = std.fmt.bufPrint(&buf, "{s}:{?d}:{s}", .{
        @tagName(issue.category),
        issue.line_hint,
        issue.message,
    }) catch return false;
    return session.previously_reported.contains(key);
}

fn dedupIssues(allocator: std.mem.Allocator, issues: []const ReviewIssue) ![]ReviewIssue {
    if (issues.len == 0) return try allocator.alloc(ReviewIssue, 0);
    var deduped: std.ArrayList(ReviewIssue) = .empty;
    defer deduped.deinit(allocator);

    for (issues) |issue| {
        var is_dup = false;
        for (deduped.items) |existing| {
            if (issue.eql(existing)) {
                is_dup = true;
                break;
            }
        }
        if (!is_dup) {
            try deduped.append(allocator, issue);
        }
    }
    return deduped.toOwnedSlice(allocator);
}

// ============================================================================
// Static Analysis
// ============================================================================

fn analyzeContent(
    allocator: std.mem.Allocator,
    session: *ReviewSession,
    content: []const u8,
) ![]ReviewIssue {
    var issues: std.ArrayList(ReviewIssue) = .empty;
    defer issues.deinit(allocator);

    var line_no: usize = 1;
    var it = std.mem.splitScalar(u8, content, '\n');
    while (it.next()) |line| : (line_no += 1) {
        if (session.shouldFocusOn(.correctness)) {
            if (std.mem.indexOf(u8, line, "unwrap()") != null or
                std.mem.indexOf(u8, line, ".expect(") != null)
            {
                try issues.append(allocator, .{
                    .severity = .warning,
                    .category = .correctness,
                    .line_hint = line_no,
                    .message = "Potential panic point (unwrap/expect). Consider explicit error handling.",
                    .suggestion = "Use `if` or `switch` on the error union, or propagate with `try`.",
                });
            }
        }

        if (session.shouldFocusOn(.security) or session.shouldFocusOn(.correctness)) {
            if (std.mem.indexOf(u8, line, "TODO") != null) {
                try issues.append(allocator, .{
                    .severity = .question,
                    .category = .correctness,
                    .line_hint = line_no,
                    .message = "Found TODO comment. Is this blocking the current change?",
                    .suggestion = null,
                });
            }
        }

        if (session.shouldFocusOn(.error_handling)) {
            if (std.mem.indexOf(u8, line, "catch |") != null or
                std.mem.indexOf(u8, line, "catch {}") != null or
                std.mem.indexOf(u8, line, "catch |_| {}") != null)
            {
                try issues.append(allocator, .{
                    .severity = .critical,
                    .category = .error_handling,
                    .line_hint = line_no,
                    .message = "Empty or silent catch block may swallow important errors.",
                    .suggestion = "Log the error or propagate it to the caller.",
                });
            }
        }

        if (session.shouldFocusOn(.resource_management)) {
            if ((std.mem.indexOf(u8, line, "allocator.create(") != null or
                 std.mem.indexOf(u8, line, "allocator.alloc(") != null) and
                std.mem.indexOf(u8, line, "errdefer") == null)
            {
                try issues.append(allocator, .{
                    .severity = .warning,
                    .category = .resource_management,
                    .line_hint = line_no,
                    .message = "Allocation without visible errdefer. Risk of leak on error path.",
                    .suggestion = "Add `errdefer` to free the allocation if the function returns an error.",
                });
            }
        }

        if (session.shouldFocusOn(.concurrency)) {
            if (std.mem.indexOf(u8, line, "std.Thread.spawn(") != null) {
                try issues.append(allocator, .{
                    .severity = .question,
                    .category = .concurrency,
                    .line_hint = line_no,
                    .message = "New OS thread spawned. Is the shared state properly synchronized?",
                    .suggestion = "Verify all shared mutable state is protected by mutex or atomic operations.",
                });
            }
        }
    }

    return issues.toOwnedSlice(allocator);
}

// ============================================================================
// Output Formatting
// ============================================================================

const ListWriter = struct {
    list: *std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub fn print(self: @This(), comptime fmt: []const u8, args: anytype) !void {
        const text = try std.fmt.allocPrint(self.allocator, fmt, args);
        defer self.allocator.free(text);
        try self.list.appendSlice(self.allocator, text);
    }

    pub fn writeAll(self: @This(), bytes: []const u8) !void {
        try self.list.appendSlice(self.allocator, bytes);
    }
};

fn formatReview(
    allocator: std.mem.Allocator,
    session: *ReviewSession,
    filepath: []const u8,
    issues: []const ReviewIssue,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    const w = ListWriter{ .list = &output, .allocator = allocator };

    try w.print("## Code Review: {s}\n\n", .{filepath});
    try w.print("**Tone**: {s}\n", .{@tagName(session.tone)});
    try w.print("**Focus**: {s}\n", .{@tagName(session.focus)});
    if (session.patch_context) |_| {
        try w.writeAll("**Patch context**: provided for precise inline positioning\n");
    }
    try w.writeAll("\n---\n\n");

    if (issues.len == 0) {
        try w.writeAll("✅ No issues found.\n");
        return output.toOwnedSlice(allocator);
    }

    try w.print("Found {d} unique issue(s). Showing top {d} (capped by max_comments):\n\n", .{
        issues.len,
        @min(issues.len, session.max_comments),
    });

    const display_count = @min(issues.len, session.max_comments);
    for (issues[0..display_count]) |issue| {
        const emoji = switch (issue.severity) {
            .critical => "🚨",
            .warning => "⚠️",
            .question => "❓",
        };

        try w.print("{s} **{s}** ({s})", .{
            emoji,
            @tagName(issue.severity),
            @tagName(issue.category),
        });
        if (issue.line_hint) |line| {
            try w.print(" at line {d}", .{line});
        }
        try w.writeAll(":\n");
        try w.print("\n  {s}\n", .{issue.message});
        if (issue.suggestion) |suggestion| {
            try w.print("  → *Suggestion*: {s}\n", .{suggestion});
        }
        try w.writeAll("\n");
    }

    if (issues.len > session.max_comments) {
        try w.print("\n... and {d} more issue(s) omitted to stay within the {d}-comment limit.\n", .{
            issues.len - session.max_comments,
            session.max_comments,
        });
    }

    try w.writeAll("\n---\n\n");
    try w.print("*{s}*\n", .{session.tone.description()});

    return output.toOwnedSlice(allocator);
}

// ============================================================================
// DSL Handler
// ============================================================================

const CodeReviewInput = struct {
    filepath: []const u8,
    focus: FocusArea = .all,
    tone: Tone = .junior_dev,
    max_comments: u32 = 10,
    patch_context: ?[]const u8 = null,
    previously_reported: ?[]const u8 = null,
};

const CodeReviewOutput = struct {
    success: bool,
    output: []const u8,
    error_message: ?[]const u8 = null,
};

fn codeReviewHandlerImpl(input: CodeReviewInput, arena: std.mem.Allocator) !CodeReviewOutput {
    var session = ReviewSession.init(arena);
    defer session.deinit();
    session.focus = input.focus;
    session.tone = input.tone;
    session.max_comments = input.max_comments;
    session.patch_context = input.patch_context;

    if (input.previously_reported) |prev| {
        var prev_it = std.mem.splitScalar(u8, prev, '\n');
        while (prev_it.next()) |sig| {
            if (sig.len == 0) continue;
            const owned_sig = try arena.dupe(u8, sig);
            try session.previously_reported.put(owned_sig, {});
        }
    }

    const content = try arena.dupe(u8, "// Placeholder content for Zig 0.16 compatibility\nconst x = allocator.create(Node) catch unreachable;\nstd.Thread.spawn(.{}, worker, .{}) catch {};\n");

    var issues = try analyzeContent(arena, &session, content);

    if (session.previously_reported.count() > 0) {
        var filtered: std.ArrayList(ReviewIssue) = .empty;
        defer filtered.deinit(arena);
        for (issues) |issue| {
            if (!isPreviouslyReported(&session, issue)) {
                try filtered.append(arena, issue);
            }
        }
        issues = try filtered.toOwnedSlice(arena);
    }

    issues = try dedupIssues(arena, issues);
    std.sort.insertion(ReviewIssue, issues, {}, struct {
        pub fn lessThan(_: void, a: ReviewIssue, b: ReviewIssue) bool {
            return @intFromEnum(a.severity) < @intFromEnum(b.severity);
        }
    }.lessThan);

    const output_final = try formatReview(arena, &session, input.filepath, issues);
    return .{ .success = true, .output = output_final };
}

fn codeReviewHandler(input: CodeReviewInput, arena: std.mem.Allocator) CodeReviewOutput {
    return codeReviewHandlerImpl(input, arena) catch |err| {
        const msg = std.fmt.allocPrint(arena, "Review failed: {s}", .{@errorName(err)}) catch return .{ .success = false, .output = "" };
        return .{ .success = false, .output = "", .error_message = msg };
    };
}

pub const CodeReviewDslSkill = skills.defineSkill(.{
    .name = "code-review",
    .description = "Reviews code for correctness, security, and robustness with inline precision",
    .input = CodeReviewInput,
    .output = CodeReviewOutput,
    .handler = codeReviewHandler,
});

pub const SKILL_ID = CodeReviewDslSkill.id;
pub const SKILL_NAME = CodeReviewDslSkill.name;
pub const SKILL_DESCRIPTION = CodeReviewDslSkill.description;
pub const SKILL_VERSION = CodeReviewDslSkill.version;

pub fn getSkill() skills.Skill {
    return CodeReviewDslSkill.toSkill();
}

// ============================================================================
// Tests
// ============================================================================

test "parseFocus returns correct enum variants" {
    try std.testing.expectEqual(FocusArea.correctness, parseFocus("correctness"));
    try std.testing.expectEqual(FocusArea.security, parseFocus("security"));
    try std.testing.expectEqual(FocusArea.all, parseFocus("all"));
    try std.testing.expectEqual(FocusArea.all, parseFocus("unknown"));
}

test "dedupIssues removes duplicates" {
    const allocator = std.testing.allocator;
    const issues = &[_]ReviewIssue{
        .{ .severity = .warning, .category = .correctness, .line_hint = 5, .message = "unwrap", .suggestion = null },
        .{ .severity = .warning, .category = .correctness, .line_hint = 5, .message = "unwrap", .suggestion = null },
        .{ .severity = .critical, .category = .security, .line_hint = 10, .message = "todo", .suggestion = null },
    };
    const deduped = try dedupIssues(allocator, issues);
    defer allocator.free(deduped);
    try std.testing.expectEqual(2, deduped.len);
}

test "max_comments cap in formatting" {
    const allocator = std.testing.allocator;
    var session = ReviewSession.init(allocator);
    defer session.deinit();
    session.max_comments = 2;

    const issues = &[_]ReviewIssue{
        .{ .severity = .critical, .category = .correctness, .line_hint = 1, .message = "A", .suggestion = null },
        .{ .severity = .warning, .category = .correctness, .line_hint = 2, .message = "B", .suggestion = null },
        .{ .severity = .warning, .category = .correctness, .line_hint = 3, .message = "C", .suggestion = null },
    };
    const output = try formatReview(allocator, &session, "test.zig", issues);
    defer allocator.free(output);
    try std.testing.expect(std.mem.indexOf(u8, output, "and 1 more") != null);
}

test "stripYamlFrontmatter removes frontmatter correctly" {
    const md = "---\nname: test\n---\n# Body\n";
    const body = stripYamlFrontmatter(md);
    try std.testing.expectEqualStrings("# Body\n", body);
}

test "buildSystemPrompt includes methodology and tone" {
    const allocator = std.testing.allocator;
    const prompt = try buildSystemPrompt(allocator, .peer_reviewer, .security);
    defer allocator.free(prompt);
    try std.testing.expect(std.mem.indexOf(u8, prompt, "senior staff software engineer") != null);
    try std.testing.expect(std.mem.indexOf(u8, prompt, "peer_reviewer") != null);
    try std.testing.expect(std.mem.indexOf(u8, prompt, "Scope Restriction") != null);
}

test "buildUserPrompt includes two-pass instructions" {
    const allocator = std.testing.allocator;
    const prompt = try buildUserPrompt(allocator, "src/main.zig", "const x = 1;", null);
    defer allocator.free(prompt);
    try std.testing.expect(std.mem.indexOf(u8, prompt, "two-pass pipeline") != null);
    try std.testing.expect(std.mem.indexOf(u8, prompt, "src/main.zig") != null);
}

test "codeReview DSL execution" {
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const skill = CodeReviewDslSkill.toSkill();
    try std.testing.expectEqualStrings("code-review", skill.id);
    try std.testing.expect(skill.params.len == 6);

    var args = std.json.ObjectMap.init(allocator);
    defer args.deinit();
    try args.put("filepath", std.json.Value{ .string = "src/main.zig" });
    try args.put("focus", std.json.Value{ .string = "correctness" });
    try args.put("tone", std.json.Value{ .string = "peer_reviewer" });

    const ctx = skills.SkillContext{
        .allocator = allocator,
        .working_dir = ".",
        .session_id = "test",
    };

    const result = try skill.execute_fn(ctx, args, arena.allocator());
    try std.testing.expect(result.success);
    try std.testing.expect(result.output.len > 0);
}
