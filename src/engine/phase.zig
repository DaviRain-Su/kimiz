//! Phase execution engine - LLM-driven document generation (T-128)

const std = @import("std");
const project_mod = @import("project.zig");
const review_mod = @import("review.zig");
const core = @import("../core/root.zig");
const ai = @import("../ai/root.zig");
const fs = @import("../utils/fs_helper.zig");

pub const PhaseStatus = enum {
    done,
    needs_revision,
    blocked,
};

pub const PhaseResult = struct {
    status: PhaseStatus,
    feedback: []const u8,

    pub fn init(allocator: std.mem.Allocator, status: PhaseStatus, feedback: []const u8) !PhaseResult {
        return .{
            .status = status,
            .feedback = try allocator.dupe(u8, feedback),
        };
    }

    pub fn deinit(self: *PhaseResult, allocator: std.mem.Allocator) void {
        allocator.free(self.feedback);
    }
};

pub const Agent = @import("../agent/agent.zig").Agent;

/// Execute a single phase: generate document via LLM, validate structure,
/// and perform content review.
///
/// On success, writes the generated document to project_dir/0N-phase.md.
/// Returns the review result.
///
/// Retry logic: if review returns NEEDS_REVISION, we retry once more.
pub fn executePhase(
    allocator: std.mem.Allocator,
    agent: *Agent,
    project: *project_mod.Project,
    phase: project_mod.Phase,
) !PhaseResult {
    const doc_path = try std.fs.path.join(allocator, &.{ project.dir_path, phase.docName() });
    defer allocator.free(doc_path);

    // 1. Build author prompt
    const prompt = try buildAuthorPrompt(allocator, project, phase);
    defer allocator.free(prompt);

    // 2. Call LLM
    const assistant_msg = try callLlm(allocator, agent, prompt);
    defer allocator.free(assistant_msg);

    // 3. Write document
    try fs.writeFile(doc_path, assistant_msg);

    // 4. Structural validation
    const struct_ok = try project_mod.validatePhaseDocument(allocator, project.dir_path, phase);
    if (!struct_ok) {
        return PhaseResult.init(allocator, .needs_revision, "Generated document fails structural validation; missing required sections.");
    }

    // 5. Content review (with one retry on NEEDS_REVISION)
    var reviewer = review_mod.ReviewAgent.init(allocator, reviewRoleForPhase(phase));
    var report = try reviewer.review(agent, assistant_msg);
    defer report.deinit();

    if (report.result == .needs_revision) {
        std.log.warn("Phase {s} needs revision: {s}. Retrying once...", .{ @tagName(phase), report.feedback });

        // Regenerate with feedback as additional context
        const retry_prompt = try buildRevisionPrompt(allocator, project, phase, prompt, report.feedback);
        defer allocator.free(retry_prompt);

        const retry_msg = try callLlm(allocator, agent, retry_prompt);
        defer allocator.free(retry_msg);

        try fs.writeFile(doc_path, retry_msg);

        const retry_struct_ok = try project_mod.validatePhaseDocument(allocator, project.dir_path, phase);
        if (!retry_struct_ok) {
            return PhaseResult.init(allocator, .needs_revision, "Retry document still fails structural validation.");
        }

        var retry_report = try reviewer.review(agent, retry_msg);
        defer retry_report.deinit();

        return PhaseResult.init(allocator, mapReviewResult(retry_report.result), retry_report.feedback);
    }

    return PhaseResult.init(allocator, mapReviewResult(report.result), report.feedback);
}

fn mapReviewResult(r: review_mod.ReviewResult) PhaseStatus {
    return switch (r) {
        .pass => .done,
        .needs_revision => .needs_revision,
        .blocked => .blocked,
    };
}

