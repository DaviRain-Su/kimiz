### TASK-BUG-005: 修复 CLI stdout writer API 使用错误
**状态**: pending
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 1h

**描述**:
CLI 中多处使用了无效的 `std.fs.File.stdout().writer(&buffer)` API，这不是标准 Zig I/O API。

**受影响位置**（10+处）:
- src/cli/root.zig:128
- src/cli/root.zig:204
- src/cli/root.zig:223
- src/cli/root.zig:232
- src/cli/root.zig:241
- src/cli/root.zig:250
- src/cli/root.zig:259
- src/cli/root.zig:277
- src/cli/root.zig:291
- src/cli/root.zig:305

**问题代码模式**:
```zig
var stdout_buf: [4096]u8 = undefined;
const stdout = std.fs.File.stdout().writer(&stdout_buf);
// ❌ 错误：writer() 不接受缓冲区参数
```

**修复方案**:

**选项1**: 使用标准 IO（推荐）
```zig
const stdout = std.io.getStdOut().writer();
// 无需缓冲区，标准库已处理
```

**选项2**: 使用 bufferedWriter（如果需要缓冲）
```zig
var stdout_buf = std.io.bufferedWriter(std.io.getStdOut().writer());
const stdout = stdout_buf.writer();
defer stdout_buf.flush() catch {};
```

**验收标准**:
- [ ] 修复所有10+处的 stdout 使用
- [ ] 选择合适的 API（标准 IO vs buffered）
- [ ] 编译通过
- [ ] 输出正常显示

**依赖**: 
- URGENT-FIX (编译错误修复后才能测试)

**相关文件**:
- src/cli/root.zig

**笔记**:
这可能是从旧版本 Zig 迁移时遗留的问题，需要统一修改。
