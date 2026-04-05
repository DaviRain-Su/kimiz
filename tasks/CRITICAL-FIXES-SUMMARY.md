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
| TASK-FEAT-016 | AI Slop 垃圾回收 | P2 | 6h | FEAT-014 |
| TASK-FEAT-017 | Agent Self-Review | P2 | 8h | FEAT-014, FEAT-015 |

---

## 总工作量估算

| 优先级 | 任务数 | 预计工时 |
|--------|--------|----------|
| P0 | 9 | 36.5h |
| P1 | 18 | 94h |
| P2 | 6 | 22h |
| **总计** | **33** | **152.5h** |

按每天 6 小时有效工作时间计算：约 **25 个工作日** (5 周)

**详细分解**: 见 `docs/07-kimiz-vision-b.md`

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

---

**下一步行动**:
1. 立即开始 TASK-BUG-021 (创建缺失工具)
2. 然后修复 TASK-BUG-022, TASK-BUG-023
3. 最后集成 Memory/Learning/Skills
