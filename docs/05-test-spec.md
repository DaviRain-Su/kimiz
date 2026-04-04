: 0
# Test Spec — kimiz 测试规格

**版本**: 0.1.0  
**日期**: 2026-04-04  
**依赖**: [04-task-breakdown.md](./04-task-breakdown.md)

> ⚠️ TDD 原则：先写测试，再写实现。所有测试必须在实现前定义。

---

## 1. 测试策略

### 1.1 测试层级

| 层级 | 范围 | 工具 | 目标 |
|------|------|------|------|
| Unit Test | 单个函数/类型 | Zig 内置 test | 100% 核心逻辑覆盖 |
| Integration Test | 模块间交互 | Zig 内置 test + mock | 关键流程覆盖 |
| E2E Test | 完整 CLI 流程 | 脚本测试 | 主要用户场景 |

### 1.2 测试文件组织

```
src/
├── ai/
│   ├── types.zig
│   ├── types_test.zig      <- 类型单元测试
│   ├── models.zig
│   ├── models_test.zig
│   ├── sse.zig
│   ├── sse_test.zig
│   ├── json_utils.zig
│   ├── json_utils_test.zig
│   └── providers/
│       ├── openai.zig
│       ├── openai_test.zig
│       ├── anthropic_test.zig
│       └── google_test.zig
├── http.zig
├── http_test.zig
└── agent/
    ├── agent.zig
    └── agent_test.zig
```

---

## 2. 单元测试规格

### 2.1 ai/types.zig 测试

#### Test: StopReason 枚举映射
```zig
test "StopReason from string" {
    try std.testing.expectEqual(StopReason.stop, parseStopReason("stop"));
    try std.testing.expectEqual(StopReason.length, parseStopReason("length"));
    try std.testing.expectEqual(StopReason.tool_use, parseStopReason("tool_calls"));
    try std.testing.expectEqual(StopReason.@"error", parseStopReason("content_filter"));
    try std.testing.expectEqual(StopReason.stop, parseStopReason(null));
}
```

#### Test: Usage 成本计算
```zig
test "Usage cost calculation" {
    const model = Model{
        .cost = .{ .input = 2.5, .output = 10.0, .cache_read = 1.25, .cache_write = 0 },
        // ... other fields
    };
    var usage = Usage{ .input = 1000000, .output = 500000 };
    calculateCost(&model, &usage);
    
    try std.testing.expectApproxEqAbs(2.5, usage.cost.input, 0.001);
    try std.testing.expectApproxEqAbs(5.0, usage.cost.output, 0.001);
    try std.testing.expectApproxEqAbs(7.5, usage.cost.total, 0.001);
}
```

#### Test: Message 构造
```zig
test "UserMessage construction" {
    const msg = UserMessage{
        .content_text = "Hello",
        .timestamp = 1234567890,
    };
    try std.testing.expectEqualStrings("Hello", msg.content_text.?);
    try std.testing.expectEqual(@as(i64, 1234567890), msg.timestamp);
}
```

---

### 2.2 ai/models.zig 测试

#### Test: getModel 查找
```zig
test "getModel finds existing model" {
    const model = getModel(.openai, "gpt-4o-mini");
    try std.testing.expect(model != null);
    try std.testing.expectEqualStrings("gpt-4o-mini", model.?.id);
    try std.testing.expectEqual(KnownApi.@"openai-completions", model.?.api);
}

test "getModel returns null for unknown model" {
    const model = getModel(.openai, "unknown-model");
    try std.testing.expect(model == null);
}

test "getModelsByProvider filters correctly" {
    const models = getModelsByProvider(.anthropic);
    try std.testing.expect(models.len >= 2);
    for (models) |m| {
        try std.testing.expectEqual(KnownProvider.anthropic, m.provider);
    }
}
```

---

### 2.3 ai/sse.zig 测试

#### Test: parseSseLine 正常数据
```zig
test "parseSseLine extracts data" {
    const line = "data: {\"key\":\"value\"}";
    const result = try parseSseLine(line);
    try std.testing.expectEqualStrings("{\"key\":\"value\"}", result.?);
}

test "parseSseLine returns null for comment" {
    const line = ": keep-alive";
    const result = try parseSseLine(line);
    try std.testing.expect(result == null);
}

test "parseSseLine returns null for empty line" {
    const line = "";
    const result = try parseSseLine(line);
    try std.testing.expect(result == null);
}

test "parseSseLine returns SseDoneReceived for DONE" {
    const line = "data: [DONE]";
    const result = parseSseLine(line);
    try std.testing.expectError(error.SseDoneReceived, result);
}
```

