# T-128: 设计并实现 KimiZ 运行时任务状态机（TaskEngine）

**任务类型**: Implementation  
**优先级**: P0  
**预计耗时**: 12h  
**前置任务**: T-120 ~ T-124（文档驱动基础设施已落地）

---

## 参考文档

- [TASK-LIFECYCLE](../guides/TASK-LIFECYCLE.md) - 任务文件管理规范
- [ZIG-LLM-SELF-EVOLUTION-STRATEGY](../research/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md) - 自我进化三阶段战略
- [TigerBeetle Patterns](../research/TIGERBEETLE-PATTERNS-ANALYSIS.md) - 零技术债务、编译时验证原则
- [OpenCLI Analysis](../research/OPENCLI-ANALYSIS.md) - 探测-固化-验证闭环

---

## 背景

KimiZ 目前已经具备了丰富的**能力模块**：
- T-103: comptime Skill DSL
- T-100/T-101: auto skill 生成 + AutoRegistry
- T-092/T-119: subagent + worktree 隔离
- T-120 ~ T-123: 文档驱动工作流（读取任务、更新日志、同步 spec）
- T-124: 可观测性 metrics

但这些能力都是**离散的**。Agent 每次启动都依赖人类提示词告诉它"现在该做 T-XXX"。系统本身不知道自己该做什么、做完了什么、下一步该推进什么。

**核心缺口：没有调度器。**

如果把 KimiZ 比作一个工程师团队，那么我们现在有：
- 优秀的编译器（Zig comptime）
- 熟练的程序员（Skills）
- 完善的文档系统（Task + Spec）
- 但**没有项目经理**——没人排期、没人跟踪进度、没人验收

TaskEngine 就是这个项目经理。它让 KimiZ 从"高级 REPL"升级为"能自主执行工作流的 Agent"。

---

## 目标

1. **设计并实现 `TaskEngine` 核心模块**：解析 `tasks/active/` 下的任务文件，构建运行时任务状态机
2. **任务队列自动加载**：Agent 启动时自动识别当前 Sprint 的所有任务，无需人类指定
3. **依赖解析与优先级排序**：实现 `getNextTask()`，自动找出当前可执行的最高优先级任务
4. **状态流转闭环**：Agent 完成执行后，自动验证验收标准并推进到下一个任务
5. **自动归档**：任务标记为 `done` 后，自动移动到 `tasks/completed/`
6. **Agent Loop 集成**：提供 `--autonomous` 运行模式，让 KimiZ 能无人值守地执行整个 Sprint

---

## 关键设计决策

### 1. 任务文件作为唯一数据源（Single Source of Truth）

**决策**：TaskEngine 不引入数据库或独立状态文件，直接解析 markdown 任务文件。

原因：
- 保持人类可读/可编辑
- 与现有任务系统 100% 兼容
- 无需新增持久化依赖

**任务状态以文件位置 + frontmatter 为准**：
- `tasks/active/sprint-*/T-XXX.md` + `status: in-progress` = 当前执行中
- `tasks/active/sprint-*/T-XXX.md` + `status: todo` = 等待执行
- `tasks/completed/sprint-*/T-XXX.md` + `status: done` = 已完成

### 2. 轻量级运行时状态缓存

TaskEngine 在内存中维护：

```zig
pub const Task = struct {
    id: []const u8,
    title: []const u8,
    status: Status,           // todo / in_progress / done / blocked
    priority: Priority,       // P0 / P1 / P2
    spec_path: []const u8,    // 对应 docs/specs/
    task_path: []const u8,    // 当前文件路径
    dependencies: []const []const u8,  // 阻塞任务 ID 列表
    acceptance_criteria: []const AcceptanceCriterion,
    
    // 运行时衍生
    is_blocked: bool,         // 依赖未满足？
    can_start: bool,          // 可以开始执行？
};

pub const TaskEngine = struct {
    allocator: std.mem.Allocator,
    tasks: std.ArrayList(Task),
    task_map: std.StringHashMap(usize),  // id -> tasks index
    
    pub fn loadFromActiveDir(self: *TaskEngine, path: []const u8) !void;
    pub fn resolveDependencies(self: *TaskEngine) void;
    pub fn getNextTask(self: *TaskEngine) ?*Task;
    pub fn startTask(self: *TaskEngine, id: []const u8) !void;
    pub fn completeTask(self: *TaskEngine, id: []const u8) !void;
    pub fn archiveCompleted(self: *TaskEngine) !void;
};
```

