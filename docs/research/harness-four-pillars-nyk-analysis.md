# Harness 四大支柱深度分析 (Nyk @ Builderz)

**研究日期**: 2026-04-05  
**来源**: @nyk_builderz (Builderz.dev / Split Labs 联合创始人)  
**核心观点**: "The harness is the product. The model is the engine."  
**背景**: Terminal Bench 2.0 实测 —— 只改 harness 就从 52.8% 提升到 66.5% (Top 30 → Top 5)

---

## 1. 执行摘要

Nyk 提出了**生产级 Agent Harness 的完整工程框架**，核心洞察：

> **模型正在商品化，真正的护城河是 Harness 积累的智能（上下文、失败模式、架构决策）**

**关键数据**:
- LangChain: 只改 harness，Terminal Bench 2.0 从 52.8% → 66.5%
- Gartner: 2027 年 40% Agentic AI 项目会被取消
- 研究数据: 复杂企业任务 Agent 失败率 70-95%

**根本原因**: 大家迷信"挑最好的模型"，忽视了 Harness 才是决定成败的关键。

---

## 2. Harness 三大核心职责

```
┌─────────────────────────────────────────────────────────────────┐
│                     Harness Architecture                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │  1. Context Architecture (上下文架构)                     │   │
│   │     → 决定模型每一步该看到什么信息                        │   │
│   │     → 分层披露，非一股脑全扔                             │   │
│   └─────────────────────────────────────────────────────────┘   │
│                              │                                   │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │  2. Execution Guardrails (执行护栏)                      │   │
│   │     → 硬性限制模型能干什么、不能干什么                    │   │
│   │     → 成本、安全、流程约束                               │   │
│   └─────────────────────────────────────────────────────────┘   │
│                              │                                   │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │  3. Memory Infrastructure (记忆基础设施)                 │   │
│   │     → 让模型真正从历史学习，而非每次都失忆                │   │
│   │     → 跨 session 的 persistent memory                   │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. 四大支柱 (Four Pillars)

### Pillar 1: Context Architecture (上下文架构)

#### 核心原则
- **分层逐步披露**: 项目级 → 模块级 → 文件级
- **Token 预算管理**: 超 40% 就报警
- **动态注入**: 只加载相关上下文，非百科全书

#### 常见错误 ❌
```
CLAUDE.md / AGENTS.md 越写越大
└── 2000 行百科全书 → 模型直接忽略
```

#### 正确做法 ✅
```
根指令文件 < 200 行
├── docs/ (结构化目录)
│   ├── architecture/
│   ├── patterns/
│   └── decisions/
└── 动态注入: task 级加载相关上下文
    └── 过期规则: 每月清理
```

#### 与 Kimiz 现状对比

| Nyk 建议 | Kimiz 现状 | 差距 | 改进建议 |
|----------|-----------|------|----------|
| 分层披露 | WorkspaceContext 基础框架 | 🟡 部分有 | 强化层级加载 |
| Token 预算 40% 报警 | 暂无 | 🔴 缺失 | 添加预算监控 |
| <200 行根指令 | AGENTS.md 设计 | 🟢 符合 | 保持精简 |
| 动态注入 | ContextTruncation 基础 | 🟡 部分有 | 完善 task 级加载 |
| 每月清理过期 | 暂无自动清理 | 🔴 缺失 | 添加过期检测 |

**相关文件**: 
- `src/harness/context_truncation.zig`
- `src/workspace/context.zig`
- `src/harness/prompt_cache.zig`

---

### Pillar 2: Agent Specialization (Agent 专业化)

#### 核心原则
- **不要万能 Agent** → 按领域拆分专职 Subagent
- **工具最小化** → 每个 Agent 只给需要的工具
- **结构化 Handoff** → Agent 间通信协议

#### 专业化分工示例
```
Master Agent
    │
    ├── CodeWriter Agent
    │   └── 工具: file_write, code_edit
    │
    ├── TestAgent  
    │   └── 工具: test_runner, coverage_check
    │
    ├── ReviewAgent
    │   └── 工具: linter, security_scan (read-only)
    │
    └── DeployAgent
        └── 工具: git, ci_cd, monitoring
