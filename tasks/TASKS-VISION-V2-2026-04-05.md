# Kimiz 任务清单 (Vision V2.0)

**愿景**: Harness Engineering Platform  
**日期**: 2026-04-05  
**核心原则**: 借鉴 Pi 的简洁核心，构建更大的 Harness 平台

---

## 架构层次

```
┌─────────────────────────────────────────┐
│  Layer 4: Platform                      │
│  - Harness 市场                          │
│  - 可视化编辑器                          │
│  - 企业级功能                            │
├─────────────────────────────────────────┤
│  Layer 3: Multi-Agent                   │
│  - Agent 编排器                          │
│  - 任务分配 (Smart Routing)              │
│  - 共享记忆 (三层记忆)                    │
│  - 协作协议                              │
├─────────────────────────────────────────┤
│  Layer 2: Harness Engine                │
│  - Skills 系统 (结构化知识)               │
│  - 约束系统                              │
│  - Learning 系统 (Harness 优化)           │
│  - Extension 系统                        │
├─────────────────────────────────────────┤
│  Layer 1: Core Runtime (借鉴 Pi)         │
│  - 简洁 Agent 循环                        │
│  - 基础工具集                            │
│  - 单层 Session                          │
│  - 稳定 API                              │
└─────────────────────────────────────────┘
```

---

## 实施阶段

### Phase 1: Core Runtime (Week 1-2)
**目标**: 借鉴 Pi，建立稳固核心

| 任务 | 优先级 | 预计 | 说明 |
|------|--------|------|------|
| **URGENT-FIX** | P0 | 0.5h | 编译错误 |
| **BUG-013** | P0 | 4h | page_allocator 修复 |
| **BUG-014** | P0 | 6h | CLI 实现 |
| **BUG-015** | P0 | 3h | 错误处理 |
| **BUG-016** | P0 | 2h | 内存安全 |
| **BUG-017** | P0 | 3h | 客户端复用 |
| **BUG-018** | P0 | 5h | 流式处理 |
| **BUG-019** | P0 | 2h | API Key 管理 |
| **BUG-020** | P0 | 2h | Logger 线程安全 |
| **REF-003** | P0 | 8h | Session 简化 (单层) |
| **FEAT-007** | P0 | 4h | Tools 简化 (5个核心) |
| **FEAT-001** | P0 | 12h | TUI 完整实现 |

**Phase 1 小计**: 12个任务，52小时

---

### Phase 2: Harness Engine (Week 3-4)
**目标**: 实现 Harness 核心能力

#### 2.1 Skills 系统 (P0)

| 任务 | 优先级 | 预计 | 说明 |
|------|--------|------|------|
| **FEAT-003-register** | P0 | 4h | Skills 注册 |
| **FEAT-003-harness** | P0 | 6h | Harness 解析器 |
| **FEAT-003-constraints** | P0 | 4h | 约束系统 |

**Skills 是 Harness 的核心**:
- 声明式知识定义
- 约束绑定
- 工具组合

#### 2.2 Extension 系统 (P0)

| 任务 | 优先级 | 预计 | 说明 |
|------|--------|------|------|
| **FEAT-006-extension** | P0 | 16h | WASM Extension |

**Extension 与 Skills 互补**:
- Skills: 声明式 (What)
- Extension: 命令式 (How)

#### 2.3 Workspace Context (P1)

| 任务 | 优先级 | 预计 | 说明 |
|------|--------|------|------|
| **FEAT-006-workspace** | P1 | 4h | Git + AGENTS.md |
| **REF-006** | P1 | 4h | Workspace 简化 |

#### 2.4 Prompt & Context (P1)

| 任务 | 优先级 | 预计 | 说明 |
|------|--------|------|------|
| **FEAT-007-prompt** | P1 | 6h | Prompt Caching |
| **FEAT-008** | P1 | 3h | Context Truncation |

**Phase 2 小计**: 7个任务，47小时

---

### Phase 3: Multi-Agent (Week 5-6)
**目标**: 实现 Multi-Agent 协作

#### 3.1 基础架构 (P1)

| 任务 | 优先级 | 预计 | 说明 |
|------|--------|------|------|
| **FEAT-011** | P1 | 8h | Agent 编排器 |
| **FEAT-010** | P1 | 4h | Session 持久化 |

#### 3.2 Smart Routing (P1)

| 任务 | 优先级 | 预计 | 说明 |
|------|--------|------|------|
| **T-012** | P1 | 3h | 任务分配器 |

**重新设计**: 从单 Agent 自动路由 → Multi-Agent 调度器

#### 3.3 记忆系统 (P1)

