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

        if (phase == .task_breakdown and retry_report.result == .pass) {
            try generateTasksFromBreakdown(allocator, project);
        }
        return PhaseResult.init(allocator, mapReviewResult(retry_report.result), retry_report.feedback);
    }

    if (phase == .task_breakdown and report.result == .pass) {
        try generateTasksFromBreakdown(allocator, project);
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

/// After Phase 4 (task_breakdown) passes review, parse the breakdown markdown
/// table and generate T-XXX.md task files in tasks/active/sprint-current/.
fn generateTasksFromBreakdown(allocator: std.mem.Allocator, project: *project_mod.Project) !void {
    const doc_path = try std.fs.path.join(allocator, &.{ project.dir_path, project_mod.Phase.task_breakdown.docName() });
    defer allocator.free(doc_path);

    const content = try fs.readFileAlloc(allocator, doc_path, 256 * 1024);
    defer allocator.free(content);

    // Find ## Tasks section
    const tasks_heading = "## Tasks";
    const tasks_start = std.mem.indexOf(u8, content, tasks_heading) orelse {
        std.log.warn("Task Breakdown document missing '## Tasks' section; no tasks generated.", .{});
        return;
    };
    const section = content[tasks_start + tasks_heading.len ..];

    // Find the end of the section (next ## heading or end of file)
    const section_end = std.mem.indexOf(u8, section, "\n## ") orelse section.len;
    const tasks_block = section[0..section_end];

    // Output directory
    const out_dir = "tasks/active/sprint-current";
    fs.makeDirRecursive(out_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    var lines = std.mem.splitScalar(u8, tasks_block, '\n');
    var generated: usize = 0;
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;
        if (std.mem.startsWith(u8, trimmed, "|")) {
            // Skip header separator
            if (std.mem.indexOf(u8, trimmed, "---") != null) continue;
            if (try parseTaskRowAndWrite(allocator, trimmed, out_dir, project.name)) {
                generated += 1;
            }
        }
    }

    std.log.info("Generated {d} tasks from breakdown into {s}", .{ generated, out_dir });
}

/// Parse a single markdown table row like `| T-129 | Title | p0 | 16 |`
/// and write the corresponding task file.
fn parseTaskRowAndWrite(allocator: std.mem.Allocator, row: []const u8, out_dir: []const u8, project_name: []const u8) !bool {
    // Split by '|' and trim each field
    var fields: [6][]const u8 = undefined;
    var field_count: usize = 0;

    var it = std.mem.splitScalar(u8, row, '|');
    while (it.next()) |raw| {
        const f = std.mem.trim(u8, raw, " \t\r");
        if (f.len == 0) continue; // skip empty splits before first and after last |
        if (field_count >= fields.len) return false;
        fields[field_count] = f;
        field_count += 1;
    }

    // Expect at least 4 columns: ID, Title, Priority, Estimated Hours
    if (field_count < 4) return false;

    const id = fields[0];
    const title = fields[1];
    const priority = fields[2];
    const hours = fields[3];

    // Skip header row accidentally passed in
    if (std.mem.eql(u8, id, "ID")) return false;

    const filename = try std.fmt.allocPrint(allocator, "{s}.md", .{id});
    defer allocator.free(filename);
    const filepath = try std.fs.path.join(allocator, &.{ out_dir, filename });
    defer allocator.free(filepath);

    const task_doc = try std.fmt.allocPrint(allocator,
        \\---
        \\id: {s}
        \\title: "{s}"
        \\status: todo
        \\priority: {s}
        \\estimated_hours: {s}
        \\dependencies: []
        \\max_steps: 50
        \\---
        \\n        \\# {s}: {s}
        \\n        \\## 参考文档
        \\n        \\- Spec: `docs/specs/{s}-design.md`
        \\n        \\## 背景
        \\n        \\Auto-generated from Phase 4 Task Breakdown for project "{s}".
        \\n        \\## 目标
        \\n        \\- 
        \\n        \\## 验收标准
        \\n        \\- [ ] 
        \\n        \\## Log
        \\n        \\- **2026-04-06**: Created by TaskEngine Phase 4.
    , .{
        id, title, priority, hours,
        id, title,
        id,
        project_name,
    });
    defer allocator.free(task_doc);

    try fs.writeFile(filepath, task_doc);
    return true;
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

test "parseTaskRowAndWrite generates correct task file" {
    const allocator = std.testing.allocator;
    const tmp_dir = "/tmp/kimiz_phase_test_tasks";
    try fs.makeDirRecursive(tmp_dir);
    defer fs.deleteTree(tmp_dir) catch {};

    const row = "| T-999 | Test Task Title | p1 | 8 |";
    const ok = try parseTaskRowAndWrite(allocator, row, tmp_dir, "TestProject");
    try std.testing.expect(ok);

    const filepath = try std.fs.path.join(allocator, &.{ tmp_dir, "T-999.md" });
    defer allocator.free(filepath);
    const content = try fs.readFileAlloc(allocator, filepath, 64 * 1024);
    defer allocator.free(content);

    try std.testing.expect(std.mem.indexOf(u8, content, "id: T-999") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "title: \"Test Task Title\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "priority: p1") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "estimated_hours: 8") != null);
}

test "generateTasksFromBreakdown parses markdown table" {
    const allocator = std.testing.allocator;
    const tmp_project_dir = "/tmp/kimiz_phase_test_proj";
    try fs.makeDirRecursive(tmp_project_dir);
    defer fs.deleteTree(tmp_project_dir) catch {};
    defer fs.deleteTree("tasks/active/sprint-current") catch {};

    var project = try project_mod.Project.init(allocator, "proj-001", "Demo", tmp_project_dir);
    defer project.deinit();

    const breakdown =
        \\---
        \\name: Demo
        \\phase: task_breakdown
        \\status: in_progress
        \\---
        \\n        \\# Task Breakdown
        \\n        \\## Tasks
        \\n        \\| ID | Title | Priority | Estimated Hours |
        \\|---|---|---|---|
        \\| T-001 | First task | p0 | 4 |
        \\| T-002 | Second task | p1 | 8 |
        \\n        \\## Dependencies
        \\n        \\-
    ;

    const doc_path = try std.fs.path.join(allocator, &.{ project.dir_path, "04-task-breakdown.md" });
    defer allocator.free(doc_path);
    try fs.writeFile(doc_path, breakdown);

    try generateTasksFromBreakdown(allocator, &project);

    const task1 = try std.fs.path.join(allocator, &.{ "tasks/active/sprint-current", "T-001.md" });
    defer allocator.free(task1);
    const t1 = try fs.readFileAlloc(allocator, task1, 64 * 1024);
    defer allocator.free(t1);
    try std.testing.expect(std.mem.indexOf(u8, t1, "id: T-001") != null);

    const task2 = try std.fs.path.join(allocator, &.{ "tasks/active/sprint-current", "T-002.md" });
    defer allocator.free(task2);
    const t2 = try fs.readFileAlloc(allocator, task2, 64 * 1024);
    defer allocator.free(t2);
    try std.testing.expect(std.mem.indexOf(u8, t2, "id: T-002") != null);
}
