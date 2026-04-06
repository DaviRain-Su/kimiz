# 所有任务清单

**生成时间**: 2026-04-05  
**任务总数**: 30个 (原有17个 + 新增13个)

---

## 🚨 P0 - 阻塞级别（6个）

### 编译和基础功能

- [x] **TASK-INFRA-007**: 编译修复批量任务 (协调任务) ✅ 2026-04-05
  - 📁 `tasks/active/COMPILATION-FIX-QUICKSTART.md`
  - 🎯 所有编译错误已修复，`zig build` 和 `zig build test` 均通过

- [x] **TASK-BUG-026**: 修复 Zig 0.16 argsAlloc API 变更 ✅ 已在之前修复
  - 📄 `src/cli/root.zig` - 已使用 `std.process.Args`

- [x] **TASK-BUG-027**: 修复未使用的 task_type 参数 ✅ 已在之前修复
  - 📄 `src/learning/root.zig`

- [x] ~~**URGENT-FIX**: 修复编译错误~~ ✅ 被 TASK-INFRA-007 覆盖

- [ ] **TASK-BUG-013**: 修复 page_allocator 滥用
  - 📁 `tasks/backlog/bugfix/TASK-BUG-013-fix-page-allocator-abuse.md`
  - 📄 `src/ai/providers/*.zig`, `src/core/root.zig`
  - ⏱️ 4小时
  - 🎯 使用 Arena Allocator 替代 page_allocator
  - 🚫 **阻塞**: Provider 相关开发

- [ ] **TASK-BUG-014**: 修复 CLI 未实现
  - 📁 `tasks/backlog/bugfix/TASK-BUG-014-fix-cli-unimplemented.md`
  - 📄 `src/cli/root.zig`
  - ⏱️ 6小时
  - 🎯 实现完整的 CLI 参数解析和命令路由
  - 🚫 **阻塞**: 项目可用性

### TODO 任务 (代码扫描新增)

- [ ] **TASK-TODO-001**: 实现 AI Provider JSON 序列化
  - 📁 `tasks/backlog/bugfix/TASK-TODO-001-implement-ai-provider-json-serialization.md`
  - 📄 `src/ai/providers/google.zig`, `kimi.zig`, `anthropic.zig`
  - ⏱️ 6小时
  - 🎯 实现完整的请求/响应 JSON 序列化
  - 🚫 **阻塞**: AI API 调用

- [x] **TASK-TODO-002**: 实现完整 HTTP 客户端 ✅ 2026-04-05
  - 📄 `src/http.zig` - 已使用 Zig 0.16 `std.http.Client` 实现
  - 🎯 支持 POST JSON 和 SSE 流式读取
  - 📝 待优化: 连接池、重试延迟、Keep-Alive

---

## 🔴 P1 - 高优先级（9个）

### 内存和安全（4个）

- [ ] **TASK-BUG-015**: 修复静默错误处理
  - 📁 `tasks/backlog/bugfix/TASK-BUG-015-fix-silent-catch-empty.md`
  - 📄 `src/ai/providers/*.zig`, `src/agent/agent.zig`
  - ⏱️ 3小时
  - 🎯 替换 `catch {}` 为带日志的错误处理

- [ ] **TASK-BUG-016**: 修复工具结果内存浅拷贝
  - 📁 `tasks/backlog/bugfix/TASK-BUG-016-fix-tool-result-memory.md`
  - 📄 `src/agent/agent.zig:180-195`
  - ⏱️ 2小时
  - 🎯 实现深拷贝，避免悬空指针

- [ ] **TASK-BUG-019**: 修复 getApiKey 内存管理
  - 📁 `tasks/backlog/bugfix/TASK-BUG-019-fix-getApiKey-memory-management.md`
  - 📄 `src/core/root.zig`, `src/ai/models.zig`
  - ⏱️ 2小时
  - 🎯 添加 allocator 参数，明确所有权
  - 📝 **覆盖**: TASK-BUG-001

