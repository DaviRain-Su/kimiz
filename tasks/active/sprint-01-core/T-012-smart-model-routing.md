### T-012: 实现智能模型路由
**状态**: superseded
**优先级**: P2
**创建**: 2026-04-05
**完成**: 2026-04-05 (将被移除)
**预计耗时**: 3h
**实际耗时**: 2.5h

**描述**:
根据 PRD 实现智能模型路由 - 根据任务类型自动选择最优模型。

**文件**:
- `src/ai/routing.zig` - 完整实现

**已实现功能**:
- [x] 任务分类器定义 (TaskType: simple_chat, code_generation, code_review, etc.)
- [x] 基础路由决策 (RoutingDecision)
- [x] SmartRouter 结构体
- [x] 简单路由逻辑实现
- [x] **TaskAnalyzer** - 自动分析用户输入确定任务类型和复杂度
- [x] **autoRoute()** - 自动路由方法
- [x] **模型检测修复** - 使用精确的模型前缀匹配

**路由规则**:
| 任务类型 | 选择模型 | 原因 |
|----------|----------|------|
| simple_chat | gpt-4o-mini | 快速、便宜 |
| code_generation | claude-3-7-sonnet | 最佳代码能力 |
| code_review | claude-3-7-sonnet | 准确分析 |
| debugging | kimi-for-coding | 思考模型 |
| documentation | gpt-4o | 良好的写作能力 |
| complex_analysis | claude-3-7-sonnet | 最佳推理能力 |

**验收标准**:
- [x] 任务分类器（简单/复杂/代码/文档）✅
- [x] 成本-质量权衡算法（基础实现）✅
- [x] 自动模型切换（基础逻辑）✅
- [x] 模型检测精确匹配 ✅

**依赖**: 

**笔记**:
⚠️ **此任务已被新架构决策取代** (2026-04-05)

根据与 Pi-Mono 的对比分析，Smart Routing 被认为是过度设计：
- 自动选择往往不符合用户预期
- 增加代码复杂度 (~300行)
- 手动选择更简单可靠

**替代方案**:
- 用户手动选择模型 (Ctrl+L)
- 命令行 `--model` 参数
- 简单配置默认模型

**相关任务**: TASK-REF-005-remove-smart-routing

---

原实现功能:
- 基于关键词的任务类型自动检测
- 复杂度评估（1-10分）
- 智能模型选择
- 详细的决策理由

