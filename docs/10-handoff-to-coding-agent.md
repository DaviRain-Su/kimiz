# 交接文档 - 给 Coding Agent

**交接时间**: 2026-04-05  
**交接人**: Droid (Documentation Agent)  
**接收人**: Coding Agent

---

## 📋 已完成的工作

我已经完成了**任务系统重组和文档维护**工作，现在把代码修复工作交给你。

### 1. 任务系统重组 ✅

**Git Commit**: `0b465c4` - "docs: reorganize task system and fix inconsistencies"

**变更内容**:
- ✅ 移动 5 个已实现任务从 backlog 到 active/completed
- ✅ 修复任务编号冲突（T-006, T-009, T-010 → T-023, T-024, T-025）
- ✅ 更新任务状态为实际情况
- ✅ 创建 9 个缺失的任务记录

**当前任务分布**:
- Active: 17 个任务
- Completed: 11 个任务
- Backlog: 17 个任务（bugfix + docs + refactor）

### 2. 生成的文档 ✅

1. **`docs/08-project-audit-report.md`**
   - 完整的项目审查报告
   - 发现 17 个问题（P0-P3）

2. **`docs/09-task-status-audit.md`**
   - 任务状态审查报告
   - 识别已实现但未记录的代码

3. **`docs/10-handoff-to-coding-agent.md`**（本文件）
   - 交接文档

4. **`tasks/CRITICAL-FIXES-SUMMARY.md`**
   - 关键修复任务汇总
   - 按优先级分类

5. **`tasks/ALL-TASKS-CHECKLIST.md`**
   - 所有任务清单（17个）
   - 带验收标准

6. **`tasks/FIXES-COMPLETED-SUMMARY.md`**
   - 任务修复完成总结

7. **`tasks/TASK-STATUS-FIXES.md`**
   - 任务修复操作指南

---

## 🔧 需要你完成的代码修复

### 第一优先级 - P0 (阻塞项目)

#### URGENT-FIX: 编译错误修复

**位置**: `tasks/backlog/bugfix/URGENT-FIX-compilation-errors.md`  
**预计时间**: 30 分钟  
**必须立即修复**

**问题 1**: `src/utils/config.zig:250`
```zig
// 错误
const key = getApiKey(&config, "openai");

// 修复
const key = ConfigManager.getApiKey(&config, "openai");
```

**问题 2**: `src/http.zig:91`
```zig
// 错误
.response_writer = body_list.writer(self.allocator),

// 修复
.response_writer = body_list.writer(),
```

**验收**:
```bash
zig build  # 必须成功编译
```

---

### 第二优先级 - P1 (高优先级)

#### 内存泄漏修复 (3个任务，预计 2.5h)

1. **TASK-BUG-001**: getApiKey 内存泄漏
   - 文件: `src/core/root.zig:279`
   - 问题: 使用 page_allocator 但从不释放

2. **TASK-BUG-002**: Provider Authorization Header 泄漏
   - 文件: `src/ai/providers/openai.zig:75`, `src/ai/providers/kimi.zig:131`
   - 问题: allocPrint 分配但不释放

3. **TASK-BUG-003**: URL defer 位置错误
   - 文件: `src/ai/providers/openai.zig:98`, `src/ai/providers/google.zig:111`
   - 问题: defer 在 try 之后，错误路径泄漏

#### 任务系统文档 (2个任务，预计 45min)

4. **TASK-DOCS-001**: 修复任务编号冲突
   - 已完成 ✅（由我完成）

5. **TASK-DOCS-002**: 更新 Sprint README
   - 文件: `tasks/active/sprint-01-core/README.md`
   - 需要: 同步实际任务状态

#### 测试补充 (1个任务，预计 4h)

6. **T-009**: E2E 测试
   - 文件: `tests/e2e/`
   - 需要: Provider 测试、Agent 测试、工具测试

---

### 第三优先级 - P2 (中优先级，预计 6.5h)

7. **TASK-BUG-004**: 修复静默错误处理
8. **TASK-BUG-005**: 修复 CLI stdout API (10+处)
9. **TASK-BUG-006**: 修复 stdin 逐字节读取
10. **TASK-BUG-007**: 修复事件缓冲区分配
11. **TASK-BUG-008**: 修复 SSE 缓冲区溢出
12. **TASK-BUG-009**: 修复 StreamContext 未使用
13. **TASK-BUG-010**: 修复 Kimi 控制流

详细信息见各任务文件。

---

### 第四优先级 - P3 (低优先级，预计 1.25h)

14. **TASK-REF-001**: Response.deinit allocator 不一致
15. **TASK-DOCS-003**: getToolDefinitions 内存文档
16. **TASK-BUG-011**: 模型检测 'o' 前缀歧义
17. **TASK-BUG-012**: thinking level 静默回退

---

## 📊 当前项目状态

### 编译状态
```bash
❌ 无法编译（2个错误）
- src/utils/config.zig:250
- src/http.zig:91
```

### 任务状态

| 状态 | 数量 | 说明 |
|------|------|------|
| ✅ Completed | 11 个 | 已完成无错误 |
| 🟡 In Progress | 6 个 | 功能部分完成 |
| 🔴 Blocked | 3 个 | 因编译错误阻塞 |
| 🔴 Pending | 2 个 | 未开始 |