- [ ] **TASK-BUG-001**: ~~修复 getApiKey 内存泄漏~~
  - 📁 `tasks/backlog/bugfix/TASK-BUG-001-fix-getApiKey-memory-leak.md`
  - ⏱️ ~~1小时~~
  - 📝 **状态**: 被 TASK-BUG-019 覆盖，待删除

### 性能和功能（5个）

- [ ] **TASK-BUG-017**: 修复 AI 客户端重复创建
  - 📁 `tasks/backlog/bugfix/TASK-BUG-017-fix-ai-client-reuse.md`
  - 📄 `src/agent/agent.zig:130-165`
  - ⏱️ 3小时
  - 🎯 复用 AI 客户端，提升性能

- [ ] **TASK-BUG-018**: 修复 HTTP 伪流式处理
  - 📁 `tasks/backlog/bugfix/TASK-BUG-018-fix-http-streaming-implementation.md`
  - 📄 `src/http.zig:87-120`
  - ⏱️ 5小时
  - 🎯 实现真正的 SSE 流式读取
  - 📝 **覆盖**: TASK-BUG-008, TASK-BUG-009

- [ ] **TASK-FEAT-001**: 完整实现 TUI
  - 📁 `tasks/backlog/feature/TASK-FEAT-001-implement-tui-complete.md`
  - 📄 `src/tui/*.zig`
  - ⏱️ 12小时
  - 🎯 完整的消息显示、输入、滚动、主题

- [ ] **TASK-FEAT-002**: 实现 Skills 注册
  - 📁 `tasks/backlog/feature/TASK-FEAT-002-implement-skills-registration.md`
  - 📄 `src/skills/*.zig`
  - ⏱️ 6小时
  - 🎯 注册4个内置技能，集成到 Agent

- [ ] **T-009**: 编写 E2E 测试
  - 📁 `tasks/active/sprint-01-core/T-009-e2e-tests.md`
  - ⏱️ 4小时
  - 🎯 补充测试覆盖率

### TODO 任务 (代码扫描新增)

- [ ] **TASK-TODO-003**: 恢复 Workspace Git 上下文
  - 📁 `tasks/backlog/feature/TASK-TODO-003-restore-workspace-git-context.md`
  - 📄 `src/workspace/context.zig`
  - ⏱️ 4小时
  - 🎯 实现完整的 Git 仓库检测和信息收集

- [ ] **TASK-TODO-004**: 实现 Extension 系统核心功能
  - 📁 `tasks/backlog/feature/TASK-TODO-004-implement-extension-core.md`
  - 📄 `src/extension/root.zig`
  - ⏱️ 8小时
  - 🎯 实现 Extension 安装/卸载/加载

---

## 🟡 P2 - 中优先级（8个）

### 代码质量（3个）

- [ ] **TASK-BUG-020**: 修复 Logger 线程安全
  - 📁 `tasks/backlog/bugfix/TASK-BUG-020-fix-logger-thread-safety.md`
  - 📄 `src/utils/log.zig`
  - ⏱️ 2小时
  - 🎯 确保多线程日志安全

- [ ] **TASK-REF-002**: 重构请求序列化
  - 📁 `tasks/backlog/refactor/TASK-REF-002-serialize-request-refactor.md`
  - 📄 `src/ai/providers/*.zig`
  - ⏱️ 4小时
  - 🎯 使用 JSON 序列化替代手动拼接
  - 📝 **覆盖**: TASK-REF-001

- [ ] **TASK-REF-001**: ~~修复 Response.deinit allocator~~
  - 📁 `tasks/backlog/refactor/TASK-REF-001-fix-response-deinit-allocator.md`
  - ⏱️ ~~30分钟~~
  - 📝 **状态**: 被 TASK-REF-002 覆盖，待删除

### API 和 I/O（3个）

- [ ] **TASK-BUG-002**: ~~修复 Provider Authorization Header~~
  - 📁 `tasks/backlog/bugfix/TASK-BUG-002-fix-provider-auth-header-leak.md`
  - ⏱️ ~~1小时~~
  - 📝 **状态**: 被 TASK-BUG-013 覆盖，待删除

