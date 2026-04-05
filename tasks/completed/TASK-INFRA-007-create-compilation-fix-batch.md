### TASK-INFRA-007: 创建编译修复批量任务
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 30分钟
**类型**: 批量任务协调

**描述**:
协调并执行所有编译错误修复任务，确保项目可编译。

**子任务**:

| 顺序 | 任务 ID | 描述 | 预计 | 状态 |
|------|---------|------|------|------|
| 1 | TASK-BUG-027 | 修复未使用参数 | 5分钟 | pending |
| 2 | TASK-BUG-026 | 修复 argsAlloc API | 15分钟 | pending |
| 3 | 验证 | 运行 zig build | 2分钟 | pending |
| 4 | 验证 | 运行 zig build test | 5分钟 | pending |
| 5 | 验证 | 测试 CLI 基本功能 | 3分钟 | pending |

**执行步骤**:

```bash
# 1. 修复 TASK-BUG-027
# 编辑 src/learning/root.zig:160
# 添加: _ = task_type;

# 2. 修复 TASK-BUG-026
# 编辑 src/cli/root.zig:86
# 替换为 ArgIterator 实现

# 3. 验证编译
zig build

# 4. 验证测试
zig build test

# 5. 验证 CLI
./zig-out/bin/kimiz --help
./zig-out/bin/kimiz  # 进入交互模式后输入 exit
```

**验收标准**:
- [ ] `zig build` 编译成功，无错误
- [ ] `zig build test` 所有测试通过
- [ ] `./zig-out/bin/kimiz --help` 正常显示
- [ ] 交互模式可以正常启动和退出

**依赖**:
- 无

**阻塞**:
- 所有其他开发工作

**完成后**:
- 更新 `tasks/ALL-TASKS-CHECKLIST.md`
- 将任务移动到 `tasks/completed/`
- 创建 Phase 3 规划任务

**参考**:
- `tasks/backlog/bugfix/TASK-BUG-026-fix-zig-016-argsAlloc.md`
- `tasks/backlog/bugfix/TASK-BUG-027-fix-unused-task_type-param.md`
