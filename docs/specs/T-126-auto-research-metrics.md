# T-126 Technical Specification: Auto Research & Learning Metrics

**Version**: 1.0  
**Last Updated**: 2026-04-06  
**Status**: Draft  
**Task**: T-126

---

## Overview

扩展KimiZ的Observability Metrics系统，添加**Research & Learning维度**，记录Agent在Document-Driven Workflow中的研究过程和学习轨迹，实现Karpathy Auto Research理念的自我优化反馈循环。

### 设计理念

> "The future of AI is not just about better models, but about systems that can learn and evolve from their interactions."  
> — Andrej Karpathy

**核心目标**：
1. **可观测性** - 记录研究过程的每个关键步骤
2. **可量化性** - 衡量研究效率（时间、文档价值、决策质量）
3. **可学习性** - 从历史数据中提取成功模式
4. **可优化性** - 自动改进研究策略

---

## Architecture

### 系统集成图

```
┌─────────────────────────────────────────────────────────────┐
│                    Observability Metrics                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────┐      ┌─────────────────────┐      │
│  │  Runtime Metrics    │      │ Research Metrics    │      │
│  │     (T-124)         │      │     (T-126)         │      │
│  ├─────────────────────┤      ├─────────────────────┤      │
│  │ • session           │      │ • research_start    │      │
│  │ • iteration         │      │ • document_read     │      │
│  │ • tool_execution    │      │ • finding           │      │
│  │ • llm_call          │      │ • state_change      │      │
│  │ • memory_snapshot   │      │ • design_decision   │      │
│  │ • assertion         │      │ • learning_event    │      │
│  └──────────┬──────────┘      └──────────┬──────────┘      │
│             │                            │                 │
│             └────────────┬───────────────┘                 │
│                          ▼                                 │
│              ┌────────────────────────┐                    │
│              │  MetricsCollector      │                    │
│              │  (Unified Storage)     │                    │
│              └────────────────────────┘                    │
│                          │                                 │
│                          ▼                                 │
│              ~/.kimiz/metrics/*.jsonl                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│               Analysis & Optimization Layer                 │
│               (Future: Auto-Evolution)                      │
├─────────────────────────────────────────────────────────────┤
│  • Pattern Extractor                                        │
│  • Document Recommender                                     │
│  • Strategy Optimizer                                       │
└─────────────────────────────────────────────────────────────┘
```

---

## Data Model Design

### Event Types (新增6个)

```zig
// src/observability/metrics.zig 扩展

pub const EventType = enum {
    // === Runtime Metrics (T-124) ===
    session_start,
    session_end,
    agent_iteration,
    tool_execution,
    llm_call,
    memory_snapshot,
    assertion_trigger,
    
    // === Research & Learning Metrics (T-126) ===
    research_start,          // Agent开始研究某个主题
    research_document_read,  // 读取研究文档
    research_finding,        // 记录研究发现/结论
    task_state_change,       // 任务状态转换 (research→spec→implement→verify→done)
    design_decision,         // 记录设计决策和权衡
    learning_event,          // 学习事件（pattern/preference）
};
```

### Data Structures

#### 1. ResearchStartData

记录Agent开始研究某个主题的起点。

```zig
pub const ResearchStartData = struct {
    task_id: []const u8,         // "T-126"
    topic: []const u8,           // "Auto Research Metrics"
    trigger: ResearchTrigger,    // 触发原因
    initial_context: ?[]const u8, // 初始上下文（可选）
};

pub const ResearchTrigger = enum {
    new_task,           // 新任务创建
    gap_found,          // 发现知识gap
    design_question,    // 设计问题需要研究
    user_request,       // 用户显式要求
};
```

**使用时机**：
- TaskManager创建新任务时
- Agent遇到未知概念需要调研时
- 用户明确要求"research X"时

**JSON示例**：
```json
{
  "timestamp": 1712390400000,
  "session_id": "s-20260406-001",
  "event_type": "research_start",
  "data": {
    "task_id": "T-126",
    "topic": "Auto Research Metrics",
    "trigger": "new_task",
    "initial_context": "User suggested integrating observability with auto research"
  }
}
```

---

#### 2. ResearchDocumentReadData

