### TASK-DOCS-003: 为 getToolDefinitions 添加内存所有权文档
**状态**: pending
**优先级**: P3
**创建**: 2026-04-05
**预计耗时**: 15分钟

**描述**:
Agent.getToolDefinitions() 返回的切片使用 toOwnedSlice() 分配，调用者必须释放，但缺少文档说明。

**问题代码**: src/agent/agent.zig:268
```zig
pub fn getToolDefinitions(self: *Self) ![]const core.Tool {
    // ...
    return tools.toOwnedSlice(self.allocator);  // ⚠️ 返回需要释放的内存
}
// ❌ 没有文档说明调用者需要 free
```

**问题**:
1. 调用者不知道需要释放内存
2. 可能导致内存泄漏
3. 内存所有权不明确

**修复方案**:

**添加文档注释**:
```zig
/// Get tool definitions for the current agent
/// 
/// Returns a slice of tool definitions that must be freed by the caller.
/// The slice is allocated using self.allocator.
/// 
/// Example:
/// ```zig
/// const tools = try agent.getToolDefinitions();
/// defer agent.allocator.free(tools);
/// // use tools...
/// ```
/// 
/// Returns: Owned slice of Tool definitions
/// Caller owns: The returned slice (must be freed)
pub fn getToolDefinitions(self: *Self) ![]const core.Tool {
    // ...
    return tools.toOwnedSlice(self.allocator);
}
```

**或者改为 Caller-owned 命名约定**:
```zig
/// Caller must free the returned slice
pub fn getToolDefinitionsOwned(self: *Self) ![]const core.Tool {
    // ...
}
```

**验收标准**:
- [ ] 添加清晰的文档注释
- [ ] 说明调用者必须释放内存
- [ ] 提供使用示例
- [ ] 检查所有调用点是否正确释放

**依赖**: 无

**相关文件**:
- src/agent/agent.zig

**笔记**:
这是文档问题，不影响功能但影响 API 使用安全性。
