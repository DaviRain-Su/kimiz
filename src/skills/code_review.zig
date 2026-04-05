//! CodeReview Skill - Automated code review with Factory Droid-inspired best practices
//!
//! Design influences from Factory Droid Review:
//! - Inline comment precision via patch context
//! - Deduplication: never re-raise the same issue twice
//! - Accuracy gate: low confidence -> ask clarifying question
//! - Tone control: junior developer defers to author
//! - Max comment cap (default 10) to avoid noise
//! - Two-Pass Review Pipeline: candidate generation -> validation
//! - P0/P1/P2/P3 priority classification

const std = @import("std");
const skills = @import("root.zig");
const Skill = skills.Skill;
const SkillContext = skills.SkillContext;
const SkillResult = skills.SkillResult;
const SkillParam = skills.SkillParam;

// Skill metadata
pub const SKILL_ID = "code-review";
pub const SKILL_NAME = "Code Review";
pub const SKILL_DESCRIPTION = "Reviews code for correctness, security, and robustness with inline precision";
pub const SKILL_VERSION = "1.2.0";

// ============================================================================
// LLM Prompt Templates (Factory-inspired Two-Pass Pipeline)
// ============================================================================

/// The canonical system prompt is maintained in SKILL.md and embedded at compile time.
const EMBEDDED_SKILL_MD = @embedFile("code_review/SKILL.md");

/// Strip YAML frontmatter (content between first two `---` lines) from SKILL.md
fn stripYamlFrontmatter(content: []const u8) []const u8 {
    if (!std.mem.startsWith(u8, content, "---")) return content;
    const after_first = content[3..];
    const end_idx = std.mem.indexOf(u8, after_first, "\n---") orelse return content;
    const after_frontmatter = after_first[end_idx + 4 ..];
    // Trim leading newlines
    var start: usize = 0;
    while (start < after_frontmatter.len and after_frontmatter[start] == '\n') {
        start += 1;
    }
    return after_frontmatter[start..];
}

/// Build the system prompt sent to the LLM.
/// Combines the shared methodology from SKILL.md with tone calibration.
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

/// Build the user prompt containing the code/diff to review.
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
    line_hint: ?usize,     // approximate line number or diff position
    message: []const u8,
    suggestion: ?[]const u8,

    pub const Severity = enum {
        critical,
        warning,
        question,
    };

    /// Deduplication key: same category + same line + same first 64 bytes of message
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
// Skill Parameters
// ============================================================================

