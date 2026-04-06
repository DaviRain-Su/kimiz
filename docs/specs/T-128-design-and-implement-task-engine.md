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
pub fn executePhase(author_agent: *Agent, project: *Project, phase: Phase) !PhaseResult {
    // 1. 读取模板
    const template = try loadPhaseTemplate(phase);
    
    // 2. 检查/创建输出文档
    const output_doc = try project.getPhaseDocPath(phase);
    
    // 3. Author Agent 生成/完善文档内容
    const result = try author_agent.generatePhaseDocument(project, phase, template, output_doc);
    
    // 4. TaskEngine 形式验收（结构检查）
    const struct_passed = try validatePhaseDocument(phase, output_doc);
    if (!struct_passed) {
        return .{ .status = .needs_revision, .feedback = "文档缺少必要章节" };
    }
    
    // 5. Review Agent 内容评审（关键新增）
    var reviewer = try ReviewAgent.init(phase.reviewRole());
    const review_result = try reviewer.review(output_doc);
    
    switch (review_result.status) {
        .pass => return .{ .status = .done, .next_phase = phase.next() },
        .needs_revision => return .{ 
            .status = .needs_revision, 
            .feedback = review_result.feedback 
        },
        .blocked => return .{ 
            .status = .blocked, 
            .feedback = review_result.feedback 
        },
    }
}
```

**Phase 验收标准（最小可行）**：
- 文档存在
- 包含模板中要求的全部 `##` 一级标题
- 对于 Phase 3（Technical Spec），必须包含 `## 影响文件` 和 `## 验收标准`

### 2.5 Phase Review Agent（多角色评审）

每个 Phase 的产出不仅由 TaskEngine 做形式检查，还必须由**专门的 Review Agent** 做内容评审。这是 7-phase 质量保证的核心。

```
Phase 1 PRD          → Product Manager Agent
Phase 2 Architecture → System Architect Agent
Phase 3 Tech Spec    → Tech Lead Agent
Phase 4 Task Breakdown → Project Manager Agent
Phase 5 Test Spec    → QA Engineer Agent
Phase 6 Implementation → Code Reviewer Agent
Phase 7 Review       → Release Engineer / Security Agent
```

**每个 Review Agent 的职责**：
- 读取当前 Phase 的产出文档
- 根据该 Phase 的验收标准 checklist 逐项检查
- 输出 `PASS` 或带具体修改意见的 `NEEDS_REVISION`
- 不直接修改文档，只返回 review 报告

**Review Agent 的实现方式**：

```zig
pub const ReviewAgent = struct {
    role: Role,
    system_prompt: []const u8,
    
    pub const Role = enum {
        product_manager,    // Phase 1
        system_architect,   // Phase 2
        tech_lead,          // Phase 3
        project_manager,    // Phase 4
        qa_engineer,        // Phase 5
        code_reviewer,      // Phase 6
        release_engineer,   // Phase 7
    };
    
    pub fn review(self: *ReviewAgent, phase_doc: []const u8) !ReviewResult {
        // 1. 加载该角色的 system prompt
        // 2. 构造 prompt：文档内容 + 验收标准 + "请 review"
        // 3. 调用 LLM
        // 4. 解析结果：PASS / NEEDS_REVISION
    }
};
```

**Review Result 的三种状态**：
- `PASS` — 进入下一阶段
- `NEEDS_REVISION` — 返回给 Author Agent（执行 Phase 的 Agent）修改，最多重试 2 次
- `BLOCKED` — 根本性缺陷，无法在当前迭代中解决，Project 暂停

**Prompt 管理**：
- `prompts/review/product-manager.md`
- `prompts/review/system-architect.md`
- `prompts/review/tech-lead.md`
- ...

每个 prompt 必须明确：
1. 该 Phase 的核心目标是什么
2. 必须包含哪些章节/内容
3. 常见的反模式（如 Phase 3 缺少影响文件、Phase 5 测试与 spec 不匹配）
4. 输出格式要求（`PASS` 或 `NEEDS_REVISION: <具体意见>`）

**与 T-120 ~ T-123 的关系**：
- T-120 建立了 Document-Driven Workflow（Agent 读文档、更新日志）
- T-128 的 Review Agent 是该工作流的**自然延伸**——现在 Agent 不仅要读写文档，还要**评审文档**

### 2.6 与 gstack 的集成：从手动 Skill 到自动 Review Agent

**gstack** (garrytan/gstack) 已经证明了"专家角色即 Skill"的模式可以大规模扩展。gstack 用 23 个 `SKILL.md` 文件定义了 CEO Reviewer、Eng Reviewer、QA Lead、Security Officer 等角色，每个角色都是一个目录 + SKILL.md（YAML frontmatter + 详细指令）。

**gstack 的运作方式**：
- 人类主动输入 `/plan-ceo-review`、`/review`、`/qa` 来调用对应角色
- 每个 `SKILL.md` 定义了角色的目标、工具权限、执行流程、检查清单
- 通过 `agents/openai.yaml` 和主 `SKILL.md` 中的 routing rules 自动分发请求

