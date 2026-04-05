### Task-FEAT-007: 实现 Prompt Caching 系统
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 6h

**描述**:
实现稳定的 prompt 前缀缓存机制，避免每次 API 调用都传输完整的静态上下文。

**目标功能**:

1. **Prompt 分层**
   - **Stable Prefix** (缓存): 系统指令 + 工具描述 + Workspace 摘要
   - **Dynamic Content** (每次传输): 用户消息 + 对话历史 + Memory

2. **PromptCache 结构**
```zig
pub const PromptCache = struct {
    allocator: std.mem.Allocator,
    stable_prefix: []const u8,       // 缓存的稳定部分
    workspace_hash: u32,             // workspace 指纹，变化时重建
    tools_hash: u32,                 // 工具列表指纹
    last_updated: i64,
    
    pub fn getOrBuild(self: *Self, workspace: *WorkspaceInfo, tools: []const Tool) ![]const u8 {
        // 检查是否需要重建
        if (self.isValid(workspace, tools)) {
            return self.stable_prefix;
        }
        // 重建 stable prefix
        return try self.buildPrefix(workspace, tools);
    }
};
```

3. **Provider 适配**
   - OpenAI: 在首条 user 消息前插入 system
   - Anthropic: 使用已有的 system 字段 + cache tokens
   - Google: 使用 systemInstruction 字段

**验收标准**:
- [ ] Stable prefix 正确缓存和失效
- [ ] Token 消耗降低 30-50%
- [ ] 集成到 Agent.runLoop()
- [ ] 基准测试验证

**依赖**:
- Task-FEAT-006 (WorkspaceContext)

**阻塞**:
- Context Truncation (Task-FEAT-008)

**笔记**:
这是降低 API 成本的关键优化。
