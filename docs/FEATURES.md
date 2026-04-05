# KimiZ 特性清单

> **本文档记录 KimiZ 已实现的全部特性。**  
> 最后更新: 2026-04-06

---

## 状态图例

- ✅ **已上线** - 代码已实现并通过验证
- 🟡 **代码已提交，待验证** - 实现完成但当前因编译问题未实际跑通
- ⚪ **未开始** - 已规划但未实现

---

## Phase 0: 项目基础

| 特性 | 状态 | 说明 | 相关文件 |
|------|------|------|----------|
| 项目构建系统 | ✅ | `zig build` / `zig build test` / `zig build run` | `build.zig` |
| 模块化代码结构 | ✅ | core / ai / agent / cli / skills / utils / memory | `src/*/root.zig` |
| 多 Provider 支持 | ✅ | OpenAI, Anthropic, Google, Kimi, Fireworks | `src/ai/providers/*.zig` |
| 模型注册表 | ✅ | 8+ 模型定义，自动 API Key 获取，成本计算 | `src/ai/models.zig` |
| HTTP Client | ✅ | POST JSON / SSE 流式 / 重试机制 | `src/http.zig` |
| 核心类型系统 | ✅ | Message, Role, Request, Response, Tool 等 | `src/core/root.zig` |

> ⚠️ **注意**: Phase 0 当前因 Zig 0.16 API 回退问题导致无法编译，需要 `FIX-ZIG-015` 修复。

---

## Phase 1: 核心 Agent

| 特性 | 状态 | 说明 | 相关文件 |
|------|------|------|----------|
| Agent Loop | ✅ | 完整状态机（prompt → AI → tool call → execute → repeat） | `src/agent/agent.zig` |
| 事件系统 | ✅ | Message, ToolCall, ToolResult, Error 事件 | `src/agent/agent.zig` |
| 工具框架 | ✅ | AgentTool 统一封装，参数验证 | `src/agent/tool.zig` |
| 工具注册表 | ✅ | 动态注册/查询/搜索 | `src/agent/registry.zig` |
| 内置文件工具 | ✅ | read_file, write_file | `src/agent/tools/*.zig` |
| 内置搜索工具 | ✅ | glob, grep (via fff C FFI) | `src/agent/tools/*.zig` |
| 内置命令工具 | ✅ | bash (安全确认) | `src/agent/tools/bash.zig` |
| 内置网络工具 | ✅ | web_search, url_summary | `src/agent/tools/*.zig` |
| Skills 框架 | ✅ | SkillRegistry + 6 个内置 skill | `src/skills/root.zig` |
| 内置 Skills | ✅ | code_review, refactor, test_gen, doc_gen, debug | `src/skills/*.zig` |
| RTK Token 优化器 | ✅ | 作为 Skill 集成 | `src/skills/rtk_optimize.zig` |
| 内存管理修复 | ✅ | 消除 page_allocator 滥用，修复泄漏 | 各 Provider 文件 |

---

## Phase 2: 用户体验 (UX Foundation)

> 这是最近完成的一批功能（2026-04-05 密集提交），目标是补齐与官方 kimi-cli 的核心体验差距。

| 特性 | 状态 | 说明 | 相关文件 / Commit |
|------|------|------|-------------------|
| REPL 模式 | ✅ | 交互式对话、流式输出 | `src/cli/root.zig` |
| Slash 命令 | ✅ | `/help`, `/clear`, `/model`, `/yolo`, `/plan`, `/sessions`, `/resume`, `/title` | `src/cli/slash.zig` |
| 会话持久化 | ✅ | `--continue`, `--session <id>` 恢复，自动保存到 `~/.kimiz/sessions/` | `f7ee56a` |
| Shell 模式 | ✅ | `$` 前缀直接执行 shell 命令 | `0edec45` |
| Plan 模式 | ✅ | `/plan on` 切换只读探索模式，输出保存到 `plan.md` | `a371fc5` |
| YOLO 工具审批 | ✅ | 三级策略（safe/moderate/critical），`/yolo` 热切换 | `0edec45` |
| Git 工具集 | ✅ | `git_status`, `git_diff`, `git_log` 安全封装 | `88c0af4` |
| 默认 Kimi 模型 | ✅ | `kimi-k2.5` 通过 Anthropic-compatible API | `c540c22` |
| 错误恢复 | ✅ | 单次错误不崩溃，Agent Loop 继续运行 | `bf25819` |

