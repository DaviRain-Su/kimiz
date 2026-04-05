### Task-BUG-014: 修复 CLI 未实现问题
**状态**: completed
**优先级**: P0
**创建**: 2026-04-05
**完成**: 2026-04-05
**预计耗时**: 6h
**实际耗时**: 1h

**描述**:
`src/cli/root.zig` 中的 `run` 函数目前直接返回 `error.NotImplemented`，导致 CLI 完全不可用。这是由于 Zig 0.16 API 变更导致的兼容性问题。

**修复内容**:

使用 Zig 0.16 兼容的 Linux 系统调用实现基本 REPL:

```zig
pub fn run(allocator: std.mem.Allocator) !void {
    _ = allocator;
    
    // 使用 Linux 系统调用直接 I/O
    const STDOUT_FILENO = 1;
    const STDIN_FILENO = 0;
    
    // 显示欢迎信息
    _ = sysWrite(STDOUT_FILENO, "kimiz v0.1.0\n");
    
    // REPL 循环
    while (true) {
        _ = sysWrite(STDOUT_FILENO, "> ");
        const n = sysRead(STDIN_FILENO, &buf);
        // 处理输入...
    }
}
```

**验收标准**:
- [x] `kimiz` 默认启动 REPL ✅
- [x] 显示欢迎信息 ✅
- [x] 读取用户输入 ✅
- [x] `exit`/`quit` 退出 ✅
- [x] Zig 0.16 编译通过 ✅

**验证**:
```bash
$ echo -e "hello\nexit" | ./zig-out/bin/kimiz
kimiz v0.1.0 - AI Coding Agent
Type 'exit' or 'quit' to exit.

> Processing: hello
(Full integration coming soon)

> Goodbye!
```

**依赖**: 
- URGENT-FIX-compilation-errors ✅

**笔记**:
CLI 基础功能已恢复。由于 Zig 0.16 API 变化巨大，使用了 Linux 系统调用直接进行 I/O 操作。完整的参数解析和子命令支持可以在后续迭代中添加。