**KimiZ 的改进方向**：
gstack 解决了"角色专业化"的问题，但**没有解决自动编排的问题**。人类仍然需要记住在什么时候调用哪个角色。KimiZ 的 TaskEngine 要做的是：

1. **复用 gstack 的"角色即 Skill"设计模式**
   - 每个 Review Agent 对应一个 KimiZ Skill（使用 `defineSkill` DSL）
   - Prompt 文件的结构参考 gstack 的 `SKILL.md`（YAML frontmatter + 指令）

2. **将 gstack 的手动触发改为 TaskEngine 自动触发**
   - Phase 1 完成后 → 自动调用 `product-manager-review` Skill
   - Phase 2 完成后 → 自动调用 `system-architect-review` Skill
   - Phase 6 代码提交后 → 自动调用 `code-reviewer` Skill（类似 gstack `/review`）
   - 不再需要人类输入 slash command

3. **吸收 gstack 的最佳实践到 Prompt 中**
   - `plan-ceo-review` 的 **4 scope modes**（扩张/选择性扩张/保持/缩减）可用于 Phase 2 的 scope 决策
   - `review` 的 **SQL safety、LLM trust boundary、conditional side effects** 检查可融入 Phase 6 Code Reviewer
   - `qa` 的 **real browser testing、health scores** 可融入 Phase 5/7 的验收标准
   - `cso` (Chief Security Officer) 的 **OWASP + STRIDE** 审计可融入 Phase 7 Release Engineer

4. **统一的 Prompt 模板引擎**
   - 参考 gstack 的 `SKILL.md.tmpl` + `bun run gen:skill-docs`
   - KimiZ 可以在 `prompts/review/TEMPLATE.md` 中定义共享结构
   - 各角色 prompt 从模板生成，确保一致性和可维护性

### 2.7 Prompt 加载与自定义系统（用户可扩展角色）

这是 KimiZ 相比 gstack 的关键差异化能力：**不仅内置角色，还允许用户完全自定义和扩展角色**。

#### 层级覆盖机制（Cascade Loading）

Prompt 加载器按优先级从三个层级搜索 prompt 文件，**高优先级覆盖低优先级**：

```
1. 项目级: .kimiz/prompts/review/ROLE.md   (当前工作目录)
2. 用户级: ~/.kimiz/prompts/review/ROLE.md (用户 home)
3. 系统级: prompts/review/ROLE.md          (KimiZ 仓库自带)
```

示例配置见 `examples/.kimiz/config.yaml`。

**行为**：
- 如果项目级存在 `custom-auditor.md`，TaskEngine 会注册一个名为 `custom-auditor` 的新 Review Agent
- 如果用户级存在 `tech-lead.md`，它会完全覆盖系统内置的 Tech Lead prompt
- 如果只有系统级存在，使用默认内置 prompt

#### PromptLoader 数据结构

```zig
pub const PromptLoader = struct {
    allocator: std.mem.Allocator,
    
    /// Search paths in priority order
    search_paths: []const []const u8,
    
    /// Load all prompts from search paths
    pub fn loadAll(self: *PromptLoader, registry: *PromptRegistry) !void {
        // 1. Load system defaults
        try self.loadFromDir("prompts/review", registry);
        
        // 2. Load user overrides
        try self.loadFromDir("~/.kimiz/prompts/review", registry);
        
        // 3. Load project overrides (highest priority)
        try self.loadFromDir(".kimiz/prompts/review", registry);
    }
    
    /// Parse a markdown file with YAML frontmatter into PromptTemplate
    pub fn loadPromptFile(self: *PromptLoader, path: []const u8) !PromptTemplate {
        // Read file
        // Parse YAML frontmatter (between --- lines)
        // Extract: role, phase, name, version, allowed_tools, description
        // Body = markdown content after frontmatter
        // Return PromptTemplate
    }
};
```

#### 自定义角色的两种模式

**模式 A：覆盖现有角色**

用户创建 `~/.kimiz/prompts/review/tech-lead.md`：
```yaml
---
role: tech-lead
phase: 3
name: "My Company's Tech Lead"
version: "1.0.0"
---

You are a tech lead at ACME Corp. In addition to standard checks,
ALWAYS verify that:
- All new code uses our internal `acme_alloc` allocator
- No `std.debug.print` remains in production code
- Every public function has a corresponding benchmark
```

**模式 B：创建全新角色**

用户创建 `.kimiz/prompts/review/rust-specialist.md`：
```yaml
---
role: rust-specialist
phase: 6
name: "Rust Safety Specialist"
version: "1.0.0"
---

You are a Rust safety specialist. Review the code for:
- Unsafe blocks are minimized and justified
- No `.unwrap()` in production paths
- Proper lifetime annotations on public APIs
```

然后用户可以在 `.kimiz/config.yaml` 中配置 Phase 映射：

```yaml
review_agents:
  phase_6: rust-specialist  # 覆盖默认的 code-reviewer
```

或者 TaskEngine 自动识别：只要在 `prompts/review/` 里有的 `.md` 文件，自动注册为可用 Review Agent。

#### 动态 Prompt 注入流程

