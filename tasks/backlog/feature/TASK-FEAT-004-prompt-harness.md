### Task-FEAT-004: 实现 Prompt Cache (提示缓存)
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 5h
**参考**: [Coding Agent Components Analysis](../../docs/design/coding-agent-components-analysis.md)

**描述**:
根据 Sebastian Raschka 的文章，Prompt Cache 是 Coding Agent 的第二核心组件。它通过缓存稳定的提示前缀（系统指令、工具描述、工作区摘要）来减少重复计算，提高响应速度。

**核心概念**:

```
Full Prompt = Stable Prefix (cached) + Dynamic Content

Stable Prefix:
- 系统指令（system prompt）
- 工具描述（tool definitions）
- 工作区摘要（workspace summary）

Dynamic Content:
- 短期记忆（short-term memory）
- 最近对话（recent transcript）
- 用户请求（user request）
```

**实现方案**:

```zig
// src/prompts/cache.zig
pub const PromptCache = struct {
    allocator: std.mem.Allocator,
    
    // 稳定前缀（缓存）
    stable_prefix: StablePrefix,
    stable_prefix_hash: u64,
    
    // 动态内容
    dynamic_content: DynamicContent,
    
    pub fn init(allocator: std.mem.Allocator) Self;
    
    /// 构建或更新稳定前缀
    pub fn buildStablePrefix(
        self: *PromptCache,
        config: PromptConfig,
    ) !void;
    
    /// 检查配置是否变化
    pub fn isCacheValid(self: PromptCache, new_config: PromptConfig) bool;
    
    /// 构建完整提示
    pub fn buildFullPrompt(
        self: *PromptCache,
        dynamic: DynamicContent,
    ) ![]const u8;
    
    pub fn deinit(self: *PromptCache) void;
};

pub const StablePrefix = struct {
    system_prompt: []const u8,
    tool_definitions: []const u8,
    workspace_summary: []const u8,
    
    /// 序列化为可缓存格式
    pub fn serialize(self: StablePrefix) ![]const u8;
    
    /// 计算哈希用于比较
    pub fn hash(self: StablePrefix) u64;
};

pub const DynamicContent = struct {
    short_term_memory: []const u8,
    recent_transcript: []const Message,
    user_request: []const u8,
};

pub const PromptConfig = struct {
    system_prompt: []const u8,
    tools: []const Tool,
    workspace: WorkspaceContext,
};
```

**缓存策略**:

```zig
pub const CacheStrategy = struct {
    /// 当以下任一变化时，重建稳定前缀
    pub fn shouldRebuild(old: PromptConfig, new: PromptConfig) bool {
        return !std.mem.eql(u8, old.system_prompt, new.system_prompt) or
               !toolsEqual(old.tools, new.tools) or
               !workspaceEqual(old.workspace, new.workspace);
    }
};
```

**与 Provider 集成**:

```zig
// src/ai/providers/openai.zig
pub fn complete(http_client: *HttpClient, ctx: core.Context) !core.AssistantMessage {
    // 使用 PromptCache 构建请求
    var cache = ctx.prompt_cache.?;
    
    // 检查缓存是否有效
    if (!cache.isCacheValid(ctx.prompt_config)) {
        try cache.buildStablePrefix(ctx.prompt_config);
    }
    
    // 构建完整提示
    const prompt = try cache.buildFullPrompt(.{
        .short_term_memory = ctx.memory.short_term,
        .recent_transcript = ctx.messages,
        .user_request = ctx.user_input,
    });
    
    // 发送请求...
}
```

**验收标准**:
- [ ] 稳定前缀正确缓存
- [ ] 配置变化时正确重建
- [ ] 动态内容正确注入
- [ ] 缓存命中率统计（可选）
- [ ] 内存使用合理（不重复存储）
- [ ] 添加单元测试
- [ ] 编译通过，无内存泄漏

**性能目标**:
- 缓存命中时，提示构建时间 < 1ms
- 缓存未命中时，提示构建时间 < 50ms

**依赖**:
- TASK-FEAT-003-implement-workspace-context
- TASK-BUG-013-fix-page-allocator-abuse

**阻塞**:
- 高效的 Agent 对话

**笔记**:
Prompt Cache 是性能优化的关键。在长对话中，稳定前缀可能占提示的 50%+，缓存能显著减少处理时间。
