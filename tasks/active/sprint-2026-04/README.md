# Sprint 2026-04: Zig 0.16 稳定 + 战略扩展

**Sprint 周期**: 2026-04-06 开始  
**目标**: 
1. 确保 KimiZ 在 Zig 0.16 下可编译、可测试、可运行
2. 验证 Phase 2 核心成果（子 Agent、E2E、comptime DSL）
3. 推进 T-127：将 `zig-to-yul` 集成为合约生成 skill（Scale 战略新里程碑）

**负责**: Coding Agent

---

## 成功标准

1. `zig build` ✅ 零错误（Zig 0.16）
2. `zig build test` ✅ 全部通过
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

## 当前活跃任务队列

| # | 任务文件 | 标题 | 状态 | Spec |
|---|----------|------|------|------|
| 1 | `T-126-auto-research-metrics.md` | Agent 研究与学习过程的可观测性 | `spec` | 待创建 |
| 2 | `T-127-integrate-zig-to-yul-as-contract-skill.md` | **将 zig-to-yul 集成为 KimiZ 的合约生成 skill** | `todo` | `docs/specs/T-127-integrate-zig-to-yul-as-contract-skill.md` |

---

## 快速链接

- **路线图**: `docs/ROADMAP-v2.md`
- **特性清单**: `docs/FEATURES.md`
- **实现参考索引**: `docs/DESIGN-REFERENCES.md`（执行任务前必读）
- **Agent 入口**: `AGENT-ENTRYPOINT.md`
