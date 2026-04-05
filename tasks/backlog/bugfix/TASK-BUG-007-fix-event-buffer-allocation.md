### TASK-BUG-007: 修复事件回调中的缓冲区分配问题
**状态**: pending
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 30分钟

**描述**:
事件回调函数在每次调用时都创建新的 4096 字节缓冲区，浪费栈空间且效率低。

**问题代码**: src/cli/root.zig:145-165
```zig
const event_callback = struct {
    fn onEvent(event: core.AgentEvent) void {
        var stdout_buf: [4096]u8 = undefined;  // ❌ 每次事件都创建
        const stdout = std.fs.File.stdout().writer(&stdout_buf);
        // ...
    }
}.onEvent;
```

**问题**:
1. 每次事件（可能很频繁）都分配 4KB 栈空间
2. 在流式输出时可能有数百次事件
3. 可能导致栈溢出

**修复方案**:

**选项1**: 使用共享的输出机制（推荐）
```zig
const event_callback = struct {
    fn onEvent(event: core.AgentEvent) void {
        const stdout = std.io.getStdOut().writer();
        // 直接使用，无需缓冲
        switch (event) {
            .thinking => stdout.print("🤔 {s}\n", .{event.thinking}) catch {},
            // ...
        }
    }
}.onEvent;
```

**选项2**: 使用闭包捕获共享缓冲区
```zig
// 在外部创建一次
var stdout_buf = std.io.bufferedWriter(std.io.getStdOut().writer());

// 回调中使用
const event_callback = struct {
    writer: *@TypeOf(stdout_buf),
    
    fn onEvent(self: @This(), event: core.AgentEvent) void {
        const stdout = self.writer.writer();
        // ...
        self.writer.flush() catch {};
    }
}.onEvent;
```

**验收标准**:
- [ ] 移除事件回调中的缓冲区分配
- [ ] 使用共享的输出机制
- [ ] 测试流式输出性能
- [ ] 验证无栈溢出

**依赖**: 
- TASK-BUG-005 (stdout API 修复)

**相关文件**:
- src/cli/root.zig

**笔记**:
这是性能优化问题，在流式输出场景下影响明显。
