# KimiZ 产品路线图 v2.0

> **统一路线图：0-10 阶段**  
> 最后更新: 2026-04-06  
> 状态: Phase 2 已完成（待编译修复验证）

---

## 路线图概览

```
Phase 0: 基础修复        → 编译通过、可运行
Phase 1: 核心 Agent      → Loop、工具、Provider、Skills
Phase 2: 用户体验        → REPL、Session、Plan/Shell/YOLO、Git 工具
Phase 3: 子 Agent        → Delegate、Worktree、Coordinator
Phase 4: Harness 层      → WorkspaceContext、PromptCache、ContextTruncation
Phase 5: 可观测性        → Trace、Limits、Linter
Phase 6: 外部集成        → AutoLab、OpenCLI、Web Search
Phase 7: 高级自动化      → SlopGC、SelfReview、Learning
Phase 8: 平台化          → MultiAgent、Routing、Extensions
Phase 9: 商业化          → PayGo、Enterprise
Phase 10: 远期研究       → WASM Sandbox、Formal Verification
```

---

## 已完成阶段

### Phase 0: 基础修复

**目标**: 项目可编译、可测试、可运行  
**状态**: ✅ 曾完成，当前因 Zig 0.16 API 回退需重新修复

| 任务 | 状态 |
|------|------|
| 项目结构初始化 | ✅ |
| 构建系统 | ✅ |
| CI/CD 基础 | ⚪ |

### Phase 1: 核心 Agent

**目标**: 完整的 Agent 运行引擎  
**状态**: ✅ 已完成

| 任务 | 状态 | 说明 |
|------|------|------|
| Agent Loop 状态机 | ✅ | prompt → AI → tool → execute |
| 事件系统 | ✅ | Message/ToolCall/ToolResult/Error |
| 5 Provider 支持 | ✅ | OpenAI, Anthropic, Google, Kimi, Fireworks |
| 模型注册表 | ✅ | 8 模型 + 成本计算 |
| 7 个内置工具 | ✅ | read/write/bash/grep/glob/web_search/url_summary |
| 工具注册表 | ✅ | 动态管理 |
| Skills 框架 | ✅ | Registry + 6 内置 skill |
| RTK Token 优化 | ✅ | 作为 Skill |

**产出版本**: `kimiz v0.3.0`

### Phase 2: 用户体验 (UX Foundation)

**目标**: 补齐与官方 kimi-cli 的核心体验差距  
**状态**: ✅ 已完成 (2026-04-05)

| 任务 | 状态 | Commit |
|------|------|--------|
| REPL + Slash 命令 | ✅ | 基础 |
| 会话持久化 (T-086) | ✅ | `f7ee56a` |
| Shell 模式 (T-087) | ✅ | `0edec45` |
| YOLO 工具审批 (T-095) | ✅ | `0edec45` |
| Plan 模式 (T-088) | ✅ | `a371fc5` |
| Git 工具集 | ✅ | `88c0af4` |
| 默认 Kimi 模型 | ✅ | `c540c22` |

**产出版本**: `kimiz v0.4.0`

---

## 当前阶段

### Phase 3: 子 Agent 系统 (Subagent)

**目标**: 让 Agent 能安全地委派任务给子 Agent  
**状态**: 🟡 代码已提交，待编译恢复后验证

| 任务 | 状态 | 来源 | 预计 |
|------|------|------|------|
| 修复编译兼容性 | `todo` | FIX-ZIG-015 | 1.5h |
| 验证 delegate 工具 | `todo` | T-092 | 30min |
| 验证 git worktree 隔离 | `todo` | T-119 | 1h |
| Named Sub-agents | `todo` | backlog | 4h |
| Coordinator Mode MVP | `todo` | cc-1~cc-4 | 8h |
| 安全分类器 | `todo` | cc-5 | 6h |
| 工具调用摘要 | `todo` | cc-6 | 4h |

**验收标准**:
- [ ] `zig build test` 通过
- [ ] REPL 中 AI 可调用 `delegate` 工具
- [ ] 子 Agent 在独立 worktree 中运行
- [ ] Coordinator 能判断何时委派、聚合结果

**产出版本**: `kimiz v0.5.0`

---

## 未来阶段

### Phase 4: Harness 层

**目标**: 完整的 Agent 工作环境（Harness）  
**时间**: Phase 3 完成后 2-3 周

| 任务 | 来源 | 预计 |
|------|------|------|
| WorkspaceContext (Git + 文档) | TASK-FEAT-006 | 4h |
| PromptCache (stable prefix) | TASK-FEAT-007 | 6h |
| Context Truncation | TASK-FEAT-008 | 3h |
| Session Persistence 完善 | TASK-FEAT-010 | 6h |

**产出版本**: `kimiz v0.6.0`

### Phase 5: 可观测性与约束

**目标**: Agent 行为可预测、可调试、有边界  
**时间**: Phase 4 完成后 2 周

| 任务 | 来源 | 预计 |
|------|------|------|
| Reasoning Trace | TASK-FEAT-012 | 6h |
| Resource Limits | TASK-FEAT-013 | 4h |
| Agent Linter | TASK-FEAT-015 | 6h |
| Tool Approval 完善 | TASK-FEAT-009 | 4h |

