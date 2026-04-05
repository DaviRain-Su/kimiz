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
| 1 | `FIX-ZIG-015-compatibility.md` | 修复 Zig 0.15.2 编译兼容性 | `todo` | `docs/specs/FIX-ZIG-015-compatibility.md` |
| 2 | `T-092-verify-delegate-tool.md` | 验证 delegate subagent 注册 | `todo` | `docs/specs/T-092-verify-delegate-tool.md` |
| 3 | `T-119-verify-worktree.md` | 验证 git worktree 隔离 | `todo` | `docs/specs/T-119-verify-worktree.md` (待创建) |
| 4 | `T-009-e2e-tests.md` | 补充 E2E 测试 | `todo` | `docs/specs/T-009-e2e-tests.md` |

---

## 快速链接

- **路线图**: `docs/ROADMAP-v2.md`
- **特性清单**: `docs/FEATURES.md`
- **Agent 入口**: `AGENT-ENTRYPOINT.md`
