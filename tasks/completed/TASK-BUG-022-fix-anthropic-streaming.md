### TASK-BUG-022: 修复 Anthropic 流式处理
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 4h

**描述**:
Anthropic Provider 的流式处理完全损坏，`StreamContext.processLine()` 是空实现。

**位置**: `src/ai/providers/anthropic.zig:261-274`

**当前代码**:
```zig
fn processLine(self: *StreamContext, line: []const u8) void {
    // 空的！没有解析 SSE 事件
    _ = line;
    _ = self;
}
```

**问题**:
- 不解析 SSE 事件
- 不调用 callback
- 流式响应完全损坏

**修复方案**:

参考 Google Provider 的 `processLine()` 实现:

```zig
fn processLine(self: *StreamContext, line: []const u8) void {
    if (line.len == 0 or line[0] != '{') return;
    
    // 解析 JSON
    var parser = std.json.Parser.init(self.allocator, .alloc_if_needed);
    defer parser.deinit();
    
    const value = parser.parse(line) catch return;
    const obj = value.object.get("type") orelse return;
    const type_str = obj.string;
    
    if (std.mem.eql(u8, type_str, "content_block_delta")) {
        // 处理 text_delta
        if (self.callback) |cb| {
            const delta = value.object.get("delta") orelse continue;
            const text = delta.object.get("text") orelse continue;
            cb(.{ .text_delta = text.string });
        }
    } else if (std.mem.eql(u8, type_str, "message_stop")) {
        // 处理停止
        if (self.callback) |cb| {
            cb(.{ .done = {} });
        }
    }
}
```

**验收标准**:
- [ ] Anthropic 流式响应正确处理
- [ ] SSE 事件正确解析
- [ ] callback 正确调用
- [ ] text_delta 事件正常触发

**依赖**:
- TASK-BUG-021 (修复编译错误)

**阻塞**:
- Anthropic 流式功能

**笔记**:
参考 `src/ai/providers/google.zig:170-200` 的实现。