#### Test: parseSseLine 边界条件
```zig
test "parseSseLine handles Windows line ending" {
    const line = "data: hello\r";
    const result = try parseSseLine(line);
    try std.testing.expectEqualStrings("hello", result.?);
}

test "parseSseLine ignores event field" {
    const line = "event: message";
    const result = try parseSseLine(line);
    try std.testing.expect(result == null);
}
```

---

### 2.4 ai/json_utils.zig 测试

#### Test: OpenAI 请求序列化
```zig
test "serializeOpenAIRequest basic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const model = getModel(.openai, "gpt-4o-mini").?;
    const context = Context{
        .system_prompt = "You are helpful.",
        .messages = &.{},
        .tools = &.{},
    };
    const options = StreamOptions{ .temperature = 0.5 };
    
    const json = try serializeOpenAIRequest(arena.allocator(), model, context, options, false);
    
    // 验证包含关键字段
    try std.testing.expect(std.mem.indexOf(u8, json, "\"model\":\"gpt-4o-mini\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"temperature\":0.5") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"stream\":false") != null);
}

test "serializeOpenAIRequest with messages" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const user_msg = Message{ .user = .{ .content_text = "Hello", .timestamp = 0 } };
    const context = Context{
        .messages = &.{user_msg},
    };
    
    const json = try serializeOpenAIRequest(arena.allocator(), model, context, .{}, false);
    
    try std.testing.expect(std.mem.indexOf(u8, json, "\"role\":\"user\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"content\":\"Hello\"") != null);
}
```

#### Test: Anthropic 请求序列化
```zig
test "serializeAnthropicRequest with system prompt" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const context = Context{
        .system_prompt = "You are Claude.",
        .messages = &.{},
    };
    
    const json = try serializeAnthropicRequest(arena.allocator(), model, context, .{}, false);
    
    try std.testing.expect(std.mem.indexOf(u8, json, "\"system\":\"You are Claude.\"") != null);
}
```

---

### 2.5 http.zig 测试

#### Test: HTTP 状态码映射
```zig
test "statusCodeToError maps correctly" {
    try std.testing.expectEqual(HttpError.AuthFailed, statusCodeToError(401));
    try std.testing.expectEqual(HttpError.RateLimitExceeded, statusCodeToError(429));
    try std.testing.expectEqual(HttpError.ServerError, statusCodeToError(500));
    try std.testing.expectEqual(HttpError.ServerError, statusCodeToError(503));
}
```

#### Test: HttpClient mock 测试
```zig
test "postJson with mock server" {
    // 使用测试服务器或 mock
    var client = HttpClient.init(std.testing.allocator);
    defer client.deinit();
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const response = try client.postJson(
        arena.allocator(),
        "http://localhost:9999/test",
        &.{.{ .name = "Content-Type", .value = "application/json" }},
        "{}",
    );
    
    try std.testing.expectEqualStrings("{\"status\":\"ok\"}", response);
}
```

---

### 2.6 ai/providers/openai.zig 测试

#### Test: 响应解析
```zig
test "parseOpenAIResponse basic" {
    const json =
        \\{
        \\  "id": "chatcmpl-123",
        \\  "model": "gpt-4o-mini",
        \\  "choices": [{
        \\    "finish_reason": "stop",
        \\    "message": {
        \\      "role": "assistant",
        \\      "content": "Hello!"
        \\    }
        \\  }],
        \\  "usage": {
        \\    "prompt_tokens": 10,
        \\    "completion_tokens": 5,
        \\    "total_tokens": 15
        \\  }
        \\}
    ;
    
    const msg = try parseOpenAIResponse(arena.allocator(), json);
    
    try std.testing.expectEqualStrings("Hello!", msg.content[0].text.text);
    try std.testing.expectEqual(StopReason.stop, msg.stop_reason);
    try std.testing.expectEqual(@as(u64, 10), msg.usage.input);
}

test "parseOpenAIResponse with tool calls" {
    const json =
        \\{
        \\  "choices": [{
        \\    "finish_reason": "tool_calls",
        \\    "message": {
        \\      "role": "assistant",
        \\      "content": null,
        \\      "tool_calls": [{
        \\        "id": "call_123",
        \\        "type": "function",
        \\        "function": {
        \\          "name": "get_time",
        \\          "arguments": "{}"
        \\        }
        \\      }]
        \\    }
        \\  }]
        \\}
    ;
    
    const msg = try parseOpenAIResponse(arena.allocator(), json);
    
    try std.testing.expectEqual(StopReason.tool_use, msg.stop_reason);
    try std.testing.expectEqualStrings("get_time", msg.content[0].tool_call.name);
}
```

