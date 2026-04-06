# Current Sprint: Sprint 2026-04

**Sprint 目标**: 
1. 确保 KimiZ 在 Zig 0.16 下稳定编译、测试、运行
2. 验证 Phase 2 核心成果（子 Agent、E2E、comptime DSL）
3. 推进 T-127：将 `zig-to-yul` 集成为合约生成 skill（Scale 战略新里程碑）

**详细看板**: `tasks/active/sprint-2026-04/README.md`

---

## 成功标准

1. `zig build` ✅ 编译成功（Zig 0.16）
2. `zig build test` ✅ 所有测试通过
3. `zig build run -- repl` 可启动并对话 ✅
4. `delegate` subagent 工具验证通过 ✅
5. git worktree 隔离验证通过 ✅
6. T-103 comptime Skill DSL 原型验证通过 ✅

---

## 已完成任务（已归档至 `tasks/completed/sprint-2026-04/`）

- T-092: 验证 delegate subagent 注册
- T-119: 验证 git worktree 隔离
- T-009: 补充 E2E 测试
- T-103-SPIKE: comptime Skill DSL 原型验证（**Scale 战略关键，结果为 GO**）
- T-100: 建立 auto skill 自动生成流水线
- T-101: 设计 AutoRegistry 动态加载
- T-120: 设计文档驱动的 Agent 工作流
- T-121: 实现 Agent 长期记忆工具
- T-122: 改造 System Prompt 强制文档前置读取
- T-123: 建立 lessons-learned 和多 Agent 一致性
- T-124: Observability Metrics - Phase 1
- T-125: 完成 Zig 0.16 API 迁移

---

## 活跃任务

### T-128: 设计并实现 KimiZ 运行时任务状态机（TaskEngine）
- **状态**: `todo`
- **Spec**: `docs/specs/T-128-design-and-implement-task-engine.md`
- **说明**: KimiZ 目前有能力模块（Skill、Subagent、文档驱动、Metrics）但缺少调度器。TaskEngine 让 Agent 启动时自动加载任务队列、解析依赖、自动推进、自动归档，是实现 autonomous 执行的关键基础设施。
- **验收要点**:
  - [ ] 解析 `tasks/active/` 构建运行时任务图
  - [ ] `getNextTask()` 按优先级+依赖返回正确任务
  - [ ] `startTask/completeTask/archiveCompleted` 闭环
  - [ ] CLI `kimiz run --autonomous` 最小可行版本

### T-129: 设计并实现 WASM-based Skill Plugin 系统
- **状态**: `todo`
- **Spec**: `docs/specs/T-129-design-and-implement-wasm-skill-plugin-system.md`
- **说明**: T-128 解决自动编排，但终端用户无法在不重新编译 Zig 的情况下自定义 Skill。WASM Plugin 是唯一能让 KimiZ 作为二进制产品支持用户自定义 Skill 的路径。基于已有的 `zwasm` 依赖，实现运行时加载、执行、热重载和安全沙箱。
- **验收要点**:
  - [ ] `PluginLoader` 能加载并执行 `.wasm` skill
  - [ ] `PluginRegistry` 支持扫描目录和热重载
  - [ ] CLI `kimiz skill create <desc> --wasm` 自动生成并编译 WASM
  - [ ] WASM skill 能被 TaskEngine 无差别调度
  - [ ] 沙箱限制（内存、超时、权限）生效

---

## 已冻结的上层任务（KimiZ 核心夯实前不做）

| 任务 | 位置 | 说明 |
|------|------|------|
| T-126 | `tasks/backlog/phase-3-subagent/` | Agent 研究与学习过程的可观测性（上层扩展） |
| T-127 | `tasks/backlog/phase-8-platform/` | zig-to-yul 合约生成 skill（区块链上层应用） |

> **原则：KimiZ 核心工具未夯实前，不启动任何上层垂直领域开发。**

---

## 执行顺序

```
[待确定核心任务] → [核心工具夯实] → 解冻上层任务
```

---

## 已完成归档

### Phase 0: 基础
- 项目结构、构建系统

### Phase 1: 核心 Agent
- Agent Loop、事件系统、5 Providers、7 工具、Skills 框架、RTK 优化

### Phase 2: 用户体验
- T-086 Session Persistence (`f7ee56a`)
- T-087 Shell Mode (`0edec45`)
- T-088 Plan Mode (`a371fc5`)
- T-095 YOLO Tool Approval (`0edec45`)
- MVP-GIT-TOOLS (`88c0af4`)

### Phase 3: 子 Agent（部分代码已提交）
- T-092 delegate 注册 (`9a24161`)
- T-119 git worktree 隔离 (`74c22ff`)

### Sprint 2026-04 前期
- T-125 Zig 0.16 迁移
- T-009 E2E 测试
- T-103 comptime DSL Spike
- T-100 / T-101 Auto skill / Registry
- T-120 ~ T-123 Document-driven workflow
- T-124 Observability Metrics Phase 1

---

## 未来方向

Sprint 2026-04 完成后，下一阶段目标可能从 backlog 中取：
- T-127 深度实现（`defineContract` DSL、安全规则、forge 测试集成）
- Named Sub-agents（YAML 角色配置）
- Coordinator Mode MVP
- 安全分类器
- 工具调用摘要机制

**最后更新**: 2026-04-06
