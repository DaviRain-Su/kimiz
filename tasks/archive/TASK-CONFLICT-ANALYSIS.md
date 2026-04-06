# 任务冲突分析与整合报告

**日期**: 2026-04-05  
**分析范围**: 所有 Backlog + Active + 新创建任务  
**目标**: 识别冲突、重复、过时的任务，提供整合方案

---

## 一、任务统计

| 类别 | 数量 | 说明 |
|------|------|------|
| Active Sprint | 18 | Sprint-01-Core |
| Completed | 11 | 已完成任务 |
| Backlog Bugfix | 22 | 待修复 Bug |
| Backlog Feature | 17 | 待实现功能 |
| Backlog Refactor | 6 | 待重构代码 |
| Backlog Docs | 4 | 待完善文档 |
| **总计** | **78** | 不含本次新增 |

---

## 二、冲突类型识别

### 2.1 重复任务 (Duplicate Tasks)

#### 冲突组 1: Memory/Session 相关

| 任务 A | 任务 B | 冲突描述 |
|--------|--------|----------|
| `T-025-memory-system` (completed) | `TASK-REF-003-simplify-memory-system` (new) | 原任务实现三层记忆，新任务简化为单层 |
| `TASK-DOCS-003-document-memory-ownership` | `TASK-REF-003` | 文档任务基于旧架构 |
| `TASK-BUG-007-fix-event-buffer-allocation` | `TASK-REF-003` | Bug 修复基于旧架构 |

**处理建议**: 
- ✅ 保留 `TASK-REF-003` (新架构方向)
- ❌ 删除/归档 `T-025` (已完成但将被重构)
- ❌ 删除 `TASK-DOCS-003` (基于旧架构)
- ❌ 删除 `TASK-BUG-007` (基于旧架构)

#### 冲突组 2: Learning 系统

| 任务 A | 任务 B | 冲突描述 |
|--------|--------|----------|
| `T-024-adaptive-learning` (completed) | `TASK-REF-004-remove-learning-system` (new) | 原任务实现 Learning，新任务移除 |
| `TASK-FEAT-004-complete-learning-system` | `TASK-REF-004` | 完善任务与移除冲突 |

**处理建议**:
- ✅ 保留 `TASK-REF-004` (新架构方向)
- ❌ 归档 `T-024` (已完成但将被移除)
- ❌ 删除 `TASK-FEAT-004-complete-learning-system`

#### 冲突组 3: Smart Routing

| 任务 A | 任务 B | 冲突描述 |
|--------|--------|----------|
| `T-012-smart-model-routing` (in-progress) | `TASK-REF-005-remove-smart-routing` (new) | 原任务实现路由，新任务移除 |
| `TASK-BUG-011-fix-model-detection-ambiguity` | `TASK-REF-005` | Bug 修复基于将被移除的功能 |

**处理建议**:
- ✅ 保留 `TASK-REF-005` (新架构方向)
- ❌ 停止 `T-012` (将被移除)
- ❌ 删除 `TASK-BUG-011`

#### 冲突组 4: Workspace Context

| 任务 A | 任务 B | 冲突描述 |
|--------|--------|----------|
| `TASK-FEAT-003-implement-workspace-context` (new) | `TASK-FEAT-006-workspace-context` (existing) | 两个任务都实现 Workspace Context |
| `TASK-FEAT-003-register-builtin-skills` | `TASK-FEAT-002-implement-skills-registration` | 重复的技能注册任务 |

**对比分析**:

| 特性 | FEAT-003 (new) | FEAT-006 (existing) |
|------|----------------|---------------------|
| 复杂度 | 高 (技术栈检测) | 低 (Git + AGENTS.md) |
| 与 Pi 对齐 | ❌ | ✅ |
| 实现成本 | 8h | 4h |
| 维护成本 | 高 | 低 |

**处理建议**:
- ✅ 保留 `TASK-FEAT-006` (existing, 简化版)
- ❌ 删除 `TASK-FEAT-003` (new, 复杂版)
- ✅ 保留 `TASK-REF-006-simplify-workspace-context` (重构任务)