#### Test: 流式 chunk 解析
```zig
test "parseOpenAIStreamChunk text delta" {
    const chunk =
        \\{"id":"chatcmpl-abc","choices":[{"delta":{"content":"Hello"},"index":0}]}
    ;
    
    const event = try parseOpenAIStreamChunk(arena.allocator(), chunk);
    
    try std.testing.expectEqual(AssistantMessageEventType.text_delta, event);
    try std.testing.expectEqualStrings("Hello", event.text_delta.delta);
}

test "parseOpenAIStreamChunk tool call delta" {
    const chunk =
        \\{"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\\"tz\\":\\"UTC\\"}"}}]}}]}
    ;
    
    const event = try parseOpenAIStreamChunk(arena.allocator(), chunk);
    
    try std.testing.expectEqual(AssistantMessageEventType.toolcall_delta, event);
}
```

---

### 2.7 agent/agent.zig 测试

#### Test: Agent 初始化和销毁
```zig
test "Agent init and deinit" {
    var ai = try Ai.init(std.testing.allocator);
    defer ai.deinit();
    
    const agent = try Agent.init(std.testing.allocator, &ai, .{
        .model = getModel(.openai, "gpt-4o-mini").?,
        .system_prompt = "You are helpful.",
    });
    defer agent.deinit();
    
    try std.testing.expectEqualStrings("You are helpful.", agent.state.system_prompt.?);
}
```

#### Test: build_context
```zig
test "Agent build_context" {
    var agent = // ... init agent
    
    // Add some messages
    try agent.state.messages.append(.{ .user = .{ .content_text = "Hello", .timestamp = 0 } });
    
    const context = agent.buildContext();
    
    try std.testing.expectEqual(@as(usize, 1), context.messages.len);
    try std.testing.expectEqualStrings("Hello", context.messages[0].user.content_text.?);
}
```

---

## 3. 集成测试规格

### 3.1 AI 层集成测试

#### Test: OpenAI 完整流程（mock）
```zig
test "OpenAI complete flow with mock" {
    var ai = try Ai.init(std.testing.allocator);
    defer ai.deinit();
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const model = getModel(.openai, "gpt-4o-mini").?;
    const context = Context{
        .messages = &.{
            .{ .user = .{ .content_text = "Say hi", .timestamp = 0 } },
        },
    };
    
    const response = try ai.complete(arena.allocator(), model, context, .{});
    
    try std.testing.expect(response.content.len > 0);
    try std.testing.expectEqual(StopReason.stop, response.stop_reason);
}
```

#### Test: 流式回调测试
```zig
test "OpenAI stream with callback" {
    var deltas = std.ArrayList([]const u8).init(std.testing.allocator);
    defer deltas.deinit();
    
    const CallbackCtx = struct {
        deltas: *std.ArrayList([]const u8),
    };
    
    const callback = struct {
        fn cb(ctx: *anyopaque, event: AssistantMessageEvent) void {
            const c = @as(*CallbackCtx, @ptrCast(@alignCast(ctx)));
            switch (event) {
                .text_delta => |d| c.deltas.append(d.delta) catch unreachable,
                else => {},
            }
        }
    }.cb;
    
    var ctx = CallbackCtx{ .deltas = &deltas };
    
    const response = try ai.stream(arena.allocator(), model, context, .{}, &ctx, callback);
    
    try std.testing.expect(deltas.items.len > 0);
}
```

---

### 3.2 Agent 集成测试

#### Test: Agent 单轮对话
```zig
test "Agent single turn conversation" {
    var ai = try Ai.init(std.testing.allocator);
    defer ai.deinit();
    
    var agent = try Agent.init(std.testing.allocator, &ai, .{
        .model = getModel(.openai, "gpt-4o-mini").?,
    });
    defer agent.deinit();
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    // Capture events
    var events = std.ArrayList(AgentEvent).init(std.testing.allocator);
    defer events.deinit();
    
    agent.subscribe(&events, struct {
        fn cb(ctx: *anyopaque, event: AgentEvent) void {
            const list = @as(*std.ArrayList(AgentEvent), @ptrCast(@alignCast(ctx)));
            list.append(event) catch unreachable;
        }
    }.cb);
    
    try agent.prompt(arena.allocator(), "Hello");
    
    // Verify events
    try std.testing.expect(events.items.len >= 4); // agent_start, turn_start, message_*, agent_end
}
```

