### TASK-DOCS-001: 修复任务编号冲突
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 30分钟

**描述**:
任务系统存在编号冲突，多个不同的任务使用了相同的编号。

**冲突列表**:

| 编号 | 任务1 | 任务2 |
|------|-------|-------|
| T-006 | CLI 基础框架 | Skill-Centric 架构 |
| T-009 | E2E 测试 | 自适应学习系统 |
| T-010 | Memory 系统 | Sprint1 Wrapup |

**修复方案**:

1. 重命名冲突的任务文件:
```bash
# T-006 冲突
T-006-cli-framework.md (保持)
T-006-skill-centric-architecture.md → T-011-skill-centric-architecture.md

# T-009 冲突
T-009-e2e-tests.md (保持)
T-009-adaptive-learning.md → T-012-adaptive-learning.md

# T-010 冲突
T-010-sprint1-wrapup.md (保持)
T-010-memory-system.md → T-013-memory-system.md
```

2. 更新所有任务文件内部的编号引用

3. 建立新的编号规则:
```
格式: T-S{Sprint}-{序号}-{类型}
示例: T-S1-001-CORE, T-S2-003-TEST
```

**验收标准**:
- [ ] 所有任务编号唯一
- [ ] 任务文件名与内容编号一致
- [ ] 更新 README 中的任务列表
- [ ] 文档化新的编号规则

**依赖**: 无

**相关文件**:
- tasks/active/sprint-01-core/
- tasks/README.md

**笔记**:
