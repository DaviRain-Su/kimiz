# T-128-04: Phase 状态机 — Project & getCurrentPhase()

**优先级**: P0 | **预计耗时**: 2h | **依赖**: 无

## 描述

实现 Phase 枚举、Project 结构、`getCurrentPhase()` 文件系统判定逻辑。

## 影响文件

| 文件 | 改动 |
|------|------|
| `src/engine/project.zig` | 新增：Phase 枚举、Project 结构、getCurrentPhase()、createProject() |

## 验收标准

- [ ] Phase 枚举包含 prd/architecture/technical_spec/task_breakdown/test_spec/implementation/review_deploy
- [ ] `getCurrentPhase(project_dir)` 按 `01-prd.md` → `02-architecture.md` → ... 顺序判断，返回第一个不存在的文档对应的 Phase
- [ ] `createProject(name, sprint_name)` 创建 `projects/<id>/` 目录和 `01-prd.md` 模板
- [ ] 不可跳跃 Phase（Phase N 完成后才能进入 N+1）
- [ ] 至少 4 个测试（初始Phase/已有多文档/全部完成/跳跃检测）

