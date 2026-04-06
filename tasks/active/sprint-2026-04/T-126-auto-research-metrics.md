# T-126: Auto Research & Learning Metrics

**Status**: `research`  
**Priority**: P1  
**Estimated effort**: 2.5h  
**Created**: 2026-04-06  
**Owner**: Droid

---

## Background

KimiZ已实现基础的Observability Metrics (T-124)，但**只记录runtime事件**（session, tool, llm等），**缺失Agent研究和学习过程的可观测性**。

### 问题陈述

当前Agent在执行Document-Driven Workflow时：
- ❌ 无法"看到"自己过去的研究路径
- ❌ 无法量化研究效率（哪些文档最有价值？research阶段多长？）
- ❌ 无法学习成功模式（类似任务应该先读什么文档？）
- ❌ 无法实现Karpathy Auto Research理念的自我优化

### 目标

扩展Observability Metrics系统，添加**Research & Learning维度**，形成完整的自我优化反馈循环：

```
Research Metrics → Pattern Analysis → Strategy Optimization → Better Research
    ↑                                                              ↓
    └───────────────── Learning Feedback Loop ─────────────────────┘
```

**完成后的影响**：
- Agent可以自动推荐相关文档
- 量化研究效率并优化策略
- 为Auto-Evolution Memory System提供数据基础
- 实现真正的"边做边学"

---

## Research

### Phase 1: 理解现有系统

- [x] `docs/DOCUMENT-DRIVEN-WORKFLOW.md` — 理解task lifecycle和4个自动编排规则
- [x] `docs/design/auto-evolution-memory-system.md` — 理解Auto Research理念和三层记忆系统
- [x] `tasks/active/sprint-2026-04/T-124-observability-metrics-phase1.md` — 理解现有metrics架构
- [x] `src/observability/metrics.zig` — 现有EventType和MetricsCollector实现

### Phase 2: 关键设计问题

- [ ] 研究过程的哪些点最值得记录？
  - 任务创建时的research起点
  - 文档阅读过程（读了什么、花了多长时间、提取了什么insights）
  - 状态转换点（research→spec→implement）
  - 设计决策和权衡
  - 遇到的阻塞和解决方式
  
- [ ] 如何与T-124的metrics系统集成？
  - 共用MetricsCollector还是独立组件？
  - 数据格式兼容性
  - 查询API设计
  
- [ ] 如何实现"推荐文档"功能？
  - 基于历史相似度匹配
  - 文档价值评分算法
  - 实时还是离线分析？

### Phase 3: 参考实现

- [ ] TigerBeetle的tracer机制 — 低开销的事件记录
- [ ] Anthropic的Chain-of-Thought analysis — 如何分析推理过程
- [ ] `docs/research/NULLCLAW-LESSONS-QUICKREF.md` — 学习提取经验教训的模式

---

## Specification

**Spec文件**: `docs/specs/T-126-auto-research-metrics.md`

### 关键设计决策

#### 1. 新增6个EventType

扩展`src/observability/metrics.zig`的EventType枚举：

```zig
pub const EventType = enum {
    // 现有的7个
    session_start,
    session_end,
    agent_iteration,
    tool_execution,
    llm_call,
    memory_snapshot,
    assertion_trigger,
    
    // 新增：Research & Learning
    research_start,          // 开始研究某个主题
    research_document_read,  // 读取研究文档
    research_finding,        // 记录研究发现/结论
    task_state_change,       // 任务状态转换
    design_decision,         // 记录设计决策
    learning_event,          // 学习事件
};
```

#### 2. 插入点策略

在以下位置插入metrics记录：
- **TaskManager.createTask()** → 记录research_start
- **Document reading (工具层)** → 记录research_document_read
- **Agent log entries** → 提取research_finding
- **Task state update** → 记录task_state_change
- **Spec编写时** → 记录design_decision
- **Pattern detection** → 记录learning_event

#### 3. 查询API设计

提供以下查询能力（Phase 2实现）：
- 获取某task的完整研究轨迹
- 查找与当前task相似的历史task
- 统计最常被引用的文档
- 分析平均research时长

### 影响文件

| 文件 | 预期改动 |
|------|----------|
| `src/observability/metrics.zig` | 添加6个新EventType和对应数据结构 |
| `src/agent/agent.zig` | 在关键点调用metrics.record() |
| `src/agent/task_manager.zig` | 记录任务生命周期事件（如果存在） |
| `docs/specs/T-126-auto-research-metrics.md` | 完整技术规格 |

---

## Acceptance Criteria

### Phase 1: 数据收集 (本任务范围)

- [ ] 6个新EventType已定义
- [ ] 6个对应的数据结构已实现
- [ ] MetricsCollector支持新事件类型
- [ ] 在Agent关键点插入metrics记录
- [ ] 单元测试：记录和序列化research events
- [ ] 集成测试：运行一个完整task lifecycle，验证所有events被记录
- [ ] `zig build test` 通过

### Phase 2: 查询和分析 (后续任务)

- [ ] 实现metrics查询API
- [ ] 生成Research Report
- [ ] 文档推荐算法原型

### Phase 3: 自我优化 (Auto-Evolution)

- [ ] Pattern Extractor实现
- [ ] 自动推荐相关文档
- [ ] 学习研究策略

---

## Log

### 2026-04-06 08:40 - 任务创建
- 创建T-126任务，初始状态为`research`
- 基于用户洞察：Observability Metrics应该记录Auto Research过程
- 目标：实现"边做边学"的反馈循环

### 2026-04-06 08:45 - Research Phase开始
- 已读取DOCUMENT-DRIVEN-WORKFLOW.md
- 已读取auto-evolution-memory-system.md  
- 已读取T-124任务和metrics.zig实现
- 理解了现有架构：7个EventType，JSON Lines存储，批量刷新
- **关键发现**：T-124已建立完整的metrics基础设施，只需扩展EventType

### Next Steps
- 完成Research Phase剩余checklist
- 创建完整的技术规格（T-126 spec）
- 设计数据结构和插入点
- 进入implement阶段

---

## Lessons Learned

_(任务完成后填写)_

### 技术方面
- 如何在现有系统上优雅扩展
- Research过程量化的关键指标
- 事件记录的性能影响

### 方法论方面
- Document-Driven Workflow的实践经验
- 自我优化反馈循环的设计模式
- 如何将"边做边学"理念具象化

---

## Related

- **Parent**: 无（独立任务）
- **Depends on**: T-124 (Observability Metrics Phase 1)
- **Blocks**: 无
- **Related**: 
  - `docs/design/auto-evolution-memory-system.md` (实现基础)
  - `docs/DOCUMENT-DRIVEN-WORKFLOW.md` (应用场景)
  - T-124 (metrics基础设施)
