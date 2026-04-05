# 所有任务清单

**生成时间**: 2026-04-05  
**任务总数**: 17个

---

## 🚨 P0 - 阻塞级别（1个）

- [ ] **URGENT-FIX**: 修复编译错误
  - 📁 `tasks/backlog/bugfix/URGENT-FIX-compilation-errors.md`
  - ⏱️ 30分钟
  - 🎯 修复 config.zig 和 http.zig 的编译错误

---

## 🔴 P1 - 高优先级（6个）

### 内存泄漏（3个）

- [ ] **TASK-BUG-001**: 修复 getApiKey 内存泄漏
  - 📁 `tasks/backlog/bugfix/TASK-BUG-001-fix-getApiKey-memory-leak.md`
  - 📄 `src/core/root.zig:279`
  - ⏱️ 1小时

- [ ] **TASK-BUG-002**: 修复 Provider Authorization Header 内存泄漏
  - 📁 `tasks/backlog/bugfix/TASK-BUG-002-fix-provider-auth-header-leak.md`
  - 📄 `src/ai/providers/openai.zig:75`, `src/ai/providers/kimi.zig:131`
  - ⏱️ 1小时

- [ ] **TASK-BUG-003**: 修复 URL 分配 defer 位置错误
  - 📁 `tasks/backlog/bugfix/TASK-BUG-003-fix-url-defer-position.md`
  - 📄 `src/ai/providers/openai.zig:98`, `src/ai/providers/google.zig:111`
  - ⏱️ 30分钟

### 任务系统（2个）

- [ ] **TASK-DOCS-001**: 修复任务编号冲突
  - 📁 `tasks/backlog/docs/TASK-DOCS-001-fix-task-numbering.md`
  - ⏱️ 30分钟
  - 🎯 T-006, T-009, T-010 编号重复

- [ ] **TASK-DOCS-002**: 更新 Sprint README
  - 📁 `tasks/backlog/docs/TASK-DOCS-002-update-sprint-readme.md`
  - ⏱️ 15分钟
  - 🎯 同步任务实际状态

### 测试（1个）

- [ ] **T-009**: 编写 E2E 测试
  - 📁 `tasks/active/sprint-01-core/T-009-e2e-tests.md`
  - ⏱️ 4小时
  - 🎯 补充测试覆盖率

---

## 🟡 P2 - 中优先级（7个）

### 错误处理（1个）

