# Kimiz 愿景 V2.0: Harness Engineering Platform

**日期**: 2026-04-05  
**愿景升级**: 从 AI Coding Assistant → Harness Engineering Platform

---

## 愿景对比

| 维度 | V1.0 (旧) | V2.0 (新) |
|------|-----------|-----------|
| **定位** | AI coding assistant | Harness Engineering Platform |
| **交互** | 简单 prompt | 结构化知识 + 约束 |
| **可靠性** | Best effort | 容错优先 |
| **架构** | 单 Agent | Multi-Agent 协作 |
| **人类角色** | 人类写代码 | 人类设计 Agent 工作环境 |

---

## 什么是 Harness Engineering Platform?

### 核心概念

不是让 AI 帮人类写代码，而是让**人类设计 Agent 的工作环境**，让 Agent 在这个环境中自主工作。

```
传统: 人类 → 写代码 → AI 辅助
Kimiz: 人类 → 设计 Harness → AI 在 Harness 中自主工作
```

### Harness 的组成

```
┌─────────────────────────────────────────┐
│         Harness Definition              │
│  (人类设计的工作环境)                     │
├─────────────────────────────────────────┤
│  1. Knowledge (结构化知识)               │
│     - AGENTS.md: Agent 行为定义          │
│     - RULES.md: 约束规则                 │
│     - CONTEXT/: 上下文文件               │
│                                         │
│  2. Constraints (约束)                   │
│     - 允许的操作                         │
│     - 禁止的操作                         │
│     - 审批流程                           │
│                                         │
│  3. Tools (工具集)                       │
│     - 内置工具                           │
│     - 自定义工具                         │
│     - 外部服务                           │
│                                         │
│  4. Collaboration (协作模式)             │
│     - Multi-Agent 拓扑                   │
│     - 任务分配                           │
│     - 结果汇总                           │
└─────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│      Agent Runtime (Kimiz Core)         │
│  - 解析 Harness 定义                     │
│  - 管理 Agent 生命周期                   │
│  - 执行约束检查                          │
│  - 协调 Multi-Agent                      │
└─────────────────────────────────────────┘
```

---

## 与 Pi-Mono 的关系

### Pi-Mono 的定位

Pi 是一个**极简的 Coding Harness**，专注于：
- 单个 Agent
- 简单的工具集
- 扩展通过 Extensions

### Kimiz 的定位

Kimiz 是一个**Harness Engineering Platform**，支持：
- 设计和运行复杂的 Harness
- Multi-Agent 协作
- 结构化的知识和约束
- 容错和可观测性

### 借鉴 Pi 的地方

| Pi 特性 | Kimiz 采用 | 原因 |
|---------|-----------|------|
| 简洁核心 | ✅ | 易于维护和发展 |
| Extension 系统 | ✅ | 可扩展性 |
| AGENTS.md | ✅ | 结构化知识 |
| 单层 Session | ✅ | 简化内存管理 |

### 超越 Pi 的地方

| Kimiz 特性 | Pi 没有 | 价值 |
|-----------|---------|------|
| Multi-Agent | ❌ | 复杂任务分解 |
| Harness DSL | ❌ | 定义复杂工作环境 |
| 约束系统 | ❌ | 容错和安全 |
| 知识图谱 | ❌ | 结构化知识 |
| 可观测性 | ❌ | 理解和调试 |

---

## 架构调整

### 保留的功能 (支持大愿景)

#### 1. Skills System ✅

**为什么保留**: Skills 是 Harness 中"知识"的载体

```
Skill = 结构化知识 + 约束 + 工具组合

例如 "CodeReviewSkill":
- 知识: 代码审查清单、最佳实践
- 约束: 只读操作、不修改代码
- 工具: read, grep, bash(test)
```

**与 Extension 的区别**:
- Extension: 运行时加载的代码
- Skill: 声明式的知识和约束

#### 2. Learning System ✅ (重新设计)

**为什么保留**: 让 Harness 自我优化

```
Learning = Harness 性能数据 → 优化建议

- 哪些约束经常触发?
- 哪些工具组合最有效?
- 如何调整 Agent 协作模式?
```

