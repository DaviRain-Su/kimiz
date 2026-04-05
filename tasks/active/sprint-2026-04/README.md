# Sprint 2026-04: 恢复编译 + 验证 Phase 2 成果

**Sprint 周期**: 2026-04-06 开始  
**目标**: 让 KimiZ 在当前环境（Zig 0.15.2）下恢复可编译、可测试、可运行，并验证最近提交的子 Agent 功能。  
**负责**: Coding Agent

---

## 成功标准

1. `zig build` ✅ 零错误
2. `zig build test` ✅ 全部通过
3. `zig build run -- repl` 可启动并对话 ✅
4. `delegate` subagent 工具验证通过 ✅
5. git worktree 隔离验证通过 ✅

---

## 任务队列（严格顺序）

| # | 任务文件 | 标题 | 状态 | Spec |
|---|----------|------|------|------|
| 1 | `FIX-ZIG-015-compatibility.md` | ~~修复 Zig 0.15.2 编译兼容性~~ | `cancelled` | `docs/specs/FIX-ZIG-015-compatibility.md` |
| 2 | `T-092-verify-delegate-tool.md` | 验证 delegate subagent 注册 | `todo` | `docs/specs/T-092-verify-delegate-tool.md` |
| 3 | `T-119-verify-worktree.md` | 验证 git worktree 隔离 | `todo` | `docs/specs/T-119-verify-worktree.md` |
| 4 | `T-009-e2e-tests.md` | 补充 E2E 测试 | `todo` | `docs/specs/T-009-e2e-tests.md` |
| 5 | `T-120-design-document-driven-loop.md` | 设计文档驱动的 Agent 工作流 | `todo` | `docs/specs/T-120-design-document-driven-loop.md` |
| 6 | `T-121-implement-memory-tools.md` | 实现 Agent 长期记忆工具 | `todo` | `docs/specs/T-121-implement-memory-tools.md` |
| 7 | `T-122-prompt-document-driven-loop.md` | 改造 System Prompt 强制文档前置读取 | `todo` | `docs/specs/T-122-prompt-document-driven-loop.md` |
| 8 | `T-123-lessons-learned-and-consistency.md` | 建立 lessons-learned 和多 Agent 一致性 | `todo` | `docs/specs/T-123-lessons-learned-and-consistency.md` |

---

## 快速链接

- **路线图**: `docs/ROADMAP-v2.md`
- **特性清单**: `docs/FEATURES.md`
- **实现参考索引**: `docs/DESIGN-REFERENCES.md`（执行任务前必读）
- **Agent 入口**: `AGENT-ENTRYPOINT.md`
