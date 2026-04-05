### Task-BUG-016: 修复工具结果内存浅拷贝问题
**状态**: completed
**优先级**: P1
**创建**: 2026-04-05
**完成**: 2026-04-05
**预计耗时**: 2h
**实际耗时**: 30分钟

**描述**:
`src/agent/agent.zig` 中的 `continueFromToolResult` 函数对 `UserContentBlock` 进行浅拷贝，可能导致内存安全问题。

**问题代码**:
```zig
// src/agent/agent.zig:180-195
pub fn continueFromToolResult(
    self: *Self,
    tool_call_id: []const u8,
    tool_name: []const u8,
    result: ToolResult,
) !void {
    // Add tool result message
    const content = try self.allocator.alloc(core.UserContentBlock, result.content.len);
    for (result.content, 0..) |block, i| {
        content[i] = block;  // ❌ 浅拷贝！
    }
    // ...
}
```

**问题分析**:

`UserContentBlock` 是联合类型：
```zig
pub const UserContentBlock = union(enum) {
    text: []const u8,
    image: []const u8, // base64 encoded
};
```

浅拷贝 `[]const u8` 指针会导致：
1. 原始内存可能被释放（arena deinit）
2. 新分配的 `content` 数组包含悬空指针
3. 访问时可能导致段错误

**修复方案**:

```zig
pub fn continueFromToolResult(
    self: *Self,
    tool_call_id: []const u8,
    tool_name: []const u8,
    result: ToolResult,
) !void {
    // 深拷贝 content blocks
    const content = try self.allocator.alloc(core.UserContentBlock, result.content.len);
    errdefer self.allocator.free(content);  // 错误时释放
    
    for (result.content, 0..) |block, i| {
        content[i] = switch (block) {
            .text => |text| .{ .text = try self.allocator.dupe(u8, text) },
            .image => |img| .{ .image = try self.allocator.dupe(u8, img) },
        };
    }
    
    // 确保后续错误时释放已拷贝的内容
    errdefer {
        for (content) |block| {
            switch (block) {
                .text => |text| self.allocator.free(text),
                .image => |img| self.allocator.free(img),
            }
        }
    }
    
    const tool_result_msg = Message{
        .tool_result = .{
            .tool_call_id = try self.allocator.dupe(u8, tool_call_id),
            .tool_name = try self.allocator.dupe(u8, tool_name),
            .content = content,
            .is_error = result.is_error,
        },
    };
    
    try self.messages.append(self.allocator, tool_result_msg);
}
```

**验收标准**:
- [ ] 实现深拷贝逻辑
- [ ] 添加适当的错误处理（errdefer）
- [ ] 确保内存不泄漏
- [ ] 添加单元测试验证内存安全
- [ ] 编译通过，测试通过

**依赖**:
- URGENT-FIX-compilation-errors

**阻塞**:
- Agent 工具执行功能

**笔记**:
这是一个潜在的内存安全问题。虽然 Zig 的 arena 模式可能掩盖这个问题，但在长期运行的 Agent 中可能导致崩溃。