#### Test: Agent Tool Calling
```zig
test "Agent tool calling flow" {
    // Define a test tool
    const test_tool = AgentTool{
        .tool = .{
            .name = "echo",
            .description = "Echo the input",
            .parameters_json = "{\"type\":\"object\",\"properties\":{\"msg\":{\"type\":\"string\"}}}",
        },
        .execute_fn = struct {
            fn cb(ctx: *anyopaque, arena: std.mem.Allocator, args: std.json.Value) !ToolResult {
                _ = ctx;
                const msg = args.object.get("msg").?.string;
                const content = try arena.dupe(u8, msg);
                return .{ .content = &.{.{ .text = .{ .text = content } }}, .is_error = false };
            }
        }.cb,
        .ctx = undefined,
    };
    
    var agent = try Agent.init(std.testing.allocator, &ai, .{
        .model = model,
        .tools = &.{test_tool},
    });
    
    try agent.prompt(arena.allocator(), "Use echo to say hello");
    
    // Verify tool was called
    try std.testing.expect(agent.state.messages.items.len >= 3); // user, assistant (tool call), tool result
}
```

---

## 4. 边界条件测试

### 4.1 必须覆盖的边界条件

| # | 边界条件 | 测试文件 | 测试名称 |
|---|----------|----------|----------|
| 1 | 空 Context | json_utils_test.zig | "serialize with empty messages" |
| 2 | API Key 含空格 | types_test.zig | "api key trimming" |
| 3 | SSE 行末 `\r\n` | sse_test.zig | "parseSseLine handles Windows line ending" |
| 4 | 工具参数为 null JSON | openai_test.zig | "parse tool call with null arguments" |
| 5 | AssistantMessage 无 content | openai_test.zig | "parse empty content response" |
| 6 | max_tokens 超出模型限制 | stream_test.zig | "clamp max_tokens to model limit" |
| 7 | usage 为 null | openai_test.zig | "parse response without usage" |
| 8 | UTF-8 截断 | sse_test.zig | "handle incomplete UTF-8 in chunk" |
| 9 | 空工具名 | agent_test.zig | "skip tool call with empty name" |
| 10 | context_window 超出 | openai_test.zig | "handle context exceeded error" |
| 11 | 重复工具 ID | openai_test.zig | "handle duplicate tool call ids" |
| 12 | 流式连接中断 | http_test.zig | "handle stream interruption" |
| 13 | 无效 JSON 响应 | openai_test.zig | "handle invalid JSON response" |
| 14 | 401/403/429 错误 | http_test.zig | "handle auth and rate limit errors" |
| 15 | Fireworks 重复循环 | stream_guard_test.zig | "detects repetition loop" |
| 16 | 重复检测误报 | stream_guard_test.zig | "avoids false positives" |

---

## 5. E2E 测试规格

### 5.1 测试脚本

```bash
#!/bin/bash
# tests/e2e/test_basic.sh

set -e

# Build
zig build

# Test 1: Help
./zig-out/bin/kimiz --help

# Test 2: Single prompt (requires OPENAI_API_KEY)
./zig-out/bin/kimiz --model openai/gpt-4o-mini "Say hello in 5 words"

# Test 3: REPL mode (send input and exit)
echo -e "Hello\nexit" | ./zig-out/bin/kimiz

echo "All E2E tests passed!"
```

### 5.2 测试场景

| 场景 | 命令 | 预期结果 |
|------|------|----------|
| 帮助信息 | `kimiz --help` | 显示用法说明 |
| 单次提问 | `kimiz "Hello"` | 输出 LLM 响应 |
| 指定模型 | `kimiz --model anthropic/claude-haiku-4-20250514 "Hi"` | 使用 Anthropic |
| 系统提示 | `kimiz --system "Be concise" "Hello"` | 响应简洁 |
| 非流式 | `kimiz --no-stream "Hello"` | 等待完整响应后输出 |
| REPL | `kimiz` 然后输入 | 交互式对话 |

---

## 6. 测试运行命令

```bash
# 运行所有测试
zig build test

# 运行特定模块测试
zig test src/ai/types_test.zig
zig test src/ai/sse_test.zig

# 运行带日志的测试
zig build test -- --nocapture

# E2E 测试
./tests/e2e/test_basic.sh
```

---

## 7. Mock 服务器规格

用于测试的 mock HTTP 服务器：

```zig
// tests/mock_server.zig
pub const MockServer = struct {
    // 配置预期请求和响应
    pub fn expect(method: []const u8, path: []const u8, response: []const u8) void;
    
    // 启动服务器
    pub fn start(self: *MockServer) !u16;  // 返回端口
    
    // 停止服务器
    pub fn stop(self: *MockServer) void;
    
    // 验证所有预期都被满足
    pub fn verify(self: *MockServer) !void;
};
```

---

## 验收标准（进入 Phase 6 的门槛）

- [ ] 所有数据类型有单元测试
- [ ] 所有 Provider 有解析测试
- [ ] SSE 解析器有完整边界测试
- [ ] HTTP 层有错误码映射测试
- [ ] Agent 有事件流程测试
- [ ] 14 个边界条件都有对应测试
- [ ] 测试能在隔离环境运行（无外部 API 依赖）
- [ ] `zig build test` 命令能运行所有测试