- [ ] **TASK-BUG-005**: ~~修复 CLI stdout writer API~~
  - 📁 `tasks/backlog/bugfix/TASK-BUG-005-fix-cli-stdout-api.md`
  - ⏱️ ~~1小时~~
  - 📝 **状态**: 被 TASK-BUG-014 覆盖，待删除

- [ ] **TASK-BUG-006**: ~~修复 stdin 逐字节读取~~
  - 📁 `tasks/backlog/bugfix/TASK-BUG-006-fix-stdin-reading.md`
  - ⏱️ ~~1小时~~
  - 📝 **状态**: 被 TASK-BUG-014 覆盖，待删除

### 其他（2个）

- [ ] **TASK-BUG-003**: 修复 URL 分配 defer 位置
  - 📁 `tasks/backlog/bugfix/TASK-BUG-003-fix-url-defer-position.md`
  - 📄 `src/ai/providers/openai.zig:98`
  - ⏱️ 30分钟

- [ ] **TASK-BUG-010**: 修复 Kimi Provider 控制流
  - 📁 `tasks/backlog/bugfix/TASK-BUG-010-fix-kimi-control-flow.md`
  - 📄 `src/ai/root.zig:87`
  - ⏱️ 30分钟

- [ ] **TASK-BUG-007**: ~~修复事件缓冲区分配~~
  - 📁 `tasks/backlog/bugfix/TASK-BUG-007-fix-event-buffer-allocation.md`
  - ⏱️ ~~30分钟~~
  - 📝 **状态**: 被 TASK-BUG-013 覆盖，待删除

- [ ] **TASK-BUG-008**: ~~修复 SSE 缓冲区溢出~~
  - 📁 `tasks/backlog/bugfix/TASK-BUG-008-fix-sse-buffer-overflow.md`
  - ⏱️ ~~1小时~~
  - 📝 **状态**: 被 TASK-BUG-018 覆盖，待删除

- [ ] **TASK-BUG-009**: ~~修复 StreamContext 未使用~~
  - 📁 `tasks/backlog/bugfix/TASK-BUG-009-fix-streamcontext-unused.md`
  - ⏱️ ~~30分钟~~
  - 📝 **状态**: 被 TASK-BUG-018 覆盖，待删除

---

## 🟢 P3 - 低优先级（6个）

### 文档（4个）

- [ ] **TASK-DOCS-004**: 完善 API 文档
  - 📁 `tasks/backlog/docs/TASK-DOCS-004-api-documentation.md`
  - ⏱️ 4小时
  - 🎯 为所有公共 API 添加文档注释

- [ ] **TASK-DOCS-001**: 修复任务编号冲突
  - 📁 `tasks/backlog/docs/TASK-DOCS-001-fix-task-numbering.md`
  - ⏱️ 30分钟

- [ ] **TASK-DOCS-002**: 更新 Sprint README
  - 📁 `tasks/backlog/docs/TASK-DOCS-002-update-sprint-readme.md`
  - ⏱️ 15分钟

- [ ] **TASK-DOCS-003**: 文档化内存所有权
  - 📁 `tasks/backlog/docs/TASK-DOCS-003-document-memory-ownership.md`
  - ⏱️ 15分钟

### 边缘情况（2个）

- [ ] **TASK-BUG-011**: 修复模型检测 'o' 前缀歧义
  - 📁 `tasks/backlog/bugfix/TASK-BUG-011-fix-model-detection-ambiguity.md`
  - 📄 `src/cli/root.zig:108`
  - ⏱️ 15分钟

- [ ] **TASK-BUG-012**: 修复 thinking level 静默回退
  - 📁 `tasks/backlog/bugfix/TASK-BUG-012-fix-thinking-level-fallback.md`
  - 📄 `src/cli/root.zig:98`
  - ⏱️ 15分钟

### TODO 任务 (代码扫描新增)