```

#### 与 Kimiz 现状对比

| Nyk 建议 | Kimiz 现状 | 差距 | 改进建议 |
|----------|-----------|------|----------|
| 专职 Subagent | 通用 Subagent | 🔴 大 | 实现 SpecialistSubAgent |
| 工具最小化 | 继承父 Agent 工具 | 🟡 部分有 | 精细化工具过滤 |
| 结构化 Handoff | 简单委派 | 🔴 缺失 | 设计 Handoff 协议 |

**相关文件**:
- `src/agent/subagent.zig` (当前是通用委派)
- `docs/research/coda-team-agent-analysis.md` (已有 Specialist 设计思路)

**改进方向**: 参考 Coda 的 5-Agent 分工模式
- `Explorer` → 代码探索
- `Planner` → 任务规划  
- `Coder` → 代码实现
- `Reviewer` → 代码审查
- `Researcher` → 技术调研

---

### Pillar 3: Persistent Memory (持久化记忆)

#### 核心原则
- **文件系统存储真实记忆** (非内存中的易失数据)
- **每次 session**: 开始读、结束写
- **Append-only**: 可审计的历史

#### 推荐记忆文件结构
```
.kimiz/memory/
├── decisions.md          # 架构决策记录
├── failure-catalog.md    # 失败模式库
├── session-state.md      # Session 状态
├── patterns.md           # 代码模式偏好
└── context/
    ├── current-task.md   # 当前任务上下文
    └── learned/
        ├── tool-effectiveness.md  # 工具效果追踪
        └── model-performance.md   # 模型性能记录
```

#### 文件内容示例

**decisions.md**:
```markdown
# Architecture Decisions

## 2026-04-05: Use LMDB for Long-Term Memory
- Context: JSON persistence too slow
- Decision: Migrate to LMDB
- Consequences: Faster reads, adds dependency
- Status: implemented
```

**failure-catalog.md**:
```markdown
# Failure Patterns

## Pattern: HTTP Timeout on Large Files
- Symptom: Read >1MB files causes timeout
- Root Cause: Buffer too small
- Fix: Increase HTTP_BUF_SIZE to 128KB
- Occurrences: 3
```

#### 与 Kimiz 现状对比

| Nyk 建议 | Kimiz 现状 | 差距 | 改进建议 |
|----------|-----------|------|----------|
| 文件系统记忆 | MemoryManager (内存) + JSON | 🟡 部分有 | 增加结构化文件记忆 |
| decisions.md | 暂无 | 🔴 缺失 | 添加 ADR 记录 |
| failure-catalog.md | LearningEngine 基础 | 🟡 部分有 | 显式失败模式库 |
| Session 读/写 | SessionStore (JSON) | 🟢 接近 | 增强为结构化格式 |
| Append-only | 覆盖式写入 | 🔴 不符合 | 改为追加模式 |

**相关文件**:
- `src/memory/root.zig` (MemoryManager)
- `src/utils/session.zig` (SessionStore)
- `src/learning/root.zig` (LearningEngine)
- `docs/research/addy-osmani-agent-skills-analysis.md` (ADR 概念)

---

### Pillar 4: Structured Execution (结构化执行)

#### 核心原则
- **强制流程**: research → plan → execute → verify
- **计划先 Review**: 执行前必须确认计划
- **预算限制**: 执行有成本上限
- **结果回写**: 把结果写回记忆

#### 执行流程图
```
User Request
    │
    ▼
┌─────────────┐
│  Research   │ ← 收集信息、上下文
└──────┬──────┘
       │
       ▼
