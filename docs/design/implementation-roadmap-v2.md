# Kimiz 实现路线图 v2.0

**基于**: [Coding Agent Components Analysis](./coding-agent-components-analysis.md)  
**日期**: 2026-04-05  
**版本**: 2.0

---

## 概述

本路线图基于 Sebastian Raschka 的《Components of A Coding Agent》文章，对 Kimiz 的实现计划进行了调整。文章提出的六个核心组件为我们的架构设计提供了重要验证和补充。

---

## 六个核心组件映射

| 文章组件 | Kimiz 实现 | 状态 | 任务 |
|---------|-----------|------|------|
| 1. Live Repo Context | Workspace Context | 🟡 待实现 | TASK-FEAT-003 |
| 2. Prompt Cache | Prompt Cache | 🟡 待实现 | TASK-FEAT-004 |
| 3. Tools & Validation | Tool System | 🟢 基础存在 | 需增强 |
| 4. Context Reduction | Context Reducer | 🟡 待实现 | TASK-FEAT-005 |
| 5. Memory & Sessions | Memory System | 🟢 基础存在 | 需增强 |
| 6. Subagents | Subagent System | 🔴 未计划 | 可选 |

---

## 修订后的实施阶段

### 阶段 0: 紧急修复 (Week 1)
**目标**: 项目可编译、可运行

| 任务 | 优先级 | 预计 | 产出 |
|------|--------|------|------|
| URGENT-FIX-compilation-errors | P0 | 0.5h | 编译通过 |
| TASK-BUG-014-fix-cli-unimplemented | P0 | 6h | CLI 可用 |
| TASK-BUG-013-fix-page-allocator-abuse | P0 | 4h | 内存管理正确 |

**里程碑**: `kimiz repl` 可以启动并基本对话

---

### 阶段 1: 核心基础 (Week 2)
**目标**: 实现 Coding Agent 核心组件

| 任务 | 优先级 | 预计 | 组件 |
|------|--------|------|------|
| TASK-BUG-019-fix-getApiKey-memory-management | P1 | 2h | - |
| TASK-BUG-015-fix-silent-catch-empty | P1 | 3h | - |
| TASK-BUG-016-fix-tool-result-memory | P1 | 2h | - |
| TASK-BUG-017-fix-ai-client-reuse | P1 | 3h | - |
| TASK-FEAT-003-implement-workspace-context | P1 | 6h | Component 1 |
| TASK-FEAT-004-implement-prompt-cache | P1 | 5h | Component 2 |

**里程碑**: Agent 具备上下文感知能力，提示构建高效

---

### 阶段 2: 上下文管理 (Week 3)
**目标**: 实现长会话支持

| 任务 | 优先级 | 预计 | 组件 |
|------|--------|------|------|
| TASK-BUG-018-fix-http-streaming-implementation | P1 | 5h | - |
| TASK-FEAT-005-implement-context-reduction | P2 | 6h | Component 4 |
| TASK-FEAT-002-implement-skills-registration | P1 | 6h | Component 3 |
| 增强: Tool Validation | P1 | 3h | Component 3 |

**里程碑**: 支持 50+ 轮的长会话，工具系统完整

---

### 阶段 3: 用户体验 (Week 4)
**目标**: 完整的用户界面

| 任务 | 优先级 | 预计 | 产出 |
|------|--------|------|------|
| TASK-FEAT-001-implement-tui-complete | P1 | 12h | TUI 界面 |
| 增强: Session Persistence | P2 | 3h | Component 5 |
| TASK-BUG-020-fix-logger-thread-safety | P2 | 2h | - |

**里程碑**: TUI 可用，用户体验完整

---

### 阶段 4: 优化和文档 (Week 5)
**目标**: 代码质量和开发者体验

| 任务 | 优先级 | 预计 | 产出 |
|------|--------|------|------|
| TASK-REF-002-serialize-request-refactor | P2 | 4h | 代码质量 |
| TASK-DOCS-004-api-documentation | P2 | 4h | 文档 |
| T-009-e2e-tests | P1 | 4h | 测试覆盖 |
| 性能优化 | P2 | 4h | 性能 |

**里程碑**: 代码审查通过，文档完整，测试覆盖率高

---

### 阶段 5: 高级功能 (可选, Week 6+)
**目标**: 差异化功能

| 任务 | 优先级 | 预计 | 组件 |
|------|--------|------|------|
| Subagent System | P3 | 8h | Component 6 |
| Advanced Learning | P3 | 6h | - |
| Plugin System | P3 | 8h | - |

**里程碑**: 具备与 Claude Code/Codex 竞争的高级功能

---

## 关键设计决策

### 决策 1: 优先实现 Workspace Context

**理由**:
- 文章强调这是第一个组件
- 区分 Coding Agent 和通用 Chat 的关键
- 为后续组件提供基础数据

**影响**:
- 需要添加 Git 依赖
- 需要文件系统遍历
- 启动时可能有延迟（可缓存）

