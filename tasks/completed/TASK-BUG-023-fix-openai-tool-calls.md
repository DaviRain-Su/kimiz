### TASK-BUG-023: 完成 OpenAI tool_calls 序列化
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 2h

**描述**:
OpenAI Provider 的 `serializeRequest` 函数中，tool_calls 序列化未完成。

**位置**: `src/ai/providers/openai.zig:399`

**当前代码**:
```zig
// TODO: Handle tool_calls serialization
try req_buf.appendSlice(std.heap.page_allocator, "}");
```

**问题**:
assistant 消息的 tool_calls 没有正确序列化到 JSON，导致带有工具调用的请求无法正确构建。

**修复方案**:

参考 OpenAI API 格式:

```json
{
  "tool_calls": [
    {
      "id": "call_abc123",
      "type": "function",
      "function": {
        "name": "get_weather",
        "arguments": "{\"location\":\"Boston\"}"
      }
    }
  ]
}
```

实现完整的 tool_calls 序列化:

```zig
// 在 assistant 消息序列化中添加
if (msg.assistant.tool_calls) |tool_calls| {
    try req_buf.appendSlice(std.heap.page_allocator, ",\"tool_calls\":[");
    for (tool_calls, 0..) |tc, tc_idx| {
        if (tc_idx > 0) try req_buf.appendSlice(std.heap.page_allocator, ",");
        try req_buf.appendSlice(std.heap.page_allocator, "{\"id\":\"");
        try req_buf.appendSlice(std.heap.page_allocator, tc.id);
        try req_buf.appendSlice(std.heap.page_allocator, "\",\"type\":\"function\",\"function\":{\"name\":\"");
        try req_buf.appendSlice(std.heap.page_allocator, tc.function.name);
        try req_buf.appendSlice(std.heap.page_allocator, "\",\"arguments\":");
        // arguments 是 JSON 字符串，需要转义
        try writeEscapedJsonString(req_buf.writer(), tc.function.arguments);
        try req_buf.appendSlice(std.heap.page_allocator, "}}");
    }
    try req_buf.appendSlice(std.heap.page_allocator, "]");
}
```

**验收标准**:
- [ ] serializeRequest 正确序列化 tool_calls
- [ ] 单元测试验证 tool_calls 序列化
- [ ] Agent 能正确发送 tool_call 结果给 LLM

**依赖**:
- TASK-BUG-021 (修复编译错误)

**阻塞**:
- Agent 工具调用功能

**笔记**:
这是 Agent Loop 完整运作的关键依赖。