┌─────────────┐
│    Plan     │ ← 生成执行计划
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Review    │ ← 人工/自动审查计划
│  (Approval) │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Execute   │ ← 执行（有预算限制）
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Verify    │ ← 验证结果
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Writeback │ ← 结果写入记忆
└─────────────┘
```

#### 与 Kimiz 现状对比

| Nyk 建议 | Kimiz 现状 | 差距 | 改进建议 |
|----------|-----------|------|----------|
| 强制流程 | Agent Loop 基础 | 🟡 部分有 | 显式状态机 |
| 计划 Review | 暂无 | 🔴 缺失 | 添加 plan_mode 强化 |
| 预算限制 | ResourceLimits 基础 | 🟢 接近 | 完善成本追踪 |
| 结果回写 | LearningEngine 基础 | 🟡 部分有 | 完善自动记录 |

**相关文件**:
- `src/agent/agent.zig` (Agent Loop)
- `src/harness/resource_limits.zig` (预算限制)
- `src/learning/root.zig` (学习回写)
- `docs/research/addy-osmani-agent-skills-analysis.md` (/spec→/plan→/build→/test 流程)

---

## 4. 护栏分层 (Guardrail Hierarchy)

```
Guardrail Layers (从上到下，约束递减)

┌─────────────────────────────────────────────────────────────┐
│ Layer 4: Hard Limits (硬限制)                                │
│ ├── 成本上限 (token/调用次数)                                │
│ ├── 文件保护 (只读模式)                                      │
│ └── 超时限制                                                 │
├─────────────────────────────────────────────────────────────┤
│ Layer 3: Safety Nets (安全网)                                │
│ ├── 模拟执行 (dry-run)                                       │
│ ├── 沙箱环境                                                 │
│ └── 回滚机制                                                 │
├─────────────────────────────────────────────────────────────┤
│ Layer 2: Golden Path (黄金路径)                              │
│ ├── 强制流程 (必须走 /spec→/plan→/build)                     │
│ ├── 检查清单 (必须完成所有项)                                │
│ └── 质量门禁                                                 │
├─────────────────────────────────────────────────────────────┤
│ Layer 1: Audit Logs (审计日志)                               │
│ ├── 完整操作记录                                             │
│ ├── 决策链路追踪                                             │
│ └── 失败模式归档                                             │
└─────────────────────────────────────────────────────────────┘
```

#### 与 Kimiz 现状对比

| 层级 | Nyk 建议 | Kimiz 现状 | 改进建议 |
|------|----------|-----------|----------|
| Hard Limits | 成本/文件/超时 | ResourceLimits 基础 | 完善文件保护 |
| Safety Nets | 模拟/沙箱/回滚 | 暂无沙箱 | 添加隔离环境 |
| Golden Path | 强制流程 | AgentLinter 基础 | 完善流程检查 |
| Audit Logs | 完整记录 | ReasoningTrace 基础 | 增强审计功能 |

**相关文件**:
- `src/harness/resource_limits.zig`
- `src/harness/agent_linter.zig`
- `src/harness/reasoning_trace.zig`
- `src/harness/self_review.zig`

---

## 5. 与 Kimiz 现有架构的映射

### 5.1 整体映射关系

```
Nyk 四大支柱                    Kimiz 现有/规划
─────────────────────────────────────────────────
Context Architecture    ↔   WorkspaceContext
                            + ContextTruncation
                            + PromptCache

Agent Specialization    ↔   Subagent (需重构为 Specialist)
                            + Skill System

Persistent Memory       ↔   MemoryManager (3-layer)
                            + SessionStore
                            + LearningEngine
                            + (新增) 文件系统记忆

Structured Execution    ↔   Agent Loop
                            + ResourceLimits
                            + AgentLinter
                            + (新增) 强制流程状态机
