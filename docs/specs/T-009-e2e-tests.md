# T-009-E2E: 补充端到端测试

**任务类型**: Testing  
**优先级**: P1  
**阻塞**: 依赖于 FIX-ZIG-015 和 T-092-VERIFY  
**预计耗时**: 4h

---

## 背景

当前项目的测试覆盖率极低。`zig build test` 虽然能运行（在编译修复后），但现有测试主要集中在底层模块的孤立单元测试上，缺乏对 **AI Provider 解析**、**Agent 工具调用**、**Agent Loop 基础流程** 的端到端验证。

本任务的目标是为这些核心路径补充测试，确保后续改动不会破坏基础功能。

---

## 测试策略

### 原则
1. **不依赖外部网络**: 所有 AI Provider 测试使用 mock JSON，不调用真实 API
2. **最小侵入性**: 尽量测试已有函数的输入输出，不为了测试而重构代码
3. **快速执行**: 每个测试应该在毫秒级完成

### 测试位置

优先使用已有的测试入口：
- `tests/integration_tests.zig`（如果存在且是 `zig build test` 的入口）
- 或者在 `src/` 各模块的 `test {}` 块中直接添加

通过运行 `zig build test --verbose` 确认测试入口。

---

## 测试清单

### 1. AI Provider 解析测试

**目标文件**: `src/ai/providers/kimi.zig`（当前默认 Provider）

#### Test 1.1: 请求序列化
测试 `serializeKimiRequest`（或类似函数）能正确把 Zig struct 转成 JSON。

```zig
test "kimi provider request serialization" {
    const allocator = std.testing.allocator;
    const request = ai.Request{
        .model = "kimi-k2.5",
        .messages = &[_]ai.Message{
            .{ .role = .user, .content = "hello" },
        },
    };
    const json = try kimiz_provider.serializeRequest(allocator, request);
    defer allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "kimi-k2.5") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "hello") != null);
}
```

> 注意：实际的函数名和 struct 名请阅读 `src/ai/providers/kimi.zig` 后确定。

#### Test 1.2: 响应解析
用 mock JSON 字符串测试响应解析逻辑。

```zig
test "kimi provider response parsing" {
    const mock_response =
        \\{"choices":[{"message":{"content":"world"},"finish_reason":"stop"}]}
    ;
    // 调用 provider 的 parseResponse 函数
    // 验证返回的 content == "world" 且 finish_reason == .stop
}
```

### 2. 工具调用测试

**目标文件**: `src/agent/tools/read_file.zig`, `src/agent/tools/bash.zig`

#### Test 2.1: read_file 读取测试文件
```zig
test "read_file tool reads existing file" {
    const allocator = std.testing.allocator;
    // 创建一个临时文件，写入已知内容
    const temp_path = ".zig-cache/test_read_file.txt";
    try std.fs.cwd().writeFile(.{
        .sub_path = temp_path,
        .data = "hello from test",
    });
    
    // 调用 read_file tool
    const result = try read_file_tool.execute(allocator, temp_path);
    defer allocator.free(result);
    
    try std.testing.expectEqualStrings("hello from test", result);
}
```

#### Test 2.2: bash 执行简单命令
```zig
test "bash tool executes echo command" {
    const allocator = std.testing.allocator;
    const result = try bash_tool.execute(allocator, "echo test_output");
    defer allocator.free(result);
    
    try std.testing.expect(std.mem.indexOf(u8, result, "test_output") != null);
}
```

> 注意：bash 工具可能要求用户确认（除非在 YOLO 模式下）。请阅读 `src/agent/tools/bash.zig` 的实现，确定如何绕过确认（例如直接调用底层执行函数，而不是经过 `AgentTool.execute` 包装）。

### 3. Agent Loop 基础测试

**目标文件**: `src/agent/agent.zig`

#### Test 3.1: 消息历史累积
创建一个 mock provider，让它总是返回固定字符串。验证 Agent Loop 运行一轮后，messages 数组中包含 user 和 assistant 两条消息。

```zig
test "agent loop accumulates messages" {
    const allocator = std.testing.allocator;
    var mock_provider = MockProvider.init("mock response");
    
    var agent = try Agent.init(allocator, .{
        .provider = &mock_provider.provider,
        // ... 其他必要选项
    });
    defer agent.deinit();
    
    try agent.prompt("hello");
    
    try std.testing.expect(agent.messages.items.len >= 2);
    try std.testing.expectEqual(ai.Role.user, agent.messages.items[0].role);
    try std.testing.expectEqual(ai.Role.assistant, agent.messages.items[1].role);
}
```

> 注意：需要检查 `Agent` struct 的字段名是否为 `messages`，以及 `prompt()` 的签名。如果 `messages` 不是 `ArrayList`，请按实际类型调整。

### 4. HTTP Client 测试

**目标文件**: `src/http.zig`

#### Test 4.1: Response 结构体生命周期
如果 `Response` 结构体有 `deinit`，测试分配和释放不泄漏。

```zig
test "http response deinit does not leak" {
    const allocator = std.testing.allocator;
    var response = http.Response{
        .allocator = allocator,
        .body = try allocator.dupe(u8, "test body"),
        .status = 200,
    };
    response.deinit();
}
```

### 5. Tool Registry 测试

**目标文件**: `src/agent/registry.zig`

#### Test 5.1: 默认注册表包含预期工具
```zig
test "default tool registry contains expected tools" {
    const allocator = std.testing.allocator;
    var registry = try ToolRegistry.createDefaultRegistry(allocator);
    defer registry.deinit();
    
    try std.testing.expect(registry.get("read_file") != null);
    try std.testing.expect(registry.get("bash") != null);
    try std.testing.expect(registry.get("write_file") != null);
}
```

---

## 实施步骤

1. **阅读现有测试结构**
   - 运行 `zig build test --verbose` 看测试是如何组织的
   - 查看 `tests/` 目录下有什么文件
   - 查看 `src/` 下哪些文件已经有 `test {}` 块

2. **逐个添加测试**
   - 每个测试一个 commit（或一个 PR）
   - 先加最简单的（HTTP Response / Tool Registry）
   - 再加需要 mock 的（Provider / Agent Loop）

3. **处理测试失败**
   - 如果测试揭示了 bug，修复它
   - 如果是为了测试而需要暴露内部 API，考虑把函数标记为 `pub` 或在同一文件中测试

---

## 验收标准

- [ ] `zig build test` 成功，且新增 **至少 5 个** 有意义的测试
- [ ] 新增测试覆盖以下至少 3 个领域：Provider 解析、工具调用、Agent Loop、HTTP Client、Tool Registry
- [ ] 所有新增测试不依赖外部网络
- [ ] 所有新增测试执行时间 < 1 秒（总共）
- [ ] 测试文件有清晰命名和注释

---

## 快速参考

### 如何查找可测试的函数
```bash
# 查找已有的 test 块
grep -rn "^test " src/

# 查找 public 函数
grep -rn "^pub fn " src/ai/providers/kimi.zig
```

### Zig 测试常用 API
- `std.testing.allocator` - 检测内存泄漏
- `std.testing.expectEqualStrings(a, b)` - 字符串相等
- `std.testing.expectEqual(expected, actual)` - 一般相等
- `std.testing.expect(condition)` - 布尔断言
