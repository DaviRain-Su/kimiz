# <TASK-ID>: <标题>

**任务类型**: Research / Design / Implementation / Verification / Bugfix / Refactor  
**优先级**: P0 / P1 / P2  
**预计耗时**: Xh  
**创建日期**: YYYY-MM-DD

---

## 1. 背景与目标

（为什么做这个任务，完成后项目会有什么变化）

## 2. Research

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

## 4. 验收标准

- [ ] 标准 1
- [ ] 标准 2
- [ ] `zig build test` 通过（任何代码任务都必须包含此项）

## 5. Log

> 执行任务的过程中，**每做一步都要在这里追加记录**。这是 Agent 的自我修正历史。

- `YYYY-MM-DD HH:MM` — 创建了任务，初始状态为 `research`

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