```

### 5.2 Kimiz 架构符合度评估

| 四大支柱 | 符合度 | 主要差距 |
|----------|--------|----------|
| Context Architecture | 70% | Token 预算监控、过期清理 |
| Agent Specialization | 40% | 需要 SpecialistSubAgent |
| Persistent Memory | 60% | 文件系统结构化记忆 |
| Structured Execution | 65% | 显式流程状态机 |
| **整体** | **~60%** | 框架已有，需细化实现 |

---

## 6. Kimiz 改进路线图 (基于四大支柱)

### Phase 1: Context Architecture 完善 (2 周)

```
Week 1:
├── Token Budget Monitor (超 40% 报警)
│   └── src/harness/token_budget.zig
├── Context Hierarchy (项目→模块→文件)
│   └── src/workspace/context_hierarchy.zig
└── Task-level Context Loader
    └── src/workspace/task_context.zig

Week 2:
├── Content Expiration (每月清理)
│   └── src/harness/content_expiration.zig
└── Dynamic Context Injection
    └── src/harness/dynamic_context.zig
```

### Phase 2: Agent Specialization (3 周)

```
Week 3-4:
├── SpecialistSubAgent 重构
│   └── src/agent/specialist.zig
├── Specialist Types
│   ├── Explorer (代码探索)
│   ├── Planner (任务规划)
│   ├── Coder (代码实现)
│   ├── Reviewer (代码审查)
│   └── Researcher (技术调研)
└── Tool Minimization
    └── src/agent/tool_filter.zig

Week 5:
├── Structured Handoff Protocol
│   └── src/agent/handoff.zig
└── Integration Tests
```

### Phase 3: Persistent Memory 增强 (2 周)

```
Week 6:
├── File System Memory
│   ├── .kimiz/memory/decisions.md (ADR)
│   ├── .kimiz/memory/failure-catalog.md
│   └── .kimiz/memory/patterns.md
└── Session Read/Write
    └── src/memory/persistent_files.zig

Week 7:
├── Append-only Audit Log
│   └── src/memory/audit_log.zig
└── Memory Query Interface
    └── src/memory/query.zig
```

### Phase 4: Structured Execution 强化 (2 周)

```
Week 8:
├── Explicit State Machine
│   └── src/agent/execution_state.zig
│       ├── research
│       ├── plan
│       ├── review
│       ├── execute
│       ├── verify
│       └── writeback
├── Plan Review Mode
│   └── src/agent/plan_review.zig
└── Result Writeback
    └── src/agent/result_writeback.zig
```

---

## 7. 关键文件模板

### 7.1 decisions.md (架构决策记录)

```markdown
# Architecture Decision Records

## ADR-001: Use Zig for Core Implementation
- Date: 2026-04-05
- Status: accepted
- Context: Need high-performance, single-binary agent
- Decision: Use Zig 0.15.2
- Consequences: Fast startup, steep learning curve

## ADR-002: LMDB for Long-Term Memory
- Date: 2026-04-05
- Status: proposed
- Context: JSON too slow for large memory
- Decision: Migrate to LMDB
- Consequences: Better performance, C dependency
```

### 7.2 failure-catalog.md (失败模式库)

```markdown
# Failure Catalog

## FC-001: Compilation Error in Self Review
- Pattern: var vs const misuse
- Symptom: Zig compile error
- Root Cause: Not checking mutability
- Fix: Always check if variable is mutated
- Prevention: AgentLinter rule
- Occurrences: 2

## FC-002: Memory Leak in Tool Result
- Pattern: Shallow copy of tool results
- Symptom: Use-after-free
- Root Cause: Not deep copying strings
- Fix: Use arena allocator
- Prevention: Memory sanitizer
- Occurrences: 1
```

### 7.3 session-state.md (Session 状态)

```markdown
# Session State: 2026-04-05-001

## Context
- Project: /home/user/project
- Task: Implement HTTP client
- Started: 2026-04-05T13:00:00Z

## Progress
- [x] Research: Completed (3 libraries compared)
- [x] Plan: Approved (use std.http)
- [ ] Build: In progress (50%)
- [ ] Test: Pending
- [ ] Review: Pending

## Decisions Made
- Use std.http over external library

