# 会话清理策略设计

**日期**: 2026-04-06  
**状态**: 设计中  
**优先级**: P2（长会话场景优化）

---

## 问题

在长会话场景中（如大型代码库重构），Agent 的 messages 列表会无限增长：
- 每次迭代 +1 assistant message
- 每个工具调用 +1 tool_result message
- 100 次迭代 → ~300 个 Message → ~10MB+ 内存
- 发送给 LLM 的 context 也越来越大 → Token 费用上升

---

## 目标

实现智能的会话清理策略：
1. 保留最近的关键消息（上下文连贯性）
2. 释放旧消息的内存
3. 避免超过 LLM context window
4. 可配置的清理策略

---

## 设计方案

### 方案 A：滑动窗口（简单）

保留最近 N 个消息，删除更早的：

```zig
pub fn trimToRecentMessages(self: *Self, keep_recent: usize) !void {
    if (self.messages.items.len <= keep_recent) return;
    
    const to_remove = self.messages.items.len - keep_recent;
    
    // 释放旧消息
    for (self.messages.items[0..to_remove]) |msg| {
        msg.deinit(self.allocator);
    }
    
    // 移动最近的消息到开头
    std.mem.copy(
        Message,
        self.messages.items,
        self.messages.items[to_remove..],
    );
    
    self.messages.items.len = keep_recent;
}
```

**优点**:
- ✅ 简单，不易出错
- ✅ 可预测的内存使用

**缺点**:
- ❌ 可能丢失重要上下文（如系统提示）
- ❌ 不考虑消息重要性

---

### 方案 B：智能保留（推荐）

根据消息类型智能保留：

```zig
pub const RetentionPolicy = struct {
    keep_system: bool = true,           // 永久保留 system 消息
    keep_recent_user: usize = 3,        // 保留最近 3 个用户消息
    keep_recent_assistant: usize = 5,   // 保留最近 5 个助手消息
    keep_recent_tools: usize = 10,      // 保留最近 10 个工具结果
    max_total: usize = 50,              // 总消息数上限
};

pub fn applyRetentionPolicy(self: *Self, policy: RetentionPolicy) !void {
    var kept = std.ArrayList(Message).init(self.allocator);
    errdefer {
        for (kept.items) |msg| msg.deinit(self.allocator);
        kept.deinit();
    }
    
    // 1. 永久保留 system 消息
    if (policy.keep_system) {
        for (self.messages.items) |msg| {
            if (isSystemMessage(msg)) {
                try kept.append(try msg.clone(self.allocator));
            }
        }
    }
    
    // 2. 保留最近 N 个用户消息
    var user_count: usize = 0;
    var i = self.messages.items.len;
    while (i > 0) : (i -= 1) {
        const msg = self.messages.items[i - 1];
        if (msg == .user) {
            user_count += 1;
            if (user_count <= policy.keep_recent_user) {
                try kept.insert(0, try msg.clone(self.allocator));
            }
        }
    }
    
    // 3. 类似处理 assistant 和 tool_result
    // ...
    
    // 4. 如果总数仍超过限制，从最早的开始删除（除了 system）
    if (kept.items.len > policy.max_total) {
        // 删除 system 之后最早的消息
    }
    
    // 5. 释放原始消息，替换为保留的
    for (self.messages.items) |msg| msg.deinit(self.allocator);
    self.messages.deinit();
    self.messages = kept;
}
```

**优点**:
- ✅ 保留重要上下文
- ✅ 灵活可配置
- ✅ 适应不同场景

**缺点**:
- ❌ 实现复杂
- ❌ clone 开销

---

### 方案 C：基于 Token 计数（最优）

根据估算的 token 数量决定何时清理：

```zig
pub const TokenBudget = struct {
    max_context_tokens: usize = 32_000,  // Claude 的 context window
    safety_margin: usize = 8_000,        // 预留给响应
    
    pub fn shouldTrim(self: TokenBudget, messages: []const Message) bool {
        const estimated = estimateTokens(messages);
        return estimated > (self.max_context_tokens - self.safety_margin);
    }
};

fn estimateTokens(messages: []const Message) usize {
    var total: usize = 0;
    for (messages) |msg| {
        total += estimateMessageTokens(msg);
    }
    return total;
}

fn estimateMessageTokens(msg: Message) usize {
    // 粗略估算：英文 ~4 chars/token，中文 ~2 chars/token
    // 实际应该调用 tiktoken 或类似库
    var chars: usize = 0;
    switch (msg) {
        .user => |m| {
            for (m.content) |block| {
                if (block == .text) chars += block.text.len;
            }
        },
        .assistant => |m| {
            for (m.content) |block| {
                if (block == .text) chars += block.text.text.len;
            }
        },
        .tool_result => |m| {
            for (m.content) |block| {
                if (block == .text) chars += block.text.len;
            }
        },
    }
    return chars / 3;  // 粗略估算
}
```

