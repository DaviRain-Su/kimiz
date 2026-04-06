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
| 4 | **`docs/guides/TASK-LIFECYCLE.md`** | 任务管理规范（**必读：做完必须归档**） |
| 5 | **`docs/ROADMAP-v2.md`** | 0-10 阶段统一路线图（需要上下文时读） |
| 6 | **`docs/FEATURES.md`** | 已实现特性清单（需要上下文时读） |

---

## 2. 当前 Sprint

|**Sprint 名称**: Sprint 2026-04 - Zig 0.16 稳定 + 战略扩展  
|**详细看板**: `tasks/active/sprint-2026-04/README.md`

### 前期任务（已完成并归档）

Sprint 2026-04 的前期目标已全部完成：
- Zig 0.16 API 迁移完成（T-125）
- 编译恢复、测试通过、REPL 可运行
- delegate / worktree / E2E / comptime DSL 验证通过
- Auto skill 流水线（T-100）和 AutoRegistry（T-101）设计完成
- Document-driven workflow 基础设施（T-120 ~ T-123）落地
- Observability Metrics Phase 1（T-124）完成

归档位置：`tasks/completed/sprint-2026-04/`

### 活跃任务队列

| # | 优先级 | 任务ID | 标题 | 状态 | Spec 文档 | 预计 |
|---|--------|--------|------|------|-----------|------|
| 1 | **P0** | **T-128** | **设计并实现 KimiZ 运行时任务状态机（TaskEngine）** | `done` | [`docs/specs/T-128-design-and-implement-task-engine.md`](docs/specs/T-128-design-and-implement-task-engine.md) | 12h |
| 2 | **P0** | **T-129** | **设计并实现 WASM-based Skill Plugin 系统** | `in-progress` | [`docs/specs/T-129-design-and-implement-wasm-skill-plugin-system.md`](docs/specs/T-129-design-and-implement-wasm-skill-plugin-system.md) | 16h |

> **原则：KimiZ 核心工具未夯实前，不启动任何上层垂直领域开发（如 T-127 区块链合约生成、T-126 高级可观测性）。T-128（调度器）+ T-129（WASM 插件）是当前 Sprint 的双核心。**
>
> 已冻结的上层任务：T-126（backlog/phase-3-subagent）、T-127（backlog/phase-8-platform）

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
- TaskEngine / Phase Execution: `src/engine/phase.zig`
- TaskEngine / ReviewAgent: `src/engine/review.zig`
- TaskEngine / Project & Task: `src/engine/project.zig`, `src/engine/task.zig`
- Prompt Loader: `src/prompts/loader.zig`

### 当前编译状态

- `zig build` ✅ 零错误（Zig 0.16）
- `zig build test` ✅ 全部通过
- `make build` / `make test` 推荐作为入口命令

---

## 6. 任务系统说明

我们已经重新整理了任务系统：

- **`tasks/active/sprint-2026-04/`** — 当前 Sprint 任务
- **`tasks/backlog/phase-N/`** — 未来任务（按 Phase 3-8 分组）
- **`tasks/completed/phase-N/`** — 已完成任务
- **`tasks/archive/`** — 历史归档（不要再碰）

如果你需要了解整体路线图，读 `docs/ROADMAP-v2.md`。

---

**当前开发分支**: `main`

**T-128 开发分支**: `rspace`（已合并到 `main` 并推送）

**最后更新**: 2026-04-06  
**维护者**: 任何进来的 Coding Agent
