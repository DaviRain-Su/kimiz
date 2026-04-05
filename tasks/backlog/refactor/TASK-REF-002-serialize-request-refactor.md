### Task-REF-002: 重构请求序列化逻辑
**状态**: pending
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 4h

**描述**:
当前的请求序列化使用手动字符串拼接，代码冗长且容易出错。应该使用 Zig 的 JSON 序列化或构建器模式。

**当前代码**:
```zig
// src/ai/providers/openai.zig:250-310
fn serializeRequest(ctx: core.Context) ![]u8 {
    // 手动构建 JSON 字符串
    var req_buf: std.ArrayList(u8) = .empty;
    try req_buf.appendSlice(std.heap.page_allocator, "{\"model\":\"");
    try req_buf.appendSlice(std.heap.page_allocator, ctx.model.id);
    try req_buf.appendSlice(std.heap.page_allocator, "\",\"messages\":[");
    // ... 大量手动拼接
}
```

**问题**:
1. 代码冗长（~100 行）
2. 容易出错（引号、逗号）
3. 难以维护
4. 不处理特殊字符转义

**修复方案**:

使用 Zig 的 JSON 序列化：
```zig
const OpenAIRequest = struct {
    model: []const u8,
    messages: []const OpenAIMessage,
    temperature: f32,
    max_tokens: u32,
    stream: bool,
    tools: ?[]const OpenAITool = null,
};

fn serializeRequest(allocator: std.mem.Allocator, ctx: core.Context) ![]u8 {
    const request = OpenAIRequest{
        .model = ctx.model.id,
        .messages = try convertMessages(allocator, ctx.messages),
        .temperature = ctx.temperature,
        .max_tokens = ctx.max_tokens,
        .stream = ctx.stream,
        .tools = if (ctx.tools.len > 0) try convertTools(allocator, ctx.tools) else null,
    };
    
    return try std.json.stringifyAlloc(allocator, request, .{
        .emit_null_optional_fields = false,
    });
}
```

**需要修改的文件**:
- [ ] src/ai/providers/openai.zig
- [ ] src/ai/providers/anthropic.zig
- [ ] src/ai/providers/google.zig
- [ ] src/ai/providers/kimi.zig

**验收标准**:
- [ ] 使用 JSON 序列化替代手动拼接
- [ ] 代码量减少 50%+
- [ ] 正确处理特殊字符
- [ ] 编译通过，测试通过

**依赖**:
- TASK-BUG-013-fix-page-allocator-abuse

**阻塞**:
- 无直接阻塞

**笔记**:
这是一个代码质量改进。手动 JSON 构建容易出错，应该使用标准库。
