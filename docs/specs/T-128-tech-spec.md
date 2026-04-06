# T-128 Technical Spec: KimiZ TaskEngine & SubAgent Budget

**Version**: 1.0
**Date**: 2026-04-06
**State**: Phase 3 (Technical Spec)

---

## 1. 概述

TaskEngine 是 KimiZ 的"项目经理"，负责：
1. 管理 7-phase 项目的状态流转
2. 控制 SubAgent 的执行预算（token/cost/step）
3. 拆分和调度 Task 的执行
4. 多角色 Review 评审 Phase 产出

**Scope**: KimiZ 定位为 coding agent，运行在用户本机。SubAgent 隔离以 **git worktree** 为主，不做容器级物理隔离。

---

## 2. 架构概览

```
Project (7-phase)
├── Phase 1: PRD
├── Phase 2: Architecture
├── Phase 3: Technical Spec
├── Phase 4: Task Breakdown
├── Phase 5: Test Spec
├── Phase 6: Implementation
└── Phase 7: Review & Deploy

TaskEngine
├── ProjectEngine — Phase 状态机
├── TaskQueue — Task 加载/依赖/调度
├── SubBudget — SubAgent 预算控制
├── ReviewGate — 角色评审
└── PromptLoader — Prompt cascade 加载
```

---

## 3. SubAgent Budget

### 3.1 Budget 结构

```zig
pub const SubBudget = struct {
    max_tokens: u32 = 100_000,     /// 总 token 上限（input + output）
    max_cost_cents: u64 = 500,     /// 费用上限（美分，默认 $5）
    max_steps: u32 = 50,           /// 最大 LLM 调用次数
    max_output_bytes: usize = 65536, /// 结果大小限制（64KB）
    max_wall_ms: u64 = 300_000,    /// 执行时间上限（5 分钟）
};
```

### 3.2 预算追踪

SubAgent 每次运行前记录快照，执行后计算实际消耗：

```zig
pub const BudgetSnapshot = struct {
    tokens_before: u32,
    cost_before: u64,
    steps_before: u32,
    wall_ms_before: u64,  // std.time.milliTimestamp()
};
```

**违规处理**:
- 超过 `max_steps` → 立即终止，返回 "budget exceeded"
- 超过 `max_cost_cents` → 立即终止，记录警告
- 超过 `max_wall_ms` → 立即终止，返回 "timeout"

### 3.3 默认预算分级

| 级别 | max_tokens | max_cost_cents | 用途 |
|------|-----------|---------------|------|
| `tiny` | 10,000 | 50 | 文件读取/小查询 |
| `small` | 50,000 | 200 | 单文件修改 |
| `medium` | 100,000 | 500 | 模块级重构 |
| `large` | 500,000 | 2000 | 多文件功能实现 |

---

## 4. Task 拆分与调度

### 4.1 Task 模型

```zig
pub const Task = struct {
    id: []const u8,          // "T-042"
    title: []const u8,
    status: Status,           // todo | in_progress | done | blocked | failed
    priority: Priority,       // p0 | p1 | p2 | p3
    dependencies: []const []const u8, // ["T-040", "T-041"]
    subagent_budget: SubBudget,
    spec_path: []const u8,   // docs/specs/T-042-xxx.md
    task_path: []const u8,   // tasks/active/sprint-xxx/T-042-xxx.md
};
```

### 4.2 依赖解析（DAG）

TaskEngine 加载 `tasks/active/` 下所有任务文件，构建依赖图：

```zig
pub fn getNextTask(self: *Self, done_ids: []const []const u8) ?Task {
    // 1. 过滤掉已完成的
    // 2. 过滤掉依赖未满足的
    // 3. 按 priority 排序
    // 4. 返回第一个可执行的
}
```

**依赖满足判定**: Task A 依赖 Task B，当 B.status == done 时视为满足。

### 4.3 调度策略

```
while (has_undedone_tasks) {
    task = getNextTask();
    if (task == null) {
        if (has_blocked_tasks) → print_blocked_report();
        break;
    }
    result = executeTask(task);  // Agent 或 SubAgent 执行
    updateTaskStatus(task, result);
}
```

**SubAgent 执行**: Task 的 `subagent_budget` 决定创建 SubAgent 的配置。Budget 小的任务用 SubAgent，大的任务由主 Agent 执行。

### 4.4 Task 文件解析

从 markdown 文件的 YAML frontmatter 提取元数据：

```yaml
---
id: T-042
title: "实现缓存 HTTP 客户端"
status: todo
priority: p1
dependencies: [T-040, T-041]
estimated_hours: 4
---
```

---

## 5. 7-Phase 项目状态机

### 5.1 Phase 判定

当前 Phase 由文件系统中 `projects/<id>/` 下存在的文档决定：

