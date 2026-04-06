# Sprint 2026-04: KimiZ 核心工具夯实

**Sprint 周期**: 2026-04-06 开始  
**目标**: 完善 KimiZ 核心工具链，不启动任何上层垂直领域开发

**负责**: Coding Agent

---

## 成功标准

1. `zig build` ✅ 零错误（Zig 0.16）
2. `zig build test` ✅ 全部通过
3. `zig build run -- repl` 可启动并对话 ✅
4. KimiZ 核心基础设施（Skill 系统、Agent Loop、工具链）稳定可用

---

## 已完成任务（已归档至 `tasks/completed/sprint-2026-04/`）

- T-092: 验证 delegate subagent 注册
- T-119: 验证 git worktree 隔离
- T-009: 补充 E2E 测试
- T-103-SPIKE: comptime Skill DSL 原型验证（结果为 GO）
- T-100: 建立 auto skill 自动生成流水线（设计完成）
- T-101: 设计 AutoRegistry 动态加载（设计完成）
- T-120: 设计文档驱动的 Agent 工作流
- T-121: 实现 Agent 长期记忆工具
- T-122: 改造 System Prompt 强制文档前置读取
- T-123: 建立 lessons-learned 和多 Agent 一致性
- T-124: Observability Metrics - Phase 1
- T-125: 完成 Zig 0.16 API 迁移

---

## 已冻结的上层任务（暂不做）

| 任务 | 位置 | 说明 |
|------|------|------|
| T-126 | `tasks/backlog/phase-3-subagent/` | Agent 研究与学习过程的可观测性（上层扩展） |
| T-127 | `tasks/backlog/phase-8-platform/` | zig-to-yul 合约生成 skill（区块链上层应用） |

> **原则：KimiZ 核心工具未夯实前，不启动任何上层垂直领域开发。**

---

## 当前活跃任务

**待确定**：需要重新评估 KimiZ 核心工具链中，哪些设计任务（如 T-100/T-101）需要真正代码实现，或是否有其他核心阻塞项。
