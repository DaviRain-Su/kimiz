# 🤖 KimiZ Coding Agent Entrypoint

> **如果你是来修改 KimiZ 代码的 Agent，先读 `AGENTS.md`，再读本文档。**  
> `AGENTS.md` 是通用行为规范，本文档是当前执行状态的实时看板。

---

## 0. 环境约束（必须先确认）

```bash
zig version  # 必须是 0.16.0-dev+
```

- **Zig 版本**: `0.16.0-dev`（Makefile 使用 `$(HOME)/zig-0.16.0-dev/zig`）
- **项目路径**: `/Users/davirian/dev/active/kimiz`
- **构建命令**: `make build` / `make test`（推荐）或 `zig build` / `zig build test`
- **当前状态**: ✅ **代码已升级到 Zig 0.16 API**
- **⚠️ 注意**: 部分开发/CI 环境可能仍为 0.15.2，需优先保证 0.16 编译通过

---

## 1. 文档地图（按优先级阅读）

| 顺序 | 文档 | 作用 |
|------|------|------|
| 1 | **`AGENT-ENTRYPOINT.md`** | 本文件，当前执行入口 |
| 2 | **`tasks/active/sprint-2026-04/README.md`** | 当前 Sprint 看板 |
| 3 | **`docs/DESIGN-REFERENCES.md`** | 实现参考索引（做任务前必须查） |
| 4 | **`docs/specs/FIX-ZIG-015-compatibility.md`** | 第一个任务的 Technical Spec |
| 5 | **`docs/ROADMAP-v2.md`** | 0-10 阶段统一路线图（需要上下文时读） |
| 6 | **`docs/FEATURES.md`** | 已实现特性清单（需要上下文时读） |

---

## 2. 当前 Sprint（本周内必须完成）

**Sprint 名称**: Sprint 2026-04 - 恢复编译 + 验证 Phase 2 成果  
**详细看板**: `tasks/active/sprint-2026-04/README.md`

### 执行任务队列（严格按顺序，不要跳过）

| # | 优先级 | 任务ID | 标题 | 状态 | Spec 文档 | 预计 |
|---|--------|--------|------|------|-----------|------|
| 1 | P0 | **FIX-ZIG-015** | ~~修复 Zig 0.15.2 编译兼容性~~ | `cancelled` | 已确认项目目标为 Zig 0.16，此修复回滚 | - |
| 2 | P0 | **T-092-VERIFY** | 验证 delegate subagent 注册 | `done` | [`docs/specs/T-092-verify-delegate-tool.md`](docs/specs/T-092-verify-delegate-tool.md) | 30min |
| 3 | P0 | **T-119-VERIFY** | 验证 git worktree 隔离 | `done` | [`docs/specs/T-119-verify-worktree.md`](docs/specs/T-119-verify-worktree.md) | 1h |
| 4 | P1 | **T-009-E2E** | 补充 E2E 测试（核心工具 + Agent Loop） | `done` | [`docs/specs/T-009-e2e-tests.md`](docs/specs/T-009-e2e-tests.md) | 4h |
| 5 | **P0** | **T-103-SPIKE** | **comptime Skill DSL 原型验证（Scale 战略关键）** | `done` | [`docs/specs/T-103-spike-comptime-skill-dsl.md`](docs/specs/T-103-spike-comptime-skill-dsl.md) | 4h |
| 6 | P1 | **T-100** | 建立 auto skill 自动生成流水线 | `done` | [`docs/specs/T-100-establish-auto-skill-generation-pipeline.md`](docs/specs/T-100-establish-auto-skill-generation-pipeline.md) | 12h |
| 7 | P1 | **T-101** | 设计 AutoRegistry 动态加载 | `done` | [`docs/specs/T-101-design-autoregistry-dynamic-loading.md`](docs/specs/T-101-design-autoregistry-dynamic-loading.md) | 10h |
| 8 | P1 | **T-120-DESIGN** | 设计文档驱动的 Agent 工作流 | `todo` | [`docs/specs/T-120-design-document-driven-loop.md`](docs/specs/T-120-design-document-driven-loop.md) | 2h |
| 9 | P1 | **T-121-IMPLEMENT** | 实现 Agent 长期记忆工具 | `todo` | [`docs/specs/T-121-implement-memory-tools.md`](docs/specs/T-121-implement-memory-tools.md) | 4h |
| 10 | P1 | **T-122-PROMPT** | 改造 System Prompt 强制文档前置读取 | `todo` | [`docs/specs/T-122-prompt-document-driven-loop.md`](docs/specs/T-122-prompt-document-driven-loop.md) | 3h |
| 11 | P2 | **T-123-LESSONS** | 建立 lessons-learned 和多 Agent 一致性 | `todo` | [`docs/specs/T-123-lessons-learned-and-consistency.md`](docs/specs/T-123-lessons-learned-and-consistency.md) | 3h |
| 12 | **P1** | **T-124-METRICS** | **Observability Metrics - Phase 1 (内置收集)** | `research` | [`docs/specs/T-124-observability-metrics-phase1.md`](docs/specs/T-124-observability-metrics-phase1.md) | 6-8h |

