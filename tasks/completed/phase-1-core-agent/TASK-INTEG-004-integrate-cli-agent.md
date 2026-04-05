### TASK-INTEG-004: 集成 CLI 和 Agent
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 4h

**描述**:
当前 CLI 只是 echo 用户输入，没有实际调用 Agent。

**当前状态**:
```zig
// src/cli/root.zig
while (true) {
    _ = sysWrite(STDOUT_FILENO, "Processing: ");
    _ = sysWrite(STDOUT_FILENO, input);
    _ = sysWrite(STDOUT_FILENO, "\n(Full integration coming soon)\n\n");
}
```

**目标**: CLI 真正调用 Agent

**实现步骤**:

1. **初始化 Agent**
```zig
pub fn run(allocator: std.mem.Allocator) !void {
    // 创建 Agent
    var agent = try agent.Agent.init(allocator, .{
        .model = model_from_config(),
        .tools = try tool_registry.getBuiltinTools(allocator),
    });
    defer agent.deinit();
    
    // 设置事件回调
    agent.setEventCallback(handleAgentEvent);
    
    // REPL 循环
    while (true) {
        const input = try readLine();
        if (std.mem.eql(u8, input, "exit")) break;
        
        try agent.prompt(input);
    }
}
```

2. **事件处理**
```zig
fn handleAgentEvent(evt: agent.AgentEvent) void {
    switch (evt) {
        .message_delta => |text| {
            // 流式输出
            std.debug.print("{s}", .{text});
        },
        .message_complete => |msg| {
            // 完整响应
            std.debug.print("\n", .{});
        },
        .tool_call_start => |info| {
            std.debug.print("[Calling {s}...]\n", .{info.name});
        },
        .tool_result => |result| {
            std.debug.print("[{s}: {s}]\n", .{result.tool_name, result.result.content[0].text});
        },
        .done => {},
        .err => |e| {
            std.debug.print("Error: {s}\n", .{e});
        },
    }
}
```

3. **配置管理**
```zig
// 从配置文件或环境变量读取模型选择
fn model_from_config() []const u8 {
    if (std.env.get("KIMIZ_MODEL")) |model| {
        return model;
    }
    return "gpt-4o";  // 默认
}
```

**验收标准**:
- [ ] CLI 启动 Agent
- [ ] 用户输入被传递给 Agent
- [ ] Agent 响应流式输出
- [ ] 工具调用显示进度
- [ ] `exit` 命令正确退出

**依赖**:
- TASK-BUG-024 (修复测试编译)

**阻塞**:
- 用户无法真正使用 Agent

**笔记**:
这是让项目可用的关键步骤。
