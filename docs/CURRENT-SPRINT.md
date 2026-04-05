# Current Sprint: Sprint 2026-04

**Sprint 目标**: 让 KimiZ 在当前环境（Zig 0.15.2）下恢复可编译、可测试、可运行，并验证最近提交的子 Agent 功能。  
**详细看板**: `tasks/active/sprint-2026-04/README.md`

---

## 成功标准

1. `zig build` ✅ 编译成功
2. `zig build test` ✅ 所有测试通过
3. `zig build run -- repl` 可启动并对话 ✅
4. `delegate` subagent 工具验证通过 ✅
5. git worktree 隔离验证通过 ✅

---

## 任务看板

### P0 - 阻塞级

#### FIX-ZIG-015: 修复 Zig 0.15.2 编译兼容性
- **状态**: `done`
- **Spec**: `docs/specs/FIX-ZIG-015-compatibility.md`
- **问题**: 代码使用了 Zig 0.16 API（`std.process.Init`, `std.Io`），但环境是 0.15.2
- **影响文件**: `src/main.zig`, `src/http.zig`, `src/utils/io_manager.zig` 等
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

#### T-119-VERIFY: 验证 git worktree 隔离
- **状态**: `todo`
- **Spec**: `docs/specs/T-119-verify-worktree.md` (待创建)
- **背景**: Commit `74c22ff` 实现了 worktree 隔离，但编译阻塞导致无法验证
- **影响文件**: `src/utils/worktree.zig`, `src/agent/subagent.zig`
- **验收**:
  - [ ] `WorktreeManager` 能正确创建/删除 worktree
  - [ ] Subagent 的文件操作默认发生在独立 worktree 中

### P1 - 高优先级

#### T-009-E2E: 补充端到端测试
- **状态**: `todo`
- **Spec**: `docs/specs/T-009-e2e-tests.md`
- **背景**: 项目目前测试覆盖率极低，需要至少覆盖核心路径
- **影响文件**: `tests/integration_tests.zig` 或新增 `tests/*.zig`
- **验收**:
  - [ ] Provider 解析测试（mock）
  - [ ] 工具调用测试（read_file, bash）
  - [ ] Agent Loop 基础测试
  - [ ] 所有测试通过

---

## 执行顺序

```
FIX-ZIG-015 → T-092-VERIFY → T-119-VERIFY → T-009-E2E
```

---

## 已完成（归档在 `tasks/completed/`）

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

---

## 归档说明

本 Sprint 完成后，下一个 Sprint 的目标将从 `backlog/phase-3-subagent/` 中取任务：
- Named Sub-agents（YAML 角色配置）
- Coordinator Mode MVP
- 安全分类器
- 工具调用摘要机制

**这些任务目前不在 Sprint 范围内，不要提前做。**

**最后更新**: 2026-04-06