> **规则**: 只有上一行标记为 `done` 后，才能开始下一行的 `todo` 任务。

---

## 3. 工作流程（每做一个任务必须执行）

1. **阅读 `docs/DOCUMENT-DRIVEN-WORKFLOW.md`**，确认当前任务所处的生命周期状态
2. **从队列中选第一个 `todo` 或 `in-progress` 任务**
3. **阅读任务文件本身**（检查 `Research` 和 `Log` 章节）
4. **阅读对应的 Technical Spec**（`docs/specs/` 下的 `.md` 文件）
5. **根据任务阶段，阅读 `docs/DESIGN-REFERENCES.md` 中的相关参考文档**
6. **实现代码**
   - 遵守参考文档中的设计原则
   - **必须使用 Zig 0.16 API**（如 `std.process.Init`, `std.Io` 等），禁止使用已废弃的 0.15 API
7. **在任务文件的 `Log` 章节追加你的执行记录**
8. **运行 `zig build test`**（在 Zig 0.16 环境下必须全绿）
9. **完成任务后，填写 `Lessons Learned` 并检查是否需要更新 `DESIGN-REFERENCES.md` 或 `lessons-learned.md`**
10. **更新本文件中的状态**（把 `todo` 改成 `done`）
11. **更新 `tasks/active/sprint-2026-04/README.md` 中的状态**
12. **提交 commit**，消息格式：
    ```
    fix: 简短描述 (任务ID)

    - 具体修改
    - 验证方式: zig build test 通过
    ```

---

## 4. 噪音文档（不要读，会误导你）

以下文档写于编译修复之前，内容已过时：

- ❌ `docs/reports/08-project-audit-report.md`
- ❌ `docs/reports/09-task-status-audit.md`
- ❌ `docs/reports/10-handoff-to-coding-agent.md`
- ❌ `docs/reports/review-report.md`
- ❌ `tasks/archive/sprint-01-core/T-00*.md`（旧 Sprint，状态混乱）
- ❌ `tasks/archive/old-backlog/*`（历史归档）

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
- Worktree: `src/utils/worktree.zig`

### 当前已知编译错误
1. `src/main.zig:5:30`: `root source file struct 'process' has no member named 'Init'`
   - 原因: 使用了 Zig 0.16 的 `std.process.Init`
2. `src/http.zig:48:51`: `no field named 'io' in struct 'http.Client'`
   - 原因: 使用了 Zig 0.16 的 `std.Io`

解决方案详见 **FIX-ZIG-015** 的 Spec。

---

## 6. 任务系统说明

我们已经重新整理了任务系统：

- **`tasks/active/sprint-2026-04/`** — 当前 Sprint 任务
- **`tasks/backlog/phase-N/`** — 未来任务（按 Phase 3-8 分组）
- **`tasks/completed/phase-N/`** — 已完成任务
- **`tasks/archive/`** — 历史归档（不要再碰）

如果你需要了解整体路线图，读 `docs/ROADMAP-v2.md`。

---

**最后更新**: 2026-04-06  
**维护者**: 任何进来的 Coding Agent
