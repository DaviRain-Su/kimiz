# T-124: Observability Metrics System - Phase 1 (Built-in Collection)

**任务类型**: Implementation  
**优先级**: P1  
**预计耗时**: 6-8h  
**创建日期**: 2026-04-06

---

## 1. 背景与目标

### 背景

KimiZ作为AI Agent系统，具有以下特性使得可观测性成为必需：
- 🔄 复杂的状态机转换（idle → thinking → tool_calling → executing_tool）
- 🤖 LLM API调用（延迟、费用、token消耗）
- 🔧 工具执行（成功率、耗时分布）
- 💾 内存动态增长（长会话可能退化）
- ⚡ 断言触发频率（质量指标）
- 📊 多会话性能对比

当前KimiZ缺乏运行时metrics收集能力，无法回答：
- "这个会话总共花了多少钱？"
- "哪些工具经常失败？"
- "内存泄漏在哪个阶段发生？"
- "为什么这次迭代这么慢？"

### 目标

**Phase 1**（本任务）：建立内置metrics收集系统
- 最小依赖（仅JSON Lines格式，无外部服务）
- CLI友好（`kimiz metrics show/history/export`）
- 本地存储（`~/.kimiz/metrics/`）
- Agent/Tool透明集成

**Phase 2**（未来）：可选Web Dashboard
**Phase 3**（未来）：Prometheus + Grafana（如KimiZ变为长期服务）

---

## 2. Research

做这个任务前，必须阅读和参考的文档。

- [x] `docs/research/TIGERBEETLE-PATTERNS-ANALYSIS.md` — 学习TigerBeetle的metrics设计：低开销、无锁、追加写入
- [ ] `docs/guides/NULLCLAW-LESSONS-QUICKREF.md` — 资源边界管理，metrics不应影响主流程性能
- [ ] `src/agent/agent.zig` — 理解Agent状态机和事件回调机制
- [ ] `src/utils/session.zig` — 会话持久化机制，metrics需要与session关联
- [ ] JSON Lines格式规范（https://jsonlines.org/） — 选择这个格式的原因：追加写入、流式读取、易于grep/awk处理

> 如果在实现过程中发现需要补充新的参考，更新此列表，并在 `Log` 中记录。

---

## 3. Spec

**Spec 文件**: `docs/specs/T-124-observability-metrics-phase1.md`

### 3.1 关键设计决策

1. **格式选择：JSON Lines（.jsonl）**
   - 原因：追加写入无需加载整个文件，单行 = 单条记录，易于流式处理
   - 替代方案：SQLite（过重），CSV（类型丢失），二进制（不可读）

2. **存储位置：`~/.kimiz/metrics/{session_id}.jsonl`**
   - 原因：每个会话独立文件，避免单文件过大，便于清理
   - 替代方案：单一文件（会无限增长），内存（重启丢失）

3. **集成方式：Agent事件回调 + Tool装饰器**
   - 原因：无侵入式设计，现有代码无需大改
   - Agent已有`event_callback`机制，直接复用
   - Tool执行通过统一的`execute_fn`包装

4. **性能要求：单次记录 < 1ms**
   - 原因：不能成为Agent执行瓶颈
   - 实现：批量写入（每5条或每500ms刷新）

### 3.2 影响文件

| 文件 | 预期改动 |
|------|----------|
| `src/observability/metrics.zig` | **新增**：MetricsCollector核心结构 |
| `src/observability/cli.zig` | **新增**：CLI命令实现（show/history/export） |
| `src/agent/agent.zig` | **修改**：在init时创建MetricsCollector并设置回调 |
| `src/agent/tool.zig` | **修改**：Tool执行装饰器记录metrics |
| `src/cli/root.zig` | **修改**：注册`kimiz metrics`子命令 |
| `build.zig` | **修改**：添加observability模块到构建 |

---

## 4. 验收标准

- [ ] `src/observability/metrics.zig`实现完整并有单元测试
- [ ] CLI命令`kimiz metrics show`能显示当前会话统计
- [ ] CLI命令`kimiz metrics history --last 5`能显示最近5个会话
- [ ] CLI命令`kimiz metrics export --format csv`能导出CSV
- [ ] Agent运行时自动记录以下指标：
  - [ ] 内存指标（allocated/freed/live）
  - [ ] Agent指标（iteration_count, message_count, state_transitions）
  - [ ] 工具指标（calls/successes/failures/avg_duration_ms）
  - [ ] LLM指标（calls/tokens_input/tokens_output/estimated_cost）
- [ ] 单次metrics记录开销 < 1ms（性能测试验证）
- [ ] 长会话测试（100轮迭代）无内存泄漏
- [ ] `zig build test` 通过

---

## 5. Log

> 执行任务的过程中，**每做一步都要在这里追加记录**。这是 Agent 的自我修正历史。

- `2026-04-06 06:45` — 创建了任务，初始状态为 `research`
- `2026-04-06 06:45` — 已读TIGERBEETLE-PATTERNS-ANALYSIS.md，确认追加写入 + 无锁设计

---

## 6. Lessons Learned

> 任务完成后，填写此章节。这是把个人任务经验升级为项目级长期记忆的关键步骤。

**分类**: 架构决策

**内容**:
（待任务完成后填写）

**后续动作**:
- [ ] 更新 `docs/DESIGN-REFERENCES.md`（添加observability架构参考）
- [ ] 更新 `docs/lessons-learned.md`（如果有通用的metrics设计经验）