---

## Phase 3: 子 Agent 系统 (Subagent)

| 特性 | 状态 | 说明 | 相关文件 / Commit |
|------|------|------|-------------------|
| SubAgent 核心模块 | ✅ | 深度限制、只读模式、工具过滤 | `src/agent/subagent.zig` |
| `delegate` 工具 | 🟡 | 已注册到主 Agent（`9a24161`），待编译恢复后验证 | `src/agent/agent.zig` |
| Git Worktree 隔离 | 🟡 | 子 Agent 独立工作区（`74c22ff`），待编译恢复后验证 | `src/utils/worktree.zig` |
| Named Sub-agents | ⚪ | YAML 角色配置（coder/reviewer/tester） | 规划中 |
| Coordinator Mode | ⚪ | 智能判断何时委派、结果聚合 | 规划中 |
| 并发批处理 | ⚪ | 多 subagent 并行执行 | 远期 |

---

## Phase 4: Harness 层

| 特性 | 状态 | 说明 |
|------|------|------|
| WorkspaceContext | ⚪ | Git 上下文 + 项目文档收集 |
| PromptCache | ⚪ | Stable prefix、分层 prompt、降低成本 |
| Context Truncation | ⚪ | 消息截断、工具输出压缩、历史去重 |
| AGENTS.md 知识库 | ⚪ | 结构化知识解析与加载 |

> 相关文档: `docs/06-agent-harness-upgrade.md`

---

## Phase 5: 可观测性与约束

| 特性 | 状态 | 说明 |
|------|------|------|
| Reasoning Trace | ⚪ | thought → action → observation 记录 |
| Resource Limits | ⚪ | 步数/成本/内存/超时限制 |
| Agent Linter | ⚪ | 约束规则检查 |
| Tool Approval 完善 | ⚪ | Ask/Session/Always 更细粒度策略 |

---

## Phase 6: 外部集成

| 特性 | 状态 | 说明 |
|------|------|------|
| AutoLab Critic | ⚪ | 外部评估器接入 Agent 迭代循环 |
| OpenCLI Skill | ⚪ | 调用外部 CLI adapter |
| Web Search 增强 | ⚪ | DuckDuckGo / 更稳定的搜索 |
| Lightpanda 浏览器 | ⚪ | 无头浏览器工具 |

---

## Phase 7: 高级自动化

| 特性 | 状态 | 说明 |
|------|------|------|
| AI Slop 垃圾回收 | ⚪ | 低质量生成检测与清理 |
| Agent Self-Review | ⚪ | 多 Agent 审查循环 |
| 自适应学习 | ✅ (框架) | `src/learning/root.zig` 已存在，待深度集成 |

---

## Phase 8: 平台化

| 特性 | 状态 | 说明 |
|------|------|------|
| Multi-Agent 编排器 | ⚪ | 任务分配、并行执行、结果聚合 |
| Smart Routing | ✅ (框架) | `src/ai/routing.zig` 已存在，待深度集成 |
| Extension 系统 | ⚪ | 动态加载扩展 |
| Skill 市场 | ⚪ | 共享和复用 Harness |

---

## Phase 9: 商业化

| 特性 | 状态 | 说明 |
|------|------|------|
| Pay-as-you-go | ⚪ | 余额策略、充值入口 |
| 企业级功能 | ⚪ | SSO、审计日志、团队管理 |

---

## Phase 10: 远期研究

| 特性 | 状态 | 说明 |
|------|------|------|
| WASM/WASI 沙箱 | ⚪ | 安全隔离高风险 skill |
| OS Namespace 隔离 | ⚪ | Linux 进程级沙箱 |
| 形式化验证 | ⚪ | TLA+ / Spark Ada 验证关键组件 |

---

## 快速统计

- ✅ 已上线: **25+** 项
- 🟡 代码已提交待验证: **2** 项 (delegate, git worktree)
- ⚪ 规划中: **30+** 项

**当前最大阻塞**: Zig 0.15.2 编译兼容性 (`FIX-ZIG-015`)