fn reviewRoleForPhase(phase: project_mod.Phase) review_mod.ReviewRole {
    return switch (phase) {
        .prd => .product_manager,
        .architecture => .system_architect,
        .technical_spec => .tech_lead,
        .task_breakdown => .project_manager,
        .test_spec => .qa_engineer,
        .implementation => .code_reviewer,
        .review_deploy => .release_engineer,
    };
}

fn callLlm(allocator: std.mem.Allocator, agent: *Agent, prompt: []const u8) ![]const u8 {
    const system_text = "You are a senior software engineer following the KimiZ 7-phase development methodology. Produce only the requested markdown document with no extra commentary.\n\n";
    const full_content = try std.fmt.allocPrint(allocator, "{s}{s}", .{ system_text, prompt });
    defer allocator.free(full_content);

    const content_blocks = try allocator.alloc(core.UserContentBlock, 1);
    errdefer allocator.free(content_blocks);
    content_blocks[0] = .{ .text = full_content };

    const messages = &[_]core.Message{
        .{ .user = .{ .content = content_blocks } },
    };

    const ctx = core.Context{
        .model = agent.options.model,
        .messages = messages,
        .temperature = agent.options.temperature,
        .max_tokens = agent.options.max_tokens,
        .stream = false,
        .thinking_level = agent.options.thinking_level,
    };

    const response = try agent.ai_client.complete(ctx);

    var response_text: std.ArrayList(u8) = .empty;
    defer response_text.deinit(allocator);
    for (response.content) |block| {
        switch (block) {
            .text => |t| try response_text.appendSlice(allocator, t.text),
            else => {},
        }
    }

    response.deinit(allocator);
    allocator.free(content_blocks);
    return allocator.dupe(u8, response_text.items);
}

fn buildAuthorPrompt(
    allocator: std.mem.Allocator,
    project: *project_mod.Project,
    phase: project_mod.Phase,
) ![]const u8 {
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(allocator);

    try buf.appendSlice(allocator, "# Phase Document Authoring Task\n\n");
    try buf.appendSlice(allocator, "## Project\n- Name: ");
    try buf.appendSlice(allocator, project.name);
    try buf.appendSlice(allocator, "\n- Phase: ");
    try buf.appendSlice(allocator, @tagName(phase));
    try buf.appendSlice(allocator, "\n\n");

    // Include previous phase document as context when available
    if (phase != .prd) {
        if (phase.next()) |prev_phase| {
            const prev_doc = try std.fs.path.join(allocator, &.{ project.dir_path, prev_phase.docName() });
            defer allocator.free(prev_doc);
            const prev_content = fs.readFileAlloc(allocator, prev_doc, 256 * 1024) catch |err| blk: {
                if (err == error.FileNotFound) break :blk "";
                return err;
            };
            if (prev_content.len > 0) {
                defer allocator.free(prev_content);
                try buf.appendSlice(allocator, "## Previous Phase Document\n\n");
                try buf.appendSlice(allocator, "```markdown\n");
                try buf.appendSlice(allocator, prev_content);
                try buf.appendSlice(allocator, "\n```\n\n");
            }
        }
    }

    try buf.appendSlice(allocator, "## Template\n\n");
    try buf.appendSlice(allocator, phaseTemplate(phase));

    try buf.appendSlice(allocator, "\n\n## Instructions\n");
    try buf.appendSlice(allocator, "1. Write a complete, actionable markdown document following the template above.\n");
    try buf.appendSlice(allocator, "2. Start with YAML frontmatter exactly like the template.\n");
    try buf.appendSlice(allocator, "3. Do not output any explanatory text outside the document.\n");

    return buf.toOwnedSlice(allocator);
}

fn buildRevisionPrompt(
    allocator: std.mem.Allocator,
    project: *project_mod.Project,
    phase: project_mod.Phase,
    original_prompt: []const u8,
    feedback: []const u8,
) ![]const u8 {
    _ = project;
    _ = phase;
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(allocator);

    try buf.appendSlice(allocator, original_prompt);
    try buf.appendSlice(allocator, "\n\n## Revision Feedback\n\nThe previous version was reviewed with the following feedback. Please address it:\n\n");
    try buf.appendSlice(allocator, feedback);
    try buf.appendSlice(allocator, "\n");

    return buf.toOwnedSlice(allocator);
}

