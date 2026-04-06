# Task Lifecycle Management Guide

**适用对象**: 所有进入 KimiZ 项目的 Coding Agent  
**核心原则**: **Active 只放当前正在做的事，做完必须归档。**

---

## 1. 目录结构

```
tasks/
├── active/              ← 当前 Sprint 或当前正在执行的任务
│   ├── sprint-YYYY-MM/  ← 按 Sprint 分组
│   └── ...              ← 特殊全局 active 文档（如路线图，尽量少放）
├── backlog/             ← 已规划但尚未启动的任务
│   ├── phase-1-core-agent/
│   ├── phase-2-ux/
│   ├── phase-3-subagent/
│   ├── phase-8-platform/
│   └── research/        ← 纯研究类任务
├── completed/           ← 已完成的任务
│   ├── sprint-YYYY-MM/  ← 按 Sprint 归档
│   └── phase-N/         ← 按阶段归档
└── archive/             ← 过时/废弃/历史遗留（不要再碰）
```

---

## 2. 任务状态与目录映射

| 状态 | 所在目录 | 说明 |
|------|----------|------|
| `todo` / `in-progress` | `tasks/active/sprint-*/` | 当前 Sprint 正在推进的任务 |
| `spec` / `design` | `tasks/active/sprint-*/` 或 `tasks/backlog/` | 如果属于当前 Sprint，放 active；否则放 backlog |
| `done` / `completed` | `tasks/completed/sprint-*/` 或 `tasks/completed/phase-*/` | **必须从 active 移出** |
| `cancelled` | `tasks/completed/...` 或 `tasks/archive/` | 取消的任务也要移出 active |
| `backlog` / `frozen` | `tasks/backlog/...` | 已规划但暂不执行 |

---

## 3. 关键规则

### Rule 1: Active 目录只放"当前正在做"的事

- 一个 Sprint 周期内，active 目录里的具体任务文件应控制在 **5 个以内**。
- 已完成（`done`）的任务文件**不得**留在 active 目录超过一次 commit。
- Sprint 看板（`README.md`）可以留在 active，但它**不是任务文件**。

### Rule 2: 任务完成后必须立即归档

任务标记为 `done` 后，Agent 必须在**同一次 commit** 中执行：

```bash
# 1. 移动任务文件到 completed
mv tasks/active/sprint-2026-04/T-XXX-task-name.md tasks/completed/sprint-2026-04/

# 2. 更新 Sprint 看板，把该任务从活跃列表移除（移入"已完成归档"章节）
# 3. 提交 commit
```

### Rule 3: 冻结任务放回 backlog

如果当前决定暂停某个任务（如"等核心工具夯实后再做"），不要让它留在 active 里：

```bash
mv tasks/active/sprint-2026-04/T-XXX-task-name.md tasks/backlog/phase-N/
```

### Rule 4: 一个任务只有一个真实位置

禁止同一任务文件同时存在于：
- `tasks/active/` 和 `tasks/backlog/`
- `tasks/active/` 和 `tasks/completed/`
- `tasks/backlog/` 和 `tasks/completed/`

如果发现重复，立即删除错误位置的副本。

---

## 4. Sprint 看板的维护义务

Sprint `README.md` 是任务的**真实入口**，Agent 每次完成/移动任务后都必须更新它：

```markdown
## 当前主任务
| # | 任务文件 | 标题 | 状态 | Spec |
|---|----------|------|------|------|
| 1 | `T-XXX-...md` | ... | `in-progress` | ... |

## 已完成归档
- T-YYY: ...（已移至 `tasks/completed/sprint-2026-04/`）
- T-ZZZ: ...（已移至 `tasks/completed/sprint-2026-04/`）

## 冻结/延期任务
- T-AAA: ...（已移至 `tasks/backlog/...`）
```

---

## 5. 为什么这很重要

1. **减少认知负担**: 进来的 Agent 只需看 `tasks/active/` 就知道现在要做什么。
2. **避免重复工作**: 已完成的任务如果留在 active，可能被下一个 Agent 误认为是未完成的。
3. **保持诚实**: Active 目录的任务数量直接反映项目真实的并行度和焦点清晰度。
4. **文档即状态**: 目录结构就是项目状态的可视化仪表盘。

---

## 6. 快速检查清单

每次 commit 前问自己：

- [ ] 我刚完成的任务文件还在 active 里吗？如果是，移动到 completed。
- [ ] 我刚冻结/延期的任务文件还在 active 里吗？如果是，移动到 backlog。
- [ ] Sprint `README.md` 更新了吗？
- [ ] `AGENT-ENTRYPOINT.md` 的活跃任务列表更新了吗？
- [ ] `docs/CURRENT-SPRINT.md` 更新了吗？

---

**最后更新**: 2026-04-06