记录Agent阅读研究文档的过程和收获。

```zig
pub const ResearchDocumentReadData = struct {
    task_id: []const u8,
    document_path: []const u8,   // "docs/research/TIGERBEETLE-PATTERNS.md"
    document_type: DocType,      // 文档类型
    relevance: f32,              // 0.0-1.0，文档相关度
    duration_ms: i64,            // 阅读耗时
    key_insights: []const []const u8, // 提取的关键insights
    follow_up_needed: bool,      // 是否需要继续深入研究
};

pub const DocType = enum {
    design_doc,      // 设计文档
    research_doc,    // 研究分析
    guide,           // 使用指南
    spec,            // 技术规格
    reference,       // API参考
    external_link,   // 外部资源
};
```

**使用时机**：
- Agent使用Read工具读取docs/下的文档
- 在Research phase阅读参考材料
- 查阅技术规格或设计文档

**JSON示例**：
```json
{
  "timestamp": 1712390405000,
  "session_id": "s-20260406-001",
  "event_type": "research_document_read",
  "data": {
    "task_id": "T-126",
    "document_path": "docs/design/auto-evolution-memory-system.md",
    "document_type": "design_doc",
    "relevance": 0.95,
    "duration_ms": 3500,
    "key_insights": [
      "Three-layer memory: short-term, work, long-term",
      "Pattern Extractor + Preference Learner architecture",
      "Feedback loop is core to self-optimization"
    ],
    "follow_up_needed": true
  }
}
```

---

#### 3. ResearchFindingData

记录Agent在研究过程中的发现和结论。

```zig
pub const ResearchFindingData = struct {
    task_id: []const u8,
    finding_type: FindingType,
    content: []const u8,         // 发现内容（简短摘要）
    confidence: f32,             // 0.0-1.0，结论的置信度
    references: []const []const u8, // 支持该结论的参考文档
    impact: FindingImpact,       // 发现的影响程度
};

pub const FindingType = enum {
    pattern,         // 发现了一种模式
    constraint,      // 发现了约束条件
    opportunity,     // 发现了优化机会
    risk,            // 发现了潜在风险
    dependency,      // 发现了依赖关系
    best_practice,   // 发现了最佳实践
};

pub const FindingImpact = enum {
    low,      // 影响小，不改变设计
    medium,   // 需要调整方案
    high,     // 重大发现，需要重新设计
};
```

**使用时机**：
- 完成一份文档阅读后总结关键结论
- 发现重要的设计模式或约束
- 识别出潜在风险或优化机会

**JSON示例**：
```json
{
  "timestamp": 1712390410000,
  "session_id": "s-20260406-001",
  "event_type": "research_finding",
  "data": {
    "task_id": "T-126",
    "finding_type": "pattern",
    "content": "T-124 already has complete metrics infrastructure, only need to extend EventType",
    "confidence": 0.9,
    "references": [
      "src/observability/metrics.zig",
      "tasks/active/sprint-2026-04/T-124-observability-metrics-phase1.md"
    ],
    "impact": "high"
  }
}
```

---

#### 4. TaskStateChangeData

记录任务在Document-Driven Workflow中的状态转换。

```zig
pub const TaskStateChangeData = struct {
    task_id: []const u8,
    from_state: TaskState,
    to_state: TaskState,
    duration_in_state_ms: i64,   // 在前一个状态停留的时间
    blockers_encountered: usize, // 在该状态遇到的阻塞数量
    artifacts_created: []const []const u8, // 产生的工件（spec文件等）
};

pub const TaskState = enum {
    research,
    spec,
    implement,
    verify,
    done,
};
```

**使用时机**：
- 任务从research进入spec阶段
- 完成spec开始implement
- 任何状态转换点

**JSON示例**：
```json
{
  "timestamp": 1712390420000,
  "session_id": "s-20260406-001",
  "event_type": "task_state_change",
  "data": {
    "task_id": "T-126",
    "from_state": "research",
    "to_state": "spec",
    "duration_in_state_ms": 20000,
    "blockers_encountered": 0,
    "artifacts_created": [
      "docs/specs/T-126-auto-research-metrics.md"
    ]
  }
}
```

---

