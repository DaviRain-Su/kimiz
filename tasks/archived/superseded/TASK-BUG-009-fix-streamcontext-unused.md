### TASK-BUG-009: 修复 Anthropic StreamContext 未使用问题
**状态**: pending
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 30分钟

**描述**:
Anthropic provider 的 stream() 函数创建了 StreamContext 但立即丢弃，没有实际使用。

**问题代码**: src/ai/providers/anthropic.zig:248
```zig
pub fn stream(..., callback: *const fn(chunk: []const u8) void) !void {
    // ...
    _ = StreamContext{ .callback = callback };  // ❌ 创建后丢弃
    
    const onLine = struct {
        fn processLine(line: []const u8) void {
            // callback 没有被传递进来
        }
    }.processLine;
    
    try http_client.postStream(url, headers, body_str, onLine);
}
```

**问题**:
1. StreamContext 创建但不使用
2. callback 无法传递给内部函数
3. 流式输出可能不工作

**修复方案**:

**使用闭包捕获 context**:
```zig
pub fn stream(..., callback: *const fn(chunk: []const u8) void) !void {
    // ...
    const Context = struct {
        cb: *const fn(chunk: []const u8) void,
        
        fn processLine(self: @This(), line: []const u8) void {
            // 解析 SSE
            // ...
            if (content) |text| {
                self.cb(text);  // ✅ 使用 callback
            }
        }
    };
    
    var ctx = Context{ .cb = callback };
    
    try http_client.postStream(url, headers, body_str, 
        struct {
            fn onLine(line: []const u8) void {
                ctx.processLine(line);
            }
        }.onLine
    );
}
```

**或者修改 postStream 支持 context**:
```zig
// 修改 http.zig 的 postStream 签名
pub fn postStream(
    self: *Self,
    url: []const u8,
    headers: []const std.http.Header,
    body: []const u8,
    context: anytype,
    callback: *const fn(@TypeOf(context), []const u8) void,
) !void
```

**验收标准**:
- [ ] StreamContext 正确传递给回调
- [ ] callback 被正确调用
- [ ] 测试 Anthropic 流式输出
- [ ] 验证其他 provider 是否有同样问题

**依赖**: 无

**相关文件**:
- src/ai/providers/anthropic.zig
- src/http.zig (如果修改 postStream)

**笔记**:
需要测试确认 Anthropic 流式输出是否真的不工作。
