### TASK-BUG-026: 修复 Zig 0.16 argsAlloc API 变更
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 15分钟
**阻塞**: 所有开发工作

**描述**:
Zig 0.16 中 `std.process.argsAlloc` 函数已被移除或更名，导致编译错误。

**错误信息**:
```
src/cli/root.zig:86:33: error: root source file struct 'process' has no member named 'argsAlloc'
    const args = try std.process.argsAlloc(allocator);
                     ~~~~~~~~~~~^~~~~~~~~~
```

**修复方案**:

方案 1: 使用 `std.process.ArgIterator` (推荐)
```zig
// 替换前:
const args = try std.process.argsAlloc(allocator);
defer std.process.argsFree(allocator, args);

// 替换后:
var arg_iter = std.process.ArgIterator.initWithAllocator(allocator);
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

方案 2: 使用 `std.os.argv` (简单但功能有限)
```zig
const args = std.os.argv;
// 注意: 需要手动转换 [][*:0]u8 到 [][]u8
```

**文件位置**:
- `src/cli/root.zig:86`

**验收标准**:
- [ ] `zig build` 编译成功
- [ ] CLI 参数解析正常工作
- [ ] `kimiz --help` 显示正确
- [ ] `kimiz skill <id>` 命令正常工作

**依赖**:
- 无

**阻塞**:
- 所有其他开发工作

**参考**:
- Zig 0.16 标准库文档: `std.process.ArgIterator`