- [ ] **TASK-TODO-005**: 实现 Learning 系统高级功能
  - 📁 `tasks/backlog/feature/TASK-TODO-005-implement-learning-advanced.md`
  - 📄 `src/learning/root.zig`
  - ⏱️ 6小时
  - 🎯 实现代码变更学习和模型推荐

- [ ] **TASK-TODO-006**: 实现 Harness 高级功能
  - 📁 `tasks/backlog/feature/TASK-TODO-006-implement-harness-advanced.md`
  - 📄 `src/harness/context_truncation.zig`, `reasoning_trace.zig`
  - ⏱️ 8小时
  - 🎯 实现 AI 摘要和 Trace 完整序列化

---

## 新增任务汇总

### 本次审查新增（16个）

| 任务 | 优先级 | 类型 | 预计 | 描述 |
|------|--------|------|------|------|
| TASK-INFRA-007 | P0 | Infra | 30m | 编译修复批量任务 |
| TASK-BUG-026 | P0 | Bugfix | 15m | Zig 0.16 argsAlloc API |
| TASK-BUG-027 | P0 | Bugfix | 5m | 未使用参数修复 |
| TASK-BUG-013 | P0 | Bugfix | 4h | page_allocator 滥用 |
| TASK-BUG-014 | P0 | Bugfix | 6h | CLI 未实现 |
| TASK-BUG-015 | P1 | Bugfix | 3h | 静默错误处理 |
| TASK-BUG-016 | P1 | Bugfix | 2h | 工具结果内存浅拷贝 |
| TASK-BUG-017 | P1 | Bugfix | 3h | AI 客户端重复创建 |
| TASK-BUG-018 | P1 | Bugfix | 5h | HTTP 伪流式处理 |
| TASK-BUG-019 | P1 | Bugfix | 2h | getApiKey 内存管理 |
| TASK-FEAT-001 | P1 | Feature | 12h | 完整 TUI 实现 |
| TASK-FEAT-002 | P1 | Feature | 6h | Skills 注册 |
| TASK-BUG-020 | P2 | Bugfix | 2h | Logger 线程安全 |
| TASK-REF-002 | P2 | Refactor | 4h | 请求序列化重构 |
| TASK-DOCS-004 | P2 | Docs | 4h | API 文档完善 |

### 被覆盖的原有任务（8个）

| 原任务 | 被新任务 | 原因 |
|--------|----------|------|
| URGENT-FIX | TASK-BUG-026, TASK-BUG-027 | 更精确的编译错误修复 |
| TASK-BUG-001 | TASK-BUG-019 | 更全面的解决方案 |
| TASK-BUG-002 | TASK-BUG-013 | 统一内存管理修复 |
| TASK-BUG-004 | TASK-BUG-015 | 更全面的错误处理 |
| TASK-BUG-005, 006 | TASK-BUG-014 | CLI 整体修复 |
| TASK-BUG-007 | TASK-BUG-013 | 统一内存管理修复 |
| TASK-BUG-008, 009 | TASK-BUG-018 | 流式处理整体修复 |
| TASK-REF-001 | TASK-REF-002 | 更全面的重构 |

---

## 统计汇总

**任务数量**:
- 总计: 39个 (17原有 + 16新增 + 6个TODO任务)
- P0: 8个 (新增3个编译修复任务 + 2个TODO任务)
- P1: 11个 (新增2个TODO任务)
- P2: 10个 (新增2个TODO任务)
- P3: 6个

**按类型**:
- Bugfix: 23个 (12原有 + 10新增 + 1个TODO)
- Feature: 6个 (2原有 + 4个TODO)
- Refactor: 2个 (1原有 + 1新增)
- Docs: 4个 (3原有 + 1新增)
- Infra: 2个 (1原有 + 1个TODO)
- Test: 1个 (原有)

**预计总耗时**:
- P0: 24.83小时 (新增14小时 TODO任务)
- P1: 43小时 (新增4小时 TODO任务)
- P2: 26小时 (新增14小时 TODO任务)
- P3: 5.25小时
- **总计**: ~99小时