| 任务 | 优先级 | 预计 | 说明 |
|------|--------|------|------|
| **T-025** | P1 | 8h | 三层记忆实现 |

**重新设计**: 从单 Agent 优化 → Multi-Agent 共享

#### 3.4 Learning (P2)

| 任务 | 优先级 | 预计 | 说明 |
|------|--------|------|------|
| **FEAT-004-learning** | P2 | 6h | Harness 优化 |

**重新设计**: 从自适应 → Harness 性能优化

**Phase 3 小计**: 5个任务，29小时

---

### Phase 4: Platform (Week 7+)
**目标**: 平台化

| 任务 | 优先级 | 预计 | 说明 |
|------|--------|------|------|
| **FEAT-014** | P2 | 6h | Knowledge Base |
| **FEAT-015** | P2 | 4h | Agent Linter |
| **FEAT-016** | P2 | 3h | SLOP Collector |
| **FEAT-013** | P2 | 3h | Resource Limits |

**Phase 4 小计**: 4个任务，16小时

---

## 任务状态总览

### P0 - 阻塞 (12个)

**Bugfix (9个)**:
- URGENT-FIX, BUG-013~020

**Feature (3个)**:
- REF-003 (Session 简化)
- FEAT-007 (Tools 简化)
- FEAT-001 (TUI)

### P1 - 高优先级 (12个)

**Harness Engine (7个)**:
- FEAT-003-register (Skills 注册)
- FEAT-003-harness (Harness 解析)
- FEAT-003-constraints (约束系统)
- FEAT-006-extension (Extension 系统)
- FEAT-006-workspace (Workspace)
- FEAT-007-prompt (Prompt Cache)
- FEAT-008 (Context Truncation)

**Multi-Agent (5个)**:
- FEAT-011 (Agent 编排)
- FEAT-010 (Session 持久化)
- T-012 (Smart Routing)
- T-025 (三层记忆)
- FEAT-004-learning (Learning)

### P2 - 中优先级 (8个)

- 各种高级功能

---

## 关键决策

### 保留的功能 (支持大愿景)

| 功能 | 原因 | 实现策略 |
|------|------|----------|
| **Skills** | Harness 核心 | P0, 声明式 |
| **Extension** | 可扩展性 | P0, WASM |
| **Smart Routing** | Multi-Agent 调度 | P1, 重新设计 |
| **三层记忆** | Multi-Agent 共享 | P1, 重新设计 |
| **Learning** | Harness 优化 | P2, 重新设计 |

### 借鉴 Pi 的地方

| 方面 | 策略 |
|------|------|
| **核心运行时** | 简洁设计 |
| **Session 管理** | 单层 + Compaction |
| **工具系统** | 5个核心工具 |
| **Extension** | WASM 运行时 |

### 超越 Pi 的地方

| 方面 | 策略 |
|------|------|
| **Skills** | 声明式知识系统 |
| **Harness** | 结构化工作环境 |
| **Multi-Agent** | 协作编排 |
| **约束系统** | 容错和安全 |

---

## 与之前清理的对比

### 恢复的任务

| 任务 | 原因 |
|------|------|
| **T-008 (Skills)** | Harness 核心 |
| **T-012 (Routing)** | Multi-Agent 调度 |
| **T-025 (Memory)** | Multi-Agent 共享 |
| **FEAT-004 (Learning)** | Harness 优化 |
| **FEAT-003-register** | Skills 注册 |

### 保持删除的任务

| 任务 | 原因 |
|------|------|
| 重复的任务 | 真正的重复 |
| 基于已移除功能的 Bugfix | 过时 |

---

## 总结

### 核心洞察

1. **Pi 是起点，不是终点**
   - 借鉴 Pi 的简洁核心
   - 但目标是更大的 Harness Platform

2. **渐进式架构**
   - Layer 1: Core (借鉴 Pi)
   - Layer 2: Harness Engine
   - Layer 3: Multi-Agent
   - Layer 4: Platform

3. **功能保留原则**
   - 支持 Harness 愿景的保留
   - 单 Agent 优化的简化

### 时间线

| Phase | 时间 | 产出 |
|-------|------|------|
| Phase 1 | Week 1-2 | 稳固核心 |
| Phase 2 | Week 3-4 | Harness Engine |
| Phase 3 | Week 5-6 | Multi-Agent |
| Phase 4 | Week 7+ | Platform |

**总计**: 6-8 周达到可用状态

---

**维护者**: Kimiz Team  
**愿景**: Harness Engineering Platform  
**策略**: 借鉴 Pi，超越 Pi
