# Kimiz 任务清单 (清理后)

**日期**: 2026-04-05  
**状态**: 已清理重复和过时任务  
**总任务数**: 45 (从 78 减少到 45)

---

## 清理摘要

### 已归档任务 (33个)

| 类别 | 数量 | 说明 |
|------|------|------|
| Superseded | 10 | 被新架构替代 |
| Duplicate | 14 | 重复任务 |
| Obsolete | 9 | 基于已移除功能 |

### 关键决策

1. ✅ **简化架构** - 向 Pi-Mono 看齐
2. ✅ **Extension 替代 Skills**
3. ✅ **单层 Session 替代三层记忆**
4. ✅ **手动选择替代 Smart Routing**

---

## 当前任务结构

### 🔴 P0 - 阻塞级别 (12个)

#### Bugfix (9个)

- [ ] **URGENT-FIX**: 修复编译错误
  - 📁 `backlog/bugfix/URGENT-FIX-compilation-errors.md`
  - ⏱️ 0.5h

- [ ] **TASK-BUG-013**: 修复 page_allocator 滥用
  - 📁 `backlog/bugfix/TASK-BUG-013-fix-page-allocator-abuse.md`
  - 📄 多处文件
  - ⏱️ 4h

- [ ] **TASK-BUG-014**: 修复 CLI 未实现
  - 📁 `backlog/bugfix/TASK-BUG-014-fix-cli-unimplemented.md`
  - 📄 `src/cli/root.zig`
  - ⏱️ 6h

- [ ] **TASK-BUG-015**: 修复静默错误处理
  - 📁 `backlog/bugfix/TASK-BUG-015-fix-silent-catch-empty.md`
  - 📄 多个 providers
  - ⏱️ 3h

- [ ] **TASK-BUG-016**: 修复工具结果内存浅拷贝
  - 📁 `backlog/bugfix/TASK-BUG-016-fix-tool-result-memory.md`
  - 📄 `src/agent/agent.zig`
  - ⏱️ 2h

- [ ] **TASK-BUG-017**: 修复 AI 客户端重复创建
  - 📁 `backlog/bugfix/TASK-BUG-017-fix-ai-client-reuse.md`
  - 📄 `src/agent/agent.zig`
  - ⏱️ 3h

- [ ] **TASK-BUG-018**: 修复 HTTP 伪流式处理
  - 📁 `backlog/bugfix/TASK-BUG-018-fix-http-streaming-implementation.md`
  - 📄 `src/http.zig`
  - ⏱️ 5h

- [ ] **TASK-BUG-019**: 修复 getApiKey 内存管理
  - 📁 `backlog/bugfix/TASK-BUG-019-fix-getApiKey-memory-management.md`
  - 📄 `src/core/root.zig`
  - ⏱️ 2h

- [ ] **TASK-BUG-020**: 修复 Logger 线程安全
  - 📁 `backlog/bugfix/TASK-BUG-020-fix-logger-thread-safety.md`
  - 📄 `src/utils/log.zig`
  - ⏱️ 2h

#### Refactor (3个)

- [ ] **TASK-REF-003**: 简化 Memory 系统
  - 📁 `backlog/refactor/TASK-REF-003-simplify-memory-system.md`
  - ⏱️ 8h
  - 🎯 三层 → 单层 Session

- [ ] **TASK-REF-004**: 移除 Learning 系统
  - 📁 `backlog/refactor/TASK-REF-004-remove-learning-system.md`
  - ⏱️ 2h
  - 🎯 完全移除

- [ ] **TASK-REF-005**: 移除 Smart Routing
  - 📁 `backlog/refactor/TASK-REF-005-remove-smart-routing.md`
  - ⏱️ 2h
  - 🎯 完全移除

---

### 🟡 P1 - 高优先级 (14个)

#### Refactor (2个)

- [ ] **TASK-REF-006**: 简化 Workspace Context
  - 📁 `backlog/refactor/TASK-REF-006-simplify-workspace-context.md`
  - ⏱️ 4h
  - 🎯 AGENTS.md + Git 信息

- [ ] **TASK-REF-002**: 重构请求序列化
  - 📁 `backlog/refactor/TASK-REF-002-serialize-request-refactor.md`
  - ⏱️ 4h
  - 🎯 手动 JSON → 序列化

#### Feature (8个)

- [ ] **TASK-FEAT-006**: 实现 Extension 系统
  - 📁 `backlog/feature/TASK-FEAT-006-implement-extension-system.md`
  - ⏱️ 16h
  - 🎯 WASM 运行时

- [ ] **TASK-FEAT-007**: 简化 Tools 系统
  - 📁 `backlog/feature/TASK-FEAT-007-simplify-tools.md`
  - ⏱️ 4h
  - 🎯 7个 → 5个工具

