# T-120-DESIGN: 设计文档驱动的 Agent 工作流

**任务类型**: Design  
**优先级**: P1  
**预计耗时**: 2h  
**前置任务**: T-009-E2E

---

## 参考文档

- [NullClaw Lessons](../guides/NULLCLAW-LESSONS-QUICKREF.md) - 工具安全边界与可观测性
- [Harness Four Pillars](../research/harness-four-pillars-nyk-analysis.md) - WorkspaceContext、PromptCache 设计原则
- [Yoyo Evolve](../research/YOYO-EVOLVE-ANALYSIS.md) - 自进化循环与编译反馈

---

## 背景

根据 yage.ai《从上下文失忆到文档驱动开发》的论述，Agentic AI 在 5000 行以上项目失效的根本原因是：**记忆完全依赖上下文窗口**。解决方案是引入"文档驱动开发"作为 Agent 的长期记忆。

当前 KimiZ 已经有任务系统（`tasks/active/`）和规格文档（`docs/specs/`），但 Agent 只是**被动读取**文档，不会主动更新任务日志，也没有把文档作为控制面（control plane）来工作。

本任务的目标是为 KimiZ 设计一套**文档驱动的 Agent 工作流（Document-Driven Agent Loop）**，让 Agent 能够：
1. 自动读取当前活跃任务和参考文档
2. 在执行过程中更新任务日志
3. 通过对比 Spec 和代码发现不一致
4. 把经验教训沉淀为长期记忆

---

## 设计目标

### 必须输出
1. **`docs/design/document-driven-agent-loop.md`**
   - 完整的架构设计图
   - Agent Loop 改造前后对比
   - 3 个新工具（`read_active_task`, `update_task_log`, `sync_spec_with_code`）的接口定义
   - System Prompt 改造方案
   - 人机协作工作流（人改文档 → AI 重写代码）

2. **`docs/lessons-learned-template.md`**
   - 经验教训文档的格式模板
   - 记录分类：架构决策、踩坑记录、性能优化、API 选择

### 设计约束
- 所有新工具必须用 Zig 0.16 API 实现
- 文档更新必须是原子操作（read → modify → write）
- 不能破坏现有 Agent Loop 的稳定性

---

## 验收标准

- [ ] `docs/design/document-driven-agent-loop.md` 已创建并通过 review
- [ ] 文档中明确了 3 个新工具的 JSON Schema / Zig 函数签名
- [ ] 文档中描述了 System Prompt 的注入点和内容
- [ ] 文档中描述了人类通过修改文档来纠正 AI 的完整工作流
- [ ] 设计被引用到 `docs/DESIGN-REFERENCES.md` 中
