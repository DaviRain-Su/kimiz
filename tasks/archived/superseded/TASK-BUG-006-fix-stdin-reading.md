### TASK-BUG-006: 修复 stdin 逐字节读取问题
**状态**: pending
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 1h

**描述**:
REPL 模式中使用逐字节读取 stdin 并手动搜索换行符，效率低且容易出错。

**问题代码**: src/cli/root.zig:175-180
```zig
// 当前实现：逐字节读取
var input_buf: [4096]u8 = undefined;
var input_len: usize = 0;
while (input_len < input_buf.len) {
    const byte = stdin.readByte() catch break;
    input_buf[input_len] = byte;
    input_len += 1;
    if (byte == '\n') break;
}
```

**问题**:
1. 效率低 - 每个字节一次系统调用
2. 不处理缓冲输入
3. 不处理 EOF 正确
4. 不处理 UTF-8 多字节字符

**修复方案**:

使用标准库的 buffered reader：
```zig
var stdin_buf = std.io.bufferedReader(std.io.getStdIn().reader());
const stdin = stdin_buf.reader();

var input_buf: [4096]u8 = undefined;
const line = stdin.readUntilDelimiterOrEof(&input_buf, '\n') catch |err| {
    if (err == error.EndOfStream) break;
    log.err("Failed to read stdin: {}", .{err});
    continue;
};

if (line == null) break; // EOF
const user_input = std.mem.trim(u8, line.?, &std.ascii.whitespace);
```

**验收标准**:
- [ ] 使用 bufferedReader 和 readUntilDelimiterOrEof
- [ ] 正确处理 EOF
- [ ] 正确处理错误
- [ ] 测试多行输入
- [ ] 测试 UTF-8 输入

**依赖**: 
- TASK-BUG-005 (stdout API 修复)

**相关文件**:
- src/cli/root.zig

**笔记**:
应该在 REPL 模式测试中验证各种输入场景。
