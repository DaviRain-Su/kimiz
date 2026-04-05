### Task-REF-003: 简化 Memory 系统为单层 Session
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 8h
**参考**: [Simplified Architecture Proposal](../../docs/design/simplified-architecture-proposal.md)

**描述**:
将当前复杂的三层记忆系统（Short-term, Working, Long-term）简化为单层 Session + Compaction 模式，参考 Pi-Mono 的设计。

**当前问题**:
- 三层记忆逻辑复杂，整合困难
- 内存管理复杂，容易出错
- 代码量大（~800 行），维护成本高

**简化目标**:
```
Before:
ShortTermMemory (100 entries) → WorkingMemory → LongTermMemory (JSON file)

After:
Session (JSONL file) + Compaction
```

**实现方案**:

```zig
// src/core/session.zig (替换 src/memory/root.zig)
pub const Session = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    created_at: i64,
    
    // 消息历史
    messages: std.ArrayList(Message),
    
    // 元数据
    metadata: SessionMetadata,
    
    // 分支支持
    parent_id: ?[]const u8,
    branch_point: ?usize,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, id: []const u8) Self;
    
    /// 添加消息
    pub fn addMessage(self: *Self, msg: Message) !void;
    
    /// 自动压缩（当接近上下文限制时）
    pub fn compact(self: *Self) !void;
    
    /// 手动压缩（带自定义指令）
    pub fn compactWithPrompt(self: *Self, prompt: []const u8) !void;
    
    /// 创建分支
    pub fn fork(self: *Self, new_id: []const u8) !Self;
    
    /// 持久化到 JSONL
    pub fn save(self: Session, dir: []const u8) !void;
    
    /// 从 JSONL 加载
    pub fn load(allocator: std.mem.Allocator, dir: []const u8, id: []const u8) !Self;
    
    /// 导出为 HTML
    pub fn exportHtml(self: Session, path: []const u8) !void;
    
    pub fn deinit(self: *Self) void;
};

pub const SessionMetadata = struct {
    working_dir: []const u8,
    model_id: []const u8,
    total_tokens: u64,
    total_cost: f64,
    message_count: struct {
        user: u32,
        assistant: u32,
        tool_calls: u32,
    },
};
```

**Compaction 策略**:

```zig
pub const CompactionStrategy = struct {
    /// 触发阈值
    max_messages: usize = 100,
    max_tokens: usize = 100000,
    
    /// 保留最近 N 条完整消息
    keep_recent: usize = 10,
    
    /// 压缩函数
    pub fn compact(
        allocator: std.mem.Allocator,
        messages: []Message,
        keep_recent: usize,
    ) ![]Message {
        // 1. 保留最近的消息
        const recent = messages[messages.len - keep_recent ..];
        
        // 2. 对更早的消息生成摘要
        const older = messages[0 .. messages.len - keep_recent];
        const summary = try generateSummary(allocator, older);
        
        // 3. 组合：[摘要, ...最近消息]
        var result = try allocator.alloc(Message, 1 + recent.len);
        result[0] = Message{
            .system = .{ .content = summary },
        };
        std.mem.copy(Message, result[1..], recent);
        
        return result;
    }
};
```

**文件格式 (JSONL)**:

```jsonl
{"type": "metadata", "data": {"id": "abc123", "created_at": 1234567890, ...}}
{"type": "message", "data": {"role": "user", "content": "Hello"}}
{"type": "message", "data": {"role": "assistant", "content": "Hi!"}}
{"type": "compaction", "data": {"summary": "User greeted, assistant responded...", "original_count": 50}}
{"type": "message", "data": {"role": "user", "content": "Next question"}}
```

**需要修改的文件**:
- [ ] 删除 `src/memory/root.zig`
- [ ] 创建 `src/core/session.zig`
- [ ] 修改 `src/agent/agent.zig` (使用新 Session)
- [ ] 修改 `src/utils/session.zig` (整合)
- [ ] 更新所有引用

**验收标准**:
- [ ] Session 可以创建、保存、加载
- [ ] 自动压缩正常工作
- [ ] 分支功能可用
- [ ] 导出 HTML 功能
- [ ] 代码量减少 50%+
- [ ] 单元测试覆盖
- [ ] 编译通过，无内存泄漏

**依赖**:
- URGENT-FIX-compilation-errors
- TASK-BUG-013-fix-page-allocator-abuse

**阻塞**:
- Agent 核心功能

**笔记**:
这是架构简化的核心任务。Pi-Mono 证明单层 Session + Compaction 足够好用。
