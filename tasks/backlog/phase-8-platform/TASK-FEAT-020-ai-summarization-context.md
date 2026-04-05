### TASK-FEAT-020: 实现 AI 驱动的上下文摘要
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 8h
**参考**: TASK-FEAT-019 (Context Constitution) - 摘要是 Constitution 的一部分

**描述**:
实现基于 AI 的上下文摘要策略，在 context_truncation.zig 中替换 placeholder 实现，使用 AI 模型对长对话进行智能摘要。

**背景**:
当前 `context_truncation.zig` 中的 `truncateWithSummarization` 是 placeholder：

```zig
// 当前实现 (placeholder)
fn truncateWithSummarization(self: *Self, messages: *std.ArrayList(core.Message)) !void {
    // For now, fall back to oldest_first
    // TODO: Implement actual summarization using AI
    try self.truncateOldestFirst(messages);
}
```

需要实现真正的 AI 驱动摘要能力。

**设计目标**:
```
原始消息 (100 条, ~50k tokens)
    ↓ AI 摘要
摘要消息 (1 条, ~200 tokens)
    + 保留的关键信息
    = ~500 tokens (99% 节省)
```

**摘要策略**:
```zig
// src/harness/summarizer.zig
pub const ContextSummarizer = struct {
    allocator: std.mem.Allocator,
    model: *const AIProvider,
    constitution: *const ContextConstitution,
    
    /// 摘要级别
    pub const SummaryLevel = enum {
        /// 简洁: 只保留实体和结果
        concise,
        /// 标准: 保留实体、动作、结果、关键上下文
        standard,
        /// 详细: 保留完整推理链
        detailed,
    };
    
    /// 摘要请求
    pub const SummaryRequest = struct {
        messages: []const core.Message,
        level: SummaryLevel,
        focus: ?[]const u8 = null,  // 可选的重点主题
        max_tokens: u32 = 256,
    };
    
    /// 摘要结果
    pub const SummaryResult = struct {
        summary: []const u8,
        key_entities: []const []const u8,    // 关键实体
        key_actions: []const []const u8,     // 关键动作
        key_outcomes: []const []const u8,   // 关键结果
        preserved_links: []const MemoryLink, // 保留的记忆链接
        token_count: u32,
    };
    
    /// 摘要一段消息
    pub fn summarize(self: *Self, request: SummaryRequest) !SummaryResult {
        // 1. 提取关键信息
        const extracted = try self.extractKeyInformation(request.messages);
        
        // 2. 构建摘要提示
        const prompt = try self.buildSummaryPrompt(request, extracted);
        
        // 3. 调用 AI 生成摘要
        const response = try self.model.complete(.{
            .prompt = prompt,
            .max_tokens = request.max_tokens,
            .temperature = 0.3,  // 低温度保证一致性
        });
        
        // 4. 解析结果
        return try self.parseSummaryResponse(response, extracted);
    }
    
    /// 提取关键信息 (无需 AI)
    fn extractKeyInformation(self: *Self, messages: []const core.Message) !ExtractedInfo {
        var entities = std.ArrayList([]const u8).init(self.allocator);
        var actions = std.ArrayList(Action).init(self.allocator);
        var outcomes = std.ArrayList([]const u8).init(self.allocator);
        var memory_links = std.ArrayList(MemoryLink).init(self.allocator);
        
        for (messages) |msg| {
            switch (msg) {
                .user => |u| {
                    // 提取用户意图
                    try self.extractIntents(u, &entities, &actions);
                },
                .assistant => |a| {
                    // 提取 AI 响应
                    for (a.content) |block| {
                        if (block == .text) {
                            try self.extractFromText(block.text, &outcomes);
                        }
                    }
                },
                .tool_result => |tr| {
                    // 提取工具结果
                    try self.extractToolResults(tr, &entities, &outcomes);
                },
            }
        }
        
        return .{
            .entities = try entities.toOwnedSlice(),
            .actions = try actions.toOwnedSlice(),
            .outcomes = try outcomes.toOwnedSlice(),
            .memory_links = try memory_links.toOwnedSlice(),
        };
    }
    
    /// 构建摘要提示
    fn buildSummaryPrompt(self: *Self, request: SummaryRequest, extracted: ExtractedInfo) ![]u8 {
        const level_instruction = switch (request.level) {
            .concise => "只保留: 实体(人/物)、最终结果",
            .standard => "保留: 实体、动作、结果、关键上下文",
            .detailed => "保留: 完整推理链、每个步骤、结果",
        };
        
        const focus_instruction = if (request.focus) |f|
            std.fmt.allocPrint(self.allocator, "重点关注: {s}", .{f})
        else "";
        
        return std.fmt.allocPrint(self.allocator,
            \\你是一个上下文摘要助手。请将以下对话摘要成 {d} tokens 以内。
            \\
            \\摘要级别: {s}
            \\{s}
            \\
            \\关键实体: {s}
            \\关键动作: {s}
            \\关键结果: {s}
            \\
            \\请生成包含以上信息的简洁摘要。
        , .{
            request.max_tokens,
            level_instruction,
            focus_instruction,
            self.joinStrings(extracted.entities),
            self.formatActions(extracted.actions),
            self.joinStrings(extracted.outcomes),
        });
    }
};
```

