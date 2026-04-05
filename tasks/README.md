# Task Management System

## 设计原则

1. **原子化**: 每个任务独立、可执行、可验证
2. **状态驱动**: 明确的状态流转（pending → in_progress → review → done）
3. **动态扩展**: 随时添加新任务，不影响已完成任务
4. **可追溯**: 每个任务有创建时间、完成时间、耗时统计

## 任务状态

```
┌─────────┐    ┌──────────┐    ┌────────┐    ┌──────┐
│ pending │ → │ in_progress│ → │ review │ → │ done │
└─────────┘    └──────────┘    └────────┘    └──────┘
     ↑              ↓              ↓
     └──────── blocked ←──────────┘
```

- **pending**: 等待开始
- **in_progress**: 进行中（同一时间只能有一个）
- **blocked**: 被阻塞（等待依赖）
- **review**: 完成待审查
- **done**: 已完成

## 任务模板

```markdown
### Task-{ID}: {标题}
**状态**: {status}
**优先级**: P0/P1/P2/P3
**创建**: YYYY-MM-DD
**开始**: YYYY-MM-DD
**完成**: YYYY-MM-DD
**耗时**: Xh Ym

**描述**:
{任务描述}

**验收标准**:
- [ ] {标准1}
- [ ] {标准2}

**依赖**:
- Task-{ID}
- 外部: {描述}

**阻塞记录**:
- YYYY-MM-DD: {阻塞原因} → {解决方式}

**笔记**:
{执行过程中的关键决策、问题、解决方案}
```

## 目录结构

```
tasks/
├── README.md              # 本文件
├── active/                # 当前 Sprint 的任务
│   ├── sprint-01-core/    # Sprint 1: 核心基础设施
│   ├── sprint-02-agent/   # Sprint 2: Agent 能力
│   └── sprint-03-ui/      # Sprint 3: UI 界面
├── backlog/               # 待办任务池
│   ├── feature/           # 功能任务
│   ├── bugfix/            # 修复任务
│   ├── refactor/          # 重构任务
│   └── docs/              # 文档任务
├── completed/             # 已完成任务（按 Sprint 归档）
│   ├── sprint-01-core/
│   ├── sprint-02-agent/
│   └── ...
└── templates/             # 任务模板
    ├── feature.md
    ├── bugfix.md
    └── refactor.md
```

## 工作流程

### 1. 创建任务

```bash
# 从模板创建新任务
make task-create TYPE=feature TITLE="实现 Skill 注册表"
# 生成: tasks/backlog/feature/T-001-implement-skill-registry.md
```

### 2. 开始任务

```bash
# 将任务从 backlog 移到 active
make task-start T-001 SPRINT=sprint-01-core
# 状态变为 in_progress
```

### 3. 完成任务

```bash
# 标记完成，移到 review
make task-complete T-001
# 状态变为 review
```

### 4. 审查通过

```bash
# 审查通过，移到 completed
make task-approve T-001
# 状态变为 done，归档到 completed/
```

### 5. 添加新任务

```bash
# 随时添加新任务到 backlog
make task-create TYPE=feature TITLE="添加 PDF 支持"
# 动态扩展，不影响已有任务
```

## 紧急任务

### 🔴 Zig 0.16 迁移

Zig 0.16 引入了重大破坏性变更，特别是 I/O 系统的全面重构。详见：
- [迁移任务清单](./zig-0.16-migration.md)
- [迁移示例代码](../docs/migration-examples.md)
- [I/O Helper 模块](../src/utils/io_helper.zig)

**关键变更**:
- `std.fs.File` → `std.Io.File`
- I/O 操作需要 `std.Io` 实例
- `writer.print()` → `writer.interface.print()`
- ArrayList API 调整

**状态**: 🔴 阻塞中 - 必须先完成才能继续其他开发

---

## Sprint 规划

### Sprint 0: Zig 0.16 迁移 (当前)
- 目标: 适配 Zig 0.16 的破坏性变更
- 任务数: 15+ 个原子任务
- 产出: 可在 Zig 0.16 上编译运行的代码
- **阻塞**: 所有其他开发任务

### Sprint 1: Core Infrastructure (Week 1-2)
- 目标: 项目初始化 + 核心类型 + OpenAI Provider
- 任务数: 8-10 个原子任务
- 产出: 可运行的基础 CLI
- **依赖**: Sprint 0 完成

### Sprint 2: Agent Runtime (Week 3-4)
- 目标: Agent Loop + Tools + Memory
- 任务数: 10-12 个原子任务
- 产出: 可执行任务的 Agent

### Sprint 3: UI & Polish (Week 5-6)
- 目标: TUI + 优化 + 文档
- 任务数: 8-10 个原子任务
- 产出: 可用的产品

## 动态扩展示例

### 场景 1: 发现新需求

```
Sprint 2 进行中，发现需要 "代码语法高亮"

操作:
1. make task-create TYPE=feature TITLE="实现代码语法高亮"
2. 评估: 放入当前 Sprint 还是 Backlog？
3. 决定: 放入 Sprint 2（优先级高）
4. 调整: 将低优先级任务移出到 Backlog
```

### 场景 2: 任务拆分

```
Task-005 "实现 Agent Loop" 太大，需要拆分

操作:
1. 原任务标记为 superseded
2. 创建子任务:
   - Task-005a: 实现事件系统
   - Task-005b: 实现状态机
   - Task-005c: 实现循环控制
3. 更新依赖关系
```

### 场景 3: 阻塞处理

```
Task-010 "实现 TUI" 被阻塞，因为 libvaxis 有 bug

操作:
1. 标记状态为 blocked
2. 记录阻塞原因和预计解决时间
3. 并行执行其他任务
4. 阻塞解除后自动恢复
```

## 工具命令

```makefile
# 任务管理
task-create TYPE={feature|bugfix|refactor|docs} TITLE="..."
task-start ID SPRINT={sprint-name}
task-block ID REASON="..."
task-unblock ID
task-complete ID
task-approve ID

# 查询
task-list [STATUS] [SPRINT]
task-show ID
task-stats

# Sprint 管理
sprint-create NAME START=YYYY-MM-DD END=YYYY-MM-DD
sprint-close NAME
sprint-list
```

## 报告生成

```bash
# 生成 Sprint 报告
make sprint-report SPRINT=sprint-01-core

# 生成项目进度报告
make project-report

# 生成个人贡献报告
make contributor-report AUTHOR=davirain
```