### 决策 2: Prompt Cache 在应用层实现

**理由**:
- 不同 Provider 的缓存机制不同
- 应用层控制更灵活
- 可以跨 Provider 复用逻辑

**影响**:
- Provider 实现更复杂
- 需要传递 Cache 状态
- 内存占用增加

### 决策 3: Context Reduction 定期执行

**理由**:
- 避免每轮都处理（性能）
- 保持近期上下文完整
- 可配置的策略

**影响**:
- 需要选择合适的时间点
- 可能影响对话连贯性
- 需要监控效果

---

## 与 v1.0 路线图的变化

### 新增任务

| 任务 | 原因 |
|------|------|
| TASK-FEAT-003 | 文章 Component 1 |
| TASK-FEAT-004 | 文章 Component 2 |
| TASK-FEAT-005 | 文章 Component 4 |

### 优先级调整

| 任务 | 原优先级 | 新优先级 | 原因 |
|------|---------|---------|------|
| Workspace Context | - | P1 | 核心组件 |
| Prompt Cache | - | P1 | 核心组件 |
| Context Reduction | - | P2 | 性能优化 |
| Skills | P1 | P1 | 保持不变 |
| TUI | P1 | P1 | 保持不变 |

### 时间线调整

| 阶段 | 原时间 | 新时间 | 变化 |
|------|--------|--------|------|
| 紧急修复 | Week 1 | Week 1 | 不变 |
| 核心基础 | Week 2 | Week 2 | 内容增加 |
| 上下文管理 | - | Week 3 | 新增阶段 |
| 用户体验 | Week 3 | Week 4 | 延后 |
| 优化文档 | Week 4 | Week 5 | 延后 |

**总时间**: 4周 → 5周（增加1周）

---

## 成功指标

### 技术指标

| 指标 | 目标 | 测量方式 |
|------|------|---------|
| 启动时间 | < 2s | 从命令输入到可交互 |
| 首 token 延迟 | < 3s | 用户输入到首响应 |
| 上下文构建时间 | < 100ms | Prompt Cache 命中时 |
| 长会话稳定性 | 100+ 轮 | 不崩溃、不混乱 |
| 内存占用 | < 500MB | 100 轮会话后 |

### 功能指标

| 指标 | 目标 | 验证方式 |
|------|------|---------|
| Git 信息收集 | 100% | 测试仓库 |
| 工具调用成功率 | > 95% | E2E 测试 |
| 会话恢复 | 100% | 手动测试 |
| TUI 可用性 | 完整 | 功能检查 |

### 用户体验指标

| 指标 | 目标 | 测量方式 |
|------|------|---------|
| 代码理解准确率 | > 80% | 人工评估 |
| 工具使用恰当性 | > 90% | 人工评估 |
| 响应相关性 | > 85% | 人工评估 |

---

## 风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| Workspace Context 复杂度高 | 中 | 高 | 分阶段实现，先基础后高级 |
| Prompt Cache 效果不明显 | 中 | 中 | 添加性能监控，必要时简化 |
| Context Reduction 影响体验 | 中 | 高 | 可配置策略，A/B 测试 |
| 时间线延期 | 高 | 中 | 明确 MVP 范围，高级功能可延后 |

---

## 参考资源

- [Coding Agent Components Analysis](./coding-agent-components-analysis.md)
- [Mini Coding Agent](https://github.com/rasbt/mini-coding-agent) - Python 参考实现
- [Claude Code Documentation](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview)
- [OpenAI Codex CLI](https://github.com/openai/codex)

---

## 附录: 任务依赖图

```
阶段 0: 紧急修复
├── URGENT-FIX-compilation-errors
│   └── TASK-BUG-014-fix-cli-unimplemented
│       └── TASK-BUG-013-fix-page-allocator-abuse
│           └── 阶段 1

阶段 1: 核心基础
├── TASK-BUG-019-fix-getApiKey-memory-management
├── TASK-BUG-015-fix-silent-catch-empty
├── TASK-BUG-016-fix-tool-result-memory
├── TASK-BUG-017-fix-ai-client-reuse
├── TASK-FEAT-003-implement-workspace-context
│   └── TASK-FEAT-004-implement-prompt-cache
│       └── 阶段 2

阶段 2: 上下文管理
├── TASK-BUG-018-fix-http-streaming-implementation
├── TASK-FEAT-005-implement-context-reduction
├── TASK-FEAT-002-implement-skills-registration
│   └── 阶段 3

阶段 3: 用户体验
├── TASK-FEAT-001-implement-tui-complete
│   └── 阶段 4

阶段 4: 优化和文档
├── TASK-REF-002-serialize-request-refactor
├── TASK-DOCS-004-api-documentation
├── T-009-e2e-tests
│   └── 阶段 5 (可选)

阶段 5: 高级功能 (可选)
├── Subagent System
├── Advanced Learning
└── Plugin System
```

---

**维护者**: Kimiz Team  
**审核状态**: 待审核  
**下次更新**: 阶段 1 完成后
