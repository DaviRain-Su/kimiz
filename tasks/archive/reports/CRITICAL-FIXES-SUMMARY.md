# Kimiz 任务总览 (Claude Code 模式)

**更新日期**: 2026-04-05  
**架构**: 选项 B - 完整 Harness Agent (对标 Claude Code)  
**参考文档**: `docs/07-kimiz-vision-b.md`

---

## ⚠️ 架构决策 (2026-04-05)

**选择**: 选项 B - 完整 Harness Agent

**理由**: 对标 Claude Code，实现完整的 Agent Harness 系统

**保留功能**:
- ✅ 三层 Memory 系统
- ✅ Learning 系统
- ✅ Smart Routing
- ✅ Skills 系统

**新增功能** (基于论文):
- WorkspaceContext, PromptCache, ContextTruncation
- ReasoningTrace, ResourceLimits
- KnowledgeBase, AgentLinter, SelfReview
- Subagent Delegation

**废弃简化路线**:
- ❌ 单层 Memory → 保留三层
- ❌ 移除 Learning → 保留并增强
- ❌ 移除 Smart Routing → 保留

---

## 🔴 P0 - 阻塞性问题（必须立即解决）

### 1. 编译错误（已存在任务）
- **任务**: URGENT-FIX-compilation-errors
- **状态**: pending
- **问题**: 项目无法编译
- **预计**: 30分钟

