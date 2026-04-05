# 关键修复任务汇总

**生成日期**: 2026-04-05  
**来源**: 项目审查报告 + Code Review

---

## 🚨 P0 - 阻塞级别（必须立即修复）

### URGENT-FIX: 编译错误修复
**位置**: `tasks/backlog/bugfix/URGENT-FIX-compilation-errors.md`  
**预计**: 30分钟  
**影响**: 项目完全不可用

**问题**:
1. `src/utils/config.zig:250` - 函数调用缺少命名空间
2. `src/http.zig:91` - ArrayList.writer() API 使用错误

**修复**:
```zig
// config.zig
- const key = getApiKey(&config, "openai");
+ const key = ConfigManager.getApiKey(&config, "openai");

// http.zig
- .response_writer = body_list.writer(self.allocator),
+ .response_writer = body_list.writer(),
```

---

## 🔴 P1 - 高优先级（本周内修复）

### 内存泄漏问题（3个任务）

#### TASK-BUG-001: getApiKey 内存泄漏
**位置**: `tasks/backlog/bugfix/TASK-BUG-001-fix-getApiKey-memory-leak.md`  
**文件**: `src/core/root.zig:279`  
**预计**: 1小时

使用 `std.process.getEnvVarOwned` 但从不释放内存。

#### TASK-BUG-002: Provider Authorization Header 内存泄漏
**位置**: `tasks/backlog/bugfix/TASK-BUG-002-fix-provider-auth-header-leak.md`  
**文件**: 
- `src/ai/providers/openai.zig:75`
- `src/ai/providers/kimi.zig:131`

**预计**: 1小时

Authorization header 使用 allocPrint 但从不释放。

#### TASK-BUG-003: URL 分配 defer 位置错误
**位置**: `tasks/backlog/bugfix/TASK-BUG-003-fix-url-defer-position.md`  
**文件**:
- `src/ai/providers/openai.zig:98`
- `src/ai/providers/google.zig:111`

**预计**: 30分钟

defer 在 try 之后，错误路径会泄漏。

### 任务系统问题（2个任务）

#### TASK-DOCS-001: 修复任务编号冲突
**位置**: `tasks/backlog/docs/TASK-DOCS-001-fix-task-numbering.md`  
**预计**: 30分钟

T-006, T-009, T-010 编号重复。

#### TASK-DOCS-002: 更新 Sprint README
**位置**: `tasks/backlog/docs/TASK-DOCS-002-update-sprint-readme.md`  
**预计**: 15分钟

README 显示所有任务 pending，但实际多个已完成。

### 测试覆盖率

#### T-009: E2E 测试
**位置**: `tasks/active/sprint-01-core/T-009-e2e-tests.md`  
**状态**: pending  
**预计**: 4小时

当前只有1个测试文件，需要补充：
- Provider 测试
- Agent 测试
- 工具测试
- E2E 场景测试

---

## 🟡 P2 - 中优先级（本月内修复）

### 错误处理问题

来自 Code Review，多处发现：

1. **静默错误吞噬** (多个文件)
   - `src/http.zig:98, 165` - reader 错误被 catch break
   - 所有 Provider 的 SSE 处理 - `catch {}`
   - `src/agent/agent.zig:264` - tools.append catch {}

2. **控制流问题**
   - `src/ai/root.zig:87` - kimi provider 控制流
   - `src/ai/providers/anthropic.zig:248` - StreamContext 未使用

3. **缓冲区问题**
   - `src/http.zig:155` - SSE 行缓冲区溢出风险
   - `src/cli/root.zig:145` - 每次事件创建 4KB 缓冲区

4. **API 使用问题**
   - `src/cli/root.zig:128` - 无效的 stdout.writer() API（多处）
   - `src/cli/root.zig:175` - 逐字节读取 stdin

---

## 🟢 P3 - 低优先级（有时间再修复）

### 代码质量问题（4个任务）

#### TASK-REF-001: Response.deinit allocator 不一致
**位置**: `tasks/backlog/refactor/TASK-REF-001-fix-response-deinit-allocator.md`  
**文件**: `src/http.zig:183`  
**预计**: 30分钟

Response 存储 allocator 但 deinit 又要求传入。

#### TASK-DOCS-003: getToolDefinitions 内存所有权文档
**位置**: `tasks/backlog/docs/TASK-DOCS-003-document-memory-ownership.md`  
**文件**: `src/agent/agent.zig:268`  
**预计**: 15分钟

返回的切片需要释放但缺少文档说明。

#### TASK-BUG-011: 模型检测 'o' 前缀歧义
**位置**: `tasks/backlog/bugfix/TASK-BUG-011-fix-model-detection-ambiguity.md`  
**文件**: `src/cli/root.zig:108`  
**预计**: 15分钟

'o' 前缀太宽泛，可能误判其他模型。

#### TASK-BUG-012: thinking level 静默回退
**位置**: `tasks/backlog/bugfix/TASK-BUG-012-fix-thinking-level-fallback.md`  
**文件**: `src/cli/root.zig:98`  
**预计**: 15分钟

无效输入静默使用 .off，隐藏用户错误。

---

## 修复计划建议

### 第1天（立即）
- [ ] URGENT-FIX: 修复编译错误（30分钟）
- [ ] 验证编译通过（10分钟）
- [ ] TASK-DOCS-001: 修复任务编号（30分钟）
- [ ] TASK-DOCS-002: 更新 README（15分钟）

**预计**: 1.5小时，恢复项目可用性

### 第2-3天（本周）
- [ ] TASK-BUG-001: 修复 getApiKey 泄漏（1小时）
- [ ] TASK-BUG-002: 修复 Provider 泄漏（1小时）
- [ ] TASK-BUG-003: 修复 defer 位置（30分钟）
- [ ] 验证无内存泄漏（30分钟）

**预计**: 3小时，解决内存问题

### 第4-5天（本周）
- [ ] T-009: 补充基础测试（4小时）
  - HTTP 客户端测试
  - Provider 基础测试
  - Agent 基础测试
- [ ] 修复部分 P2 错误处理（2小时）

**预计**: 6小时，提升质量

### 下周
- [ ] 完善 E2E 测试
- [ ] 修复剩余 P2 问题
- [ ] 处理 P3 问题
- [ ] 完成 T-010 Sprint Wrapup

---

## 统计

**任务总数**: 17个
- 🚨 P0: 1个（编译错误）
- 🔴 P1: 6个（3个内存泄漏 + 2个任务系统 + 1个测试）
- 🟡 P2: 7个（错误处理、API使用、性能）
- 🟢 P3: 4个（文档、边缘情况）

**按类型分类**:
- Bugfix: 12个 (URGENT-FIX + TASK-BUG-001 到 012)
- Docs: 3个 (TASK-DOCS-001 到 003)
- Refactor: 1个 (TASK-REF-001)
- Test: 1个 (T-009 E2E 测试)

**预计修复时间**:
- 紧急恢复: 1.5小时
- 高质量状态: 10.5小时（~2个工作日）
- 完全修复: ~20小时（~1周）

---

## 验收检查清单

修复完成后，必须通过：

- [ ] `zig build` 编译成功
- [ ] `zig build test` 全部通过
- [ ] 无内存泄漏警告
- [ ] E2E 测试通过
- [ ] Code Review 通过
- [ ] 文档更新完成
- [ ] 任务状态准确

---

**下一步行动**: 执行 URGENT-FIX 任务，恢复项目可编译状态。