**优点**:
- ✅ 直接对应 LLM 限制
- ✅ 自适应不同消息大小

**缺点**:
- ❌ Token 估算不精确（需要 tiktoken）
- ❌ 实现复杂

---

## 推荐实施方案

**阶段 1**：实施方案 A（滑动窗口）
- 简单有效
- 立即可用
- 可配置窗口大小

**阶段 2**（可选）：升级到方案 B（智能保留）
- 当用户反馈丢失重要上下文时
- 时间充足时

**阶段 3**（未来）：升级到方案 C（Token 预算）
- 集成 tiktoken 或类似库
- 生产环境优化

---

## API 设计

```zig
pub const Agent = struct {
    // 配置
    max_messages: ?usize = null,  // null = 不限制
    
    /// 在每次迭代结束时检查并清理
    fn runLoop(self: *Self) !void {
        while (...) {
            // ... 执行迭代 ...
            
            // 迭代结束，检查是否需要清理
            if (self.max_messages) |max| {
                if (self.messages.items.len > max) {
                    try self.trimToRecentMessages(max);
                }
            }
        }
    }
    
    /// 手动触发清理
    pub fn trimToRecentMessages(self: *Self, keep_recent: usize) !void {
        // 实现方案 A
    }
    
    /// 清除所有历史（重置会话）
    pub fn clearHistory(self: *Self) void {
        for (self.messages.items) |msg| msg.deinit(self.allocator);
        self.messages.clearRetainingCapacity();
    }
};
```

---

## 配置示例

```zig
// 用户可配置
pub const AgentOptions = struct {
    // ...
    max_messages: ?usize = 50,  // 默认保留 50 个消息
};

// REPL 命令
// /clear-history  - 清除所有历史
// /trim 30        - 保留最近 30 个消息
```

---

## 测试用例

```zig
test "trim to recent messages" {
    const allocator = std.testing.allocator;
    var agent = try Agent.init(allocator, .{
        .model = test_model,
        .max_messages = 10,
    });
    defer agent.deinit();
    
    // 添加 20 个消息
    for (0..20) |i| {
        const text = try std.fmt.allocPrint(allocator, "Message {}", .{i});
        const content = try allocator.alloc(core.UserContentBlock, 1);
        content[0] = .{ .text = text };
        try agent.messages.append(allocator, .{
            .user = .{ .content = content },
        });
    }
    
    // 验证只保留最近 10 个
    try agent.trimToRecentMessages(10);
    try std.testing.expectEqual(@as(usize, 10), agent.messages.items.len);
    
    // 验证是最近的 10 个（index 10-19）
    const first = agent.messages.items[0].user.content[0].text;
    try std.testing.expect(std.mem.indexOf(u8, first, "Message 10") != null);
}
```

---

## 性能影响

**内存节省**:
- 长会话（1000 次迭代）：从 ~100MB → ~5MB（保留 50 个消息）

**性能开销**:
- 方案 A：O(n) 移动操作，每次清理 ~1ms
- 方案 B：O(n) clone，每次清理 ~5ms
- 方案 C：O(n) token 计算，每次 ~10ms

**触发频率**:
- 每次迭代结束检查（cheap check）
- 只在超过限制时执行清理（rare）

---

## 风险评估

🟢 **低风险**
- 可选功能（默认不启用）
- 不影响核心逻辑
- 容易测试和验证

---

## 实施计划

1. 实现 `trimToRecentMessages` 方法（方案 A）
2. 添加 `max_messages` 配置选项
3. 在 `runLoop` 中集成自动清理
4. 添加测试用例
5. 文档更新

**预计时间**: 2-3 小时

---

## 参考

- [Discord.js Message Sweeping](https://discord.js.org/#/docs/main/stable/class/Sweepers)
- [Redis Memory Eviction](https://redis.io/docs/manual/eviction/)
