### Task-BUG-017: 修复 Agent 循环中 AI 客户端重复创建问题
**状态**: completed
**优先级**: P1
**创建**: 2026-04-05
**完成**: 2026-04-05
**预计耗时**: 3h
**实际耗时**: 30分钟

**描述**:
`src/agent/agent.zig` 的 `runLoop` 函数在每次迭代中都创建新的 `Ai` 客户端，导致 HTTP 连接无法复用，性能低下。

**问题代码**:
```zig
// src/agent/agent.zig:130-165
fn runLoop(self: *Self) !void {
    self.iteration_count = 0;

    while (self.iteration_count < self.options.max_iterations) {
        self.iteration_count += 1;
        
        // ... 准备上下文 ...
        
        // ❌ 每次迭代都创建新客户端
        var ai_client = ai.Ai.init(self.allocator);
        defer ai_client.deinit();  // 连接被关闭

        const response = ai_client.complete(ctx) catch |err| {
            // ...
        };
        
        // ... 处理响应 ...
    }
}
```

**问题影响**:
1. 每次迭代建立新的 HTTP 连接
2. TCP/TLS 握手开销
3. 无法利用 HTTP keep-alive
4. 高延迟（特别是 TLS 连接）

**修复方案**:

方案 1: 在 Agent 初始化时创建客户端（推荐）
```zig
pub const Agent = struct {
    allocator: std.mem.Allocator,
    options: AgentOptions,
    state: AgentState = .idle,
    messages: std.ArrayList(Message),
    event_callback: ?*const fn (event: AgentEvent) void,
    iteration_count: u32 = 0,
    ai_client: ai.Ai,  // 复用的客户端

    pub fn init(allocator: std.mem.Allocator, options: AgentOptions) !Self {
        return .{
            .allocator = allocator,
            .options = options,
            .state = .idle,
            .messages = .empty,
            .event_callback = null,
            .ai_client = ai.Ai.init(allocator),  // 初始化客户端
        };
    }

    pub fn deinit(self: *Self) void {
        self.messages.deinit(self.allocator);
        self.ai_client.deinit();  // 清理客户端
    }

    fn runLoop(self: *Self) !void {
        while (self.iteration_count < self.options.max_iterations) {
            self.iteration_count += 1;
            
            // 复用已存在的客户端
            const response = self.ai_client.complete(ctx) catch |err| {
                // ...
            };
            
            // ...
        }
    }
};
```

方案 2: 使用连接池（更复杂，长期方案）
```zig
// 未来可以考虑实现连接池
pub const HttpConnectionPool = struct {
    // 管理多个持久连接
};
```

**需要修改的文件**:
- [ ] src/agent/agent.zig

**验收标准**:
- [ ] `Ai` 客户端在 Agent 初始化时创建
- [ ] `runLoop` 中复用客户端
- [ ] Agent deinit 时正确清理客户端
- [ ] 编译通过，测试通过
- [ ] 性能测试显示连接复用（可选）

**依赖**:
- URGENT-FIX-compilation-errors

**阻塞**:
- 无直接阻塞，但影响性能

**笔记**:
这是一个性能优化问题。当前实现每次对话轮次都建立新连接，对于多轮对话场景性能影响明显。
