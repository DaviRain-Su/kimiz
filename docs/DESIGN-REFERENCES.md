# KimiZ 实现参考索引

> **本文档是所有后续实现的必读参考。**  
> 每个 Technical Spec 必须引用本索引中的相关章节。  
> 最后更新: 2026-04-06

---

## 使用方式

1. 拿到任务后，先读 `AGENT-ENTRYPOINT.md`
2. 读任务的 Technical Spec
3. **根据任务所属的 Phase，到本文档找对应的参考文档**
4. 在实现代码前，先阅读相关参考文档中的**设计原则**和**代码模式**
5. 在 Spec 的 `References` 章节中列出你实际参考的文档

---

## Phase 0-2: 项目基础与核心 Agent 编码规范

### Zig 版本策略

- **目标 Zig 版本**: `0.16.0-dev`
- **所有新代码必须使用 Zig 0.16 API**
- **禁止**: 使用 Zig 0.15 中已废弃或在 0.16 中移除的 API
- **示例**: `main()` 必须使用 `std.process.Init` 签名；`std.http.Client` 必须传入 `std.Io`

### Zig 代码质量基线

| 文档 | 核心要点 | 应用场景 |
|------|----------|----------|
| [TigerBeetle Patterns](research/TIGERBEETLE-PATTERNS-ANALYSIS.md) | 状态机、显式错误处理、无隐藏分配、Arena 模式 | **所有 Zig 代码** |
| [NullClaw Lessons](guides/NULLCLAW-LESSONS-QUICKREF.md) | 工具沙箱、优雅降级、日志可观测、资源边界 | **Agent Loop、工具实现** |
| [Zig 0.16 Breaking Changes](guides/ZIG-0.16-BREAKING-CHANGES-SUMMARY.md) | 0.15→0.16 迁移差异对照 | **API 选型时必读** |

**关键原则（写入代码时必须遵守）**:
- **Zig 0.16 优先**: 新实现优先使用 0.16 引入的 API，不向后兼容 0.15
- **无隐藏分配**: 所有分配必须通过 `allocator` 参数显式传入
- **状态机显式化**: Agent Loop 必须用明确的 enum 状态，不要用隐式跳转
- **错误传播**: 底层错误要映射到语义化的 `AiError`，不要 `catch unreachable`
- **资源边界**: 任何持有 allocator 的 struct 必须有对称的 `deinit`

---

## Phase 3: 子 Agent 系统 (Subagent)

| 文档 | 核心要点 | 应用场景 |
|------|----------|----------|
| [SUBAGENT-ARCHITECTURE-AND-IMPLEMENTATION-PLAN.md](design/SUBAGENT-ARCHITECTURE-AND-IMPLEMENTATION-PLAN.md) | Delegate 工具架构、Worktree 隔离、Coordinator Mode | **Subagent 全部实现** |

**关键原则**:
- 子 Agent 默认在独立 worktree 中运行，不污染主 tree
- `delegate` 是唯一的跨 Agent 边界工具
- Coordinator 负责"何时委派"和"结果聚合"，不是子 Agent 自己的事

---

## Phase 4: Harness 层

| 文档 | 核心要点 | 应用场景 |
|------|----------|----------|
| [Harness Four Pillars](research/harness-four-pillars-nyk-analysis.md) | WorkspaceContext、PromptCache、ContextTruncation、SessionPersistence | **Harness 全部实现** |
| [Claude Code Prompt Analysis](research/CLAUDE-CODE-PROMPT-ANALYSIS.md) | Prompt 分层、Stable Prefix、System Prompt 工程 | **PromptCache、Agent 提示** |
| [06-agent-harness-upgrade.md](lifecycle/06-agent-harness-upgrade.md) | 项目自身的 Harness 升级计划 | **Harness 优先级排序** |
| [Document-Driven Agent Loop](design/document-driven-agent-loop.md) | 文档作为长期记忆、三阶段 Loop、任务日志管理 | **Agent Loop 改造、文档驱动工作流** |

**关键原则**:
- PromptCache 的核心是"Stable Prefix"：不重复发送静态上下文
- Context Truncation 优先丢弃旧的 tool result，保留 system prompt 和最近对话
- WorkspaceContext 必须自动收集：README、package 文件、Git 状态、相关源码

---

## Phase 5: 可观测性与约束

| 文档 | 核心要点 | 应用场景 |
|------|----------|----------|
| [NullClaw Analysis](research/NULLCLAW-ANALYSIS.md) | 失败模式分类、日志追踪、安全分类器 | **Agent Linter、Resource Limits** |

**关键原则**:
- 每个 Agent 步骤都要产生可读的 trace（thought → action → observation）
- 资源限制必须同时控制：步数、token、时间、内存
- 安全分类器在 LLM 输出层和工具执行层都要部署（双层防护）

---

## Phase 6: 外部集成

| 文档 | 核心要点 | 应用场景 |
|------|----------|----------|
| [OpenCLI Analysis](research/OPENCLI-ANALYSIS.md) | CLI adapter 设计、命令发现、参数映射 | **OpenCLI Skill** |
| [AutoLab Integration](research/AUTOLAB-INTEGRATION-ANALYSIS.md) | 外部 Critic 接入、评估循环、反馈驱动迭代 | **AutoLab Critic** |
| [MCX Integration](research/MCX-INTEGRATION-ANALYSIS.md) | MCP 服务器协议、Zig 客户端实现 | **MCP Client** |
| [Lightpanda Browser](research/lightpanda-browser-analysis.md) | 无头浏览器集成、轻量化 web 抓取 | **Web 工具增强** |