### 代码质量问题

- **P0**: 1 个（编译错误）
- **P1**: 6 个（3 内存泄漏 + 2 文档 + 1 测试）
- **P2**: 7 个（错误处理 + API 使用）
- **P3**: 4 个（文档 + 边缘情况）

---

## 🎯 建议的修复顺序

### Day 1 (立即，1.5h)
1. ✅ **URGENT-FIX** - 修复编译错误 (30min)
2. ✅ **验证编译通过** (10min)
3. ✅ **TASK-DOCS-002** - 更新 Sprint README (15min)
4. ✅ **验收测试** (10min)

### Day 2-3 (本周，3h)
5. ✅ **TASK-BUG-001** - getApiKey 泄漏 (1h)
6. ✅ **TASK-BUG-002** - Provider 泄漏 (1h)
7. ✅ **TASK-BUG-003** - defer 位置 (30min)
8. ✅ **验证无内存泄漏** (30min)

### Day 4-5 (本周，6h)
9. ✅ **T-009** - E2E 测试 (4h)
10. ✅ **修复部分 P2** - 错误处理 (2h)

### Week 2 (下周)
11. ✅ 修复剩余 P2 问题
12. ✅ 处理 P3 问题
13. ✅ 完成 T-010 Sprint Wrapup

---

## 📁 重要文件位置

### 任务清单
- **所有任务**: `tasks/ALL-TASKS-CHECKLIST.md`
- **修复汇总**: `tasks/CRITICAL-FIXES-SUMMARY.md`
- **Active 任务**: `tasks/active/sprint-01-core/*.md`
- **Bugfix 任务**: `tasks/backlog/bugfix/TASK-BUG-*.md`

### 文档
- **项目审查**: `docs/08-project-audit-report.md`
- **任务审查**: `docs/09-task-status-audit.md`
- **交接文档**: `docs/10-handoff-to-coding-agent.md`（本文件）

### 代码
- **核心类型**: `src/core/root.zig`
- **HTTP 客户端**: `src/http.zig`
- **Providers**: `src/ai/providers/*.zig`
- **CLI**: `src/cli/root.zig`
- **配置**: `src/utils/config.zig`

---

## ✅ 验收标准（全部修复后）

修复完成后，必须满足：

- [ ] `zig build` 编译成功，无错误
- [ ] `zig build test` 所有测试通过
- [ ] 无内存泄漏警告
- [ ] 所有 P0 和 P1 问题已修复
- [ ] E2E 测试覆盖核心功能
- [ ] Code review 通过
- [ ] Sprint README 已更新
- [ ] 提交 git commit 记录所有修复

---

## 🔄 工作流程

### 修复一个问题时：

1. **开始任务**
   - 阅读任务文件（`tasks/backlog/bugfix/TASK-BUG-XXX.md`）
   - 理解问题和修复方案

2. **修复代码**
   - 修改相关文件
   - 验证编译通过
   - 运行相关测试

3. **更新任务状态**
   - 修改任务文件状态为 `completed`
   - 添加实际耗时
   - 移动到 `tasks/completed/sprint-01-bugfixes/`

4. **提交代码**
   ```bash
   git add <修改的文件>
   git commit -m "fix: <简短描述>
   
   解决 TASK-BUG-XXX
   
   - 具体修复内容
   - 验证方式
   
   Co-authored-by: factory-droid[bot] <138933559+factory-droid[bot]@users.noreply.github.com>"
   ```

---

## 📞 需要帮助时

如果遇到问题：

1. **查看文档**
   - `docs/08-project-audit-report.md` - 完整问题列表
   - `docs/09-task-status-audit.md` - 任务状态详情
   - `tasks/CRITICAL-FIXES-SUMMARY.md` - 修复汇总

2. **检查任务文件**
   - 每个任务都有详细的问题描述
   - 都有建议的修复方案
   - 都有验收标准

3. **参考 Code Review**
   - Code Review 发现了所有问题
   - 包含具体的行号和代码片段

---

## 🎯 目标

**短期目标**（本周）:
- ✅ 项目可编译
- ✅ 修复所有 P1 内存泄漏
- ✅ 补充基础测试

**中期目标**（下周）:
- ✅ 修复所有 P2 问题
- ✅ 完成 E2E 测试
- ✅ Sprint 1 Wrapup

**长期目标**（下个月）:
- ✅ 修复所有 P3 问题
- ✅ 完善进行中的功能
- ✅ 准备 Sprint 2

---

## 📌 重要提醒

1. **修复编译错误是最高优先级** - 项目当前完全不可用
2. **所有修复都有详细的任务文件** - 不需要猜测如何修复
3. **验收标准必须满足** - 不要标记为 completed 如果未验证
4. **保持任务状态同步** - 修复后更新任务文件
5. **提交信息要清晰** - 引用任务编号，说明修复内容

---

**开始修复吧！优先从 URGENT-FIX 开始。** 🚀

**联系方式**: 如果有任何文档问题，随时可以找我更新。