#### 冲突组 5: Skills 系统

| 任务 A | 任务 B | 冲突描述 |
|--------|--------|----------|
| `T-023-skill-centric-integration` (completed) | `TASK-FEAT-006-implement-extension-system` (new) | Skills vs Extensions |
| `T-008-built-in-skills` (in-progress) | `TASK-FEAT-002` + `TASK-FEAT-003-register` | 重复的技能实现 |
| `TASK-FEAT-003-register-builtin-skills` | `T-023` | T-023 声称已完成注册 |

**关键发现**:
- `T-023` 标记为 completed，但代码中 `registerBuiltinSkills` 为空
- `T-008` 仍在 in-progress
- 新架构决定用 Extensions 替代 Skills

**处理建议**:
- ✅ 保留 `TASK-FEAT-006-implement-extension-system` (新方向)
- ❌ 停止 `T-008` (将被 Extension 替代)
- ❌ 删除 `TASK-FEAT-002` 和 `TASK-FEAT-003-register`
- 📝 更新 `T-023` 状态 (实际未完成)

#### 冲突组 6: Prompt Cache

| 任务 A | 任务 B | 冲突描述 |
|--------|--------|----------|
| `TASK-FEAT-004-implement-prompt-cache` (new) | `TASK-FEAT-007-prompt-caching` (existing) | 重复任务 |

**对比**:
- 两个任务目标相同
- `FEAT-007` (existing) 更详细，有具体实现方案
- `FEAT-004` (new) 基于 Raschka 文章

**处理建议**:
- ✅ 保留 `TASK-FEAT-007-prompt-caching` (existing)
- ❌ 删除 `TASK-FEAT-004-implement-prompt-cache` (new)

#### 冲突组 7: Context Reduction/Truncation

| 任务 A | 任务 B | 冲突描述 |
|--------|--------|----------|
| `TASK-FEAT-005-implement-context-reduction` (new) | `TASK-FEAT-008-context-truncation` (existing) | 重复任务 |

**对比**:
- 目标相同：防止上下文溢出
- `FEAT-008` (existing) 更具体，有代码示例
- `FEAT-005` (new) 更理论化

**处理建议**:
- ✅ 保留 `TASK-FEAT-008-context-truncation` (existing)
- ❌ 删除 `TASK-FEAT-005-implement-context-reduction` (new)

---

### 2.2 依赖冲突 (Dependency Conflicts)

#### 冲突: Extension 系统 vs 其他功能

许多任务依赖将被移除的功能：

| 任务 | 原依赖 | 冲突描述 |
|------|--------|----------|
| `TASK-FEAT-004-complete-learning` | Memory | 依赖将被移除的三层记忆 |
| `TASK-FEAT-007-prompt-caching` | Workspace | 依赖将被简化的 Workspace |
| `TASK-FEAT-009-tool-approval` | Learning | 依赖将被移除的 Learning |

**处理建议**:
- 更新这些任务的依赖描述
- 或标记为 blocked 直到重构完成

---

### 2.3 编号冲突 (ID Conflicts)

发现多个任务使用相同编号：

| 编号 | 任务 A | 任务 B | 任务 C |
|------|--------|--------|--------|
| BUG-018 | fix-http-streaming-implementation | fix-skill-category-keyword | - |
| BUG-019 | fix-getApiKey-memory-management | fix-tool-calls-serialization | - |
| BUG-020 | fix-http-streaming | fix-logger-thread-safety | - |
| BUG-021 | fix-skill-category-keyword | - | - |
| FEAT-003 | implement-workspace-context | register-builtin-skills | - |
| FEAT-004 | implement-prompt-cache | complete-learning-system | - |
| FEAT-005 | implement-context-reduction | implement-tui-mode | - |
| FEAT-006 | implement-extension-system | workspace-context | - |
| FEAT-007 | simplify-tools | prompt-caching | - |

**处理建议**:
- 删除重复编号的任务时解决
- 或重新编号保留的任务

---

## 三、过时任务识别 (Obsolete Tasks)

基于新架构，以下任务已过时：