#### 5. DesignDecisionData

记录重要的设计决策及其推理过程。

```zig
pub const DesignDecisionData = struct {
    task_id: []const u8,
    decision: []const u8,        // 决策内容（简短）
    alternatives: []const []const u8, // 考虑的其他方案
    chosen_rationale: []const u8,// 选择该方案的理由
    trade_offs: []const u8,      // 权衡分析
    decision_type: DecisionType,
};

pub const DecisionType = enum {
    architecture,    // 架构级决策
    algorithm,       // 算法选择
    data_structure,  // 数据结构设计
    integration,     // 集成方式
    optimization,    // 优化策略
};
```

**使用时机**：
- 在Spec phase做出关键设计选择
- 在多个方案之间权衡时
- 记录"为什么不选择X"的理由

**JSON示例**：
```json
{
  "timestamp": 1712390430000,
  "session_id": "s-20260406-001",
  "event_type": "design_decision",
  "data": {
    "task_id": "T-126",
    "decision": "Extend MetricsCollector instead of creating separate ResearchCollector",
    "alternatives": [
      "Create separate ResearchCollector component",
      "Use document-level annotations only"
    ],
    "chosen_rationale": "Unified storage simplifies queries, reuse existing infrastructure",
    "trade_offs": "Slightly larger EventType enum, but negligible impact",
    "decision_type": "architecture"
  }
}
```

---

#### 6. LearningEventData

记录Agent学到的patterns和preferences，驱动自我优化。

```zig
pub const LearningEventData = struct {
    event_type: LearningType,
    category: []const u8,        // "code_style" / "research_strategy" / "tool_usage"
    content: []const u8,         // 学到的内容
    confidence: f32,             // 0.0-1.0
    sample_size: usize,          // 基于多少个样本学习的
    trigger: []const u8,         // 什么触发了这次学习
    actionable: bool,            // 是否可以立即应用
};

pub const LearningType = enum {
    pattern_discovered,      // 发现了一种pattern
    preference_updated,      // 更新了用户偏好
    strategy_improved,       // 改进了某种策略
    mistake_learned,         // 从错误中学习
};
```

**使用时机**：
- 完成任务后回顾发现的patterns
- 连续3次类似决策后识别preference
- 从失败/错误中提取教训

**JSON示例**：
```json
{
  "timestamp": 1712390500000,
  "session_id": "s-20260406-001",
  "event_type": "learning_event",
  "data": {
    "event_type": "strategy_improved",
    "category": "research_strategy",
    "content": "Always read utils/fs_helper.zig first when encountering Zig 0.16 API changes - saves 15min on average",
    "confidence": 0.85,
    "sample_size": 3,
    "trigger": "Completed T-125 Zig 0.16 migration efficiently",
    "actionable": true
  }
}
```

---

## Implementation Plan

### Phase 1: 数据收集基础设施 (本任务，2.5h)

#### Step 1: 扩展metrics.zig (30min)
- 添加6个新EventType到枚举
- 定义6个数据结构
- 扩展MetricsData union
- 添加单元测试

#### Step 2: 插入记录点 (1h)
- **Agent.zig**:
  - `init()`: 生成session时考虑关联task
  - `runLoop()`: 状态变化时记录
- **TaskManager** (如果存在):
  - `createTask()`: 记录research_start
  - `updateTaskState()`: 记录task_state_change
- **工具层**:
  - Read工具读取docs/时记录document_read

#### Step 3: 辅助函数 (30min)
- `extractInsights()`: 从文档内容提取关键insights
- `calculateRelevance()`: 计算文档相关度（简单版）
- `detectLearningEvent()`: 检测是否产生了learnable pattern

#### Step 4: 测试验证 (30min)
- 单元测试：每个EventType的序列化/反序列化
- 集成测试：完整task lifecycle生成所有事件
- 性能测试：确保开销<5%

### Phase 2: 查询和分析 (后续任务，2h)
- 实现metrics查询API
- 文档相关度分析
- 研究效率报告

### Phase 3: 自我优化 (后续任务，4h)
- Pattern Extractor实现
- 文档推荐引擎
- 策略优化器

---

## Integration Points

### 与T-124 Runtime Metrics的关系