### 3. 依赖解析算法

`getNextTask()` 的逻辑：

```zig
1. 筛选 status != done 的任务
2. 标记 is_blocked = true 的任务：存在依赖任务 status != done
3. 在 is_blocked == false 的任务中，按 priority 排序（P0 > P1 > P2）
4. 返回第一个 status == todo 的任务
   （如果没有任何 todo 但存在 in_progress，返回 in_progress 的任务以继续）
5. 如果全部 done，返回 null
```

### 4. 验收标准自检

任务文件中通常有：

```markdown
## 验收标准
- [ ] A 实现完成
- [ ] B 测试通过
```

TaskEngine 需要解析这个 checklist，并在 Agent 声称完成时验证：
- 如果 Agent 没有勾选任何项，拒绝标记为 done
- （未来扩展）Agent 可以调用 `zig build test` 等命令，根据结果自动勾选

**T-128 第一阶段**：只要求 Agent 在 `Log` 中记录验证过程，TaskEngine 检查 checklist 是否至少有一个 `[x]`。

### 5. 自动归档机制

`archiveCompleted()` 的行为：

```zig
for (tasks) |*task| {
    if (task.status == .done) {
        // 1. 移动文件
        move(task.task_path, "tasks/completed/sprint-2026-04/" + basename);
        // 2. 更新内存状态
        remove from active task list;
    }
}
```

归档后，TaskEngine 重新 `loadFromActiveDir()` 以反映最新状态。

### 6. Agent Loop 集成方式

**方案 A：新增 `--autonomous` CLI 模式（推荐）**

```bash
kimiz run --autonomous
```

内部逻辑：

```zig
pub fn runAutonomous(allocator: std.mem.Allocator) !void {
    var engine = try TaskEngine.init(allocator);
    defer engine.deinit();
    
    try engine.loadFromActiveDir("tasks/active/sprint-2026-04");
    
    while (true) {
        const task = engine.getNextTask() orelse {
            printLine("✅ All tasks completed.");
            break;
        };
        
        try engine.startTask(task.id);
        
        // Agent 执行任务
        var result = try agent.executeTask(task);
        
        if (result.success) {
            try engine.completeTask(task.id);
            try engine.archiveCompleted();
        } else {
            // 失败则标记为 blocked，记录原因，退出循环
            try engine.blockTask(task.id, result.error_message);
            printLine("❌ Task blocked, exiting autonomous mode.");
            break;
        }
    }
}
```

**方案 B：在 REPL 中增加 `/next` 和 `/task` 命令**
- `/task` — 显示当前任务
- `/next` — 手动推进到下一个任务
- `/done` — 标记当前任务完成并归档

**决策：先做方案 A 的最小可行版本**，同时保留方案 B 的 CLI 命令作为调试入口。

---

## 影响文件

| 文件 | 预期改动 |
|------|----------|
| `src/task_engine.zig` 或 `src/engine/task.zig` | 新增：TaskEngine 核心实现 |
| `src/cli/root.zig` | 新增：`--autonomous` 子命令；可能新增 `/task`, `/next` REPL 命令 |
| `src/agent/agent.zig` | 新增：`executeTask(task)` 接口，集成文档驱动协议 |
| `src/agent/tools/task_tools.zig` | 新增/扩展：`read_task`, `update_task_status`, `archive_task` 等工具 |
| `tests/task_engine_tests.zig` | 新增：TaskEngine 单元测试 |
| `docs/guides/TASK-LIFECYCLE.md` | 更新：加入 TaskEngine 自动归档规则 |

---

## 验收标准

- [ ] `TaskEngine` 能正确解析 `tasks/active/sprint-2026-04/` 下所有任务文件的 YAML frontmatter
- [ ] `getNextTask()` 能按优先级和依赖关系返回正确的下一个任务
- [ ] `startTask()` 将任务状态从 `todo` 改为 `in-progress` 并更新文件
- [ ] `completeTask()` 验证 checklist 至少有一项被勾选，然后将状态改为 `done`
- [ ] `archiveCompleted()` 将 `done` 任务文件移动到 `tasks/completed/sprint-2026-04/`
- [ ] CLI `kimiz run --autonomous` 能启动并顺序执行至少 2 个测试任务
- [ ] Agent 执行失败时，任务状态变为 `blocked`，系统自动退出 autonomous 模式
- [ ] 所有新增代码通过 `zig build test`
- [ ] 更新 `AGENT-ENTRYPOINT.md` 和 `docs/CURRENT-SPRINT.md`