```zig
pub const Phase = enum(u8) {
    prd = 1,              // 01-prd.md
    architecture = 2,     // 02-architecture.md
    technical_spec = 3,   // 03-technical-spec.md
    task_breakdown = 4,   // 04-task-breakdown.md
    test_spec = 5,        // 05-test-spec.md
    implementation = 6,   // (T-XXX 任务文件存在)
    review_deploy = 7,    // 07-review-deploy.md
};

pub fn getCurrentPhase(proj_dir: []const u8) Phase {
    const phase_docs = [_]struct { Phase; []const u8 }{
        .{ .prd, "01-prd.md" },
        .{ .architecture, "02-architecture.md" },
        .{ .technical_spec, "03-technical-spec.md" },
        .{ .task_breakdown, "04-task-breakdown.md" },
        .{ .test_spec, "05-test-spec.md" },
        .{ .review_deploy, "07-review-deploy.md" },
    };
    for (phase_docs) |pd| {
        var path_buf: [512]u8 = undefined;
        const path = std.fs.path.join(...) or return pd[0];
        if (!fileExists(path)) return pd[0];
    }
    return .review_deploy;  // 全部存在
}
```

### 5.2 Project 结构

```
projects/proj-20260406-001/
├── 01-prd.md
├── 02-architecture.md
├── 03-technical-spec.md
├── 04-task-breakdown.md    → 自动拆分为 T-XXX
├── 05-test-spec.md
└── 07-review-deploy.md
```

Phase 4 完成后，TaskEngine 解析 `04-task-breakdown.md` 中的任务列表，在 `tasks/active/sprint-xxx/` 下创建对应的 `T-XXX-xxx.md` 文件。

---

## 6. Review Agent（多角色评审）

### 6.1 角色定义

| Phase | Review 角色 | 检查重点 |
|-------|-----------|---------|
| PRD | `product_manager` | 需求完整性、边界条件 |
| Architecture | `system_architect` | 模块边界、依赖关系 |
| Technical Spec | `tech_lead` | API 设计、影响文件、验收标准 |
| Task Breakdown | `project_manager` | 任务粒度、依赖合理性 |
| Test Spec | `qa_engineer` | 测试覆盖率 |
| Implementation | `code_reviewer` | 代码质量、安全、规范 |
| Review | `release_engineer` | 发布就绪性 |

### 6.2 Review 输出

```zig
pub const ReviewResult = enum {
    pass,          /// 通过，可进入下一阶段
    needs_revision, /// 需修改，附带 feedback
    blocked,       /// 阻塞，需人工介入
};

pub const ReviewReport = struct {
    status: ReviewResult,
    feedback: []const u8,  // 修改建议（needs_revision 时）
    role: []const u8,      // 评审角色
};
```

### 6.3 Prompt 加载

Review Agent 的 prompt 从 markdown 文件加载，支持 cascade 覆盖：

```
优先级: .kimiz/prompts/review/ > ~/.kimiz/prompts/review/ > prompts/review/
```

---

## 7. CLI 命令

```bash
# 创建项目并初始化 Phase 1
kimiz project create "实现带缓存的 HTTP 客户端"

# 自主模式：Agent 自动完成 Phase 1 → 7
kimiz project create "实现带缓存的 HTTP 客户端" --autonomous

# 手动执行某个 Phase
kimiz phase run <project-id> <phase-number>

# 查看任务队列
kimiz task list
kimiz task next

# 执行任务
kimiz task run <task-id>
```

---

## 8. 影响文件

| 文件 | 说明 |
|------|------|
| `src/engine/project.zig` | Project + Phase 状态机 |
| `src/engine/task.zig` | TaskEngine 核心（队列/依赖/调度） |
| `src/engine/budget.zig` | SubBudget 定义和追踪 |
| `src/engine/review.zig` | ReviewAgent 多角色评审 |
| `src/prompts/loader.zig` | Prompt cascade 加载 |
| `src/cli/root.zig` | project/phase/task 子命令 |
| `prompts/review/` | 7 个角色 prompt 文件 |
| `tests/task_engine_tests.zig` | 全部测试 |

---

## 9. 验收标准

### SubBudget 层
- [ ] SubBudget 结构定义完整（token/cost/step/output_bytes/wall_ms）
- [ ] 4 级默认预算（tiny/small/medium/large）
- [ ] 预算超限时正确终止 SubAgent 并返回错误
- [ ] 至少 3 个 Budget 相关测试

### Task Queue 层
- [ ] Task 模型包含 id/title/status/priority/dependencies/subagent_budget
- [ ] 从 markdown YAML frontmatter 正确解析 Task
- [ ] `getNextTask()` 正确过滤已完成和依赖未满足的任务
- [ ] 依赖图无环检测
- [ ] 至少 5 个 Task 相关测试

### Phase 状态机层
- [ ] Project 创建正确初始化 `01-prd.md`
- [ ] `getCurrentPhase()` 根据文件存在性返回正确 Phase
- [ ] Phase 不可跳跃（不能从 Phase 1 直接到 Phase 3）
- [ ] Phase 4 完成后至少在 `tasks/active/` 下创建 1 个任务文件
- [ ] 至少 4 个 Phase 相关测试

### Review 层
- [ ] 7 个 Review 角色定义
- [ ] Review 输出可解析为 PASS / NEEDS_REVISION / BLOCKED
- [ ] Prompt cascade 加载正确（用户覆盖 > 内置默认）
- [ ] 至少 3 个 Review 相关测试

### CLI 层
- [ ] `kimiz project create` 创建项目目录和 PRD 模板
- [ ] `kimiz task list` 列出当前 Sprint 任务
- [ ] `kimiz task next` 显示下一个可执行任务
