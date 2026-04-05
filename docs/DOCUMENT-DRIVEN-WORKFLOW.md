# 文档驱动任务管理规范

> **本规范定义 KimiZ 项目中任务（Task）的完整生命周期。**  
> 任何进入任务系统的工作项，都必须遵循此规范。  
> 基于 yage.ai《从上下文失忆到文档驱动开发》的方法论设计。

---

## 1. 核心原则

### 1.1 任务 = 长期记忆的载体

Agent 的上下文窗口是有限的，但任务文档是持久的。**任务的执行过程本身就是知识的沉淀过程。**

### 1.2 "边做边学"，不是"先学再做"

调研（Research）和实现（Implement）不是两个独立的阶段。
- **创建任务时**：必须列出已知的相关参考
- **执行任务时**：允许在阅读参考后发现需要补充新的分析，但必须在 `Log` 中记录这个发现
- **完成任务时**：必须把经验教训写回项目的长期记忆（`lessons-learned.md` 或更新 `DESIGN-REFERENCES.md`）

### 1.3 没有 Spec，不写代码

对于任何涉及代码改动的任务（Bugfix、Feature、Refactor），**必须先有 Technical Spec**，并在任务文件中明确引用。

---

## 2. 任务的四态生命周期

每个任务在系统中必须明确处于以下四种状态之一：

| 状态 | 含义 | 进入条件 | 退出条件 |
|------|------|----------|----------|
| **`research`** | 正在收集参考和分析 | 任务创建时，如果相关参考不足 | `Research` 章节已列出足够的参考文档 |
| **`spec`** | 正在编写/完善 Technical Spec | `research` 完成，且任务涉及代码改动 | `docs/specs/<task-id>.md` 已创建并通过 review |
| **`implement`** | 正在写代码 | `spec` 完成（或任务本身不需要代码改动） | 代码已提交，且 `zig build test` 通过 |
| **`verify`** | 正在验证/验收 | `implement` 完成 | 所有验收标准已勾选并通过 |
| **`done`** | 已完成 | `verify` 完成 | — |

> **状态流转是单向的**：`research` → `spec` → `implement` → `verify` → `done`  
> 不允许倒流。如果发现有重大问题，创建**新任务**来修复，而不是把当前任务状态改回去。

---

## 3. 任务文件模板（强制使用）

创建新任务时，必须使用以下模板。不允许缺少任何带 `*` 的章节。

```markdown
# <TASK-ID>: <标题>

**任务类型**: Research / Design / Implementation / Verification / Bugfix / Refactor  
**优先级**: P0 / P1 / P2  
**预计耗时**: Xh  
**创建日期**: YYYY-MM-DD

---

## 1. 背景与目标 (*)

（为什么做这个任务，完成后项目会有什么变化）

## 2. Research (*)

做这个任务前，必须阅读和参考的文档。

- [ ] `docs/research/XXXX.md` — 说明这个参考和本任务的关系
- [ ] `docs/guides/YYYY.md` — 说明这个参考和本任务的关系
- [ ] `docs/design/ZZZZ.md` — 说明这个参考和本任务的关系

> 如果在实现过程中发现需要补充新的参考，更新此列表，并在 `Log` 中记录。

## 3. Spec

> 如果本任务**不涉及代码改动**，可以写 "N/A"。  
> 如果涉及代码改动，必须链接到 `docs/specs/<TASK-ID>.md`。

**Spec 文件**: `docs/specs/<TASK-ID>.md`

### 3.1 关键设计决策
（用 bullet 列出本任务的核心设计选择，以及为什么这样选）

### 3.2 影响文件
| 文件 | 预期改动 |
|------|----------|
| `src/xxx.zig` | 描述 |

## 4. 验收标准 (*)

- [ ] 标准 1
- [ ] 标准 2
- [ ] `zig build test` 通过（任何代码任务都必须包含此项）

## 5. Log (*)

> 执行任务的过程中，**每做一步都要在这里追加记录**。这是 Agent 的自我修正历史。

- `YYYY-MM-DD HH:MM` — 创建了任务，初始状态为 `research`
- `YYYY-MM-DD HH:MM` — 完成了 Research，状态改为 `spec`
- `YYYY-MM-DD HH:MM` — 开始实现，发现 `std.Io` 的用法与预期不同，参考了 `docs/guides/ZIG-0.16-BREAKING-CHANGES-SUMMARY.md` 后修正

## 6. Lessons Learned

> 任务完成后，填写此章节。这是把个人任务经验升级为项目级长期记忆的关键步骤。

**分类**: 架构决策 / 踩坑记录 / 性能优化 / API 选择 / 工具使用

**内容**:
- 这个任务中最关键的教训是什么？
- 如果重来一次，你会怎么做不同？
- 有什么可以被其他任务复用的知识？

**后续动作**:
- [ ] 更新 `docs/DESIGN-REFERENCES.md`（如果本任务产出了新的分析结论）
- [ ] 更新 `docs/lessons-learned.md`（如果这个教训具有通用性）
```

