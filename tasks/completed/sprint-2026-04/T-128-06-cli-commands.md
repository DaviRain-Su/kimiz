# T-128-06: CLI 命令 — project/phase/task 子命令

**优先级**: P1 | **预计耗时**: 1h | **依赖**: T-128-02, T-128-03, T-128-04

## 描述

添加 yazap 子命令：`kimiz project create`, `kimiz task list`, `kimiz task next`。

## 影响文件

| 文件 | 改动 |
|------|------|
| `src/cli/root.zig` | 新增：project/task 子命令定义和 handler 函数 |

## 验收标准

- [ ] `kimiz project create "<name>"` 调用 Project.createProject() 并打印项目 ID
- [ ] `kimiz task list` 列出当前 Sprint 所有任务的状态和优先级
- [ ] `kimiz task next` 显示 getNextTask() 返回的下一个可执行任务
- [ ] `zig build && zig build test` 通过

