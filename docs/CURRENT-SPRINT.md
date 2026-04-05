# Current Sprint: Phase 0 - 恢复编译 + 验证最近功能

**Sprint 目标**: 让 KimiZ 在当前环境（Zig 0.15.2）下恢复可编译、可测试、可运行。  
**成功标准**:
- `zig build` ✅
- `zig build test` ✅
- `zig build run -- repl` 可启动并对话 ✅
- `delegate` subagent 工具验证通过 ✅

---

## 任务看板

### P0 - 阻塞级

#### FIX-ZIG-015: 修复 Zig 0.15.2 编译兼容性
- **状态**: `todo`
- **Spec**: `docs/specs/FIX-ZIG-015-compatibility.md`
- **问题**: 代码使用了 Zig 0.16 API（`std.process.Init`, `std.Io`），但环境是 0.15.2
- **影响文件**: `src/main.zig`, `src/http.zig`, `src/utils/io_manager.zig`
- **验收**:
  - [ ] `zig build` 成功
  - [ ] `zig build test` 成功
  - [ ] REPL 可启动

#### T-092-VERIFY: 验证 delegate subagent 注册
- **状态**: `todo`
- **Spec**: `docs/specs/T-092-verify-delegate-tool.md`
- **背景**: Commit `9a24161` 声称已完成注册，但编译阻塞导致无法验证
- **影响文件**: `src/agent/agent.zig`, `src/cli/root.zig`, `src/agent/subagent.zig`
- **验收**:
  - [ ] AI 可以在 REPL 中调用 `delegate` 工具
  - [ ] 子代理结果正确返回
  - [ ] 深度限制有效

### P1 - 高优先级

#### T-009-E2E: 补充 E2E 测试
- **状态**: `todo`
- **Spec**: `docs/specs/T-009-e2e-tests.md`
- **背景**: 项目目前测试覆盖率极低，需要至少覆盖核心路径
- **影响文件**: `tests/integration_tests.zig` 或新增 `tests/*.zig`
- **验收**:
  - [ ] Provider 解析测试（mock）
  - [ ] 工具调用测试（read_file, bash）
  - [ ] Agent Loop 基础测试
  - [ ] 所有测试通过

### 已完成（代码已实现，只需更新任务状态）

| 任务ID | 标题 | Commit | 状态 |
|--------|------|--------|------|
| T-086 | Session Persistence | `f7ee56a` | `done` |
| T-087 | Shell Mode | `0edec45` | `done` |
| T-088 | Plan Mode | `a371fc5` | `done` |
| T-095 | YOLO Tool Approval | `0edec45` | `done` |

> 注: T-086 ~ T-095 的代码已经提交到仓库，但对应的任务文件（`tasks/active/T-086*.md` 等）可能还标记为 `in-progress`。如有需要，更新这些文件的状态为 `completed`。

---

## 执行顺序

```
FIX-ZIG-015 → T-092-VERIFY → T-009-E2E
     ↓
(同时更新 T-086~T-095 任务文件状态)
```

---

## 归档说明

本 Sprint 完成后，下一个 Sprint（Phase 1）将是：
- Harness 核心增强: WorkspaceContext, PromptCache, Context Truncation
- 但目前这些任务**不在本 Sprint 范围内**，不要提前做。

**最后更新**: 2026-04-06