## Next Steps
- Complete error handling
- Write unit tests
```

---

## 8. 与之前研究的关联

### 8.1 关联文档矩阵

| 本文 | 关联文档 | 关联点 |
|------|----------|--------|
| Context Architecture | `open-multi-agent-architecture-analysis.md` | MCP 上下文协议 |
| Agent Specialization | `coda-team-agent-analysis.md` | 6-Agent 分工模式 |
| Persistent Memory | `addy-osmani-agent-skills-analysis.md` | ADR 记录 |
| Structured Execution | `addy-osmani-agent-skills-analysis.md` | /spec→/plan→/build 流程 |
| Guardrails | `gstack-skill-infrastructure-analysis.md` | 约束系统 |

### 8.2 趋势整合

```
2026-04 Agent Harness 趋势总结

Sarah Wooders (Letta)          Harness = 记忆/上下文核心
        ↓
Raschka                        6大组件理论框架
        ↓
Harrison Chase (LangChain)     Context + Learning + Meta-Harness
        ↓
Ivan (Open-Multi-Agent)        编排层架构
        ↓
din0s_ (Autoresearch)          科研闭环应用
        ↓
datachaz (Addy Skills)         工程文化技能包
        ↓
Garry Tan (GStack)             技能分发基础设施
        ↓
ashpreetbedi (Coda)            团队级 Multi-Agent
        ↓
Nyk (本文)                     🔥 生产级 Harness 工程框架
                               (四大支柱 + 护栏分层)
```

---

## 9. 关键结论

> **"The harness is the product. The model is the engine."**
> 
> **"六个月积累的上下文、失败模式、架构决策，才是别人换个模型也复制不了的真正护城河。"**

### 对 Kimiz 的核心启示

1. **停止追逐最新模型** → 专注完善 Harness 四大支柱
2. **框架已有 60%** → 不需要重构，只需细化实现
3. **记忆是护城河** → 完善 Persistent Memory 系统
4. **专业化是趋势** → Subagent 必须重构为 Specialist
5. **流程强制是必要的** → 结构化执行防止"抄近路"

### Kimiz 的独特优势

| 优势 | 说明 |
|------|------|
| **Zig 高性能** | <100ms 启动，适合快速迭代 |
| **三层 Memory** | 已有 Short/Working/Long Term 架构 |
| **WASM 扩展** | zwasm 提供动态能力扩展 |
| **单二进制** | 部署简单，无依赖 |

### 与 "模型商品化" 的应对

```
模型商品化趋势
    │
    ├── Claude/GPT/Gemini 能力收敛
    │   └── 每季度差距缩小
    │
    └── 赢家 = Harness 最好的团队
        │
        ├── Context Architecture → 知道喂什么
        ├── Agent Specialization → 知道谁来做
        ├── Persistent Memory → 记得做过什么
        └── Structured Execution → 知道怎么做
        
        Kimiz 目标: 成为 Harness 最好的开源方案
```

---

## 10. 立即行动清单

### 本周 (High Priority)

- [ ] 创建 `.kimiz/memory/` 目录结构
- [ ] 实现 `decisions.md` 自动记录
- [ ] 添加 Token Budget 监控 (40% 报警)

### 本月 (Medium Priority)

- [ ] 重构 Subagent → SpecialistSubAgent
- [ ] 实现 Explorer/Researcher specialist
- [ ] 完善 Structured Execution 状态机

### 本季度 (Long Term)

- [ ] 完整的 Persistent Memory 文件系统
- [ ] 生产级 Guardrail 分层
- [ ] 跨 session Learning 系统

---

## 参考资源

- **Nyk 原帖**: Twitter/X @nyk_builderz
- **LangChain Terminal Bench**: https://terminalbench.com
- **Gartner Agentic AI 报告**: 2024-2025
- **相关研究**:
  - `docs/research/open-multi-agent-architecture-analysis.md`
  - `docs/research/gstack-skill-infrastructure-analysis.md`
  - `docs/research/addy-osmani-agent-skills-analysis.md`
  - `docs/research/coda-team-agent-analysis.md`

---

*文档版本: 1.0*  
*最后更新: 2026-04-05*  
*维护者: kimiz-core-team*