**共享**：
- MetricsCollector实例
- JSON Lines存储格式
- 批量刷新机制

**独立**：
- EventType定义（各自扩展）
- 数据结构（不相互依赖）
- 记录时机（不同生命周期阶段）

### 与Document-Driven Workflow的关系

**关键插入点**：
1. **任务创建时** → research_start
2. **Research phase** → document_read, finding
3. **状态转换** → task_state_change
4. **Spec编写** → design_decision
5. **任务完成** → learning_event

---

## Testing Strategy

### Unit Tests

```zig
test "ResearchStartData serialization" {
    const data = ResearchStartData{
        .task_id = "T-126",
        .topic = "Test Topic",
        .trigger = .new_task,
        .initial_context = null,
    };
    
    const snapshot = MetricsSnapshot{
        .timestamp = 1712390400000,
        .session_id = "test-session",
        .event_type = .research_start,
        .data = .{ .research_start = data },
    };
    
    // Test JSON serialization
    const json = try std.json.stringify(snapshot, .{}, writer);
    // Verify can deserialize
    const parsed = try std.json.parse(...);
}
```

### Integration Test

```zig
test "Complete research lifecycle" {
    var collector = try MetricsCollector.init(allocator, "test-session");
    defer collector.deinit();
    
    // 1. Start research
    try collector.record(.{
        .timestamp = now(),
        .session_id = "test",
        .event_type = .research_start,
        .data = .{ .research_start = ... },
    });
    
    // 2. Read documents
    try collector.record(...); // document_read
    
    // 3. Record findings
    try collector.record(...); // finding
    
    // 4. State change
    try collector.record(...); // task_state_change
    
    // 5. Design decision
    try collector.record(...); // design_decision
    
    // 6. Learning
    try collector.record(...); // learning_event
    
    // Verify all events were written
    const metrics_file = ...; // read JSON Lines
    try expect(metrics_file.lines.len == 6);
}
```

---

## Performance Considerations

### 开销目标
- 每个event记录 < 0.5ms（Runtime的一半，因为频率更低）
- 总体影响 < 2%（Research阶段本身就慢，可以接受稍高开销）

### 优化策略
1. **批量刷新** - 复用T-124的500ms/4KB机制
2. **惰性序列化** - 只在flush时才序列化JSON
3. **简化insights提取** - 不做复杂NLP，只提取Markdown标题
4. **异步写入** - 考虑后台线程（可选）

---

## Future Extensions (Phase 2-3)

### Phase 2: 分析和推荐
- **文档推荐引擎**
  - 基于topic相似度匹配历史task
  - 推荐最常被高评分的文档
  - 生成"Most Valuable Documents"排行榜

- **研究效率报告**
  - 平均research duration by task type
  - 阻塞分析：哪个阶段最容易卡住？
  - 文档ROI：阅读时间 vs 价值

### Phase 3: 自我优化
- **Pattern Extractor**
  - 从learning_event中提取patterns
  - 构建"topic → best docs → typical decisions"知识图谱

- **Strategy Optimizer**
  - 自动调整research顺序
  - 优先推荐高价值文档
  - 跳过低相关度参考

---

## Success Criteria

### Phase 1 (本任务)
- ✅ 6个新EventType完整实现
- ✅ Agent关键点成功记录events
- ✅ 单元测试100%通过
- ✅ 集成测试验证完整lifecycle
- ✅ 性能影响 < 2%

### Phase 2 (后续)
- ✅ 查询API可用
- ✅ 文档推荐准确率 > 70%
- ✅ 研究效率报告生成

### Phase 3 (长期)
- ✅ Pattern Extractor提取有效patterns
- ✅ 平均research时间降低20%+
- ✅ Agent能自主优化研究策略

---

## References

- `docs/design/auto-evolution-memory-system.md` - Auto Research理念和架构
- `docs/DOCUMENT-DRIVEN-WORKFLOW.md` - Task lifecycle定义
- `docs/specs/T-124-observability-metrics-phase1.md` - Runtime metrics架构
- `src/observability/metrics.zig` - 现有实现
- TigerBeetle tracer patterns - 低开销事件记录
- Anthropic CoT analysis - 推理过程分析
