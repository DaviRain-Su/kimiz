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

### T-126: Agent 研究与学习过程的可观测性
- **状态**: `spec`
- **说明**: 在 T-124 runtime metrics 基础上，补充 Agent 研究/学习阶段的可观测性。Spec 待创建。

### T-127: 将 zig-to-yul 集成为 KimiZ 的合约生成 skill
- **状态**: `todo`
- **Spec**: `docs/specs/T-127-integrate-zig-to-yul-as-contract-skill.md`
- **说明**: 把已有的 `zig-to-yul` 编译器与 KimiZ Agent 整合，实现需求 → Zig 合约 → EVM Bytecode → 测试部署的完整闭环。

---

## 执行顺序

```
T-126 (spec) → T-127 (implementation)
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