- [ ] **TASK-BUG-004**: 修复静默错误处理
  - 📁 `tasks/backlog/bugfix/TASK-BUG-004-fix-silent-error-handling.md`
  - 📄 多个文件 (http.zig, agent.zig, providers/*.zig)
  - ⏱️ 2小时
  - 🎯 移除 `catch {}` 空处理

### API 使用（3个）

- [ ] **TASK-BUG-005**: 修复 CLI stdout writer API
  - 📁 `tasks/backlog/bugfix/TASK-BUG-005-fix-cli-stdout-api.md`
  - 📄 `src/cli/root.zig` (10+处)
  - ⏱️ 1小时
  - 🎯 修复 stdout().writer() 错误用法

- [ ] **TASK-BUG-006**: 修复 stdin 逐字节读取
  - 📁 `tasks/backlog/bugfix/TASK-BUG-006-fix-stdin-reading.md`
  - 📄 `src/cli/root.zig:175`
  - ⏱️ 1小时
  - 🎯 使用 bufferedReader

- [ ] **TASK-BUG-010**: 修复 Kimi Provider 控制流
  - 📁 `tasks/backlog/bugfix/TASK-BUG-010-fix-kimi-control-flow.md`
  - 📄 `src/ai/root.zig:87`
  - ⏱️ 30分钟
  - 🎯 内部 switch 缺少 return

### 性能/资源（2个）

- [ ] **TASK-BUG-007**: 修复事件缓冲区分配
  - 📁 `tasks/backlog/bugfix/TASK-BUG-007-fix-event-buffer-allocation.md`
  - 📄 `src/cli/root.zig:145`
  - ⏱️ 30分钟
  - 🎯 每次事件创建 4KB 缓冲区

- [ ] **TASK-BUG-008**: 修复 SSE 缓冲区溢出
  - 📁 `tasks/backlog/bugfix/TASK-BUG-008-fix-sse-buffer-overflow.md`
  - 📄 `src/http.zig:155`
  - ⏱️ 1小时
  - 🎯 固定缓冲区可能丢失数据

### 逻辑（1个）

- [ ] **TASK-BUG-009**: 修复 StreamContext 未使用
  - 📁 `tasks/backlog/bugfix/TASK-BUG-009-fix-streamcontext-unused.md`
  - 📄 `src/ai/providers/anthropic.zig:248`
  - ⏱️ 30分钟
  - 🎯 创建后立即丢弃

---

## 🟢 P3 - 低优先级（4个）

### 代码质量（1个）

- [ ] **TASK-REF-001**: 修复 Response.deinit allocator 不一致
  - 📁 `tasks/backlog/refactor/TASK-REF-001-fix-response-deinit-allocator.md`
  - 📄 `src/http.zig:183`
  - ⏱️ 30分钟
  - 🎯 既存储又要求传入 allocator

### 文档（1个）

- [ ] **TASK-DOCS-003**: 文档化 getToolDefinitions 内存所有权
  - 📁 `tasks/backlog/docs/TASK-DOCS-003-document-memory-ownership.md`
  - 📄 `src/agent/agent.zig:268`
  - ⏱️ 15分钟
  - 🎯 说明调用者需要释放内存

### 边缘情况（2个）

- [ ] **TASK-BUG-011**: 修复模型检测 'o' 前缀歧义
  - 📁 `tasks/backlog/bugfix/TASK-BUG-011-fix-model-detection-ambiguity.md`
  - 📄 `src/cli/root.zig:108`
  - ⏱️ 15分钟
  - 🎯 'o' 前缀太宽泛

- [ ] **TASK-BUG-012**: 修复 thinking level 静默回退
  - 📁 `tasks/backlog/bugfix/TASK-BUG-012-fix-thinking-level-fallback.md`
  - 📄 `src/cli/root.zig:98`
  - ⏱️ 15分钟
  - 🎯 无效值没有提示

---

## 统计汇总

**任务数量**:
- 总计: 17个
- P0: 1个
- P1: 6个
- P2: 7个
- P3: 4个

**按类型**:
- Bugfix: 12个
- Docs: 3个
- Refactor: 1个
- Test: 1个

**预计总耗时**:
- P0: 0.5小时
- P1: 7.25小时
- P2: 6.5小时
- P3: 1.25小时
- **总计**: ~15.5小时

---

## 推荐执行顺序

### 阶段 1: 紧急修复（立即，0.5h）
1. ✅ URGENT-FIX - 修复编译错误

### 阶段 2: 高优先级（本周，7.25h）
2. ✅ TASK-DOCS-001 - 修复任务编号
3. ✅ TASK-DOCS-002 - 更新 README
4. ✅ TASK-BUG-001 - getApiKey 泄漏
5. ✅ TASK-BUG-002 - Provider 泄漏
6. ✅ TASK-BUG-003 - defer 位置
7. ✅ T-009 - E2E 测试（部分）

### 阶段 3: 中优先级（下周，6.5h）
8. ✅ TASK-BUG-004 - 错误处理
9. ✅ TASK-BUG-005 - stdout API
10. ✅ TASK-BUG-006 - stdin 读取
11. ✅ TASK-BUG-007 - 缓冲区分配
12. ✅ TASK-BUG-008 - SSE 溢出
13. ✅ TASK-BUG-009 - StreamContext
14. ✅ TASK-BUG-010 - 控制流

### 阶段 4: 低优先级（有空时，1.25h）
15. ✅ TASK-REF-001 - allocator 一致性
16. ✅ TASK-DOCS-003 - 内存文档
17. ✅ TASK-BUG-011 - 模型检测
18. ✅ TASK-BUG-012 - thinking level

---

## 验收标准

所有任务完成后必须满足：

- [ ] `zig build` 编译成功，无错误
- [ ] `zig build test` 所有测试通过
- [ ] 无内存泄漏警告
- [ ] 任务系统编号唯一且准确
- [ ] Sprint README 与实际状态一致
- [ ] E2E 测试覆盖核心功能
- [ ] Code review 通过
- [ ] 文档更新完成

---

**下一步**: 执行 URGENT-FIX，恢复项目可编译状态
