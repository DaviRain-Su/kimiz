### Task-REF-005: 移除 Smart Routing
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 2h
**参考**: [Simplified Architecture Proposal](../../docs/design/simplified-architecture-proposal.md)

**描述**:
移除 Smart Routing 系统，改为用户手动选择模型。Smart Routing 的自动模型选择往往不符合用户预期。

**当前代码**:
```zig
// src/ai/routing.zig (~300 行)
pub const SmartRouter = struct {
    pub fn selectModel(self: *Self, task: TaskType, complexity: u8) !RoutingDecision;
    pub fn autoRoute(self: *Self, user_input: []const u8) !RoutingDecision;
    
    fn detectTaskType(input: []const u8) TaskType;
    fn calculateComplexity(input: []const u8) u8;
};
```

**移除内容**:
1. 删除 `src/ai/routing.zig`
2. 删除所有路由相关逻辑
3. 简化模型选择为用户手动

**替代方案**:

```bash
# 命令行选择
kimiz --model claude-sonnet-4
kimiz --model openai/gpt-4o
kimiz --model kimi-k2-5:high  # with thinking level

# 或在 TUI 中
Ctrl+L  # 打开模型选择器
```

```zig
// src/cli/root.zig
pub fn run(allocator: std.mem.Allocator) !void {
    // 解析 --model 参数
    const model_id = args.model orelse config.default_model;
    const model = try resolveModel(model_id);
    
    // 直接使用，不经过路由
    var agent = try Agent.init(allocator, .{ .model = model });
}

// src/tui/root.zig
fn handleInput(self: *TuiApp, key: Key) !void {
    switch (key) {
        .ctrl_l => try self.showModelSelector(),
        // ...
    }
}
```

**模型解析支持**:

```zig
pub fn resolveModel(model_id: []const u8) !Model {
    // 支持格式:
    // - "claude-sonnet-4"
    // - "anthropic/claude-sonnet-4"
    // - "claude-sonnet-4:high" (with thinking)
    
    var parts = std.mem.split(u8, model_id, "/");
    const provider_part = parts.next();
    const model_part = parts.next() orelse provider_part;
    
    // 解析 thinking level (e.g., ":high")
    var model_parts = std.mem.split(u8, model_part, ":");
    const base_model = model_parts.next().?;
    const thinking = model_parts.next();
    
    // 查找模型...
}
```

**需要修改的文件**:
- [ ] 删除 `src/ai/routing.zig`
- [ ] 修改 `src/cli/root.zig` (简化模型选择)
- [ ] 修改 `src/tui/root.zig` (添加模型选择器)
- [ ] 更新 `src/ai/root.zig`

**验收标准**:
- [ ] Smart Routing 完全移除
- [ ] 命令行 --model 参数工作
- [ ] TUI 模型选择器 (Ctrl+L) 工作
- [ ] 代码减少 300+ 行
- [ ] 编译通过
- [ ] 测试通过

**依赖**:
- TASK-BUG-014-fix-cli-unimplemented

**阻塞**:
- 无

**笔记**:
手动选择模型更简单可靠。用户知道自己想要什么模型。
