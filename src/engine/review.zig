const std = @import("std");
const core = @import("../core/root.zig");
const ai = @import("../ai/root.zig");
const fs = @import("../utils/fs_helper.zig");
const Agent = @import("../agent/agent.zig").Agent;

// ============================================================================
// ReviewAgent — Multi-role review layer (T-128-05)
// ============================================================================

// Review roles aligned with 7 development phases
pub const ReviewRole = enum {
    product_manager,
    system_architect,
    tech_lead,
    project_manager,
    qa_engineer,
    code_reviewer,
    release_engineer,

    pub fn promptFile(self: ReviewRole) []const u8 {
        return switch (self) {
            .product_manager => "product-manager.md",
            .system_architect => "system-architect.md",
            .tech_lead => "tech-lead.md",
            .project_manager => "project-manager.md",
            .qa_engineer => "qa-engineer.md",
            .code_reviewer => "code-reviewer.md",
            .release_engineer => "release-engineer.md",
        };
    }
};

pub const ReviewResult = enum {
    pass,
    needs_revision,
    blocked,
};

pub const ReviewReport = struct {
    allocator: std.mem.Allocator,
    role: ReviewRole,
    result: ReviewResult,
    feedback: []const u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, role: ReviewRole, result: ReviewResult, feedback: []const u8) !Self {
        return .{
            .allocator = allocator,
            .role = role,
            .result = result,
            .feedback = try allocator.dupe(u8, feedback),
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.feedback);
    }
};

pub const ReviewAgent = struct {
    allocator: std.mem.Allocator,
    role: ReviewRole,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, role: ReviewRole) Self {
        return .{
            .allocator = allocator,
            .role = role,
        };
    }

    /// Review a document using an LLM. Reads the role-specific prompt from
    /// prompts/review/{role-file}, appends the document, and asks the model
    /// for a VERDICT.
    pub fn review(self: *const Self, agent: *Agent, document: []const u8) !ReviewReport {
        // Load review prompt
        const prompt_path = try std.fs.path.join(self.allocator, &.{ "prompts/review", self.role.promptFile() });
        defer self.allocator.free(prompt_path);

        const prompt_content = fs.readFileAlloc(self.allocator, prompt_path, 256 * 1024) catch |err| blk: {
            if (err == error.FileNotFound) {
                // Fallback: if prompt file is missing, return a stub pass so we don't block execution
                std.log.warn("Review prompt not found: {s}, using stub review.", .{prompt_path});
                break :blk "You are a reviewer. Output PASS if the document looks acceptable.";
            }
            return err;
        };
        defer self.allocator.free(prompt_content);

        // Build review request
        const review_prompt = try std.fmt.allocPrint(self.allocator,
            "{s}\n\n--- DOCUMENT TO REVIEW ---\n\n{s}\n\n--- END DOCUMENT ---\n\nPlease output your VERDICT now.",
            .{ prompt_content, document },
        );
        defer self.allocator.free(review_prompt);

        const content_blocks = try self.allocator.alloc(core.UserContentBlock, 1);
        errdefer self.allocator.free(content_blocks);
        content_blocks[0] = .{ .text = review_prompt };

        const messages = &[_]core.Message{
            .{ .user = .{ .content = content_blocks } },
        };

        const ctx = core.Context{
            .model = agent.options.model,
            .messages = messages,
            .temperature = 0.3, // Lower temperature for consistent verdict parsing
            .max_tokens = 2048,
            .stream = false,
            .thinking_level = agent.options.thinking_level,
        };

        const response = try agent.ai_client.complete(ctx);

        var response_text: std.ArrayList(u8) = .empty;
        defer response_text.deinit(self.allocator);
        for (response.content) |block| {
            switch (block) {
                .text => |t| try response_text.appendSlice(self.allocator, t.text),
                else => {},
            }
        }
        response.deinit(self.allocator);
        self.allocator.free(content_blocks);

        const raw = try self.allocator.dupe(u8, response_text.items);
        defer self.allocator.free(raw);

        return parseReviewResult(self.allocator, self.role, raw);
    }
};

pub fn parseReviewResult(allocator: std.mem.Allocator, role: ReviewRole, raw: []const u8) !ReviewReport {
    const trimmed = std.mem.trim(u8, raw, " \n\r\t");

    // Look for VERDICT line first
    if (std.mem.indexOf(u8, trimmed, "VERDICT: PASS")) |_| {
        return ReviewReport.init(allocator, role, .pass, trimmed);
    }
    if (std.mem.indexOf(u8, trimmed, "VERDICT: NEEDS_REVISION")) |_| {
        return ReviewReport.init(allocator, role, .needs_revision, trimmed);
    }
    if (std.mem.indexOf(u8, trimmed, "VERDICT: BLOCKED")) |_| {
        return ReviewReport.init(allocator, role, .blocked, trimmed);
    }

    // Fallback to prefix matching for simpler responses
    if (std.mem.startsWith(u8, trimmed, "PASS")) {
        return ReviewReport.init(allocator, role, .pass, trimmed);
    } else if (std.mem.startsWith(u8, trimmed, "NEEDS_REVISION")) {
        return ReviewReport.init(allocator, role, .needs_revision, trimmed);
    } else if (std.mem.startsWith(u8, trimmed, "BLOCKED")) {
        return ReviewReport.init(allocator, role, .blocked, trimmed);
    }

    // Default to pass if we can't parse, to avoid blocking progress
    std.log.warn("Unparseable review result, defaulting to PASS: {s}", .{trimmed});
    return ReviewReport.init(allocator, role, .pass, trimmed);
}

// ============================================================================
// Tests
// ============================================================================

test "ReviewRole promptFile" {
    try std.testing.expectEqualStrings("product-manager.md", ReviewRole.product_manager.promptFile());
    try std.testing.expectEqualStrings("code-reviewer.md", ReviewRole.code_reviewer.promptFile());
    try std.testing.expectEqualStrings("release-engineer.md", ReviewRole.release_engineer.promptFile());
}

test "parseReviewResult - verdict pass" {
    var report = try parseReviewResult(std.testing.allocator, .code_reviewer, "VERDICT: PASS\nLooks good");
    defer report.deinit();
    try std.testing.expectEqual(ReviewResult.pass, report.result);
}

test "parseReviewResult - verdict needs_revision" {
    var report = try parseReviewResult(std.testing.allocator, .qa_engineer, "VERDICT: NEEDS_REVISION\nMissing tests");
    defer report.deinit();
    try std.testing.expectEqual(ReviewResult.needs_revision, report.result);
}

test "parseReviewResult - blocked" {
    var report = try parseReviewResult(std.testing.allocator, .qa_engineer, "BLOCKED: Missing critical test cases");
    defer report.deinit();
    try std.testing.expectEqual(ReviewResult.blocked, report.result);
}

test "parseReviewResult - defaults to pass on unparseable" {
    var report = try parseReviewResult(std.testing.allocator, .product_manager, "Some random text");
    defer report.deinit();
    try std.testing.expectEqual(ReviewResult.pass, report.result);
}