**关键原则**:
- OpenCLI 的目标是"让 Agent 能调用任何遵循标准接口的 CLI"
- AutoLab Critic 必须异步运行，不阻塞 Agent Loop
- MCP 集成优先用已有 client，不要从零写协议栈

---

## Phase 7: 高级自动化

| 文档 | 核心要点 | 应用场景 |
|------|----------|----------|
| [OpenCLI Analysis](research/OPENCLI-ANALYSIS.md) | Agent 自我进化的市场需求验证、Token 经济性、探测-固化模式 | **Skill 自动生成、AutoRegistry、自我修复** |
| [Yoyo Evolve](research/YOYO-EVOLVE-ANALYSIS.md) | 自进化循环、编译反馈、代码生成-测试-修复 | **AI Slop GC、Self-Review、Learning** |
| [Zig LLM Self-Evolution](research/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md) | LLM 驱动的 Zig 代码生成策略 | **Skill 自生成** |

**关键原则**:
- 自进化的核心是"编译-运行-反馈"闭环
- 所有生成的代码必须先编译通过，再运行测试，最后才能合并
- AI Slop GC 的触发条件是"低信息熵 + 无测试覆盖 + 无引用"

---

## Phase 8: 平台化

| 文档 | 核心要点 | 应用场景 |
|------|----------|----------|
| [Kimiz Vision V2](design/kimiz-vision-v2.md) | Harness Engineering Platform 愿景 | **平台架构** |
| [Open Multi-Agent Architecture](research/open-multi-agent-architecture-analysis.md) | 多 Agent 编排、消息总线、角色定义 | **Multi-Agent 编排器** |
| [Raze TUI Analysis](research/raze-tui-analysis.md) | TUI 框架选型、Zig 终端 UI 设计 | **TUI 完整版** |
| [Ghostty Terminal](research/ghostty-terminal-analysis.md) | 高性能终端、配置系统、渲染 | **TUI、配置管理** |
| [Zig gRPC](research/grpc-zig-analysis.md) | gRPC 服务端/客户端在 Zig 中的实现 | **分布式 Agent 通信** |

**关键原则**:
- Multi-Agent 编排器先解决"任务分解 + 结果聚合"，再考虑复杂调度
- TUI 是可选增强项，不能阻塞核心 Agent 体验
- Extension 系统的接口必须稳定（Semantic Versioning）

---

## Phase 9: 商业化

| 文档 | 核心要点 | 应用场景 |
|------|----------|----------|
| [Pay-As-You-Go AI](research/PAY-AS-YOU-GO-AI-ANALYSIS.md) | 余额策略、充值入口、智能合约评估 | **PayGo 计费** |
| [OpenWallet Analysis](research/OPENWALLET-ANALYSIS.md) | 钱包集成、支付流程 | **充值入口** |

---

## 研究方法论文档

这些文档提供了具体技术的深度分析，在需要时查阅：

| 文档 | 技术领域 |
|------|----------|
| [addy-osmani-agent-skills-analysis.md](research/addy-osmani-agent-skills-analysis.md) | Agent Skill 设计模式 |
| [autoagent-meta-harness-analysis.md](research/autoagent-meta-harness-analysis.md) | Meta-Harness 架构 |
| [celer-analysis.md](research/celer-analysis.md) | 性能基准测试 |
| [coda-team-agent-analysis.md](research/coda-team-agent-analysis.md) | 团队 Agent 协作 |
| [fff-search-integration-analysis.md](research/fff-search-integration-analysis.md) | fff C FFI 搜索 |
| [gstack-skill-infrastructure-analysis.md](research/gstack-skill-infrastructure-analysis.md) | Skill 基础设施 |
| [mcp-zig-client-analysis.md](research/mcp-zig-client-analysis.md) | MCP Zig Client |
| [zbench-benchmark-testing-analysis.md](research/zbench-benchmark-testing-analysis.md) | Zig 基准测试 |
| [awesome-zig-analysis.md](research/awesome-zig-analysis.md) | Zig 生态概览 |

---

## 快速查询表

| 你正在做的任务 | 先读这些文档 |
|---------------|-------------|
| 修改 Agent Loop | TigerBeetle Patterns, NullClaw Lessons |
| 添加新工具 | NullClaw Lessons, TigerBeetle Patterns |
| 实现 PromptCache | Harness Four Pillars, Claude Code Prompt Analysis |
| 实现 WorkspaceContext | Harness Four Pillars, 06-agent-harness-upgrade |
| 实现 Coordinator Mode | SUBAGENT-ARCHITECTURE-AND-IMPLEMENTATION-PLAN |
| 实现 OpenCLI Skill | OpenCLI Analysis |
| 实现 AutoLab Critic | AutoLab Integration |
| 实现 TUI | Raze TUI Analysis, Ghostty Terminal |
| 实现 PayGo | Pay-As-You-Go AI |
| 生成新 Skill | Yoyo Evolve, Zig LLM Self-Evolution |
