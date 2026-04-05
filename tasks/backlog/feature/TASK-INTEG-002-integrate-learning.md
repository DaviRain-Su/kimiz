### TASK-INTEG-002: 集成 Learning 系统到 Agent
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 4h

**描述**:
将 Learning 系统集成到 Agent，使 Agent 能够追踪工具使用、记录模型性能并自适应行为。

**当前状态**:
- ✅ LearningEngine 实现完整 (追踪、偏好)
- ❌ Agent 未导入 learning 模块
- ❌ 未追踪工具使用
- ❌ 未记录模型性能

**目标**:
```zig
pub const Agent = struct {
    // ... 现有字段 ...
    
    // 新增
    learning_engine: LearningEngine,
};
```

**实现步骤**:

1. **在 Agent 中添加 LearningEngine**
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
    learning_engine: LearningEngine,
};
```

2. **记录工具使用**
```zig
fn executeTool(self: *Self, tool_call: core.ToolCall) !ToolResult {
    const start_time = std.time.milliTimestamp();
    const result = try self.executeToolImpl(tool_call);
    const end_time = std.time.milliTimestamp();
    
    // 新增: 记录工具使用
    self.learning_engine.recordToolUsage(.{
        .tool_name = tool_call.name,
        .success = !result.is_error,
        .execution_time_ms = @intCast(end_time - start_time),
        .parameters = tool_call.arguments,
    });
    
    return result;
}
```

3. **记录模型性能**
```zig
fn runLoop(self: *Self) !void {
    const start_time = std.time.milliTimestamp();
    const response = self.ai_client.complete(ctx) catch |err| {
        // 记录失败
        self.learning_engine.recordModelPerformance(.{
            .success = false,
            .latency_ms = @intCast(std.time.milliTimestamp() - start_time),
            .error = @errorName(err),
        });
        return err;
    };
    const end_time = std.time.milliTimestamp();
    
    // 新增: 记录成功
    self.learning_engine.recordModelPerformance(.{
        .success = true,
        .latency_ms = @intCast(end_time - start_time),
        .model_id = self.options.model.id,
        .task_type = self.getCurrentTaskType(),
    });
}
```

4. **使用自适应行为**
```zig
fn shouldAutoApprove(self: *Self, tool_name: []const u8) bool {
    // 新增: 检查是否应该自动批准
    return self.learning_engine.shouldAutoApprove(tool_name);
}
```

5. **持久化学习数据**
```zig
pub fn deinit(self: *Self) void {
    // 保存学习数据
    self.learning_engine.save(self.allocator) catch {};
    self.learning_engine.deinit();
    // ... 现有清理 ...
}
```

**验收标准**:
- [ ] Agent 有 LearningEngine 实例
- [ ] 每次工具执行记录到 ToolUsagePattern
- [ ] 每次模型调用记录到 ModelMetrics
- [ ] shouldAutoApprove() 正确判断
- [ ] 学习数据持久化

**依赖**:
- TASK-BUG-021 (修复编译错误)
- TASK-INTEG-001 (集成 Memory)

**阻塞**:
- Claude Code 模式的自适应功能

**笔记**:
这是 Claude Code 模式区别于简单 SDK 的关键。