### 将被移除的功能相关

| 任务 | 原因 |
|------|------|
| `T-012-smart-model-routing` | Smart Routing 被移除 |
| `T-024-adaptive-learning` | Learning 系统被移除 |
| `T-025-memory-system` | 三层记忆被简化 |
| `TASK-FEAT-004-complete-learning-system` | Learning 被移除 |
| `TASK-BUG-011-fix-model-detection-ambiguity` | Routing 被移除 |
| `TASK-BUG-012-fix-thinking-level-fallback` | 可能不再需要 |

### 被新任务替代

| 旧任务 | 新任务 | 说明 |
|--------|--------|------|
| `TASK-FEAT-003-implement-workspace-context` | `TASK-REF-006` | 复杂版被简化版替代 |
| `TASK-FEAT-004-implement-prompt-cache` | `TASK-FEAT-007` | 重复 |
| `TASK-FEAT-005-implement-context-reduction` | `TASK-FEAT-008` | 重复 |
| `TASK-FEAT-002-implement-skills-registration` | `TASK-FEAT-006` | Skills 被 Extensions 替代 |

---

## 四、整合方案

### 4.1 任务删除清单 (建议删除/归档)

#### 确定删除 (18个)

```
# 重复任务 (新创建的重复)
TASK-FEAT-003-implement-workspace-context.md  # 被 REF-006 替代
TASK-FEAT-004-implement-prompt-cache.md       # 被 FEAT-007 替代
TASK-FEAT-005-implement-context-reduction.md  # 被 FEAT-008 替代
TASK-FEAT-002-implement-skills-registration.md # 被 Extension 替代

# 基于将被移除的功能
TASK-FEAT-004-complete-learning-system.md
TASK-FEAT-003-register-builtin-skills.md
TASK-DOCS-003-document-memory-ownership.md
TASK-BUG-007-fix-event-buffer-allocation.md
TASK-BUG-011-fix-model-detection-ambiguity.md
TASK-BUG-012-fix-thinking-level-fallback.md

# 编号重复的次要任务
TASK-BUG-018-fix-skill-category-keyword.md
TASK-BUG-019-fix-tool-calls-serialization.md
TASK-BUG-020-fix-http-streaming.md
TASK-BUG-021-fix-skill-category-keyword.md
```

#### 确定归档 (3个)

```
# 已完成但将被重构
T-024-adaptive-learning.md
T-025-memory-system.md

# 停止进行中的
T-012-smart-model-routing.md (从 active 移出)
```

### 4.2 任务保留清单 (核心任务)

#### P0 - 立即执行

```
# 修复类
URGENT-FIX-compilation-errors.md
TASK-BUG-013-fix-page-allocator-abuse.md
TASK-BUG-014-fix-cli-unimplemented.md
TASK-BUG-015-fix-silent-catch-empty.md
TASK-BUG-016-fix-tool-result-memory.md
TASK-BUG-017-fix-ai-client-reuse.md
TASK-BUG-018-fix-http-streaming-implementation.md
TASK-BUG-019-fix-getApiKey-memory-management.md
TASK-BUG-020-fix-logger-thread-safety.md

# 重构类 (新架构)
TASK-REF-003-simplify-memory-system.md
TASK-REF-004-remove-learning-system.md
TASK-REF-005-remove-smart-routing.md
```

#### P1 - 重要

```
# 重构类
TASK-REF-006-simplify-workspace-context.md
TASK-REF-002-serialize-request-refactor.md

# 功能类
TASK-FEAT-006-implement-extension-system.md
TASK-FEAT-007-simplify-tools.md
TASK-FEAT-001-implement-tui-complete.md
TASK-FEAT-006-workspace-context.md
TASK-FEAT-007-prompt-caching.md
TASK-FEAT-008-context-truncation.md
```

#### P2 - 中优先级

```
# 其他保留任务
TASK-REF-001-fix-response-deinit-allocator.md
TASK-FEAT-009-tool-approval.md
TASK-FEAT-010-session-persistence.md
TASK-DOCS-004-api-documentation.md
```

### 4.3 任务更新清单 (需要修改)

