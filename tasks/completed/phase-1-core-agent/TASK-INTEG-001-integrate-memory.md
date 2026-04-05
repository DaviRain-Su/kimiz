### TASK-INTEG-001: 集成 Memory 系统到 Agent
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 4h

**描述**:
将 Memory 系统集成到 Agent，使 Agent 能够记住对话历史并在上下文中使用相关记忆。

**当前状态**:
- ✅ MemoryManager 实现完整 (三层记忆)
- ❌ Agent 未导入 memory 模块
- ❌ 未记录对话到记忆
- ❌ 未 recall 记忆用于上下文

**目标**:
```zig
pub const Agent = struct {
    // ... 现有字段 ...
    
    // 新增
    memory_manager: MemoryManager,
    
    // 新增: 每次工具执行后记录
    // 新增: 每次 AI 调用前 recall 相关记忆
};
```

**实现步骤**:

1. **在 Agent 中添加 MemoryManager**
```zig
pub const Agent = struct {
    allocator: std.mem.Allocator,
    messages: std.ArrayList(Message),
    options: AgentOptions,
    ai_client: *ai.Client,
    event_callback: ?*const fn (event: AgentEvent) void,
    state: AgentState = .idle,
    iteration_count: u32 = 0,
    
    // 新增
    memory_manager: MemoryManager,
};
```

2. **记录工具执行到记忆**
```zig
fn executeTool(self: *Self, tool_call: core.ToolCall) !ToolResult {
    const result = try self.executeToolImpl(tool_call);
    
    // 新增: 记录到记忆
    try self.memory_manager.remember(
        .tool_execution,
        try std.fmt.allocPrint(self.allocator, 
            "Executed {s} with result: {s}", 
            .{ tool_call.name, result.content[0].text }),
        50,  // importance
    );
    
    return result;
}
```

3. **在 AI 调用前 recall 相关记忆**
```zig
fn runLoop(self: *Self) !void {
    // 新增: 获取相关记忆
    const memories = try self.memory_manager.recall(
        self.getCurrentTask(),
        10,
    );
    
    // 将记忆加入上下文
    const context_with_memory = try self.buildContext(memories);
    
    const ctx = Context{
        .model = self.options.model,
        .messages = self.messages.items,
        // ...
        .system_context = context_with_memory,
    };
}
```

4. **会话结束时压缩记忆**
```zig
pub fn prompt(self: *Self, user_content: []const u8) !void {
    // ... 现有代码 ...
    
    // 会话结束或达到一定数量后压缩
    if (self.messages.items.len % 20 == 0) {
        try self.memory_manager.consolidate();
    }
}
```

**验收标准**:
- [ ] Agent 有 MemoryManager 实例
- [ ] 工具执行后记录到 ShortTermMemory
- [ ] AI 调用前 recall 相关记忆加入上下文
- [ ] 会话结束或达到阈值时 consolidate 到 LongTermMemory
- [ ] 测试验证记忆正确记录和recall

**依赖**:
- TASK-BUG-021 (修复编译错误)

**阻塞**:
- Claude Code 模式的记忆功能

**笔记**:
这是 Claude Code 模式的核心功能之一。