- [ ] **TASK-FEAT-001**: 完整实现 TUI
  - 📁 `backlog/feature/TASK-FEAT-001-implement-tui-complete.md`
  - ⏱️ 12h

- [ ] **TASK-FEAT-006-workspace**: 实现 Workspace Context
  - 📁 `backlog/feature/TASK-FEAT-006-workspace-context.md`
  - ⏱️ 4h
  - 🎯 Git + AGENTS.md

- [ ] **TASK-FEAT-007-prompt**: 实现 Prompt Caching
  - 📁 `backlog/feature/TASK-FEAT-007-prompt-caching.md`
  - ⏱️ 6h

- [ ] **TASK-FEAT-008**: 实现 Context Truncation
  - 📁 `backlog/feature/TASK-FEAT-008-context-truncation.md`
  - ⏱️ 3h

- [ ] **TASK-FEAT-009**: 实现 Tool Approval
  - 📁 `backlog/feature/TASK-FEAT-009-tool-approval.md`
  - ⏱️ 4h

- [ ] **TASK-FEAT-010**: 实现 Session Persistence
  - 📁 `backlog/feature/TASK-FEAT-010-session-persistence.md`
  - ⏱️ 4h

#### Active Sprint (4个)

- [ ] **T-003**: HTTP 客户端
  - 📁 `active/sprint-01-core/T-003-http-client.md`
  - 🟡 blocked

- [ ] **T-005**: OpenAI Provider
  - 📁 `active/sprint-01-core/T-005-openai-provider.md`
  - 🟡 blocked

- [ ] **T-006**: CLI 框架
  - 📁 `active/sprint-01-core/T-006-cli-framework.md`
  - 🟡 blocked

- [ ] **T-009**: E2E 测试
  - 📁 `active/sprint-01-core/T-009-e2e-tests.md`
  - 🔴 pending

---

### 🟢 P2 - 中优先级 (12个)

#### Bugfix (6个)

- [ ] **TASK-BUG-001**: 修复 getApiKey 内存泄漏
  - 📁 `backlog/bugfix/TASK-BUG-001-fix-getApiKey-memory-leak.md`
  - ⏱️ 1h
  - 📝 可能被 BUG-019 覆盖

- [ ] **TASK-BUG-002**: 修复 Provider Auth Header
  - 📁 `backlog/bugfix/TASK-BUG-002-fix-provider-auth-header-leak.md`
  - ⏱️ 1h

- [ ] **TASK-BUG-003**: 修复 URL defer 位置
  - 📁 `backlog/bugfix/TASK-BUG-003-fix-url-defer-position.md`
  - ⏱️ 0.5h

- [ ] **TASK-BUG-004**: 修复静默错误处理
  - 📁 `backlog/bugfix/TASK-BUG-004-fix-silent-error-handling.md`
  - ⏱️ 2h
  - 📝 与 BUG-015 重复

- [ ] **TASK-BUG-005**: 修复 CLI stdout API
  - 📁 `backlog/bugfix/TASK-BUG-005-fix-cli-stdout-api.md`
  - ⏱️ 1h
  - 📝 可能被 BUG-014 覆盖

- [ ] **TASK-BUG-006**: 修复 stdin 读取
  - 📁 `backlog/bugfix/TASK-BUG-006-fix-stdin-reading.md`
  - ⏱️ 1h
  - 📝 可能被 BUG-014 覆盖

#### Refactor (1个)

- [ ] **TASK-REF-001**: 修复 Response deinit allocator
  - 📁 `backlog/refactor/TASK-REF-001-fix-response-deinit-allocator.md`
  - ⏱️ 0.5h

#### Feature (3个)

- [ ] **TASK-FEAT-011**: Subagent Delegation
  - 📁 `backlog/feature/TASK-FEAT-011-subagent-delegation.md`
  - ⏱️ 8h
  - 📝 后期通过 Extension 实现

- [ ] **TASK-FEAT-012**: Reasoning Trace
  - 📁 `backlog/feature/TASK-FEAT-012-reasoning-trace.md`
  - ⏱️ 4h

- [ ] **TASK-FEAT-013**: Resource Limits
  - 📁 `backlog/feature/TASK-FEAT-013-resource-limits.md`
  - ⏱️ 3h

#### Docs (2个)

- [ ] **TASK-DOCS-001**: 修复任务编号
  - 📁 `backlog/docs/TASK-DOCS-001-fix-task-numbering.md`
  - ⏱️ 0.5h

- [ ] **TASK-DOCS-002**: 更新 Sprint README
  - 📁 `backlog/docs/TASK-DOCS-002-update-sprint-readme.md`
  - ⏱️ 0.25h