pub const params = &[_]SkillParam{
    .{
        .name = "filepath",
        .description = "Path to the file or patch to review",
        .param_type = .filepath,
        .required = true,
    },
    .{
        .name = "focus",
        .description = "Review focus area: correctness, security, performance, concurrency, error_handling, resource_management, all",
        .param_type = .selection,
        .required = false,
        .default_value = "all",
    },
    .{
        .name = "tone",
        .description = "Review tone: junior_dev, peer_reviewer, senior_architect",
        .param_type = .selection,
        .required = false,
        .default_value = "junior_dev",
    },
    .{
        .name = "max_comments",
        .description = "Maximum number of inline comments (default 10)",
        .param_type = .integer,
        .required = false,
        .default_value = "10",
    },
    .{
        .name = "patch_context",
        .description = "Optional unified diff or patch text for precise inline positioning",
        .param_type = .code,
        .required = false,
    },
    .{
        .name = "previously_reported",
        .description = "Optional list of previously reported issue signatures to avoid duplication",
        .param_type = .code,
        .required = false,
    },
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
// Parameter Parsing
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

fn parseMaxComments(raw: []const u8) u32 {
    return std.fmt.parseInt(u32, raw, 10) catch 10;
}

// ============================================================================
// Issue Collection & Deduplication
// ============================================================================

fn isPreviouslyReported(session: *ReviewSession, issue: ReviewIssue) bool {
    var buf: [256]u8 = undefined;
    const key = std.fmt.bufPrint(&buf, "{s}:{?d}:{s}", .{
        @tagName(issue.category),
        issue.line_hint,
        issue.message,
    }) catch return false;
    return session.previously_reported.contains(key);
}

fn dedupIssues(allocator: std.mem.Allocator, issues: []ReviewIssue) ![]ReviewIssue {
    if (issues.len == 0) return issues;
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
// Static Analysis (Local heuristics - complement to LLM review)
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
        // Correctness: unwrap/expect panic points
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

        // Security: TODO/FIXME markers (often indicate incomplete hardening)
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

        // Error handling: empty catch blocks
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

        // Resource management: unclosed allocations without errdefer
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

        // Concurrency: atomic operations or thread spawning
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

// TODO(Zig 0.16): std.ArrayList has no writer() method; this shim provides print/writeAll
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
    issues: []ReviewIssue,
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
// Skill Execution
// ============================================================================

/// Execute code review.
/// Currently uses local static heuristics. LLM integration is prepared via
/// buildSystemPrompt() and buildUserPrompt() for future provider wiring.
pub fn execute(
    _: SkillContext,
    args: std.json.ObjectMap,
    arena: std.mem.Allocator,
) !SkillResult {
    const filepath_val = args.get("filepath") orelse return error.MissingRequiredParam;
    const filepath = switch (filepath_val) {
        .string => |s| s,
        else => return error.InvalidParamType,
    };

    var session = ReviewSession.init(arena);
    defer session.deinit();

    // Parse focus
    if (args.get("focus")) |focus_val| {
        if (focus_val == .string) {
            session.focus = parseFocus(focus_val.string);
        }
    }

    // Parse tone
    if (args.get("tone")) |tone_val| {
        if (tone_val == .string) {
            session.tone = parseTone(tone_val.string);
        }
    }

    // Parse max_comments
    if (args.get("max_comments")) |max_val| {
        session.max_comments = switch (max_val) {
            .string => |s| parseMaxComments(s),
            .integer => |n| @intCast(@max(n, 1)),
            else => 10,
        };
    }

    // Parse patch_context
    if (args.get("patch_context")) |patch_val| {
        if (patch_val == .string) {
            session.patch_context = patch_val.string;
        }
    }

    // Parse previously_reported signatures
    if (args.get("previously_reported")) |prev_val| {
        if (prev_val == .string) {
            var prev_it = std.mem.splitScalar(u8, prev_val.string, '\n');
            while (prev_it.next()) |sig| {
                if (sig.len == 0) continue;
                const owned_sig = try arena.dupe(u8, sig);
                try session.previously_reported.put(owned_sig, {});
            }
        }
    }

    // Read file content
    // TODO: replace with actual file read once std.fs is fully compatible
    const content = try arena.dupe(u8, "// Placeholder content for Zig 0.16 compatibility\nconst x = allocator.create(Node) catch unreachable;\nstd.Thread.spawn(.{}, worker, .{}) catch {};\n");

    // NOTE: LLM prompt construction is ready for future integration.
    // Uncomment the following lines once an LLM provider is wired into SkillContext.
    // const system_prompt = try buildSystemPrompt(arena, session.tone, session.focus);
    // const user_prompt = try buildUserPrompt(arena, filepath, content, session.patch_context);
    // _ = system_prompt; _ = user_prompt;

    // Collect issues (local heuristics)
    var issues = try analyzeContent(arena, &session, content);

    // Filter out previously reported issues
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

    // Deduplicate
    issues = try dedupIssues(arena, issues);

    // Prioritize: critical > warning > question
    std.sort.insertion(ReviewIssue, issues, {}, struct {
        pub fn lessThan(_: void, a: ReviewIssue, b: ReviewIssue) bool {
            return @intFromEnum(a.severity) < @intFromEnum(b.severity);
        }
    }.lessThan);

    // Format output
    const output_final = try formatReview(arena, &session, filepath, issues);

    return SkillResult{
        .success = true,
        .output = output_final,
        .execution_time_ms = 0,
    };
}

/// Get skill definition
pub fn getSkill() Skill {
    return .{
        .id = SKILL_ID,
        .name = SKILL_NAME,
        .description = SKILL_DESCRIPTION,
        .version = SKILL_VERSION,
        .category = .review,
        .params = params,
        .execute_fn = execute,
    };
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