| 任务 | 更新内容 |
|------|----------|
| `T-023-skill-centric-integration` | 状态从 completed 改为 in-progress，添加备注 |
| `T-008-built-in-skills` | 状态改为 blocked，备注将被 Extension 替代 |
| `TASK-FEAT-007-prompt-caching` | 更新依赖，移除 Learning 依赖 |
| `TASK-FEAT-008-context-truncation` | 更新依赖，基于新的 Session 架构 |

---

## 五、整合后的任务结构

### 阶段 1: 紧急修复 (Week 1)

```
P0 - Bugfix (9个)
├── URGENT-FIX-compilation-errors
├── TASK-BUG-013-fix-page-allocator-abuse
├── TASK-BUG-014-fix-cli-unimplemented
├── TASK-BUG-015-fix-silent-catch-empty
├── TASK-BUG-016-fix-tool-result-memory
├── TASK-BUG-017-fix-ai-client-reuse
├── TASK-BUG-018-fix-http-streaming-implementation
├── TASK-BUG-019-fix-getApiKey-memory-management
└── TASK-BUG-020-fix-logger-thread-safety

P0 - Refactor (3个)
├── TASK-REF-003-simplify-memory-system
├── TASK-REF-004-remove-learning-system
└── TASK-REF-005-remove-smart-routing
```

### 阶段 2: 核心功能 (Week 2)

```
P1 - Refactor (2个)
├── TASK-REF-006-simplify-workspace-context
└── TASK-REF-002-serialize-request-refactor

P1 - Feature (4个)
├── TASK-FEAT-006-workspace-context
├── TASK-FEAT-007-prompt-caching
├── TASK-FEAT-008-context-truncation
└── TASK-FEAT-007-simplify-tools
```

### 阶段 3: Extension 系统 (Week 3-4)

```
P1 - Feature (1个)
└── TASK-FEAT-006-implement-extension-system

P1 - Feature (1个)
└── TASK-FEAT-001-implement-tui-complete
```

---

## 六、实施建议

### 立即执行 (今天)

1. **归档过时任务**
   - 将确定删除的任务移动到 `tasks/archived/`
   - 更新 `T-023` 状态

2. **更新任务清单**
   - 更新 `ALL-TASKS-CHECKLIST.md`
   - 更新 `SIMPLIFICATION-TASKS.md`

3. **通知团队**
   - 说明架构简化决策
   - 解释任务变更原因

### 本周执行

1. **开始重构任务**
   - REF-003, REF-004, REF-005 可并行
   - 完成后立即测试

2. **更新依赖关系**
   - 修改受影响任务的依赖描述
   - 重新评估时间线

### 持续监控

1. **每周审查**
   - 检查新发现的重叠
   - 评估简化效果

2. **文档同步**
   - 保持文档与代码同步
   - 更新架构图

---

## 七、风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| 删除任务导致功能缺失 | 中 | 高 | 确保 Extension 系统能替代 |
| 重构引入新 Bug | 高 | 中 | 充分测试，保留回滚方案 |
| 团队对简化有分歧 | 中 | 中 | 充分沟通，展示对比数据 |
| 时间线延期 | 中 | 中 | 明确 MVP，分阶段交付 |

---

## 八、总结

### 关键数字

- **总任务数**: 78 → 预计 45 (删除 33个)
- **重复任务**: 识别 15 组重复
- **过时任务**: 识别 18 个过时任务
- **核心任务**: 保留 20 个核心任务

### 核心决策

1. ✅ **采用简化架构** - 向 Pi-Mono 看齐
2. ✅ **Extension 替代 Skills** - 更灵活的扩展机制
3. ✅ **单层 Session 替代三层记忆** - 降低复杂度
4. ✅ **手动选择替代 Smart Routing** - 简单可靠

### 下一步行动

1. 执行本报告的删除/归档建议
2. 更新所有任务清单
3. 开始 REF-003, REF-004, REF-005 重构
4. 每周审查进展

---

**维护者**: Claude Code  
**状态**: 待执行  
**审核**: 需要团队确认
