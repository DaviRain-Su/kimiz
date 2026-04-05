# Kimiz 最终任务清单 (Vision V2.0)

**愿景**: Harness Engineering Platform  
**日期**: 2026-04-05  
**状态**: 已整合所有冲突

---

## 架构愿景

```
Kimiz = Harness Engineering Platform

人类设计 Harness → AI 在 Harness 中自主工作

Layer 4: Platform (Harness 市场、可视化编辑器)
Layer 3: Multi-Agent (编排、路由、共享记忆)
Layer 2: Harness Engine (Skills、约束、Learning)
Layer 1: Core Runtime (借鉴 Pi 的简洁核心)
```

---

## Phase 1: Core Runtime (Week 1-2)

### P0 - 立即执行 (12个任务)

#### Bugfix (9个)

| 任务 | 文件 | 预计 | 状态 |
|------|------|------|------|
| URGENT-FIX | - | 0.5h | 🔴 |
| BUG-013 | providers/*.zig | 4h | 🔴 |
| BUG-014 | cli/root.zig | 6h | 🔴 |
| BUG-015 | providers/*.zig | 3h | 🔴 |
| BUG-016 | agent/agent.zig | 2h | 🔴 |
| BUG-017 | agent/agent.zig | 3h | 🔴 |
| BUG-018 | http.zig | 5h | 🔴 |
| BUG-019 | core/root.zig | 2h | 🔴 |
| BUG-020 | utils/log.zig | 2h | 🔴 |

#### Feature (3个)

| 任务 | 文件 | 预计 | 状态 | 说明 |
|------|------|------|------|------|
| REF-003 | core/session.zig | 8h | 🔴 | 单层 Session (借鉴 Pi) |
| FEAT-007 | agent/tools/*.zig | 4h | 🔴 | 5个核心工具 (借鉴 Pi) |
| FEAT-001 | tui/*.zig | 12h | 🔴 | TUI 完整实现 |

**Phase 1 总计**: 52小时

---

## Phase 2: Harness Engine (Week 3-4)

### P0 - Harness 核心 (3个任务)

| 任务 | 文件 | 预计 | 说明 |
|------|------|------|------|
| FEAT-003-register | skills/root.zig | 4h | Skills 注册到系统 |
| FEAT-002-harness | harness/*.zig | 6h | Harness 解析器 (AGENTS.md, RULES.md) |
| FEAT-003-constraints | harness/constraints.zig | 4h | 约束系统 |

### P0 - Extension 系统 (1个任务)

| 任务 | 文件 | 预计 | 说明 |
|------|------|------|------|
| FEAT-006-extension | extension/*.zig | 16h | WASM Extension 运行时 |

### P1 - 支持功能 (4个任务)

| 任务 | 文件 | 预计 | 说明 |
|------|------|------|------|
| FEAT-006-workspace | core/workspace.zig | 4h | Workspace Context (Git + AGENTS.md) |
| FEAT-007-prompt | prompts/cache.zig | 6h | Prompt Caching |
| FEAT-008 | context/reduction.zig | 3h | Context Truncation |
| REF-002 | ai/providers/*.zig | 4h | 请求序列化重构 |

**Phase 2 总计**: 47小时

---

## Phase 3: Multi-Agent (Week 5-6)

### P1 - Multi-Agent 基础 (2个任务)

| 任务 | 文件 | 预计 | 说明 |
|------|------|------|------|
| FEAT-011 | multiagent/orchestrator.zig | 8h | Agent 编排器 |
| FEAT-010 | session/persistence.zig | 4h | Session 持久化 |

### P1 - 重新设计的功能 (3个任务)

| 任务 | 文件 | 预计 | 说明 |
|------|------|------|------|
| T-012 | multiagent/router.zig | 3h | Smart Routing (Multi-Agent 调度器) |
| T-025 | memory/layers.zig | 8h | 三层记忆 (Multi-Agent 共享) |
| FEAT-004-learning | learning/optimizer.zig | 6h | Learning (Harness 性能优化) |

**Phase 3 总计**: 29小时

---

## Phase 4: Platform (Week 7+)

### P2 - 平台功能 (4个任务)

| 任务 | 预计 | 说明 |
|------|------|------|
| FEAT-014 | 6h | Knowledge Base |
| FEAT-015 | 4h | Agent Linter |
| FEAT-016 | 3h | SLOP Collector |
| FEAT-013 | 3h | Resource Limits |

**Phase 4 总计**: 16小时

---

## 任务统计

| Phase | 任务数 | 预计工时 | 关键产出 |
|-------|--------|----------|----------|
| Phase 1 | 12 | 52h | 稳固核心 |
| Phase 2 | 8 | 47h | Harness Engine |
| Phase 3 | 5 | 29h | Multi-Agent |
| Phase 4 | 4 | 29h | Platform |
| **总计** | **29** | **144h** | **6-8周** |

---

## 关键路径

```
Phase 1 (Core)
├── URGENT-FIX → BUG-014 (CLI)
├── BUG-013 (Memory) → REF-003 (Session)
└── FEAT-007 (Tools) → FEAT-001 (TUI)

Phase 2 (Harness)
├── REF-003 → FEAT-003-register (Skills)
├── FEAT-003-register → FEAT-002-harness
└── FEAT-002-harness → FEAT-003-constraints

Phase 3 (Multi-Agent)
├── FEAT-003-constraints → FEAT-011 (Orchestrator)
├── FEAT-011 → T-012 (Routing)
├── FEAT-011 → T-025 (Memory Layers)
└── T-025 → FEAT-004-learning
```

---

## 设计原则

### 1. 借鉴 Pi 的地方

| 方面 | 策略 | 原因 |
|------|------|------|
| Core Runtime | 简洁设计 | 易于维护 |
| Session | 单层 + Compaction | 简单可靠 |
| Tools | 5个核心 | 足够使用 |
| Extension | WASM | 安全可扩展 |

### 2. 超越 Pi 的地方

| 方面 | 策略 | 价值 |
|------|------|------|
| Skills | 声明式知识 | Harness 核心 |
| Constraints | 容错安全 | 可靠性 |
| Multi-Agent | 复杂任务 | 可扩展性 |
| Learning | Harness 优化 | 自我改进 |

### 3. 功能保留决策

| 功能 | 决策 | 原因 |
|------|------|------|
| Skills | ✅ 保留 | Harness 核心 |
| Extension | ✅ 保留 | 可扩展性 |
| Smart Routing | ✅ 保留 | Multi-Agent 调度 |
| 三层记忆 | ✅ 保留 | Multi-Agent 共享 |
| Learning | ✅ 保留 | Harness 优化 |
| 复杂 Workspace | ❌ 简化 | AGENTS.md 足够 |
| 复杂 Prompt Cache | ❌ 简化 | Provider 层实现 |

---

## 文件结构 (目标)

```
src/
├── main.zig
├── core/
│   ├── types.zig
│   ├── session.zig         # 单层 Session (借鉴 Pi)
│   └── workspace.zig       # Git + AGENTS.md
├── agent/
│   ├── agent.zig           # 简洁 Agent 循环
│   ├── tools.zig           # 5个核心工具
│   └── builtins/
│       ├── read.zig
│       ├── write.zig
│       ├── edit.zig
│       ├── bash.zig
│       └── grep.zig
├── harness/                # NEW: Harness Engine
│   ├── parser.zig          # AGENTS.md, RULES.md
│   ├── skills.zig          # Skills 系统
│   ├── constraints.zig     # 约束系统
│   └── runtime.zig         # Harness 运行时
├── multiagent/             # NEW: Multi-Agent
│   ├── orchestrator.zig    # Agent 编排
│   ├── router.zig          # 任务分配
│   └── shared_memory.zig   # 共享记忆
├── memory/
│   ├── short_term.zig      # Agent 本地
│   ├── working.zig         # Agent 间共享
│   └── long_term.zig       # 跨会话
├── extension/
│   ├── runtime.zig         # WASM 运行时
│   ├── api.zig             # Extension API
│   └── loader.zig          # 加载器
├── ai/
│   ├── provider.zig
│   ├── client.zig
│   └── providers/
├── tui/
│   ├── app.zig
│   ├── editor.zig
│   └── widgets.zig
├── learning/               # Harness 优化
│   ├── tracker.zig
│   └── optimizer.zig
└── utils/
    ├── config.zig
    └── log.zig
```

---

## 参考文档

- [愿景 V2.0](../docs/design/kimiz-vision-v2.md)
- [Pi-Mono 对比](../docs/design/kimiz-vs-pi-mono-comparison.md)
- [架构简化提案](../docs/design/simplified-architecture-proposal.md)
- [冲突分析](./TASK-CONFLICT-ANALYSIS.md)

---

**维护者**: Kimiz Team  
**愿景**: Harness Engineering Platform  
**策略**: 借鉴 Pi 核心，构建 Harness 平台
