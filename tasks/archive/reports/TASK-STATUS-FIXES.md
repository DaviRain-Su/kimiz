# 任务状态修复清单

**生成时间**: 2026-04-05  
**来源**: 任务状态审查报告

---

## 📋 需要执行的修复

### 第1步: 移动 Backlog 中已实现的任务（5个）

```bash
# 1. T-007: Skill Registry (已完成)
mv tasks/backlog/feature/T-007-skill-registry.md \
   tasks/completed/sprint-01-core/T-007-skill-registry.md

# 2. T-008: Built-in Skills (进行中)
mv tasks/backlog/feature/T-008-built-in-skills.md \
   tasks/active/sprint-01-core/T-008-built-in-skills.md

# 3. T-011: Prompts 模块 (需要改状态为 in_progress)
mv tasks/backlog/feature/T-011-prompts-module.md \
   tasks/active/sprint-01-core/T-011-prompts-module.md

# 4. T-012: Smart Routing (需要改状态为 in_progress)
mv tasks/backlog/feature/T-012-smart-model-routing.md \
   tasks/active/sprint-01-core/T-012-smart-model-routing.md

# 5. T-013: Config Management (进行中)
mv tasks/backlog/feature/T-013-config-management.md \
   tasks/active/sprint-01-core/T-013-config-management.md
```

### 第2步: 修复编号冲突（3个）

```bash
# T-006 冲突: CLI vs Skill-Centric
mv tasks/active/sprint-01-core/T-006-skill-centric-architecture.md \
   tasks/active/sprint-01-core/T-023-skill-centric-integration.md

# T-009 冲突: E2E vs Learning
mv tasks/active/sprint-01-core/T-009-adaptive-learning.md \
   tasks/completed/sprint-01-core/T-024-adaptive-learning.md

# T-010 冲突: Memory vs Wrapup
mv tasks/active/sprint-01-core/T-010-memory-system.md \
   tasks/completed/sprint-01-core/T-025-memory-system.md
```

### 第3步: 更新任务状态（5个）

需要手动编辑以下文件：

1. **T-003-http-client.md**
   - 当前: `**状态**: completed`
   - 修改为: `**状态**: blocked`
   - 原因: 有编译错误

2. **T-005-openai-provider.md**
   - 当前: `**状态**: completed`
   - 修改为: `**状态**: blocked`
   - 原因: 有编译错误

3. **T-006-cli-framework.md**
   - 当前: `**状态**: completed`
   - 修改为: `**状态**: blocked`
   - 原因: 有编译错误

4. **T-011-prompts-module.md** (移动后)
   - 当前: `**状态**: completed`
   - 修改为: `**状态**: in_progress`
   - 原因: 模板替换未实现

5. **T-012-smart-model-routing.md** (移动后)
   - 当前: `**状态**: completed`
   - 修改为: `**状态**: in_progress`
   - 原因: 性能数据收集待完善

### 第4步: 创建缺失的任务（9个）

需要创建以下任务文件到 `tasks/completed/sprint-01-core/`:

- [ ] T-014-agent-tools.md
- [ ] T-015-session-management.md
- [ ] T-016-agent-registry.md
- [ ] T-018-anthropic-provider.md
- [ ] T-019-google-provider.md
- [ ] T-020-kimi-provider.md
- [ ] T-021-fireworks-provider.md
- [ ] T-022-ai-models.md

需要创建到 `tasks/active/sprint-01-core/`:

- [ ] T-017-tui-framework.md

---

## ✅ 验证清单

修复完成后检查：

- [ ] 所有任务编号唯一
- [ ] backlog/feature 中没有已实现的任务
- [ ] completed/ 中的任务都没有编译错误
- [ ] active/ 中的任务都在进行中
- [ ] blocked 任务都有明确的阻塞原因
- [ ] 所有已实现代码都有对应任务记录
- [ ] Sprint README 更新为实际状态

---

## 📊 预期结果

修复后的任务分布：

```
tasks/
├── active/sprint-01-core/        (10个 in_progress/blocked)
│   ├── T-003 (blocked)
│   ├── T-005 (blocked)
│   ├── T-006 (blocked)
│   ├── T-008 (in_progress)
│   ├── T-009-e2e-tests (pending)
│   ├── T-010-sprint1-wrapup (pending)
│   ├── T-011 (in_progress)
│   ├── T-012 (in_progress)
│   ├── T-013 (in_progress)
│   ├── T-017 (in_progress)
│   └── T-023 (in_progress)
│
├── completed/sprint-01-core/     (15个 completed)
│   ├── T-001
│   ├── T-002
│   ├── T-004
│   ├── T-007-cli
│   ├── T-007-skill-registry
│   ├── T-008-logging
│   ├── T-014 到 T-016
│   ├── T-018 到 T-022
│   ├── T-024
│   └── T-025
│
└── backlog/
    ├── bugfix/         (13个 pending)
    ├── docs/           (3个 pending)
    ├── refactor/       (1个 pending)
    └── feature/        (0个) ← 清空
```

---

**下一步**: 是否要我帮你执行这些移动和创建操作？
