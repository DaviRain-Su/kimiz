# KimiZ 生命周期文档

> 本文档目录存放 KimiZ 项目自身的 7 阶段方法论文档。

---

## 方法论来源

KimiZ 严格遵循 **[遮山鱼 Dev Lifecycle](https://codeberg.org/davirain/dev-lifecycle)** 结构化开发方法论：

```
Phase 1: PRD（需求定义）          → 做什么 / 不做什么
Phase 2: Architecture（架构设计） → 怎么组织
Phase 3: Technical Spec（技术规格）→ 每个字节怎么做（最关键）
Phase 4: Task Breakdown（任务拆解）→ ≤4h 的可执行任务
Phase 5: Test Spec（测试规格）     → TDD：先定义什么是对的
Phase 6: Implementation（实现）    → 写代码让测试通过
Phase 7: Review & Deploy（审查）   → 确认质量，部署上线
```

模板来源：`docs/methodology/dev-lifecycle/templates/`

---

## 本目录文件说明

| 文件 | 对应阶段 | 说明 |
|------|----------|------|
| `01-prd.md` | Phase 1 | 产品需求文档 |
| `02-architecture.md` | Phase 2 | 架构设计 |
| `03-technical-spec.md` | Phase 3 | 技术规格（项目级） |
| `04-task-breakdown.md` | Phase 4 | 任务拆解 |
| `05-test-spec.md` | Phase 5 | 测试规格 |
| `06-agent-harness-upgrade.md` | Phase 6 扩展 | Harness 层升级计划 |
| `06-implementation-log.md` | Phase 6 | 实现日志 |
| `07-kimiz-vision-b.md` | Phase 7 扩展 | 愿景文档 |
| `07-review-report.md` | Phase 7 | 审查报告 |

---

## 分形应用

如 [遮山鱼 Dev Lifecycle](https://codeberg.org/davirain/dev-lifecycle) 所述，这 7 个阶段适用于**所有粒度级别**：

- **项目级**：本目录下的文档是整个 KimiZ 项目的生命周期文档
- **模块级**：每个子模块（如 agent-arena、chain-hub 等）也应独立经历 7 个阶段
- **引用规则**：子模块的 Phase 1/2 可直接引用项目级文档，但 **Phase 3 必须独立编写**
