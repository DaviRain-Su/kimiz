# T-128: 设计并实现 KimiZ 运行时任务状态机（TaskEngine）

**任务类型**: Implementation  
**优先级**: P0  
**预计耗时**: 12h  
**前置任务**: T-120 ~ T-124（文档驱动基础设施已落地）

---

## 参考文档

- [TASK-LIFECYCLE](../guides/TASK-LIFECYCLE.md) - 任务文件管理规范
- [7-Phase Dev Lifecycle](../methodology/dev-lifecycle/README.md) - 强制开发流程：PRD → Architecture → Technical Spec → Task Breakdown → Test Spec → Implementation → Review & Deploy
- [ZIG-LLM-SELF-EVOLUTION-STRATEGY](../research/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md) - 自我进化三阶段战略
- [TigerBeetle Patterns](../research/TIGERBEETLE-PATTERNS-ANALYSIS.md) - 零技术债务、编译时验证原则
- [OpenCLI Analysis](../research/OPENCLI-ANALYSIS.md) - 探测-固化-验证闭环

---

## 背景

KimiZ 项目遵循严格的 **7-phase 开发方法论**（PRD → Architecture → Technical Spec → Task Breakdown → Test Spec → Implementation → Review & Deploy）。这套方法论写在 `docs/methodology/dev-lifecycle/README.md` 中，是人类开发者必须遵守的规范。

但目前的问题是：**这套流程全靠人类手动执行**。Agent 知道有 7 个阶段，但它不会在运行时自动推进这些阶段。每次启动都需要人类提示"你现在处于 Phase 3，去读 Technical Spec"。

同时，KimiZ 已经具备了丰富的能力模块：
- T-103: comptime Skill DSL
- T-100/T-101: auto skill 生成 + AutoRegistry
- T-092/T-119: subagent + worktree 隔离
- T-120 ~ T-123: 文档驱动工作流（读取任务、更新日志、同步 spec）
- T-124: 可观测性 metrics

这些能力都是**离散的**。**核心缺口不是缺少功能，而是缺少一个能把功能和流程串起来的调度器。**

如果把 KimiZ 比作一个工程师团队，我们现在有：
- 优秀的编译器（Zig comptime）
- 熟练的程序员（Skills）
- 完善的流程规范（7-phase methodology）
- 完善的文档系统（Task + Spec）
- 但**没有项目经理**——没人确保流程被正确执行、没人跟踪阶段进度、没人验收阶段产出

**TaskEngine 就是这个项目经理。而且它不是通用的项目经理，它是一个内嵌了 7-phase 开发方法论的项目经理。**

这意味着：
1. 人类只需要说需求（一句自然语言）
2. TaskEngine 自动创建 Project，进入 Phase 1（PRD）
3. Agent 按顺序完成 Phase 1 → Phase 2 → ... → Phase 7
4. 每个 Phase 的产出（`01-prd.md`, `02-architecture.md` 等）被自动创建和验收
5. Phase 4（Task Breakdown）的结果被自动拆分为 `T-XXX` 任务，放入 `tasks/active/`
6. Phase 6（Implementation）中，Agent 自动读取 `T-XXX` 任务并执行
7. 全部完成后，Project 进入 Phase 7（Review & Deploy），产出归档

**TaskEngine 让 7-phase 方法论从"文档规范"升级为"机器可执行的状态机"**。

---

## 目标

### 第一层：7-phase 项目状态机

1. **Project 作为顶层容器**：每个需求对应一个 Project，Project 的生命周期就是 7-phase 流程
2. **Phase 顺序强制**：Project 必须按 `1→2→3→4→5→6→7` 顺序推进，当前 Phase 验收通过后才能进入下一阶段
3. **Phase 产出文档自动化**：每个 Phase 的输出（`01-prd.md` 到 `07-review-deploy.md`）由 Agent 自动生成并落盘
4. **Phase 验收文档化**：TaskEngine 检查每个 Phase 的产出文档是否存在、是否符合模板结构

### 第二层：Phase 4 → Task 自动拆解

5. **Task Breakdown 机器化**：Phase 4 完成后，Agent 自动将工作拆解为 `T-XXX` 任务文件，放入 `tasks/active/`
6. **任务队列自动加载**：Phase 6 开始时，TaskEngine 自动加载 `tasks/active/` 下的所有 `T-XXX` 任务

### 第三层：Task 执行与推进

