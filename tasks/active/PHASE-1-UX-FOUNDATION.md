# Phase 1: 用户体验基础（追赶 kimi-cli）

**状态**: active
**目标**: 补齐 KimiZ 与官方 kimi-cli 之间的核心用户体验差距
**时间**: 4 周
**创建日期**: 2026-04-05
**更新日期**: 2026-04-05

---

## 背景

KimiZ 的底层架构（Zig 原生、快速启动、Skill 体系）已经稳定（MVP v0.4.0）。但与官方 kimi-cli 相比，在**日常交互体验**上仍有明显差距。本阶段聚焦最影响用户高频使用的功能：会话持久化、Shell 模式、YOLO 审批、Plan 模式。

参考差距分析: `docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md`

---

## 活跃任务

| 任务 | 文档 | 目标 | 预计工时 |
|------|------|------|----------|
| **T-086** 会话持久化 | [T-086-implement-session-persistence.md](./T-086-implement-session-persistence.md) | `--continue`, `--session`, `/sessions`, `/resume`, `/title` | 8h |
| **T-087** Shell 模式 | [T-087-implement-shell-mode.md](./T-087-implement-shell-mode.md) | `$` 前缀 / `Ctrl-X` 切换，直接执行 shell 命令 | 6h |
| **T-088** Plan 模式 | [T-088-implement-plan-mode.md](./T-088-implement-plan-mode.md) | `/plan` 切换，AI 只读探索后生成 Markdown 规划 | 10h |
| **T-095** YOLO / 工具审批 | [T-095-complete-tool-approval-yolo-mode.md](./T-095-complete-tool-approval-yolo-mode.md) | Ask/Session/Always 三级审批，集成到 Agent loop | 10h |
| **MVP-GIT** Git 工具集 | [MVP-GIT-TOOLS.md](./MVP-GIT-TOOLS.md) | `git_status`, `git_diff`, `git_log` | ✅ 已完成 |

---

## 工程参考

所有任务实现时应参考 `docs/TIGERBEETLE-PATTERNS-ANALYSIS.md` 中的最佳实践：

- **内存管理**: Arena + Pool，边界清晰
- **数据结构**: 侵入式链表（会话队列、任务队列）
- **安全**: 高密度断言，状态机不变量检查
- **测试**: 核心模块增加 fuzz 测试

---

## 验收标准

- [ ] `kimiz --continue` 能恢复昨天的会话
- [ ] 在 REPL 中按 `$` 前缀可直接执行 shell 命令
- [ ] `/plan` 模式下 AI 不会调用 write/edit/bash 工具
- [ ] 工具调用前出现清晰的审批提示（可配置 YOLO 级别）
- [ ] 所有功能通过 `zig build test`

---

## 已完成

- ✅ MVP-GIT-TOOLS: 内置 Git 工具集（2026-04-05）
- ✅ MVP Phase A/B: 核心稳定性 + 质量提升
