# 编译错误快速修复指南

**日期**: 2026-04-05
**状态**: 待执行
**预计用时**: 30分钟

---

## 🎯 目标

修复当前编译错误，让项目可以正常编译运行。

---

## 📋 错误清单

| # | 错误 | 文件 | 行号 | 任务 |
|---|------|------|------|------|
| 1 | 未使用参数 `task_type` | `src/learning/root.zig` | 160 | TASK-BUG-027 |
| 2 | `argsAlloc` API 不存在 | `src/cli/root.zig` | 86 | TASK-BUG-026 |

---

## 🔧 修复步骤

### 步骤 1: 修复 TASK-BUG-027 (5分钟)

**文件**: `src/learning/root.zig:160`

**添加代码**:
```zig
pub fn trackModelPerformance(
    self: *Self,
    model_id: []const u8,
    success: bool,
    latency_ms: i64,
    token_cost: f64,
    task_type: []const u8,
) !void {
    _ = task_type; // TODO: 实现按任务类型分类统计
    
    // 现有代码保持不变...
}
```

**验证**:
```bash
zig build 2>&1 | grep -c "error:"
# 应该只剩1个错误
```

---

### 步骤 2: 修复 TASK-BUG-026 (15分钟)

**文件**: `src/cli/root.zig:86`

**替换代码**:

找到:
```zig
const args = try std.process.argsAlloc(allocator);
defer std.process.argsFree(allocator, args);
```

替换为:
```zig
// 使用 Zig 0.16 的 ArgIterator
var arg_iter = try std.process.ArgIterator.initWithAllocator(allocator);
defer arg_iter.deinit();

var args = std.ArrayList([]const u8).init(allocator);
defer {
    for (args.items) |arg| allocator.free(arg);
    args.deinit();
}

while (arg_iter.next()) |arg| {
    try args.append(try allocator.dupe(u8, arg));
}
```

**注意**: 后续使用 `args.items` 代替 `args`。

---

### 步骤 3: 验证编译 (2分钟)

```bash
# 完整编译
zig build

# 预期输出:
# install
# +- install kimiz
#    +- compile exe kimiz Debug native
# 成功!
```

---

### 步骤 4: 验证测试 (5分钟)

```bash
zig build test

# 预期: 所有测试通过
```

---

### 步骤 5: 验证 CLI 功能 (3分钟)

```bash
# 构建
zig build

# 测试帮助
./zig-out/bin/kimiz --help

# 测试交互模式 (输入 exit 退出)
./zig-out/bin/kimiz
```

---

## ✅ 验收标准

- [ ] `zig build` 编译成功，无错误
- [ ] `zig build test` 所有测试通过
- [ ] `./zig-out/bin/kimiz --help` 正常显示帮助
- [ ] 交互模式可以正常启动和退出

---

## 📁 相关任务文件

- `tasks/backlog/bugfix/TASK-BUG-026-fix-zig-016-argsAlloc.md`
- `tasks/backlog/bugfix/TASK-BUG-027-fix-unused-task_type-param.md`
- `tasks/backlog/infra/TASK-INFRA-007-create-compilation-fix-batch.md`

---

## 🚀 完成后

1. 更新 `tasks/ALL-TASKS-CHECKLIST.md`
2. 将完成的任务移动到 `tasks/completed/`
3. 继续 Phase 3 开发或选择其他 Backlog 任务

---

**执行者**: _____________
**开始时间**: _____________
**完成时间**: _____________