**TODO 任务汇总**:
- 扫描发现 24 个 TODO 注释
- 已创建 6 个跟踪任务
- 关键路径: TASK-TODO-002 (HTTP) → TASK-TODO-001 (JSON) → API 正常工作

---

## 推荐执行顺序

### 阶段 1: 紧急修复
1. ✅ TASK-INFRA-007 - 编译修复协调 **已完成 2026-04-05**
2. ✅ TASK-BUG-027 - 修复未使用参数 **已完成**
3. ✅ TASK-BUG-026 - 修复 argsAlloc API **已完成**
4. ✅ TASK-TODO-002 - 实现 HTTP Client **已完成 2026-04-05**
5. ⏳ TASK-BUG-014 - CLI 实现 (6小时)
6. ⏳ TASK-BUG-013 - page_allocator (4小时)

**目标**: 项目可编译、可运行
**状态**: 编译已通过，剩余 BUG-014 和 BUG-013 待完成

### 阶段 2: 核心稳定（本周）
4. ✅ TASK-BUG-019 - getApiKey (2小时)
5. ✅ TASK-BUG-015 - 错误处理 (3小时)
6. ✅ TASK-BUG-016 - 内存拷贝 (2小时)
7. ✅ TASK-BUG-017 - 客户端复用 (3小时)

**目标**: 核心功能稳定

### 阶段 3: 功能完善（下周）
8. ✅ TASK-BUG-018 - 流式处理 (5小时)
9. ✅ TASK-FEAT-002 - Skills (6小时)
10. ✅ TASK-FEAT-001 - TUI (12小时)

**目标**: 用户体验完整

### 阶段 4: 优化和文档（第4周）
11. ✅ TASK-BUG-020 - Logger (2小时)
12. ✅ TASK-REF-002 - 序列化重构 (4小时)
13. ✅ TASK-DOCS-004 - API 文档 (4小时)
14. ✅ 其他小任务

**目标**: 代码质量

---

## 关键路径

```
TASK-BUG-027 ─┐
              ├→ 编译成功 ✅ 已完成
TASK-BUG-026 ─┘
    ↓
TASK-TODO-002 (HTTP Client) ✅ 已完成
    ↓
TASK-BUG-014 (CLI) ← 当前
TASK-BUG-013 (内存管理)
    ↓
TASK-BUG-019 (API Key)
    ↓
TASK-BUG-018 (流式)
    ↓
TASK-FEAT-001 (TUI)
```

---

## 验收标准

所有任务完成后必须满足：

- [x] `zig build` 编译成功，无错误 ✅ 2026-04-05
- [x] `zig build test` 所有测试通过 ✅ 2026-04-05
- [ ] `kimiz repl` 可以正常对话
- [ ] `kimiz tui` 显示完整界面
- [ ] 流式响应实时显示
- [ ] 工具调用正常工作
- [ ] 无内存泄漏
- [ ] 代码审查通过
- [ ] 文档更新完成

---

## 参考文档

- [关键修复汇总](./CRITICAL-FIXES-SUMMARY.md)
- [Sprint 1 更新报告](./active/sprint-01-core/SPRINT-UPDATE-2026-04-05.md)
- [代码审查报告](../review-report.md)
- [TODO 任务汇总](./TODO-SUMMARY.md) ⭐ 新增

---

**下一步**: 编译已修复，继续 MVP Phase A (TASK-BUG-014 CLI 实现)

---

## 新增: Zig 0.16 迁移后任务 (2026-04-05)

Zig 0.16 迁移已完成，但有一些功能被简化或禁用，需要后续实现。

### 高优先级 - 核心功能恢复

| 任务 | 优先级 | 预计 | 目标 | 状态 |
|------|--------|------|------|------|
| TASK-INFRA-008 | P0 | 8h | 实现完整 HTTP Client | 阻塞 API 调用 |
| TASK-INFRA-009 | P1 | 2h | 实现环境变量访问 | 阻塞 API Key |
| TASK-INFRA-010 | P2 | 4h | 恢复 Workspace 上下文 | 阻塞 Workspace 功能 |