- [ ] **TASK-DOCS-004**: API 文档
  - 📁 `backlog/docs/TASK-DOCS-004-api-documentation.md`
  - ⏱️ 4h

---

### 🔵 P3 - 低优先级 (7个)

#### Bugfix (1个)

- [ ] **TASK-BUG-010**: 修复 Kimi 控制流
  - 📁 `backlog/bugfix/TASK-BUG-010-fix-kimi-control-flow.md`
  - ⏱️ 0.5h

#### Feature (6个)

- [ ] **TASK-FEAT-014**: Knowledge Base
  - 📁 `backlog/feature/TASK-FEAT-014-knowledge-base.md`
  - ⏱️ 6h

- [ ] **TASK-FEAT-015**: Agent Linter
  - 📁 `backlog/feature/TASK-FEAT-015-agent-linter.md`
  - ⏱️ 4h

- [ ] **TASK-FEAT-016**: SLOP Collector
  - 📁 `backlog/feature/TASK-FEAT-016-slop-collector.md`
  - ⏱️ 3h

- [ ] **TASK-FEAT-003**: Register Builtin Skills
  - 📁 `backlog/feature/TASK-FEAT-003-register-builtin-skills.md`
  - ⏱️ 4h
  - 📝 将被 Extension 替代

- [ ] **TASK-FEAT-005**: Implement TUI Mode
  - 📁 `backlog/feature/TASK-FEAT-005-implement-tui-mode.md`
  - ⏱️ 8h
  - 📝 与 FEAT-001 重复

---

## 已归档任务

### Superseded (10个)

```
archived/superseded/
├── TASK-FEAT-004-complete-learning-system.md
├── TASK-FEAT-003-register-builtin-skills.md
├── TASK-DOCS-003-document-memory-ownership.md
├── TASK-BUG-007-fix-event-buffer-allocation.md
├── TASK-BUG-011-fix-model-detection-ambiguity.md
├── TASK-BUG-012-fix-thinking-level-fallback.md
└── (4个 active sprint 中的已标记)
```

### Duplicate (14个)

```
archived/duplicate/
├── TASK-FEAT-003-implement-workspace-context.md
├── TASK-FEAT-004-implement-prompt-cache.md
├── TASK-FEAT-005-implement-context-reduction.md
├── TASK-FEAT-002-implement-skills-registration.md
├── TASK-BUG-018-fix-skill-category-keyword.md
├── TASK-BUG-019-fix-tool-calls-serialization.md
├── TASK-BUG-020-fix-http-streaming.md
└── TASK-BUG-021-fix-skill-category-keyword.md
```

---

## 实施路线图

### 阶段 1: 紧急修复 (Week 1)

**目标**: 项目可编译、可运行

```
P0 Bugfix (并行):
├── URGENT-FIX (0.5h)
├── BUG-013 (4h)
├── BUG-014 (6h)
├── BUG-015 (3h)
├── BUG-016 (2h)
├── BUG-017 (3h)
├── BUG-018 (5h)
├── BUG-019 (2h)
└── BUG-020 (2h)

P0 Refactor (并行):
├── REF-003 (8h) - Memory 简化
├── REF-004 (2h) - Learning 移除
└── REF-005 (2h) - Routing 移除
```

### 阶段 2: 核心功能 (Week 2)

**目标**: 核心功能稳定

```
P1 Refactor:
├── REF-006 (4h) - Workspace 简化
└── REF-002 (4h) - 序列化重构

P1 Feature:
├── FEAT-007 (4h) - Tools 简化
├── FEAT-006-workspace (4h)
├── FEAT-007-prompt (6h)
└── FEAT-008 (3h)
```

### 阶段 3: Extension 系统 (Week 3-4)

**目标**: 可扩展架构

```
P1 Feature:
├── FEAT-006-extension (16h)
└── FEAT-001-tui (12h)
```

---

## 关键指标

| 指标 | 数值 |
|------|------|
| 总任务数 | 45 |
| P0 任务 | 12 |
| P1 任务 | 14 |
| P2 任务 | 12 |
| P3 任务 | 7 |
| 预计总工时 | ~120h |
| 预计周期 | 4-5 周 |

---

## 参考文档

- [冲突分析报告](./TASK-CONFLICT-ANALYSIS.md)
- [简化任务清单](./SIMPLIFICATION-TASKS.md)
- [架构简化提案](../docs/design/simplified-architecture-proposal.md)
- [Pi-Mono 对比分析](../docs/design/kimiz-vs-pi-mono-comparison.md)

---

**维护者**: Kimiz Team  
**最后更新**: 2026-04-05  
**状态**: 已清理，待执行
