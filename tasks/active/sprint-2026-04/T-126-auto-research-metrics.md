# T-126: Auto Research & Learning Metrics

**Status**: `spec`  
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

- [x] 研究过程的哪些点最值得记录？
  - ✅ **任务创建时的research起点** - 记录topic和trigger，建立研究起点
  - ✅ **文档阅读过程** - 读了什么、花了多长时间、提取了什么insights
  - ✅ **研究发现** - 记录pattern/constraint/opportunity，建立知识库
  - ✅ **状态转换点** - research→spec→implement，量化每阶段耗时
  - ✅ **设计决策和权衡** - 记录"为什么选A不选B"，形成决策历史
  - ✅ **学习事件** - 从成功/失败中提取actionable patterns
  - **关键洞察**：Document-Driven Workflow的4个状态转换是天然插入点
  
- [x] 如何与T-124的metrics系统集成？
  - ✅ **共用MetricsCollector实例** - 统一收集器，单一JSON Lines存储
  - ✅ **扩展EventType枚举** - 添加6个新事件类型（research_*）
  - ✅ **扩展MetricsData union** - 添加对应的6个数据结构
  - ✅ **复用批量刷新机制** - 500ms/4KB触发flush，无需改动
  - ✅ **数据格式兼容** - JSON Lines天然支持扩展，旧版本可忽略新字段
  - **关键决策**：不创建独立组件，扩展现有系统更简洁
  
- [x] 如何实现"推荐文档"功能？
  - ✅ **Phase 1策略（简单版）**：基于topic关键词匹配历史task
  - ✅ **Phase 2策略（中级）**：根据document_read的relevance评分排序
  - ✅ **Phase 3策略（高级）**：基于learning_event构建"topic→best_docs"知识图谱
  - ✅ **实时vs离线**：Phase 1实时查询JSON Lines，Phase 2/3离线预处理索引
  - ✅ **文档价值评分**：`score = avg(relevance) * read_count / avg(duration_ms)`
  - **关键洞察**：从简单开始，逐步优化，避免过度设计

### Phase 3: 参考实现

- [x] TigerBeetle的tracer机制 — 低开销的事件记录
  - ✅ **StaticAllocator模式** - KimiZ不适用（需要动态分配），但可借鉴边界清晰思想
  - ✅ **Arena分配器** - 每个research session使用arena，完成后一次性释放
  - ✅ **侵入式链表** - 不适用于metrics（简单append即可）
  - ✅ **断言密度** - 每个metrics.record()调用前检查session_id非空等
  - **关键借鉴**：批量刷新（T-124已实现），append-only存储（JSON Lines）
  
- [x] Anthropic的Chain-of-Thought analysis — 如何分析推理过程
  - ✅ **思维链记录** - research_finding记录推理步骤
  - ✅ **多阶段分析** - research→spec→implement对应thinking→planning→acting
  - ✅ **confidence评分** - 每个finding记录置信度（0-1）
  - ✅ **引用溯源** - references字段记录证据来源
  - **关键借鉴**：把研究过程当作"思维链"，每个finding是一个推理节点
  
- [x] `docs/research/NULLCLAW-LESSONS-QUICKREF.md` — 学习提取经验教训的模式
  - ✅ **JSON Mini Parser** - 不直接相关，但可用于查询metrics时快速提取字段
  - ✅ **Provider模式** - 未来可抽象MetricsProvider支持多后端（SQLite/Redis）
  - ✅ **Registry模式** - 可用于learning_event的pattern注册
  - **关键借鉴**：工程实现的清晰抽象，而非prompt-based技巧

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

### 2026-04-06 08:45 - Research Phase 1完成
- 已读取DOCUMENT-DRIVEN-WORKFLOW.md
- 已读取auto-evolution-memory-system.md  
- 已读取T-124任务和metrics.zig实现
- 理解了现有架构：7个EventType，JSON Lines存储，批量刷新
- **关键发现**：T-124已建立完整的metrics基础设施，只需扩展EventType

### 2026-04-06 09:00 - Research Phase 2-3完成
### 2026-04-06 09:10 - Spec细节完善完成
**Phase 2关键设计问题回答**：
1. **记录点选择** - Document-Driven Workflow的4个状态转换是天然插入点
   - 任务创建→research_start
   - 文档阅读→research_document_read
   - 研究发现→research_finding
   - 状态转换→task_state_change
   - 设计决策→design_decision
   - 完成任务→learning_event

2. **与T-124集成方案** - 共用MetricsCollector，扩展EventType
   - 不创建独立组件，保持架构简洁
   - JSON Lines格式天然支持扩展
   - 复用批量刷新机制（500ms/4KB）
   - 性能影响可控：research阶段本身就慢，<2%开销可接受

3. **文档推荐策略** - 三阶段渐进式实现
   - Phase 1：简单关键词匹配（立即可用）
   - Phase 2：relevance评分排序（更精准）
   - Phase 3：知识图谱推荐（最智能）

**Phase 3参考实现分析**：
- **TigerBeetle** - 借鉴批量刷新、append-only、断言密度
- **Anthropic CoT** - 研究过程=思维链，finding=推理节点
- **NullClaw** - 工程抽象清晰，未来可用Provider/Registry模式

**关键架构决策**：
- ✅ 使用Arena分配器管理research session内存（完成后释放）
- ✅ 每个metrics.record()前断言session_id非空
- ✅ 插入点最小化：只在关键生命周期事件记录，避免噪音
- ✅ 数据结构设计：优先简单，避免过度设计

**Spec细节完善**：
1. **测试策略**（20min）
   - 5个测试用例组（Unit + Integration + Performance）
   - 覆盖序列化、边界情况、并发、性能benchmark
   - 明确验收标准：record<0.5ms, flush<10ms, JSON<1KB

2. **错误处理策略**（10min）
   - 5类错误的处理方式（文件创建、序列化、写入、无效输入、环境）
   - Graceful degradation：metrics失败不影响核心功能
   - 重试机制：写入失败重试1次

3. **性能优化细节**（10min）
   - 4个优化策略（批量刷新、惰性序列化、简化提取、异步可选）
   - 性能监控内置：自动统计avg record/flush时间
   - CLI命令：`kimiz metrics stats`

4. **向后兼容性**（5min）
   - JSON Lines天然支持schema扩展
   - 旧版本跳过未知event_type
   - 新版本完全兼容T-124的7个EventType

5. **验收标准细化**（5min）
   - 功能性、质量性、文档性三维度
   - 手动验证步骤（repl命令序列）
   - 性能验证命令

**Total: 50min完成Spec细节完善**

**Next Steps**：
- ✅ Spec阶段完成，准备进入implementation
- 开始编写代码：扩展metrics.zig
- 实现插入点：Agent.zig、工具层
- 编写单元测试和集成测试

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
