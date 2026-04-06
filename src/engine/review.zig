const std = @import("std");

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

    pub fn review(self: *const Self, document: []const u8) !ReviewReport {
        _ = document;

        // Stub: In production, this sends the prompt + document
        // to an LLM and parses the response
        return ReviewReport.init(self.allocator, self.role, .pass, "Review stub - LLM integration pending");
    }
};

pub fn parseReviewResult(allocator: std.mem.Allocator, role: ReviewRole, raw: []const u8) !ReviewReport {
    const trimmed = std.mem.trim(u8, raw, " \n\r\t");

    if (std.mem.startsWith(u8, trimmed, "PASS")) {
        return ReviewReport.init(allocator, role, .pass, trimmed);
    } else if (std.mem.startsWith(u8, trimmed, "NEEDS_REVISION")) {
        return ReviewReport.init(allocator, role, .needs_revision, trimmed);
    } else if (std.mem.startsWith(u8, trimmed, "BLOCKED")) {
        return ReviewReport.init(allocator, role, .blocked, trimmed);
    }

    return error.InvalidReviewResult;
}

// ============================================================================
// Tests
// ============================================================================

test "ReviewRole promptFile" {
    try std.testing.expectEqualStrings("product-manager.md", ReviewRole.product_manager.promptFile());
    try std.testing.expectEqualStrings("code-reviewer.md", ReviewRole.code_reviewer.promptFile());
    try std.testing.expectEqualStrings("release-engineer.md", ReviewRole.release_engineer.promptFile());
}

test "ReviewAgent review stub" {
    const agent = ReviewAgent.init(std.testing.allocator, .tech_lead);
    var report = try agent.review("test document");
    defer report.deinit();
    try std.testing.expectEqual(ReviewRole.tech_lead, report.role);
    try std.testing.expectEqual(ReviewResult.pass, report.result);
}

test "parseReviewResult - pass" {
    var report = try parseReviewResult(std.testing.allocator, .code_reviewer, "PASS - Looks good");
    defer report.deinit();
    try std.testing.expectEqual(ReviewResult.pass, report.result);
}

test "parseReviewResult - blocked" {
    var report = try parseReviewResult(std.testing.allocator, .qa_engineer, "BLOCKED: Missing critical test cases");
    defer report.deinit();
    try std.testing.expectEqual(ReviewResult.blocked, report.result);
}