fn phaseTemplate(phase: project_mod.Phase) []const u8 {
    return switch (phase) {
        .prd =>
            \\---
            \\name: <project-name>
            \\phase: prd
            \\status: in_progress
            \\---
            \\n            \\# Product Requirements Document
            \\n            \\## Problem Statement
            \\n            \\<clear description of the problem>
            \\n            \\## Goals
            \\n            \\- <measurable goal 1>
            \\n            \\## Non-Goals
            \\n            \\- <explicitly out of scope>
            \\n            \\## Success Criteria
            \\n            \\- <criterion 1>
            ,
        .architecture =>
            \\---
            \\name: <project-name>
            \\phase: architecture
            \\status: in_progress
            \\---
            \\n            \\# Architecture
            \\n            \\## Overview
            \\n            \\<high-level architecture summary>
            \\n            \\## Components
            \\n            \\- <component 1>
            \\n            \\## Data Flow
            \\n            \\- <step 1>
            \\n            \\## Trade-offs
            \\n            \\- <trade-off 1>
            ,
        .technical_spec =>
            \\---
            \\name: <project-name>
            \\phase: technical_spec
            \\status: in_progress
            \\---
            \\n            \\# Technical Specification
            \\n            \\## Overview
            \\n            \\<technical approach>
            \\n            \\## Impact Files
            \\n            \\- <file 1>
            \\n            \\## API Changes
            \\n            \\- <change 1>
            \\n            \\## Acceptance Criteria
            \\n            \\- [ ] <criterion 1>
            ,
        .task_breakdown =>
            \\---
            \\name: <project-name>
            \\phase: task_breakdown
            \\status: in_progress
            \\---
            \\n            \\# Task Breakdown
            \\n            \\## Tasks
            \\n            \\| ID | Title | Priority | Estimated Hours |
            \\|---|---|---|---|
            \\n            \\## Dependencies
            \\n            \\- <dependency 1>
            ,
        .test_spec =>
            \\---
            \\name: <project-name>
            \\phase: test_spec
            \\status: in_progress
            \\---
            \\n            \\# Test Specification
            \\n            \\## Test Strategy
            \\n            \\<strategy>
            \\n            \\## Unit Tests
            \\n            \\- <test 1>
            \\n            \\## Integration Tests
            \\n            \\- <test 1>
            ,
        .implementation =>
            \\---
            \\name: <project-name>
            \\phase: implementation
            \\status: in_progress
            \\---
            \\n            \\# Implementation Log
            \\n            \\## Progress
            \\n            \\- <update 1>
            ,
        .review_deploy =>
            \\---
            \\name: <project-name>
            \\phase: review_deploy
            \\status: in_progress
            \\---
            \\n            \\# Review & Deploy
            \\n            \\## Review Summary
            \\n            \\- <item 1>
            \\n            \\## Deployment Notes
            \\n            \\- <note 1>
            ,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "reviewRoleForPhase maps correctly" {
    try std.testing.expectEqual(review_mod.ReviewRole.product_manager, reviewRoleForPhase(.prd));
    try std.testing.expectEqual(review_mod.ReviewRole.system_architect, reviewRoleForPhase(.architecture));
    try std.testing.expectEqual(review_mod.ReviewRole.tech_lead, reviewRoleForPhase(.technical_spec));
}

test "phaseTemplate produces non-empty strings" {
    for ([_]project_mod.Phase{ .prd, .architecture, .technical_spec, .task_breakdown, .test_spec, .implementation, .review_deploy }) |phase| {
        const tmpl = phaseTemplate(phase);
        try std.testing.expect(tmpl.len > 0);
    }
}