**说明**:
- **TASK-INFRA-008**: 当前使用简化版 HTTP Client，需要实现完整的 `std.http.Client` 集成
- **TASK-INFRA-009**: 环境变量访问被禁用，需要通过 `Init.environ_map` 实现
- **TASK-INFRA-010**: Workspace 上下文收集被禁用，需要使用 `std.Io` 恢复

### 实施建议

1. **立即开始** TASK-INFRA-008 (HTTP Client)
   - 这是最关键的任务，阻塞所有外部 API 调用
   - 需要研究 `std.Io.IoUring` 的使用

2. **然后执行** TASK-INFRA-009 (环境变量)
   - 相对简单，修改 `main` 函数接收 `Init` 参数
   - 传递 `environ_map` 到需要的地方

3. **最后执行** TASK-INFRA-010 (Workspace)
   - 依赖 TASK-INFRA-008 的 IoManager
   - 修改文件系统操作使用 `std.Io`

### HTTP Client 方案研究

**调研结果**:
- `http.zig` (karlseguin/http.zig) 是 **HTTP Server** 库，不适合
- 需要使用 Zig 0.16 标准库的 `std.http.Client`
- `std.http.Client` 需要 `std.Io` 实例

**推荐方案**: 使用 `std.http.Client` + `std.Io.IoUring`

---

## 新增: 架构简化任务 (2026-04-05)

基于与 Pi-Mono 的对比分析，决定简化架构以降低复杂度。

### 简化原则
- 极简核心，只保留最基本功能
- 高级功能通过 Extensions 实现
- 优先保证稳定性和性能

### 阶段 1: 核心简化

| 任务 | 优先级 | 预计 | 目标 | 代码变化 |
|------|--------|------|------|----------|
| TASK-REF-003 | P0 | 8h | 简化 Memory 系统 | -500 行 |
| TASK-REF-004 | P0 | 2h | 移除 Learning 系统 | -400 行 |
| TASK-REF-005 | P0 | 2h | 移除 Smart Routing | -300 行 |
| TASK-REF-006 | P1 | 4h | 简化 Workspace Context | -400 行 |
| TASK-FEAT-007 | P1 | 4h | 简化 Tools 系统 | -500 行 |

**阶段 1 小计**: 5个任务，20小时，-2100 行

### 阶段 2: Extension 系统

| 任务 | 优先级 | 预计 | 目标 |
|------|--------|------|------|
| TASK-FEAT-006 | P1 | 16h | 实现 Extension 系统 |

**阶段 2 小计**: 1个任务，16小时，+3000 行

### 简化后代码量预估

| 阶段 | 代码量 | 说明 |
|------|--------|------|
| 当前 | ~11,000 行 | 包含复杂功能 |
| 简化后 | ~10,000 行 | 结构更清晰 |
| 对比 Pi | ~30,000 行 | TypeScript |

### 被移除的功能

| 功能 | 原因 | 替代方案 |
|------|------|----------|
| 三层记忆 | 过度设计 | 单层 Session |
| Learning | 价值 unclear | 简单配置 |
| Smart Routing | 过度设计 | 手动选择 |
| 复杂 Workspace | 启动慢 | AGENTS.md |
| web_search/url_summary | 不核心 | Extension |
| Skills | 与 Extension 重复 | Extension |

### 详细文档

- [架构简化提案](./docs/design/simplified-architecture-proposal.md)
- [与 Pi-Mono 对比分析](./docs/design/kimiz-vs-pi-mono-comparison.md)
- [简化任务清单](./SIMPLIFICATION-TASKS.md)

### 实施建议

1. **立即开始** TASK-REF-003, REF-004, REF-005 (可并行)
2. **本周完成** 阶段 1 的所有任务
3. **下周开始** Extension 系统
4. **保持沟通** 定期评估简化效果

