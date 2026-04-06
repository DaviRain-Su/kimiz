### Task-BUG-019: 修复 OpenAI Provider tool_calls 序列化不完整
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 2h

**描述**:
`src/ai/providers/openai.zig` 中 `serializeRequest` 函数有 TODO 注释，tool_calls 序列化未完成实现。这会导致带有工具调用的请求无法正确发送到 OpenAI API。

**当前代码** (openai.zig:399):
```zig
// TODO: Handle tool_calls serialization
try req_buf.appendSlice(std.heap.page_allocator, "}");
```

**问题分析**:

1. assistant 消息的 tool_calls 没有正确序列化到 JSON
2. 当 LLM 返回 tool_call 时，无法正确构建请求

**修复方案**:

需要完整实现 tool_calls 的 JSON 序列化。参考 OpenAI API 格式：

```json
{
  "tool_calls": [
    {
      "id": "call_123",
      "type": "function", 
      "function": {
        "name": "get_weather",
        "arguments": "{\"location\":\"Boston\"}"
      }
    }
  ]
}
```

**验收标准**:
- [ ] serializeRequest 正确序列化 tool_calls
- [ ] 单元测试验证 tool_calls 序列化
- [ ] Agent 能正确发送 tool_call 结果给 LLM

**依赖**:
- URGENT-FIX-compilation-errors

**阻塞**:
- Agent 工具调用功能

**笔记**:
这是 Agent Loop 完整运作的关键依赖。发现于 2026-04-05 代码审查。