---

## 4. 新任务插入的自动编排规则

当一个新需求出现时，按照以下决策树来创建和组织任务：

### 规则 1：是否需要先调研？

如果新任务涉及以下任一情况，**必须先创建 Research 子任务或进入 `research` 状态**：
- 引用了一个外部项目/框架/协议（如 "集成 MCP"、"参考 TigerBeetle"）
- 当前 `docs/research/` 中没有对应的分析文档
- 任务描述中出现了 "调研"、"分析"、"评估"、"对比" 等关键词

**编排动作**：
- 如果调研内容足够独立，拆分为独立的 Research 任务（如 `T-XXX-research-mcp-client.md`）
- 如果调研量小，作为本任务的 `research` 阶段执行

### 规则 2：是否需要写 Spec？

如果新任务类型是以下之一，**必须有独立的 Spec 文件**：
- `Implementation`
- `Feature`
- `Bugfix`（影响超过 3 个文件的 Bugfix）
- `Refactor`

**编排动作**：
- 自动创建 `docs/specs/<TASK-ID>.md`
- 在任务文件中使用 `Spec` 章节链接到它
- 如果 Spec 已存在（如前置 Research 任务产出了设计文档），直接引用

### 规则 3：是否会影响项目级设计参考？

如果新任务满足以下任一条件，完成后**必须更新 `DESIGN-REFERENCES.md`**：
- 产出了新的外部项目分析文档（放入 `docs/research/`）
- 修改了核心架构（Agent Loop、工具系统、Provider 层）
- 引入了新设计模式或编码规范

### 规则 4：是否需要沉淀经验教训？

**所有 `P0` 和 `P1` 任务**，完成后必须在任务文件的 `Lessons Learned` 章节中至少写一条总结。

---

## 5. "边做边学"的执行规范

### 5.1 Agent（或人类）开始执行任务前，必须检查

1. 本任务文件是否包含 `Research` 章节？
2. `Research` 章节中是否至少有一个相关参考？
3. 如果涉及代码改动，是否有 `Spec` 章节且链接有效？
4. 当前任务状态是否为 `implement`（如果是代码任务）？

如果任何一条不满足，**停止执行**，先补齐文档。

### 5.2 Agent 在执行中必须做的事

每完成一个"有意义的步骤"（如：写完一个函数、修复一个 bug、完成一轮验证），必须：
1. **在 `Log` 中追加记录**
2. 如果这个步骤推翻了一个之前的设计假设，**更新 `Spec` 文件**
3. 如果发现了一个新的坑，**在 `Lessons Learned` 中写一条草稿**

### 5.3 Agent 完成任务时必须做的事

1. 勾选所有 `验收标准`
2. 完善 `Lessons Learned` 章节
3. 执行 `后续动作`（更新 `DESIGN-REFERENCES.md` 或 `lessons-learned.md`）
4. 将任务状态改为 `done`
5. 提交 commit，消息中包含任务 ID

---

## 6. 多 Agent / 多会话协作规范

### 6.1 任务文件是 Single Source of Truth

如果一个任务需要多个 Agent 协作，或者跨多个会话完成，**所有 Agent 都以任务文件为同步点**。

- Agent A 做完一部分后，在 `Log` 中记录进展并 commit
- Agent B 接手时，先读 `Log`，从最后一条记录继续

### 6.2 并发写保护

如果多个 Agent 可能同时操作同一个任务文件，使用 `DocumentLock`（由 T-123 实现）进行文件级锁定。

---

## 7. 快速检查清单（Agent 每次创建/执行任务时）

### 创建新任务时
- [ ] 使用了标准任务模板
- [ ] `Research` 章节至少包含 1 个相关参考
- [ ] 如果是代码任务，已创建或引用了 Spec 文件
- [ ] 已确定任务的初始状态（`research` / `spec` / `implement`）

### 执行任务时
- [ ] 已阅读 `Research` 中的所有参考
- [ ] 代码改动严格遵循 `Spec`
- [ ] 每完成一个关键步骤，在 `Log` 中追加记录
- [ ] `zig build test` 通过

### 完成任务时
- [ ] 所有验收标准已勾选
- [ ] `Lessons Learned` 已填写
- [ ] 已检查是否需要更新 `DESIGN-REFERENCES.md`
- [ ] 已检查是否需要更新 `lessons-learned.md`
- [ ] 状态已改为 `done`