### 2. page_allocator 滥用
- **任务**: TASK-BUG-013-fix-page-allocator-abuse
- **状态**: pending
- **问题**: 多处使用 page_allocator 进行小内存分配
- **影响**: 内存碎片，性能问题
- **预计**: 4小时
- **文件**: src/ai/providers/*.zig, src/core/root.zig

### 3. CLI 未实现
- **任务**: TASK-BUG-014-fix-cli-unimplemented
- **状态**: pending
- **问题**: `cli.run()` 直接返回 `error.NotImplemented`
- **影响**: 项目完全不可用
- **预计**: 6小时
- **文件**: src/cli/root.zig

### 4. 缺少工具文件 (代码审查发现) ⚠️ 新增
- **任务**: TASK-BUG-021-create-missing-tools
- **状态**: pending
- **问题**: `agent/root.zig` 导入 3 个不存在的文件
  - `glob.zig`
  - `web_search.zig`
  - `url_summary.zig`
- **影响**: 项目无法编译
- **预计**: 2小时
- **文件**: src/agent/root.zig

### 5. Anthropic 流式处理损坏 (代码审查发现) ⚠️ 新增
- **任务**: TASK-BUG-022-fix-anthropic-streaming
- **状态**: pending
- **问题**: `StreamContext.processLine()` 是空实现
- **影响**: Anthropic 流式响应完全损坏
- **预计**: 4小时
- **文件**: src/ai/providers/anthropic.zig

### 6. OpenAI tool_calls 序列化未完成 (代码审查发现) ⚠️ 新增
- **任务**: TASK-BUG-023-fix-openai-tool-calls
- **状态**: pending
- **问题**: `serializeRequest` 中 tool_calls 序列化是 TODO
- **影响**: Agent 工具调用功能不完整
- **预计**: 2小时
- **文件**: src/ai/providers/openai.zig

### 7. 测试编译失败 (最新代码审查) ⚠️ 新增
- **任务**: TASK-BUG-024-fix-test-compilation
- **状态**: pending
- **问题**: 12 个编译错误
  - `skills/root.zig:81` - undeclared 'SkillCategory'
  - `skills/test_gen.zig:103` - `.test` 保留关键字
  - 多个 unused function parameter
- **影响**: 测试无法运行
- **预计**: 1小时
- **文件**: src/skills/*.zig

### 8. registry.zig 死代码 (最新代码审查) ⚠️ 新增
- **任务**: TASK-BUG-025-clean-registry-dead-imports
- **状态**: pending
- **问题**: 导入已删除的文件
  - `tools/glob.zig`
  - `tools/web_search.zig`
  - `tools/url_summary.zig`
- **影响**: 潜在编译错误
- **预计**: 30分钟
- **文件**: src/agent/registry.zig

---

## 🟡 P1 - 高优先级问题

### 4. 静默错误处理
- **任务**: TASK-BUG-015-fix-silent-catch-empty
- **状态**: pending
- **问题**: 多处 `catch {}` 静默忽略错误
- **影响**: 调试困难、系统行为不可预测
- **预计**: 3小时
- **文件**: src/ai/providers/*.zig, src/agent/agent.zig

### 5. 工具结果内存浅拷贝
- **任务**: TASK-BUG-016-fix-tool-result-memory
- **状态**: pending
- **问题**: `continueFromToolResult` 浅拷贝可能导致悬空指针
- **影响**: 潜在的内存安全问题
- **预计**: 2小时
- **文件**: src/agent/agent.zig

### 6. AI 客户端重复创建
- **任务**: TASK-BUG-017-fix-ai-client-reuse
- **状态**: pending
- **问题**: 每次迭代创建新的 AI 客户端
- **影响**: 性能低下（无法复用连接）
- **预计**: 3小时
- **文件**: src/agent/agent.zig

### 7. HTTP 伪流式处理
- **任务**: TASK-BUG-018-fix-http-streaming-implementation
- **状态**: pending
- **问题**: 先完整收集响应再处理，不是真正的流式
- **影响**: 无法实现实时输出，大响应内存占用高
- **预计**: 5小时
- **文件**: src/http.zig

### 8. getApiKey 内存管理
- **任务**: TASK-BUG-019-fix-getApiKey-memory-management
- **状态**: pending
- **问题**: 函数签名不明确，调用者不知道需要释放内存
- **影响**: 内存泄漏风险
- **预计**: 2小时
- **文件**: src/core/root.zig, src/ai/models.zig, src/ai/providers/*.zig

### 9. 完整 TUI 实现
- **任务**: TASK-FEAT-001-implement-tui-complete
- **状态**: pending
- **问题**: TUI 只有骨架，功能不完整
- **影响**: 用户体验差
- **预计**: 12小时
- **文件**: src/tui/*.zig

### 10. Skills 注册和发现
- **任务**: TASK-FEAT-002-implement-skills-registration
- **状态**: pending
- **问题**: `registerBuiltinSkills` 是空实现
- **影响**: Skill-Centric 架构无法工作
- **预计**: 6小时
- **文件**: src/skills/*.zig, src/agent/root.zig

### 11. Memory 未集成到 Agent (代码审查发现) ⚠️ 新增
- **任务**: TASK-INTEG-001-integrate-memory
- **状态**: pending
- **问题**: 
  - MemoryManager 未添加到 Agent
  - 不记录工具执行到记忆
  - 不 recall 记忆用于上下文
- **影响**: Agent 无记忆能力
- **预计**: 4小时
- **文件**: src/agent/agent.zig

### 12. Learning 未集成到 Agent (代码审查发现) ⚠️ 新增
- **任务**: TASK-INTEG-002-integrate-learning
- **状态**: pending
- **问题**: 
  - LearningEngine 未添加到 Agent
  - 不追踪工具使用
  - 不记录模型性能
- **影响**: Agent 无自适应能力
- **预计**: 4小时
- **文件**: src/agent/agent.zig

### 13. Skills 未集成到 Agent (代码审查发现) ⚠️ 新增
- **任务**: TASK-INTEG-003-integrate-skills
- **状态**: pending
- **问题**: 
  - SkillEngine 未添加到 Agent
  - CLI 不暴露 skill 执行
  - Skills 无法被调用
- **影响**: Skills 系统形同虚设
- **预计**: 6小时
- **文件**: src/agent/agent.zig, src/cli/root.zig

### 14. CLI 未集成 Agent (最新代码审查) ⚠️ 新增
- **任务**: TASK-INTEG-004-integrate-cli-agent
- **状态**: pending
- **问题**: 
  - CLI 只是 echo 用户输入
  - 没有调用 Agent
  - 没有事件处理
- **影响**: 用户无法真正使用 Agent
- **预计**: 4小时
- **文件**: src/cli/root.zig

---

## 🟢 P2 - 中优先级问题

### 14. Logger 线程安全
- **任务**: TASK-BUG-020-fix-logger-thread-safety
- **状态**: pending
- **问题**: 全局 Logger 多线程访问可能有问题
- **影响**: 多线程场景下日志可能交错
- **预计**: 2小时
- **文件**: src/utils/log.zig

### 15. Memory recall 不完整 (代码审查发现) ⚠️ 新增
- **任务**: TASK-P2-001-complete-memory-recall
- **状态**: pending
- **问题**: recall() 只搜索 ShortTerm，未搜索 LongTerm
- **影响**: 记忆召回不完整
- **预计**: 2小时
- **文件**: src/memory/root.zig

### 16. Learning recommendModel 未实现 (代码审查发现) ⚠️ 新增
- **任务**: TASK-P2-002-complete-recommend-model
- **状态**: pending
- **问题**: `recommendModel()` 是空实现
- **影响**: 无法根据历史推荐最优模型
- **预计**: 4小时
- **文件**: src/learning/root.zig

### 17. Learning learnFromCodeChange 未实现 (代码审查发现) ⚠️ 新增
- **任务**: TASK-P2-003-complete-learn-from-code
- **状态**: pending
- **问题**: `learnFromCodeChange()` 是空实现
- **影响**: 无法从代码变更学习风格偏好
- **预计**: 6小时
- **文件**: src/learning/root.zig

### 18. 请求序列化重构
- **任务**: TASK-REF-002-serialize-request-refactor
- **状态**: pending
- **问题**: 手动 JSON 拼接冗长且容易出错
- **影响**: 代码可维护性差
- **预计**: 4小时
- **文件**: src/ai/providers/*.zig

### 19. API 文档完善
- **任务**: TASK-DOCS-004-api-documentation
- **状态**: pending
- **问题**: 公共 API 缺少文档
- **影响**: 开发者体验差
- **预计**: 4小时
- **文件**: 所有公共模块

---

## 现有 Backlog 任务（13个）

已存在的任务，需要评估是否与新任务重复：

| 任务 | 状态 | 与新任务关系 |
|------|------|-------------|
| TASK-BUG-001-fix-getApiKey-memory-leak | pending | 与 TASK-BUG-019 重复 |
| TASK-BUG-002-fix-provider-auth-header-leak | pending | 可能被 TASK-BUG-013 覆盖 |
| TASK-BUG-003-fix-url-defer-position | pending | 独立 |
| TASK-BUG-004-fix-silent-error-handling | pending | 与 TASK-BUG-015 重复 |
| TASK-BUG-005-fix-cli-stdout-api | pending | 被 TASK-BUG-014 覆盖 |
| TASK-BUG-006-fix-stdin-reading | pending | 被 TASK-BUG-014 覆盖 |
| TASK-BUG-007-fix-event-buffer-allocation | pending | 可能被 TASK-BUG-013 覆盖 |
| TASK-BUG-008-fix-sse-buffer-overflow | pending | 被 TASK-BUG-018 覆盖 |
| TASK-BUG-009-fix-streamcontext-unused | pending | 被 TASK-BUG-018 覆盖 |
| TASK-BUG-010-fix-kimi-control-flow | pending | 独立 |
| TASK-BUG-011-fix-model-detection-ambiguity | pending | 独立 |
| TASK-BUG-012-fix-thinking-level-fallback | pending | 独立 |
| TASK-REF-001-fix-response-deinit-allocator | pending | 可能被 TASK-BUG-013 覆盖 |

**建议**: 审查后合并重复任务，避免冗余工作。

---

## 修复路线图 (代码审查后更新)

### 阶段 1: 紧急修复 - 编译错误（本周）
1. TASK-BUG-024-fix-test-compilation (1h) ← **第一步！**
2. TASK-BUG-025-clean-registry-dead-imports (0.5h)
3. TASK-BUG-021-create-missing-tools (2h)
4. TASK-BUG-022-fix-anthropic-streaming (4h)
5. TASK-BUG-023-fix-openai-tool-calls (2h)

**目标**: 项目可以编译并基本运行

### 阶段 2: 核心集成（下周）
6. TASK-INTEG-004-integrate-cli-agent (4h) ← **让 Agent 可用**
7. TASK-INTEG-001-integrate-memory (4h)
8. TASK-INTEG-002-integrate-learning (4h)
9. TASK-INTEG-003-integrate-skills (6h)

**目标**: Agent 具备完整能力

### 阶段 2.5: LMDB 持久化层 (并行)
a. TASK-INFRA-001-evaluate-zig-lmdb (2h)
b. TASK-INFRA-002-lmdb-longterm-memory (8h)
c. TASK-INFRA-003-lmdb-session-store (4h)

**目标**: 替换 JSON 持久化，提升性能

### 阶段 3: Provider 修复（第3周）
10. TASK-BUG-014-fix-cli-unimplemented (6h)
11. TASK-BUG-013-fix-page-allocator-abuse (4h)
12. TASK-BUG-019-fix-getApiKey-memory-management (2h)
13. TASK-BUG-015-fix-silent-catch-empty (3h)
14. TASK-BUG-016-fix-tool-result-memory (2h)
15. TASK-BUG-017-fix-ai-client-reuse (3h)

**目标**: 核心功能稳定

### 阶段 4: 高级功能（第4-5周）
16. TASK-BUG-018-fix-http-streaming-implementation (5h)
17. TASK-FEAT-006~017 (Harness 功能，详见 docs/07-kimiz-vision-b.md)

**目标**: Claude Code 模式完成

---

## LMDB 持久化层升级任务 (新增)

基于 redb 研究评估，决定采用 **LMDB** 替代 JSON 文件持久化。

**研究结论**:
- ❌ redb (Rust): 需要 2-3 周 FFI 基础设施，风险高
- ❌ autozig: 仅 3 stars，不成熟
- ✅ **LMDB (C)**: 有成熟 Zig bindings，1 周可集成

**推荐 binding**: `nDimensional/zig-lmdb` (36 stars, 成熟稳定)

| 任务 ID | 功能 | 优先级 | 预计 | 依赖 |
|---------|------|--------|------|------|
| TASK-INFRA-001 | 评估并添加 zig-lmdb 依赖 | P1 | 2h | 无 |
| TASK-INFRA-002 | LongTermMemory 迁移到 LMDB | P1 | 8h | INFRA-001 |
| TASK-INFRA-003 | SessionStore 迁移到 LMDB | P2 | 4h | INFRA-002 |
| TASK-INFRA-004 | LMDB 性能测试与基准 | P2 | 4h | INFRA-002, INFRA-003 |
| TASK-INFRA-005 | LMDB 压缩支持 (zstd) | P3 | 6h | INFRA-002 |

**性能目标**:
| 操作 | 当前 (JSON) | 目标 (LMDB) |
|------|-------------|-------------|
| Memory 写入 | ~10ms | < 1ms |
| Memory 读取 | ~5ms | < 0.1ms |
| 启动加载 (10k条) | ~200ms | < 100ms |

---

## FFF 搜索工具集成 (新增)

基于 [fff.nvim](https://github.com/dmtrKovalenko/fff.nvim) 研究评估。

**核心优势**:
- 500k 文件 < 100ms 搜索
- 模糊匹配 + typo 纠错
- Frecency 排名（记忆常用文件）
- Git 感知（modified/staged 优先）
- MCP Server 已支持 Claude Code/OpenCode

**集成方案**: MCP Server (subprocess) - 最简方案

| 任务 ID | 功能 | 优先级 | 预计 | 依赖 |
|---------|------|--------|------|------|
| TASK-TOOL-001 | 集成 fff MCP Server | **P0** | 3h | fff-mcp 安装 |
| TASK-TOOL-002 | 集成 fff C FFI (可选高性能) | P2 | 8h | 需要源码 |

**性能对比**:
| 操作 | 当前 grep.zig | fff MCP |
|------|---------------|---------|
| 文件搜索 | O(n) 遍历 | < 100ms |
| 模糊搜索 | ❌ 无 | ✅ |
| typo 纠错 | ❌ 无 | ✅ |
| Frecency | ❌ 无 | ✅ LMDB |

---

## MCX 执行沙箱集成 (新增)

基于 [MCX](https://github.com/schizoidcock/mcx) 研究评估。

**核心价值**:
- **98% token 节省** - 过滤在沙箱内完成
- **变量持久化** ($var) - 工作记忆层
- **大文件沙箱存储** - 超过 50KB 自动 storeAs
- **内置 FFF** - mcx_find/mcx_grep 已集成
- **后台任务** - mcx_spawn 支持

**技术栈**: Bun 运行时 + TypeScript

**注意**: MCX 需要 Bun 运行时。如果需要完全自包含，考虑其他方案。

| 任务 ID | 功能 | 优先级 | 预计 | 依赖 |
|---------|------|--------|------|------|
| TASK-TOOL-003 | 集成 MCX MCP Server | **P0** | 2h | Bun + mcx-cli |

**Token 节省示例**:
```
传统工具调用:  Tool(read_file) → 50KB → Model
MCX 沙箱执行:  const data = await api.getInvoices(); return { count: data.length };
               → ~50 tokens (99% 节省)
```

---

## Obsidian Wiki 记忆层 (新增)

基于 Karpathy Idea File 方法论 + Obsidian Wiki 研究。

**核心思路**: 用 Obsidian Markdown 文件作为 Long-Term Memory，LMDB 做索引。

**优势**:
- 人类可读、可编辑
- 双链 `[[link]]` 建立记忆关联
- Obsidian 可直接读取
- 标签 + 全文搜索

**架构**:
```
memories/
├── {id}.md          # frontmatter + 内容
├── journals/        # 每日日志
└── .index/         # LMDB 索引
```

| 任务 ID | 功能 | 优先级 | 预计 | 依赖 |
|---------|------|--------|------|------|
| TASK-INFRA-006 | Obsidian Wiki Memory | P1 | 6h | INFRA-002 |

---

## Idea File 模板系统 (新增)

基于 Karpathy "分享想法而不是代码" 方法论。

**Idea File**: 用户填写 YAML 配置，Agent 自动配置自己。

**配置内容**:
- identity (Agent 身份)
- workflow (工作流程)
- tools (工具链偏好)
- memory (记忆组织)
- behavior (行为模式)
- knowledge (Obsidian 结构)
- skills (启用的技能)

| 任务 ID | 功能 | 优先级 | 预计 | 依赖 |
|---------|------|--------|------|------|
| TASK-FEAT-018 | Idea File 模板系统 | **P4** | 2h | INFRA-006 |

---

## Agent Harness 升级任务 (新增)

基于 Raschka《Components of A Coding Agent》+ Nathan Flurry (agentOS) 洞察

| 任务 ID | 功能 | 优先级 | 预计 | 依赖 |
|---------|------|--------|------|------|
| TASK-FEAT-006 | WorkspaceContext (Git 上下文) | P0 | 4h | 无 |
| TASK-FEAT-007 | Prompt Caching | P0 | 6h | FEAT-006 |
| TASK-FEAT-008 | Context Truncation | P0 | 3h | FEAT-007 |
| TASK-FEAT-009 | Tool Approval 审批 | P1 | 4h | FEAT-006 |
| TASK-FEAT-010 | Session Persistence | P2 | 6h | FEAT-008 |
| TASK-FEAT-011 | Subagent Delegation | P2 | 8h | FEAT-010 |
| TASK-FEAT-012 | Reasoning Trace | P1 | 6h | FEAT-010 |
| TASK-FEAT-013 | Resource Limits | P1 | 4h | FEAT-012 |

### Agent Engineering (论文新增)

| 任务 ID | 功能 | 优先级 | 预计 | 依赖 |
|---------|------|--------|------|------|
| TASK-FEAT-014 | AGENTS.md 结构化知识 | **P0** | 8h | FEAT-006 |
| TASK-FEAT-015 | Agent Linter 约束 | **P0** | 6h | FEAT-006 |

### Memory 增强 (基于 Letta/Sarah Wooders 观点)

基于 Sarah Wooders (Letta CTO) "记忆是 Harness 核心" 观点。

| 任务 ID | 功能 | 优先级 | 预计 | 依赖 |
|---------|------|--------|------|------|
| TASK-FEAT-019 | Context Constitution (上下文宪法) | P1 | 4h | FEAT-008 |
| TASK-FEAT-020 | AI 驱动上下文摘要 | P1 | 8h | FEAT-019 |
| TASK-FEAT-016 | AI Slop 垃圾回收 | P2 | 6h | FEAT-014 |
| TASK-FEAT-017 | Agent Self-Review | P2 | 8h | FEAT-014, FEAT-015 |

### Meta-Harness 自我进化 (基于 Harrison Chase 观点)

基于 Harrison Chase (LangChain) "Harness 层学习" 观点 + Meta-Harness 论文。

**核心**: Agent 能根据 traces/evals 自动迭代优化 harness 自身配置。

| 任务 ID | 功能 | 优先级 | 预计 | 依赖 |
|---------|------|--------|------|------|
| TASK-FEAT-021 | Meta-Harness 自我进化 | P1 | 16h | FEAT-012, FEAT-020 |

---

## 总工作量估算

| 优先级 | 任务数 | 预计工时 |
|--------|--------|----------|
| P0 | 12 | 44.5h |
| P1 | 24 | 138h |
| P2 | 12 | 38h |
| P3 | 1 | 6h |
| P4 | 1 | 2h |
| **总计** | **50** | **228.5h** |

## 新增: Harness 四大支柱任务 (2026-04-05)

基于 Nyk 深度研究 (docs/research/harness-four-pillars-nyk-analysis.md)，新增 18 个任务完善 Harness 系统：

### Pillar 1: Context Architecture
- **FEAT-022**: Token Budget Monitor (超 40% 报警)
- **FEAT-023**: Content Expiration (每月清理)

### Pillar 2: Agent Specialization  
- **FEAT-024**: Specialist Subagent (重构为专业分工)

### Pillar 3: Persistent Memory
- **FEAT-025**: Persistent File Memory (文件系统记忆)

### Pillar 4: Structured Execution
- **FEAT-026**: Execution State Machine (强制流程)
- **FEAT-027**: Guardrail Hierarchy (四层护栏)

**详细规划**: 见 `tasks/FOUR-PILLARS-TASKS.md`

---

## 参考文档

- `docs/07-kimiz-vision-b.md`
- `docs/06-agent-harness-upgrade.md`
- `docs/research/harness-four-pillars-nyk-analysis.md` (四大支柱研究)
- `docs/research/fff-search-integration-analysis.md` (fff 搜索工具研究)
- `docs/research/autoagent-meta-harness-analysis.md` (AutoAgent Meta-Harness)
- `docs/research/lightpanda-browser-analysis.md` (Lightpanda 浏览器分析)
- `docs/research/zpdf-pdf-processing-analysis.md` (zpdf PDF 处理分析)
- `docs/research/odiff-image-diff-analysis.md` (odiff 图像差异分析)
- `docs/research/zmx-zig-matrix-analysis.md` (zmx Matrix 聊天分析)
- `docs/research/zlob-storage-analysis.md` (zlob 存储工具分析)
- `docs/research/zbench-benchmark-testing-analysis.md` (zBench 基准测试分析)
- `docs/research/yazap-cli-parser-analysis.md` (yazap CLI 解析分析)
- `docs/research/mcp-zig-client-analysis.md` (mcp.zig MCP 客户端分析)
- `docs/research/raze-tui-analysis.md` (raze-tui TUI 分析)
- `docs/research/kiesel-js-engine-analysis.md` (Kiesel JS 引擎分析)
- `docs/research/kiesel-runtime-analysis.md` (Kiesel Runtime 分析)
- `docs/research/celer-analysis.md` (Celer 项目分析)
- `docs/research/zg-zig-tool-analysis.md` (zg 项目分析)
- `docs/research/ghostty-terminal-analysis.md` (Ghostty 终端分析)
- `docs/research/river-wayland-analysis.md` (River Wayland 分析)
- `docs/research/ly-display-manager-analysis.md` (Ly 登录管理器分析)
- `tasks/FOUR-PILLARS-TASKS.md` (四大支柱任务汇总)
- `tasks/WEB-SEARCH-TOOLS-ROADMAP.md` (Web 搜索工具路线图)
---

## 关键路径

```
TASK-BUG-021 (创建缺失工具) ← 第一步！
    ↓
TASK-BUG-022 (Anthropic 流式)
    ↓
TASK-BUG-023 (OpenAI tool_calls)
    ↓
TASK-INTEG-001 (Memory 集成)
    ↓
TASK-INTEG-002 (Learning 集成)
    ↓
TASK-INTEG-003 (Skills 集成)
```

**LMDB 路径 (可并行)**:
```
TASK-INFRA-001 (添加 zig-lmdb 依赖)
    ↓
TASK-INFRA-002 (LongTermMemory LMDB)
    ↓
TASK-INFRA-003 (SessionStore LMDB)
    ↓
TASK-INFRA-004 (性能测试)
```

**MCP 路径 (高优先级)**:
```
TASK-INFRA-008 (集成 mcp.zig 客户端)               [P1]
    ↓
更新 TASK-TOOL-001/003/005 (使用统一 MCP 管理)
    ↓
支持所有 MCP Servers (fff, browser, mcx, ...)
```

**工具路径 (可并行)**:
```
搜索/浏览工具:
├── TASK-TOOL-004 (实现 web_search - DuckDuckGo)     [P1]
├── TASK-TOOL-005 (集成 Lightpanda Browser)          [P2]
├── TASK-TOOL-001 (集成 fff MCP Server)              [P0]
└── TASK-TOOL-002 (可选: fff C FFI 高性能)           [P2]

文档处理工具 (Phase 2):
├── TASK-TOOL-006 (集成 zpdf PDF 处理)               [P2]
└── (考虑: image, office 等)

MCX 沙箱:
└── TASK-TOOL-003 (集成 MCX MCP Server)              [P1]
    ↓
验证 Bun 运行时依赖
```

**Obsidian 路径 (可并行)**:
```
TASK-INFRA-006 (Obsidian Wiki Memory)
    ↓
TASK-FEAT-018 (Idea File 模板)
```

---

**下一步行动**:
1. 立即开始 TASK-BUG-021 (创建缺失工具)
2. 然后修复 TASK-BUG-022, TASK-BUG-023
3. 最后集成 Memory/Learning/Skills
4. 同时可以并行开始:
   - TASK-INFRA-001 (LMDB 依赖评估)
   - TASK-TOOL-001 (fff MCP Server 集成)
   - TASK-TOOL-003 (MCX MCP Server 集成)
   - TASK-INFRA-006 (Obsidian Wiki Memory)
