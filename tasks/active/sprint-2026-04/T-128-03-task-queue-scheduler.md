# T-128-03: TaskQueue — 依赖解析与调度

**优先级**: P0 | **预计耗时**: 3h | **依赖**: T-128-02

## 描述

实现任务队列加载、依赖 DAG 构建、`getNextTask()` 调度逻辑。

## 影响文件

| 文件 | 改动 |
|------|------|
| `src/engine/task.zig` | 扩展：TaskQueue 结构、loadActiveTasks()、getNextTask()、getDoneTasks() |

## 验收标准

- [ ] `loadActiveTasks()` 扫描 `tasks/active/sprint-*/T-*.md` 并解析全部任务
- [ ] `getDoneTasks()` 返回所有 status=done 的任务 ID 列表
- [ ] `getNextTask()` 过滤出依赖已满足且 status!=done 的任务，按 priority 返回最高优先级的
- [ ] 依赖未满足时返回 `null`（不阻塞，不报错）
- [ ] 至少 5 个测试（无任务/有可执行任务/依赖已满足/依赖未满足/多优先级排序）