7. **依赖解析与优先级排序**：实现 `getNextTask()`，自动找出当前可执行的最高优先级任务
8. **状态流转闭环**：Agent 完成执行后，自动验证验收标准并推进到下一个任务
9. **自动归档**：任务标记为 `done` 后，自动移动到 `tasks/completed/`

### 第四层：自主运行模式

10. **Agent Loop 集成**：提供 `--autonomous` 运行模式，让 KimiZ 能无人值守地执行整个 Project（从需求到部署）

---

## 关键设计决策

### 0. 7-phase 是 TaskEngine 的底层状态机（最重要）

TaskEngine 管理两层结构：

```
Project（顶层）
├── Phase 1: PRD
├── Phase 2: Architecture
├── Phase 3: Technical Spec
├── Phase 4: Task Breakdown  → 产出 T-XXX 任务
├── Phase 5: Test Spec
├── Phase 6: Implementation  ← 执行 T-XXX 任务
└── Phase 7: Review & Deploy
```

**Project 的当前 Phase 以文件系统中是否存在对应文档为准**：
- `projects/<id>/01-prd.md` 存在 → Phase 1 已完成
- `projects/<id>/03-technical-spec.md` 存在 → Phase 3 已完成
- 以此类推

**Phase 顺序不可跳跃**。TaskEngine 在启动时检查：
```zig
pub fn getCurrentPhase(project_dir: []const u8) Phase {
    for (1..=7) |phase_num| {
        if (!phaseDocExists(project_dir, phase_num)) {
            return @enumFromInt(phase_num);
        }
    }
    return .review_deploy_done;
}
```

### 1. 项目初始化：从人类一句话到 Project 创建

```bash
kimiz project create "实现一个带缓存的 HTTP 客户端"
```

TaskEngine 行为：
1. 生成 project ID（如 `proj-20260406-001`）
2. 创建目录 `projects/proj-20260406-001/`
3. 复制 `docs/methodology/dev-lifecycle/templates/01-prd.md` 到项目目录
4. 将需求填充进模板
5. 自动标记 Phase 1 为 `in_progress`
6. 如果启动 `--autonomous`，立即开始执行 Phase 1

### 2. Phase 执行模式

每个 Phase 的执行流程是统一的：

```zig
pub fn executePhase(agent: *Agent, project: *Project, phase: Phase) !PhaseResult {
    // 1. 读取模板
    const template = try loadPhaseTemplate(phase);
    
    // 2. 检查/创建输出文档
    const output_doc = try project.getPhaseDocPath(phase);
    
    // 3. Agent 生成/完善文档内容
    const result = try agent.generatePhaseDocument(project, phase, template, output_doc);
    
    // 4. TaskEngine 验收
    const passed = try validatePhaseDocument(phase, output_doc);
    
    if (passed) {
        return .{ .status = .done, .next_phase = phase.next() };
    } else {
        return .{ .status = .needs_revision, .feedback = "文档缺少必要章节" };
    }
}
```

**Phase 验收标准（最小可行）**：
- 文档存在
- 包含模板中要求的全部 `##` 一级标题
- 对于 Phase 3（Technical Spec），必须包含 `## 影响文件` 和 `## 验收标准`

### 3. Phase 4 → Task 自动拆解

Phase 4 完成后，TaskEngine 解析 `04-task-breakdown.md` 中的任务表格，自动生成：

```zig
for (each task in breakdown) {
    const task_id = generateTaskId();
    const task_file = try createTaskFile(.{
        .id = task_id,
        .title = task.title,
        .priority = task.priority,
        .spec_path = task.spec_path,
        .status = .todo,
    });
    // 放入 tasks/active/sprint-*/
}
```

这实现了从"项目级规划"到"可执行任务"的自动转换。

### 4. Phase 6：Task 队列执行

当 Project 进入 Phase 6 时，TaskEngine 的行为和之前的 T-128 设计一致：

```zig
pub const Task = struct {
    id: []const u8,
    title: []const u8,
    status: Status,
    priority: Priority,
    spec_path: []const u8,
    task_path: []const u8,
    dependencies: []const []const u8,
    acceptance_criteria: []const AcceptanceCriterion,
};

// 加载 tasks/active/ 下所有 T-XXX.md
// getNextTask() 按依赖+优先级返回当前任务
// Agent 执行 → 验收 → completeTask → archiveCompleted
```

### 5. 文件系统作为唯一数据源

**不引入数据库**。所有状态由文件位置和 frontmatter 决定：
- `projects/<id>/` 目录存在 → Project 存在
- `projects/<id>/0N-*.md` 存在 → Phase N 已完成
- `tasks/active/sprint-*/T-XXX.md` + `status: in-progress` → 当前执行中
- `tasks/completed/sprint-*/T-XXX.md` + `status: done` → 已完成

