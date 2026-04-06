const std = @import("std");
const task = @import("task.zig");
const project = @import("project.zig");

// ============================================================================
// Orchestrator — 外部观察者，负责动态插入需求、状态机控制
// ============================================================================

/// 新需求的影响范围
pub const ImpactLevel = enum {
    @"prd",           // PRD 变更 → 回退到 Phase 1
    architecture,  // 架构变更 → 回退到 Phase 2
    technical,     // 技术实现变更 → 回退到 Phase 3
    tasks,         // 任务列表变更 → 回退到 Phase 4
    @"test_specs",  // 测试变更 → 回退到 Phase 5
    code,          // 实施层变更 → 当前任务插入
};

/// 新需求的放置决策
pub const PlacementDecision = struct {
    insert_into_queue: bool,
    target_phase: ?project.Phase, // null = 不改变 Phase
    rollback_required: bool,
    priority: task.TaskPriority,
    dependencies_ids: []const []const u8,
    reason: []const u8,
};

pub const Orchestrator = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    /// 评估新需求，决定放置策略
    pub fn evaluateNewNeed(
        self: *const Self,
        title: []const u8,
        description: []const u8,
        current_phase: project.Phase,
    ) !PlacementDecision {
        _ = self;
        _ = description;
        _ = current_phase;

        // 简单启发式决策：通过关键词分析 impact
        const lower_title = std.ascii.allocLowerString(std.testing.allocator, title) catch {
            return error.AllocationFailed;
        };
        defer std.testing.allocator.free(lower_title);

        // PRD 级别变更：包含 "需求", "PRD", "requirement", "user story" 等
        if (keyMatch(lower_title, &[_][]const u8{ "需求", "requirement", "prd", "user story" })) {
            return .{
                .insert_into_queue = false,
                .target_phase = .prd,
                .rollback_required = true,
                .priority = .p0,
                .dependencies_ids = &.{},
                .reason = "PRD-level change, rollback to Phase 1",
            };
        }

        // 架构变更：包含 "架构", "architecture", "design", "接口", "API"
        if (keyMatch(lower_title, &[_][]const u8{ "架构", "architecture", "design", "接口", "api", "interface" })) {
            return .{
                .insert_into_queue = false,
                .target_phase = .architecture,
                .rollback_required = true,
                .priority = .p0,
                .dependencies_ids = &.{},
                .reason = "Architecture change, rollback to Phase 2",
            };
        }

        // 默认：插入当前队列，不改变 Phase
        return .{
            .insert_into_queue = true,
            .target_phase = null, // 保持当前 Phase
            .rollback_required = false,
            .priority = .p2,
            .dependencies_ids = &.{},
            .reason = "Task-level addition, insert into queue",
        };
    }

    /// 根据决策插入任务
    pub fn insertTask(
        self: *const Self,
        ctx: *TaskInsertionContext,
        decision: *const PlacementDecision,
    ) !task.Task {
        const new_task = try task.Task.init(
            self.allocator,
            try generateTaskId(self.allocator),
            "New task",
            if (decision.insert_into_queue) task.TaskStatus.todo else task.TaskStatus.blocked,
            decision.priority,
            decision.dependencies_ids,
        );

        try ctx.queue.addTask(self.allocator, new_task);

        if (decision.rollback_required) {
            if (decision.target_phase) |phase| {
                rollbackProject(ctx.project, phase);
            }
        }

        return new_task;
    }

    /// 根据决策判断是否需要暂停当前任务
    pub fn shouldInterruptCurrent(
        self: *const Self,
        decision: *const PlacementDecision,
        next_task: ?*task.Task,
    ) bool {
        _ = self;
        // 如果需要回退状态机，且当前有正在执行的任务
        if (decision.rollback_required and next_task != null and next_task.?.status != .done) {
            return true;
        }
        return false;
    }
};

pub const TaskInsertionContext = struct {
    project: *project.Project,
    queue: *task.TaskQueue,
};

fn keyMatch(candidate: []const u8, keywords: []const []const u8) bool {
    for (keywords) |kw| {
        if (std.mem.indexOf(u8, candidate, kw) != null) return true;
    }
    return false;
}

fn generateTaskId(allocator: std.mem.Allocator) ![]u8 {
    return try allocator.dupe(u8, "T-DYNAMIC-001");
}

fn rollbackProject(proj: *project.Project, target: project.Phase) void {
    proj.current_phase = target;
}

// ============================================================================
// Tests
// ============================================================================

test "Orchestrator - PRD level requirement triggers rollback" {
    const orch = Orchestrator.init(std.testing.allocator);
    const decision = try orch.evaluateNewNeed(
        "新增用户需求",
        "需要添加登录功能",
        .implementation,
    );

    try std.testing.expect(decision.rollback_required);
    try std.testing.expectEqual(project.Phase.prd, decision.target_phase);
    try std.testing.expect(!decision.insert_into_queue);
    try std.testing.expectEqual(task.TaskPriority.p0, decision.priority);
}

test "Orchestrator - architecture change triggers rollback" {
    const orch = Orchestrator.init(std.testing.allocator);
    const decision = try orch.evaluateNewNeed(
        "修改系统架构",
        "需要从单体改为微服务",
        .technical_spec,
    );

    try std.testing.expect(decision.rollback_required);
    try std.testing.expectEqual(project.Phase.architecture, decision.target_phase);
}

test "Orchestrator - code level task inserts into queue" {
    const orch = Orchestrator.init(std.testing.allocator);
    const decision = try orch.evaluateNewNeed(
        "添加边界测试",
        "需要为空字符串添加处理",
        .implementation,
    );

    try std.testing.expect(decision.insert_into_queue);
    try std.testing.expect(decision.target_phase == null);
    try std.testing.expect(!decision.rollback_required);
}
