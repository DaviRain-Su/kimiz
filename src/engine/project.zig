const std = @import("std");

// ============================================================================
// Phase (7-phase development methodology)
// ============================================================================

pub const Phase = enum(u8) {
    prd = 1,
    architecture = 2,
    technical_spec = 3,
    task_breakdown = 4,
    test_spec = 5,
    implementation = 6,
    review_deploy = 7,

    pub fn next(self: Phase) ?Phase {
        return switch (self) {
            .prd => .architecture,
            .architecture => .technical_spec,
            .technical_spec => .task_breakdown,
            .task_breakdown => .test_spec,
            .test_spec => .implementation,
            .implementation => .review_deploy,
            .review_deploy => null,
        };
    }

    pub fn docName(self: Phase) []const u8 {
        return switch (self) {
            .prd => "01-prd.md",
            .architecture => "02-architecture.md",
            .technical_spec => "03-technical-spec.md",
            .task_breakdown => "04-task-breakdown.md",
            .test_spec => "05-test-spec.md",
            .implementation => "06-implementation.md",
            .review_deploy => "07-review-deploy.md",
        };
    }
};

// ============================================================================
// Project
// ============================================================================

pub const Project = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    name: []const u8,
    dir_path: []const u8,
    current_phase: Phase,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        id: []const u8,
        name: []const u8,
        base_dir: []const u8,
    ) !Self {
        const path = try std.fs.path.join(allocator, &.{ base_dir, id });
        errdefer allocator.free(path);

        return .{
            .allocator = allocator,
            .id = try allocator.dupe(u8, id),
            .name = try allocator.dupe(u8, name),
            .dir_path = path,
            .current_phase = .prd,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.id);
        self.allocator.free(self.name);
        self.allocator.free(self.dir_path);
    }

    pub fn phaseDocPath(self: *const Self, phase: Phase) ![]const u8 {
        return self.allocator.dupe(u8, phase.docName());
    }

    pub fn canAdvance(self: *const Self, current: Phase) bool {
        _ = self;
        return current.next() != null;
    }

    pub fn advancePhase(self: *Self) bool {
        if (self.current_phase.next()) |next_phase| {
            self.current_phase = next_phase;
            return true;
        }
        return false;
    }
};

// ============================================================================
// getCurrentPhase — Determine phase by filesystem document existence
// ============================================================================

pub fn getCurrentPhase(dir_path: []const u8) !Phase {
    const dir = try std.fs.openDirAbsolute(dir_path, .{});

    const phases = [_]Phase{
        .prd,
        .architecture,
        .technical_spec,
        .task_breakdown,
        .test_spec,
        .implementation,
        .review_deploy,
    };

    for (phases) |phase| {
        dir.access(phase.docName(), .{}) catch {
            return phase;
        };
    }

    // All documents exist - project is complete
    return .review_deploy;
}

// ============================================================================
// createProject — Create project directory with initial PRD template
// ============================================================================

pub const CreateProjectOpts = struct {
    base_dir: []const u8 = "projects",
    sprint_name: []const u8 = "sprint-current",
};

// Generate a simple project ID
pub fn generateProjectId(allocator: std.mem.Allocator, counter: u32) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "proj-{d:0>4}", .{counter});
}

pub fn createProject(
    allocator: std.mem.Allocator,
    name: []const u8,
    opts: CreateProjectOpts,
) !Project {
    const id = try generateProjectId(allocator, 0);
    errdefer allocator.free(id);

    const full_path = try std.fs.path.join(allocator, &.{ opts.base_dir, id });
    errdefer allocator.free(full_path);

    // Create directory
    try std.fs.makeDirAbsolute(full_path);

    // Write PRD template
    const prd_path = try std.fs.path.join(allocator, &.{ full_path, Phase.prd.docName() });
    errdefer allocator.free(prd_path);

    const prd_template =
        \\---
        \\name: {s}
        \\phase: prd
        \\status: in_progress
        \\---
        \\
        \\# Product Requirements Document
        \\
        \\## Problem Statement
        \\
        \\{s}
        \\
        \\## Goals
        \\
        \\- 
        \\
        \\## Non-Goals
        \\
        \\- 
        \\
        \\## Success Criteria
        \\
        \\- 
    ;

    const prd_content = try std.fmt.allocPrint(allocator, prd_template, .{ name, name });
    defer allocator.free(prd_content);

    const file = try std.fs.createFileAbsolute(prd_path, .{});
    defer file.close();
    try file.writeAll(prd_content);

    return try Project.init(allocator, id, name, full_path);
}

// ============================================================================
// Tests
// ============================================================================

test "Phase enum next" {
    try std.testing.expectEqual(Phase.architecture, Phase.prd.next());
    try std.testing.expectEqual(Phase.technical_spec, Phase.architecture.next());
    try std.testing.expectEqual(null, Phase.review_deploy.next());
}

test "Phase docName" {
    try std.testing.expectEqualStrings("01-prd.md", Phase.prd.docName());
    try std.testing.expectEqualStrings("07-review-deploy.md", Phase.review_deploy.docName());
}

test "Project init/deinit" {
    var p = try Project.init(std.testing.allocator, "proj-001", "Test Project", "/tmp");
    defer p.deinit();
    try std.testing.expectEqualStrings("proj-001", p.id);
    try std.testing.expectEqualStrings("Test Project", p.name);
    try std.testing.expectEqual(Phase.prd, p.current_phase);
}

test "Project advancePhase" {
    var p = try Project.init(std.testing.allocator, "proj-001", "Test", "/tmp");
    defer p.deinit();

    try std.testing.expectEqual(Phase.prd, p.current_phase);
    try std.testing.expect(p.advancePhase());
    try std.testing.expectEqual(Phase.architecture, p.current_phase);

    // Advance through all phases
    while (p.advancePhase()) {}
    try std.testing.expectEqual(Phase.review_deploy, p.current_phase);
    try std.testing.expect(!p.advancePhase()); // Already at the end
}

test "generateProjectId" {
    const id = try generateProjectId(std.testing.allocator, 42);
    defer std.testing.allocator.free(id);
    try std.testing.expect(id.len > 0);
    try std.testing.expect(std.mem.startsWith(u8, id, "proj-"));
}