### 6. Agent Loop 集成：两种运行模式

**模式 A：`--autonomous`（完全自主）**

```bash
kimiz project create "实现一个带缓存的 HTTP 客户端" --autonomous
```

Agent 自动完成 Phase 1 → 7 的全部流程。

```zig
pub fn runAutonomousProject(agent: *Agent, project_id: []const u8) !void {
    var project = try Project.load(agent.allocator, project_id);
    
    while (project.current_phase != .review_deploy_done) {
        const result = try TaskEngine.executePhase(agent, &project, project.current_phase);
        
        switch (result.status) {
            .done => project.advancePhase(),
            .needs_revision => {
                // 重试一次，仍然失败则退出
                std.log.warn("Phase {s} needs revision, retrying...", .{@tagName(project.current_phase)});
                const retry = try TaskEngine.executePhase(agent, &project, project.current_phase);
                if (retry.status != .done) {
                    std.log.err("Phase {s} blocked, exiting autonomous mode.", .{@tagName(project.current_phase)});
                    break;
                }
            },
            .blocked => break,
        }
    }
}
```

**模式 B：按阶段手动触发（调试/审查用）**

```bash
kimiz phase run <project-id> <phase-number>
```

**模式 C：按任务手动触发（已存在）**

```bash
kimiz run -- repl
# /task
# /next
```

**决策**：T-128 先实现模式 A 的最小可行版本，同时保留模式 B 的 CLI 命令。模式 C 已在 REPL 中部分存在，保持兼容。

---

## 影响文件

| 文件 | 预期改动 |
|------|----------|
| `src/project.zig` 或 `src/engine/project.zig` | 新增：Project 和 Phase 状态机 |
| `src/task_engine.zig` 或 `src/engine/task.zig` | 新增：TaskEngine 核心实现（任务队列、依赖解析、归档） |
| `src/cli/root.zig` | 新增：`kimiz project create` 和 `--autonomous` 子命令；保留 REPL 调试命令 |
| `src/agent/agent.zig` | 新增：`executePhase(project, phase)` 和 `executeTask(task)` 接口 |
| `src/agent/tools/task_tools.zig` | 新增/扩展：`create_project`, `read_phase_template`, `validate_phase_doc`, `read_task`, `update_task_status`, `archive_task` |
| `tests/task_engine_tests.zig` | 新增：Project/Phase/Task 三层状态机单元测试 |
| `docs/guides/TASK-LIFECYCLE.md` | 更新：加入 TaskEngine 自动归档和 7-phase 流转规则 |

---

## 验收标准

### Phase 层（7-phase 项目状态机）

- [ ] `kimiz project create "<需求>"` 能创建 `projects/<id>/` 目录并初始化 `01-prd.md`
- [ ] `getCurrentPhase(project_dir)` 能根据文档存在性正确返回当前 Phase（1~7）
- [ ] `executePhase()` 能按顺序执行 Phase 1 → Phase 2 → Phase 3，且不可跳跃
- [ ] `validatePhaseDocument()` 能检查 Phase 文档是否包含模板要求的关键章节
- [ ] Phase 4 完成后，能自动从 `04-task-breakdown.md` 生成至少 1 个 `T-XXX` 任务文件到 `tasks/active/`

### Task 层（任务队列执行）

- [ ] `TaskEngine` 能正确解析 `tasks/active/sprint-2026-04/` 下所有任务文件的 YAML frontmatter
- [ ] `getNextTask()` 能按优先级和依赖关系返回正确的下一个任务
- [ ] `startTask()` 将任务状态从 `todo` 改为 `in-progress` 并更新文件
- [ ] `completeTask()` 验证 checklist 至少有一项被勾选，然后将状态改为 `done`
- [ ] `archiveCompleted()` 将 `done` 任务文件移动到 `tasks/completed/sprint-2026-04/`

### Autonomous 模式

- [ ] CLI `kimiz project create "<需求>" --autonomous` 能启动并完成 Phase 1 → Phase 3 的连续执行（无需人工干预）
- [ ] Phase 验收失败时，自动重试 1 次；仍失败则退出 autonomous 模式并保留 Project 状态
- [ ] 所有新增代码通过 `zig build test`
- [ ] 更新 `AGENT-ENTRYPOINT.md` 和 `docs/CURRENT-SPRINT.md`
