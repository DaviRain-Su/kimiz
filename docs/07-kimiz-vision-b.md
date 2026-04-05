# Kimiz 架构愿景 (2026-04-05 更新)

**目标**: 对标 Claude Code，成为完整的本地 Coding Agent  
**定位**: 开源 + 自托管 + 高性能 + 功能完整

---

## 核心设计原则

```
Claude Code 模式 = LLM (引擎) + Harness (底盘)

Kimiz = LLM (多 Provider) + 完整 Harness System
                         ├── Workspace Context
                         ├── Prompt Cache
                         ├── Memory (三层)
                         ├── Learning
                         ├── Tools
                         ├── Trace
                         ├── Limits
                         ├── Knowledge Base
                         ├── Linter
                         ├── Self-Review
                         └── Multi-Agent
```

---

## 最终目标架构

```
┌─────────────────────────────────────────────────────────────────┐
│                         Kimiz Agent                              │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    Harness Layer                          │    │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐  │    │
│  │  │ Workspace    │ │ Prompt       │ │ Knowledge    │  │    │
│  │  │ Context     │ │ Cache        │ │ Base (AGENTS)│  │    │
│  │  └──────────────┘ └──────────────┘ └──────────────┘  │    │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐  │    │
│  │  │ Context     │ │ Trace       │ │ Limits      │  │    │
│  │  │ Manager     │ │ System      │ │ (Safety)    │  │    │
│  │  └──────────────┘ └──────────────┘ └──────────────┘  │    │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐  │    │
│  │  │ Linter      │ │ Self-Review │ │ Subagent    │  │    │
│  │  │ (Constraints)│ │             │ │ (Delegation)│  │    │
│  │  └──────────────┘ └──────────────┘ └──────────────┘  │    │
│  └─────────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    Core Agent                            │    │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐  │    │
│  │  │ Agent Loop   │ │ Memory      │ │ Learning    │  │    │
│  │  │ (Reasoning) │ │ (三层)      │ │ (Adaptive)  │  │    │
│  │  └──────────────┘ └──────────────┘ └──────────────┘  │    │
│  │  ┌──────────────┐ ┌──────────────┐                  │    │
│  │  │ Smart       │ │ Tool        │                  │    │
│  │  │ Routing     │ │ Registry   │                  │    │
│  │  └──────────────┘ └──────────────┘                  │    │
│  └─────────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    AI Providers                          │    │
│  │  OpenAI │ Anthropic │ Google │ Kimi │ Fireworks         │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 任务路线图

### Phase 0: 基础修复 (Week 1)

**目标**: 项目可编译、可运行

| 任务 ID | 功能 | 优先级 | 预计 | 依赖 |
|---------|------|--------|------|------|
| URGENT-FIX | 修复编译错误 | P0 | 0.5h | 无 |
| TASK-BUG-013 | 修复 page_allocator 滥用 | P0 | 4h | 无 |
| TASK-BUG-014 | 修复 CLI 未实现 | P0 | 6h | 无 |
| TASK-BUG-015 | 修复静默错误处理 | P0 | 3h | 无 |
| TASK-BUG-016 | 修复工具结果内存浅拷贝 | P0 | 2h | 无 |
| TASK-BUG-017 | 修复 AI 客户端重复创建 | P0 | 3h | 无 |
| TASK-BUG-018 | 修复 HTTP 伪流式处理 | P0 | 5h | 无 |
| TASK-BUG-019 | 修复 getApiKey 内存管理 | P0 | 2h | 无 |
| TASK-BUG-020 | 修复 Logger 线程安全 | P0 | 2h | 无 |

**阶段 0 小计**: 9 个任务，27.5h

---

### Phase 1: Core Agent (Week 2-3)

**目标**: 完整 Claude Code 级别的 Agent Loop

| 任务 ID | 功能 | 优先级 | 预计 | 依赖 |
|---------|------|--------|------|------|
| TASK-FEAT-006 | WorkspaceContext (Git 上下文) | **P0** | 4h | Phase 0 |
| TASK-FEAT-007 | Prompt Caching | **P0** | 6h | FEAT-006 |
| TASK-FEAT-008 | Context Truncation | **P0** | 3h | FEAT-007 |
| TASK-FEAT-009 | Tool Approval 交互流程 | P1 | 4h | FEAT-006 |
| TASK-FEAT-010 | Session Persistence | P1 | 6h | FEAT-008 |
| TASK-FEAT-011 | Subagent Delegation | P1 | 8h | FEAT-010 |

**阶段 1 小计**: 6 个任务，31h

---

### Phase 2: Harness Layer (Week 4-6)

**目标**: 完整的 Harness 系统

| 任务 ID | 功能 | 优先级 | 预计 | 依赖 |
|---------|------|--------|------|------|
| TASK-FEAT-012 | Reasoning Trace | P1 | 6h | FEAT-010 |
| TASK-FEAT-013 | Resource Limits | P1 | 4h | FEAT-012 |
| TASK-FEAT-014 | AGENTS.md 结构化知识 | **P0** | 8h | FEAT-006 |
| TASK-FEAT-015 | Agent Linter 约束系统 | **P0** | 6h | FEAT-014 |
| TASK-FEAT-016 | AI Slop 垃圾回收 | P2 | 6h | FEAT-015 |
| TASK-FEAT-017 | Agent Self-Review | P2 | 8h | FEAT-015 |

**阶段 2 小计**: 6 个任务，38h

---

### Phase 3: 体验完善 (Week 7-8)

**目标**: 完整的用户体验

| 任务 ID | 功能 | 优先级 | 预计 | 依赖 |
|---------|------|--------|------|------|
| TASK-FEAT-001 | 完整实现 TUI | P1 | 12h | Phase 1 |
| TASK-FEAT-002 | Skills 注册到 Agent | P1 | 6h | Phase 1 |
| TASK-DOCS-004 | API 文档完善 | P2 | 4h | Phase 2 |
| TASK-009 | E2E 测试 | P1 | 4h | Phase 1 |

**阶段 3 小计**: 4 个任务，26h

---

## 任务清单 (统一编号)

### P0 - 阻塞级别

| 任务 ID | 功能 | 预计 | 文件 |
|---------|------|------|------|
| URGENT-FIX | 修复编译错误 | 0.5h | config.zig, http.zig |
| TASK-BUG-013 | page_allocator 滥用 | 4h | providers/*.zig |
| TASK-BUG-014 | CLI 未实现 | 6h | cli/root.zig |
| TASK-FEAT-006 | WorkspaceContext | 4h | memory/root.zig |
| TASK-FEAT-007 | Prompt Caching | 6h | ai/root.zig |
| TASK-FEAT-014 | AGENTS.md 结构化 | 8h | harness/knowledge.zig |
| TASK-FEAT-015 | Agent Linter | 6h | harness/linter.zig |

### P1 - 高优先级

| 任务 ID | 功能 | 预计 | 依赖 |
|---------|------|------|------|
| TASK-BUG-015 | 静默错误处理 | 3h | - |
| TASK-BUG-016 | 工具结果内存 | 2h | - |
| TASK-BUG-017 | AI 客户端复用 | 3h | - |
| TASK-BUG-018 | HTTP 流式处理 | 5h | - |
| TASK-BUG-019 | getApiKey 内存 | 2h | - |
| TASK-BUG-020 | Logger 线程安全 | 2h | - |
| TASK-FEAT-008 | Context Truncation | 3h | FEAT-007 |
| TASK-FEAT-009 | Tool Approval | 4h | FEAT-006 |
| TASK-FEAT-010 | Session Persistence | 6h | FEAT-008 |
| TASK-FEAT-011 | Subagent | 8h | FEAT-010 |
| TASK-FEAT-012 | Reasoning Trace | 6h | FEAT-010 |
| TASK-FEAT-013 | Resource Limits | 4h | FEAT-012 |
| TASK-FEAT-001 | 完整 TUI | 12h | Phase 1 |
| TASK-FEAT-002 | Skills 注册 | 6h | Phase 1 |
| TASK-009 | E2E 测试 | 4h | Phase 1 |

### P2 - 中优先级

| 任务 ID | 功能 | 预计 | 依赖 |
|---------|------|------|------|
| TASK-FEAT-016 | AI Slop GC | 6h | FEAT-015 |
| TASK-FEAT-017 | Self-Review | 8h | FEAT-015 |
| TASK-DOCS-004 | API 文档 | 4h | Phase 2 |

---

## 统计汇总

| 优先级 | 任务数 | 预计工时 |
|--------|--------|----------|
| P0 | 9 | 36.5h |
| P1 | 15 | 76h |
| P2 | 3 | 18h |
| **总计** | **27** | **130.5h** |

**预计周期**: ~22 个工作日 (4.5 周)

---

## 归档的任务 (简化路线 - 已废弃)

以下任务因选择完整 Harness 架构而废弃：

### Refactor (废弃)

| 任务 ID | 原因 |
|---------|------|
| TASK-REF-003 | 三层 Memory 被保留，不需简化 |
| TASK-REF-004 | Learning 被保留，不需移除 |
| TASK-REF-005 | Smart Routing 被保留，不需移除 |
| TASK-REF-006 | Workspace 被增强，不需简化 |

### Feature (废弃)

| 任务 ID | 原因 |
|---------|------|
| TASK-FEAT-006-ext | Extension 系统不是当前重点 |
| TASK-FEAT-007-sim | Tools 不需要简化 |

---

## 参考文档

1. **Raschka**: 《Components of A Coding Agent》
2. **Nathan Flurry**: agentOS + 生产环境趋势
3. **Cursor**: Multi-Agent 协调
4. **OpenAI**: Harness Engineering

---

**状态**: 架构已确定，待执行  
**最后更新**: 2026-04-05