**产出版本**: `kimiz v0.7.0`

### Phase 6: 外部集成

**目标**: 让 Agent 能调用外部评估器和工具生态  
**时间**: Phase 5 完成后 3 周

| 任务 | 来源 | 预计 |
|------|------|------|
| AutoLab Critic 集成 | GRA-174 / TASK-FEATURE-AUTOLAB-001 | 32-40h |
| OpenCLI Skill | opencli-1/2/3 | 16h |
| Web Search 增强 | TASK-TOOL-004 | 4h |

**产出版本**: `kimiz v0.8.0`

### Phase 7: 高级自动化

**目标**: Agent 自我优化和质量保证  
**时间**: Phase 6 完成后 2-3 周

| 任务 | 来源 | 预计 |
|------|------|------|
| AI Slop GC | TASK-FEAT-016 | 6h |
| Agent Self-Review | TASK-FEAT-017 | 8h |
| Learning 系统深度集成 | TASK-INTEG-002 | 8h |

**产出版本**: `kimiz v0.9.0`

### Phase 8: 平台化

**目标**: 从单一 Agent 升级为 Harness Engineering Platform  
**时间**: Phase 7 完成后 4 周+

| 任务 | 来源 | 预计 |
|------|------|------|
| Multi-Agent 编排器 | design/kimiz-vision-v2.md | 16h |
| Smart Routing 深度集成 | T-012 | 8h |
| Extension 系统 | TASK-FEAT-006 | 12h |
| AGENTS.md 知识库 | TASK-FEAT-014 | 8h |

**产出版本**: `kimiz v1.0.0`

### Phase 9: 商业化

**目标**: 可持续的商业模式  
**时间**: v1.0 发布后

| 任务 | 来源 | 预计 |
|------|------|------|
| Pay-as-you-go 余额策略 | paygo-1 | 8h |
| 充值入口架构 | paygo-2 | 12h |
| Tezos 智能合约评估 | paygo-3 | 4h |
| 企业级功能 | - | - |

### Phase 10: 远期研究

**目标**: 安全性、可验证性、前沿探索  
**时间**: 长期

| 任务 | 来源 | 预计 |
|------|------|------|
| WASM/WASI 沙箱 | T-117 | 24h+ |
| OS Namespace 隔离 | T-118 | 24h+ |
| 形式化验证 (TLA+) | T-112 | - |

---

## 任务编排策略

### 近期执行顺序（未来 4 周）

```
Week 1:
├── FIX-ZIG-015: 恢复编译
├── T-092-VERIFY: delegate 验证
├── T-119-VERIFY: worktree 验证
└── T-009-E2E: 补充测试

Week 2-3:
├── Named Sub-agents (YAML)
├── Coordinator Mode Spec + MVP
├── 安全分类器
└── 工具调用摘要机制

Week 4:
├── WorkspaceContext
├── PromptCache
└── Context Truncation
```

### 新加小组件安排

来自外部分析和用户 todo 列表的小组块，已按依赖关系插入各阶段：

| 小组件 | 插入阶段 | 原因 |
|--------|----------|------|
| cc-1~cc-4 (Coordinator) | Phase 3 | 依赖 delegate 基础 |
| cc-5 (安全分类器) | Phase 3 | 与 Coordinator 同时部署 |
| cc-6 (工具调用摘要) | Phase 3 | UX 增强，无额外依赖 |
| opencli-1/2/3 | Phase 6 | 外部工具生态 |
| paygo-1/2/3 | Phase 9 | 商业化阶段 |
| GRA-174 (AutoLab) | Phase 6 | 外部 Critic 集成 |

---

## 文档地图

| 文档 | 作用 |
|------|------|
| `AGENT-ENTRYPOINT.md` | Coding Agent 的当前执行入口 |
| `docs/CURRENT-SPRINT.md` | 当前 Sprint 看板 |
| `docs/FEATURES.md` | 已实现的全部特性清单 |
| `docs/ROADMAP-v2.md` | 本文件，0-10 阶段统一路线图 |
| `docs/specs/*.md` | 当前可执行任务的 Technical Spec |

---

## 决策记录

### 为什么把 Coordinator Mode 放在 Phase 3？

**理由**:
1. `delegate` 工具已在代码中注册（T-092），是最直接的扩展点
2. Coordinator 的核心是"何时委派"和"如何聚合结果"，不需要 Harness 层的完整上下文
3. 先在子 Agent 层面验证多 Agent 协作，再逐步升级到平台化的 Multi-Agent 编排器（Phase 8）

### 为什么把 Harness 层放在 Phase 4？

**理由**:
1. Harness（WorkspaceContext、PromptCache、ContextTruncation）是单 Agent 体验的核心增强
2. 这些功能相对独立，可以在 Subagent 稳定后专注实现
3. 与 Raschka 论文的 6 个组件顺序一致（Context → Cache → Truncation）

### 为什么废弃旧的 T-001~T-025 编号？

**理由**:
1. 旧 Sprint 存在大量编号冲突（T-006, T-009, T-010）
2. 很多任务文件的状态与实际代码不符
3. 采用"按阶段分组 + 任务名"的新结构，比纯数字编号更易维护