```zig
pub fn getReviewAgentPrompt(loader: *PromptLoader, role: []const u8) ![]const u8 {
    // 1. Search cascade
    for (loader.search_paths) |search_dir| {
        const path = try std.fs.path.join(allocator, &.{ search_dir, role ++ ".md" });
        if (fileExists(path)) {
            const template = try loader.loadPromptFile(path);
            return try template.render(allocator, context_values);
        }
    }
    return error.RoleNotFound;
}
```

#### 与 KimiZ 现有系统的集成

- `src/prompts/root.zig` 已有 `PromptTemplate` 和 `PromptRegistry`
- 当前 `registerBuiltin()` 是硬编码字符串
- **T-128 需要重构 `PromptRegistry`**，让它支持从文件系统加载和层级覆盖
- Review Agent 的 `review()` 函数通过 `PromptLoader` 动态获取 prompt，而不是 compile-time 硬编码

#### 为什么这很重要

1. **用户主权**：每个团队/项目可以调教 Review Agent 符合自己的规范
2. **无需改代码就能扩展**：新增角色只需要创建一个 markdown 文件
3. **渐进式采用**：先用内置角色，不满意再覆盖，不需要 fork KimiZ
4. **Scale 友好**：gstack 的 23 个 skill 是仓库级维护的；KimiZ 的 prompt 可以在组织内共享（把 `~/.kimiz/prompts/` 做成 git repo 即可）

**结论**：KimiZ 不是重复发明 gstack 的角色 prompt，而是**在 gstack 之上加一个自动编排层（TaskEngine）+ 一个用户可扩展的 Prompt 加载系统**，让 gstack 式的专家 review 在正确的时机自动发生，并且完全由用户控制。

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
| `src/engine/project.zig` | 新增：Project 和 Phase 状态机 |
| `src/engine/task.zig` | 新增：TaskEngine 核心实现（任务队列、依赖解析、归档） |
| `src/engine/review.zig` | 新增：ReviewAgent 多角色评审系统 |
| `src/prompts/loader.zig` | 新增：PromptLoader，支持 cascade 加载和 YAML frontmatter 解析 |
| `src/cli/root.zig` | 新增：`kimiz project create` 和 `--autonomous` 子命令；保留 REPL 调试命令 |
| `src/agent/agent.zig` | 新增：`executePhase(project, phase)` 和 `executeTask(task)` 接口 |
| `src/agent/tools/task_tools.zig` | 新增/扩展：`create_project`, `read_phase_template`, `validate_phase_doc`, `read_task`, `update_task_status`, `archive_task` |
| `prompts/review/` | 新增：7 个 Review Agent prompt 文件（product-manager.md 等） |
| `examples/.kimiz/` | 新增：示例 config.yaml + prompts 自定义目录结构 |
| `tests/task_engine_tests.zig` | 新增：Project/Phase/Task/Review/PromptLoader 五层测试 |
| `docs/guides/TASK-LIFECYCLE.md` | 更新：加入 TaskEngine 自动归档和 7-phase 流转规则 |

---

## 验收标准

### Phase 层（7-phase 项目状态机）

- [ ] `kimiz project create "<需求>"` 能创建 `projects/<id>/` 目录并初始化 `01-prd.md`
- [ ] `getCurrentPhase(project_dir)` 能根据文档存在性正确返回当前 Phase（1~7）
- [ ] `executePhase()` 能按顺序执行 Phase 1 → Phase 2 → Phase 3，且不可跳跃
- [ ] `validatePhaseDocument()` 能检查 Phase 文档是否包含模板要求的关键章节
- [ ] Phase 4 完成后，能自动从 `04-task-breakdown.md` 生成至少 1 个 `T-XXX` 任务文件到 `tasks/active/`

### Review 层（多角色评审）

- [ ] `ReviewAgent` 支持 7 种角色：`product_manager`, `system_architect`, `tech_lead`, `project_manager`, `qa_engineer`, `code_reviewer`, `release_engineer`
- [ ] `ReviewAgent.review()` 能加载对应角色的 prompt，对 Phase 产出文档进行评审
- [ ] Review 输出能解析为 `PASS` / `NEEDS_REVISION` / `BLOCKED` 三种状态
- [ ] `executePhase()` 在形式验收后自动调用 Review Agent；`PASS` 才能进入下一阶段
- [ ] Review 结果为 `NEEDS_REVISION` 时，Author Agent 能根据反馈修改文档并重试（最多 2 次）
- [ ] `prompts/review/` 目录下至少存在 4 个角色 prompt 文件（product-manager, system-architect, tech-lead, code-reviewer）
- [ ] `PromptLoader` 能从 markdown 文件解析 YAML frontmatter 生成 `PromptTemplate`
- [ ] `PromptLoader.loadAll()` 按 `.kimiz/` > `~/.kimiz/` > `prompts/` 的优先级正确加载和覆盖
- [ ] 用户创建 `.kimiz/prompts/review/custom-role.md` 后，TaskEngine 能识别并注册为新的 Review Agent
- [ ] 用户覆盖 `~/.kimiz/prompts/review/tech-lead.md` 后，Phase 3 的 Review Agent 使用用户自定义 prompt

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