**与 ContextTruncation 集成**:
```zig
// src/harness/context_truncation.zig
pub const ContextTruncator = struct {
    // ... existing fields ...
    summarizer: ?*ContextSummarizer,  // 可选的摘要器
    
    /// 使用摘要策略截断
    pub fn truncateWithAI(self: *Self, messages: *std.ArrayList(core.Message)) !void {
        if (self.summarizer == null) {
            // Fallback to oldest_first
            return self.truncateOldestFirst(messages);
        }
        
        const summarizer = self.summarizer.?;
        
        // 1. 确定要摘要的消息范围
        const to_summarize = try self.selectMessagesForSummarization(messages);
        if (to_summarize.len == 0) return;
        
        // 2. 执行摘要
        const summary_result = try summarizer.summarize(.{
            .messages = to_summarize,
            .level = .standard,
            .max_tokens = 256,
        });
        
        // 3. 替换原消息为摘要
        const summary_message = try self.createSummaryMessage(summary_result);
        
        // 4. 保留关键实体和链接
        const retained_info = try self.retainKeyInformation(summary_result);
        
        // 5. 替换消息
        try self.replaceMessagesWithSummary(
            messages,
            to_summarize,
            summary_message,
            retained_info,
        );
        
        // 6. 记录统计
        self.stats.messages_summarized += @as(u32, @intCast(to_summarize.len));
        self.stats.tokens_saved += summary_result.token_count;
    }
    
    /// 选择要摘要的消息
    fn selectMessagesForSummarization(self: *Self, messages: []const core.Message) ![]const core.Message {
        // 选择最早的 N 条消息 (超过阈值的部分)
        const threshold = self.limits.effectiveLimit();
        var count: usize = 0;
        var token_count: usize = 0;
        
        for (messages) |msg| {
            token_count += self.estimateMessageTokens(msg);
            count += 1;
            if (token_count > threshold) break;
        }
        
        return messages[0..count];
    }
};
```

**摘要质量保障**:
```zig
/// 验证摘要质量
pub fn validateSummary(
    self: *Self,
    original: []const core.Message,
    summary: SummaryResult,
) !ValidationResult {
    var issues = std.ArrayList([]const u8).init(self.allocator);
    
    // 1. 检查关键实体是否保留
    for (self.extractEntities(original)) |entity| {
        const found = std.mem.indexOf(u8, summary.summary, entity) != null;
        if (!found) {
            try issues.append(std.fmt.allocPrint(self.allocator,
                "关键实体丢失: {s}", .{entity}));
        }
    }
    
    // 2. 检查 token 限制
    if (summary.token_count > 256) {
        try issues.append("摘要超过 token 限制");
    }
    
    // 3. 检查可读性
    if (summary.summary.len < 50) {
        try issues.append("摘要过短，可能丢失关键信息");
    }
    
    return .{
        .valid = issues.items.len == 0,
        .issues = try issues.toOwnedSlice(),
    };
}
```

**验收标准**:
- [ ] Summarizer 结构实现完整
- [ ] 摘要生成质量达标 (关键实体保留 > 90%)
- [ ] 与 ContextTruncator 正确集成
- [ ] 摘要验证机制工作正常
- [ ] 性能: 摘要生成 < 500ms
- [ ] `zig build test` 测试通过

**依赖**:
- TASK-FEAT-019 (Context Constitution)
- AI Provider 集成 (TASK-INTEG-001 或类似)

**阻塞**:
- TASK-FEAT-019

**笔记**:
- 考虑使用更小的模型做摘要 (成本优化)
- 可以缓存常用模式的摘要模板
- 考虑增量摘要 (只摘要新增部分)
