# 🤖 KimiZ Coding Agent Entrypoint

> **如果你是来修改 KimiZ 代码的 Agent，这是你的唯一入口。**  
> 不要猜测，不要读旧的任务归档。一切当前可执行的任务都在这里。

---

## 0. 环境约束（必须先确认）

```bash
zig version  # 必须是 0.15.2
```

- **Zig 版本**: `0.15.2`
- **项目路径**: `/Users/davirian/dev/active/kimiz`
- **构建命令**: `zig build` / `zig build test`
- **当前状态**: ❌ **无法编译**（代码部分迁移到了 Zig 0.16 API，但环境仍是 0.15.2）

---

## 1. 当前 Sprint（本周内必须完成）

**Sprint 名称**: Phase 0 - 恢复编译 + 验证最近功能  
**截止日期**: 立即  
**成功标准**:
1. `zig build` 编译成功
2. `zig build test` 全部通过
3. REPL 可以启动并基本对话
4. `delegate` subagent 工具被验证可用

---

## 2. 执行任务队列（严格按顺序，不要跳过）

| # | 优先级 | 任务ID | 标题 | 状态 | Spec 文档 | 预计 |
|---|--------|--------|------|------|-----------|------|
| 1 | P0 | **FIX-ZIG-015** | 修复 Zig 0.15.2 编译兼容性 | `todo` | [`docs/specs/FIX-ZIG-015-compatibility.md`](docs/specs/FIX-ZIG-015-compatibility.md) | 1.5h |
| 2 | P0 | **T-092-VERIFY** | 验证 delegate subagent 注册（代码已提交，待验证） | `todo` | [`docs/specs/T-092-verify-delegate-tool.md`](docs/specs/T-092-verify-delegate-tool.md) | 30min |
| 3 | P1 | **T-009-E2E** | 补充 E2E 测试（核心工具 + Agent Loop） | `todo` | [`docs/specs/T-009-e2e-tests.md`](docs/specs/T-009-e2e-tests.md) | 4h |
| 4 | P1 | **T-086** | Session Persistence（代码已实现，更新任务状态） | `done` | - | - |
| 5 | P1 | **T-087** | Shell Mode（代码已实现，更新任务状态） | `done` | - | - |
| 6 | P1 | **T-088** | Plan Mode（代码已实现，更新任务状态） | `done` | - | - |
| 7 | P1 | **T-095** | YOLO Tool Approval（代码已实现，更新任务状态） | `done` | - | - |

> **规则**: 只有上一行标记为 `done` 后，才能开始下一行的 `todo` 任务。

---

## 3. 工作流程（每做一个任务必须执行）

1. **从队列中选第一个 `todo` 任务**
2. **阅读对应的 Technical Spec**（`docs/specs/` 下的 `.md` 文件）
3. **实现代码**
4. **运行 `zig build test`**（必须全绿）
5. **更新本文件中的状态**（把 `todo` 改成 `done`）
6. **提交 commit**，消息格式：
   ```
   fix: 简短描述 (任务ID)

   - 具体修改
   - 验证方式: zig build test 通过
   ```

---

## 4. 噪音文档（不要读，会误导你）

以下文档写于编译修复之前，内容已过时：

- ❌ `docs/08-project-audit-report.md`
- ❌ `docs/09-task-status-audit.md`
- ❌ `docs/10-handoff-to-coding-agent.md`
- ❌ `tasks/active/sprint-01-core/T-00*.md`（旧 Sprint，状态混乱）
- ❌ `tasks/archive/*`（历史归档）

---

## 5. 快速参考

### 关键代码位置
- 入口: `src/main.zig`
- CLI/REPL: `src/cli/root.zig`
- Agent Loop: `src/agent/agent.zig`
- Subagent: `src/agent/subagent.zig`
- HTTP: `src/http.zig`
- 工具: `src/agent/tools/*.zig`
- Skills: `src/skills/*.zig`

### 当前已知编译错误
1. `src/main.zig:5:30`: `root source file struct 'process' has no member named 'Init'`
   - 原因: 使用了 Zig 0.16 的 `std.process.Init`
2. `src/http.zig:48:51`: `no field named 'io' in struct 'http.Client'`
   - 原因: 使用了 Zig 0.16 的 `std.Io`

解决方案详见 **FIX-ZIG-015** 的 Spec。

---

**最后更新**: 2026-04-06  
**维护者**: 任何进来的 Coding Agent