**重新设计**: 不作为核心功能，作为可插拔的优化器

#### 3. Smart Routing ✅ (重新设计)

**为什么保留**: Multi-Agent 需要任务分配

```
Routing = 任务 → 最合适的 Agent

在 Multi-Agent 场景中:
- 代码生成任务 → CodeAgent
- 测试任务 → TestAgent
- 文档任务 → DocAgent
```

**重新设计**: 不作为单 Agent 功能，作为 Multi-Agent 调度器

#### 4. 三层记忆 ✅ (重新设计)

**为什么保留**: Multi-Agent 需要共享记忆

```
三层记忆在 Multi-Agent 场景:
- Short-term: Agent 本地上下文
- Working: Agent 间共享的项目知识
- Long-term: 跨会话的组织知识
```

**重新设计**: 不作为单 Agent 优化，作为 Multi-Agent 共享机制

### 简化的部分

#### 1. 核心运行时

借鉴 Pi 的简洁设计：
- 清晰的 Agent 生命周期
- 简单的事件系统
- 稳定的 API

#### 2. 工具系统

基础工具保持简洁：
- read, write, edit, bash, grep
- 复杂工具通过 Extensions

#### 3. Session 管理

单层 Session + Compaction：
- 简单可靠
- 支持分支和恢复

---

## 实施策略

### 阶段 1: 稳固核心 (借鉴 Pi)

**目标**: 建立简洁可靠的核心

```
Week 1-2:
├── 简化核心 (借鉴 Pi)
│   ├── 单层 Session
│   ├── 简洁工具集
│   └── 稳定 API
├── 修复关键 Bug
└── 实现基础 TUI
```

### 阶段 2: 添加 Harness 能力

**目标**: 支持 Harness 定义和运行

```
Week 3-4:
├── Harness 解析器
│   ├── AGENTS.md
│   ├── RULES.md
│   └── CONTEXT/
├── Skills 系统 (声明式)
├── 约束检查器
└── 基础 Learning
```

### 阶段 3: Multi-Agent

**目标**: 支持 Multi-Agent 协作

```
Week 5-6:
├── Agent 编排器
├── 任务分配器 (Smart Routing)
├── 共享记忆系统
└── 协作协议
```

### 阶段 4: 平台化

**目标**: 成为真正的 Platform

```
Week 7+:
├── Harness 市场
├── 可视化编辑器
├── 可观测性
└── 企业级功能
```

---

## 任务重新评估

### 应该保留的任务

| 任务 | 原因 | 优先级 |
|------|------|--------|
| Skills System | Harness 的核心组件 | P0 |
| Learning System | Harness 自我优化 | P1 |
| Smart Routing | Multi-Agent 调度 | P1 |
| 三层记忆 | Multi-Agent 共享 | P1 |
| Extension 系统 | 可扩展性 | P0 |

### 应该简化的任务

| 任务 | 简化方式 | 原因 |
|------|----------|------|
| Memory 实现 | 先单层，后扩展 | 先稳固核心 |
| Learning 实现 | 先统计，后优化 | 渐进增强 |
| Routing 实现 | 先手动，后自动 | 先可用，后智能 |

---

## 总结

### 核心洞察

1. **Pi 的简洁是手段，不是目的**
   - Pi 为了简洁而牺牲功能
   - Kimiz 为了大愿景而保持核心简洁

2. **Harness Engineering 需要更多基础设施**
   - 结构化知识 (Skills)
   - 约束系统
   - Multi-Agent 编排
   - 可观测性

3. **渐进式增强**
   - 先借鉴 Pi 建立稳固核心
   - 再逐步添加 Harness 能力
   - 最后实现 Multi-Agent

### 关键决策

✅ **保留 Skills**: Harness 的核心  
✅ **保留 Learning**: Harness 优化  
✅ **保留 Routing**: Multi-Agent 调度  
✅ **保留三层记忆**: Multi-Agent 共享  
✅ **借鉴 Pi 核心**: 简洁可靠  
✅ **渐进增强**: 先核心，后高级功能

---

**下一步**: 继续完善 Harness Platform 架构
