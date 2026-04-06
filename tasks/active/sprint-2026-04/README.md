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
- T-100: 建立 auto skill 自动生成流水线
- T-101: 设计 AutoRegistry 动态加载
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

## 当前主任务

| # | 任务文件 | 标题 | 状态 | Spec |
|---|----------|------|------|------|
| 1 | `T-128-design-and-implement-task-engine.md` | **设计并实现 KimiZ 运行时任务状态机（TaskEngine）** | `todo` | `docs/specs/T-128-design-and-implement-task-engine.md` |
| 2 | `T-129-design-and-implement-wasm-skill-plugin-system.md` | **设计并实现 WASM-based Skill Plugin 系统** | `todo` | `docs/specs/T-129-design-and-implement-wasm-skill-plugin-system.md` |

> **说明**：T-129 是 T-128 的产品化延续。T-128 解决任务自动编排，T-129 解决终端用户自定义 Skill 的动态加载问题。两者属于同一 Sprint 核心工具链。

---

## 快速链接

- **路线图**: `docs/ROADMAP-v2.md`
- **特性清单**: `docs/FEATURES.md`
- **实现参考索引**: `docs/DESIGN-REFERENCES.md`（执行任务前必读）
- **Agent 入口**: `AGENT-ENTRYPOINT.md`
