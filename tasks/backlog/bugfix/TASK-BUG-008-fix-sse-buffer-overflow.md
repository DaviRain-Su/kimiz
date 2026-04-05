### TASK-BUG-008: 修复 SSE 缓冲区溢出风险
**状态**: pending
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 1h

**描述**:
SSE 解析器使用固定大小缓冲区（65536字节），当行超过此大小时会静默丢弃数据。

**问题代码**: src/http.zig:155-171
```zig
const SSE_LINE_BUF_SIZE = 65536;
var line_buf: [SSE_LINE_BUF_SIZE]u8 = undefined;
var line_len: usize = 0;

while (true) {
    const n = reader.read(line_buf[line_len..]) catch break;
    // ...
    if (line_len >= SSE_LINE_BUF_SIZE) {
        // ❌ 静默跳过，数据丢失
        line_len = 0;
        continue;
    }
}
```

**问题**:
1. 超长 SSE 数据行会被丢弃
2. 没有错误提示
3. 可能导致 JSON 解析失败

**修复方案**:

**选项1**: 返回错误（推荐）
```zig
if (line_len >= SSE_LINE_BUF_SIZE) {
    log.err("SSE line exceeds buffer size: {} bytes", .{SSE_LINE_BUF_SIZE});
    return AiError.ResponseTooLarge;
}
```

**选项2**: 使用动态缓冲区
```zig
var line_list = std.ArrayList(u8).init(allocator);
defer line_list.deinit();

while (true) {
    var chunk: [4096]u8 = undefined;
    const n = reader.read(&chunk) catch break;
    if (n == 0) break;
    
    try line_list.appendSlice(chunk[0..n]);
    
    // 检查换行符
    if (std.mem.indexOfScalar(u8, chunk[0..n], '\n')) |_| {
        // 处理完整行
        const line = try line_list.toOwnedSlice();
        defer allocator.free(line);
        // ...
    }
}
```

**选项3**: 增加缓冲区大小并记录警告
```zig
const SSE_LINE_BUF_SIZE = 1024 * 1024; // 1MB

if (line_len >= SSE_LINE_BUF_SIZE) {
    log.warn("SSE line exceeds 1MB, truncating", .{});
    // 继续处理截断的数据
}
```

**验收标准**:
- [ ] 选择合适的方案
- [ ] 处理超长行不丢失数据或明确报错
- [ ] 添加大 payload 测试
- [ ] 文档化最大支持的行长度

**依赖**: 无

**相关文件**:
- src/http.zig

**笔记**:
需要确认实际 AI Provider 返回的最大行长度。
