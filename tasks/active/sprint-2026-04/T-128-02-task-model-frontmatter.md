# T-128-02: Task Model & YAML Frontmatter Parser

**优先级**: P0 | **预计耗时**: 2h | **依赖**: 无

## 描述

实现 Task 数据模型和从 markdown YAML frontmatter 解析任务元数据的能力。

## 影响文件

| 文件 | 改动 |
|------|------|
| `src/engine/task.zig` | 新增：Task 结构、YAML frontmatter 解析函数 |

## 验收标准

- [ ] `Task` 结构包含 id/title/status/priority/dependencies/subagent_budget/spec_path/task_path
- [ ] YAML frontmatter 解析：id, title, status, priority, dependencies, estimated_hours
- [ ] dependencies 支持空数组（无依赖任务）
- [ ] status 枚举正确映射（todo/in_progress/done/blocked/failed）
- [ ] priority 枚举正确映射（p0/p1/p2/p3）
- [ ] 至少 4 个测试（正常解析/缺省值/无效格式/依赖解析）

