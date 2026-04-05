### Task-FEAT-005: 实现 Context Reduction (上下文缩减)
**状态**: pending
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 6h
**参考**: [Coding Agent Components Analysis](../../docs/design/coding-agent-components-analysis.md)

**描述**:
根据 Sebastian Raschka 的文章，Context Reduction 是 Coding Agent 的第四核心组件。它通过裁剪、摘要、去重等策略管理上下文膨胀，确保 Agent 在长时间对话中保持高效。

**核心策略**:

1. **Clipping (裁剪)**: 缩短长文档和大工具输出
2. **Summarization (摘要)**: 将历史对话压缩为关键信息
3. **Deduplication (去重)**: 移除重复的文件读取
4. **Recency Bias (近期偏好)**: 保留近期事件的更多细节

**实现方案**:

```zig
// src/context/reduction.zig
pub const ContextReducer = struct {
    allocator: std.mem.Allocator,
    config: ReductionConfig,
    
    pub fn init(allocator: std.mem.Allocator, config: ReductionConfig) Self;
    
    /// 主入口：应用所有缩减策略
    pub fn reduce(self: *ContextReducer, context: *Context) !void;
    
    /// 策略 1: 裁剪长输出
    pub fn clipOutputs(self: *ContextReducer, messages: []Message) !void;
    
    /// 策略 2: 摘要历史对话
    pub fn summarizeHistory(self: *ContextReducer, messages: []Message) ![]Message;
    
    /// 策略 3: 去重文件读取
    pub fn deduplicateReads(self: *ContextReducer, messages: []Message) ![]Message;
    
    /// 策略 4: 应用近期偏好
    pub fn applyRecencyBias(self: *ContextReducer, messages: []Message) void;
    
    pub fn deinit(self: *ContextReducer) void;
};

pub const ReductionConfig = struct {
    max_context_tokens: usize = 128000,
    max_output_lines: usize = 100,      // Clipping 阈值
    summary_threshold: usize = 10,       // 多少轮后摘要
    keep_recent_messages: usize = 5,     // 保留最近多少条完整消息
};

pub const ReductionStrategy = enum {
    clip,           // 直接截断
    summarize,      // LLM 摘要
    truncate,       // 截断并标记
    remove,         // 完全移除
};
```

**Clipping 实现**:

```zig
pub fn clipOutputs(self: *ContextReducer, messages: []Message) !void {
    for (messages) |*msg| {
        switch (msg.*) {
            .tool_result => |*tr| {
                for (tr.content) |*block| {
                    switch (block.*) {
                        .text => |*text| {
                            const lines = countLines(text.*);
                            if (lines > self.config.max_output_lines) {
                                // 保留头部和尾部，中间用 [... clipped ...] 替代
                                const clipped = try clipText(
                                    self.allocator,
                                    text.*,
                                    self.config.max_output_lines,
                                );
                                self.allocator.free(text.*);
                                text.* = clipped;
                            }
                        },
                        else => {},
                    }
                }
            },
            else => {},
        }
    }
}

fn clipText(allocator: std.mem.Allocator, text: []const u8, max_lines: usize) ![]const u8 {
    const head_lines = max_lines / 2;
    const tail_lines = max_lines - head_lines;
    
    // 提取头部
    const head = extractLines(text, 0, head_lines);
    
    // 提取尾部
    const total_lines = countLines(text);
    const tail = extractLines(text, total_lines - tail_lines, total_lines);
    
    // 组合
    return std.fmt.allocPrint(allocator, "{s}\n[... {d} lines clipped ...]\n{s}", .{
        head, total_lines - head_lines - tail_lines, tail,
    });
}
```

**Summarization 实现**:

```zig
pub fn summarizeHistory(self: *ContextReducer, messages: []Message) ![]Message {
    // 保留最近 N 条完整消息
    const recent = messages[messages.len - self.config.keep_recent_messages ..];
    
    // 对更早的消息进行摘要
    const older = messages[0 .. messages.len - self.config.keep_recent_messages];
    
    // 生成摘要（使用 LLM 或规则）
    const summary = try self.generateSummary(older);
    
    // 构建新的消息列表：[摘要, ...最近消息]
    var reduced = try self.allocator.alloc(Message, 1 + recent.len);
    reduced[0] = Message{
        .system = .{ .content = summary },
    };
    std.mem.copy(Message, reduced[1..], recent);
    
    return reduced;
}

fn generateSummary(self: *ContextReducer, messages: []Message) ![]const u8 {
    // 方案 1: 使用轻量级规则摘要
    // 方案 2: 调用 LLM 生成摘要（更智能但耗时）
    
    var summary_buf: std.ArrayList(u8) = .empty;
    defer summary_buf.deinit(self.allocator);
    
    try summary_buf.appendSlice(self.allocator, "Previous conversation summary:\n");
    
    for (messages) |msg| {
        switch (msg) {
            .user => try summary_buf.appendSlice(self.allocator, "- User asked a question\n"),
            .assistant => try summary_buf.appendSlice(self.allocator, "- Assistant provided response\n"),
            .tool_result => |tr| try std.fmt.format(
                summary_buf.writer(self.allocator),
                "- Tool '{s}' was executed\n",
                .{tr.tool_name},
            ),
        }
    }
    
    return try summary_buf.toOwnedSlice(self.allocator);
}
```

**Deduplication 实现**:

```zig
pub fn deduplicateReads(self: *ContextReducer, messages: []Message) ![]Message {
    var seen_files = std.StringHashMap(void).init(self.allocator);
    defer seen_files.deinit();
    
    // 从后往前遍历，保留最新的读取
    var i: usize = messages.len;
    while (i > 0) {
        i -= 1;
        
        if (messages[i] == .tool_result) {
            const tr = messages[i].tool_result;
            if (std.mem.eql(u8, tr.tool_name, "read_file")) {
                // 提取文件路径
                const path = extractPathFromToolResult(tr);
                
                if (seen_files.contains(path)) {
                    // 标记为重复（后续移除）
                    messages[i].tool_result.is_duplicate = true;
                } else {
                    try seen_files.put(path, {});
                }
            }
        }
    }
    
    // 过滤掉重复项
    return filterDuplicates(self.allocator, messages);
}
```

**与 Agent Loop 集成**:

```zig
// src/agent/agent.zig
fn runLoop(self: *Self) !void {
    // ...
    
    // 每 N 轮应用上下文缩减
    if (self.iteration_count % self.config.reduction_interval == 0) {
        var reducer = ContextReducer.init(self.allocator, self.config.reduction);
        defer reducer.deinit();
        
        try reducer.reduce(&self.context);
    }
    
    // ...
}
```

**验收标准**:
- [ ] 长输出正确裁剪（保留头尾，标记中间）
- [ ] 历史对话正确摘要
- [ ] 重复文件读取正确去重
- [ ] 近期消息保留完整
- [ ] 缩减后的上下文在 token 限制内
- [ ] Agent 性能不下降（甚至提升）
- [ ] 添加单元测试
- [ ] 编译通过，无内存泄漏

**依赖**:
- TASK-FEAT-003-implement-workspace-context
- TASK-FEAT-004-implement-prompt-cache

**阻塞**:
- 长会话的稳定性

**笔记**:
Context Reduction 是长会话的关键。没有它，Agent 会在几十轮后因为上下文过长而变得缓慢和混乱。
