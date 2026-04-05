### TASK-INFRA-003: 迁移 SessionStore 到 LMDB
**状态**: pending
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 4h

**描述**:
将 SessionStore 的 JSON 文件持久化迁移到 LMDB，提升 Session 管理的性能和可靠性。

**当前状态**:
```zig
// src/utils/session.zig:354-410
pub const SessionStore = struct {
    allocator: std.mem.Allocator,
    sessions: std.StringHashMap(Session),  // 全量内存
    data_dir: []const u8,  // JSON 文件目录
    
    pub fn saveSession(self: *Self, session: Session) !void {
        // JSON 序列化到文件
        const path = try self.getSessionPath(session.id);
        const json = try std.json.stringifyAlloc(self.allocator, session, .{});
        defer self.allocator.free(json);
        try std.fs.cwd().writeFile(path, json);
    }
    
    pub fn loadSession(self: *Self, id: []const u8) !Session {
        // 从文件读取 JSON
        const path = try self.getSessionPath(id);
        const content = try std.fs.cwd().readFileAlloc(self.allocator, path, ...);
        return try std.json.parseFromSlice(Session, self.allocator, content, .{});
    }
};
```

**目标状态**:
```zig
// src/utils/session.zig (修改)
pub const SessionStore = struct {
    allocator: std.mem.Allocator,
    sessions: std.StringHashMap(Session),  // 内存缓存
    db: LMDBStore,  // LMDB 持久化
    
    pub fn saveSession(self: *Self, session: Session) !void {
        const key = try std.fmt.allocPrint(self.allocator, "session:{s}", .{session.id});
        defer self.allocator.free(key);
        const value = try self.serializeSession(session);
        defer self.allocator.free(value);
        
        try self.db.put(key, value);
        // 更新内存缓存
        try self.sessions.put(session.id, session);
    }
    
    pub fn loadSession(self: *Self, id: []const u8) !Session {
        // 先检查内存缓存
        if (self.sessions.get(id)) |session| {
            return session;
        }
        
        // 从 LMDB 加载
        const key = try std.fmt.allocPrint(self.allocator, "session:{s}", .{id});
        defer self.allocator.free(key);
        
        const value = try self.db.get(key);
        const session = try self.deserializeSession(value);
        
        // 缓存到内存
        try self.sessions.put(try self.allocator.dupe(u8, id), session);
        return session;
    }
};
```

**实施步骤**:

1. **分析 Session 数据结构**
```zig
// src/utils/session.zig 中的 Session 结构
pub const Session = struct {
    id: []const u8,
    created_at: i64,
    updated_at: i64,
    messages: []Message,  // 需要特殊处理
    metadata: ?Metadata,
};
```

2. **设计 LMDB key-value 结构**
```
Key: "session:{session_id}"
Value: JSON 或二进制序列化的 Session

Sub-keys:
"session:{id}:msg:{index}" -> 单条消息 (可选，用于大 session)
```

3. **实现序列化**
```zig
fn serializeSession(self: *Self, session: Session) ![]u8 {
    // 方案 A: JSON (简单但大)
    // return try std.json.stringifyAlloc(self.allocator, session, .{});
    
    // 方案 B: MessagePack (紧凑，跨语言)
    // 使用 msgpack-zig
    
    // 方案 C: 自定义二进制 (最快)
    // 使用 std.io.Writer 手动序列化
}
```

4. **修改 SessionStore**
```zig
pub const SessionStore = struct {
    allocator: std.mem.Allocator,
    sessions: std.StringHashMap(Session),
    db: LMDBStore,
    
    pub fn init(allocator: std.mem.Allocator, data_dir: []const u8) !Self {
        return .{
            .allocator = allocator,
            .sessions = .{},
            .db = try LMDBStore.init(allocator, data_dir ++ "/sessions.db"),
        };
    }
    
    // ... 修改 saveSession, loadSession, listSessions 等方法
};
```

5. **处理消息拆分 (可选)**
```zig
// 对于大 session，拆分存储
pub fn saveSession(self: *Self, session: Session) !void {
    // 保存 session 元数据
    const meta = SessionMeta{
        .id = session.id,
        .created_at = session.created_at,
        .updated_at = session.updated_at,
        .message_count = session.messages.len,
    };
    try self.saveSessionMeta(meta);
    
    // 批量保存消息
    for (session.messages, 0..) |msg, i| {
        try self.saveMessage(session.id, i, msg);
    }
}
```

**验收标准**:
- [ ] `zig build` 编译通过
- [ ] Session 创建/保存/加载/列表功能正常
- [ ] Session 数量 100+ 时性能良好
- [ ] 历史消息正确持久化

**依赖**:
- TASK-INFRA-002 (LongTermMemory LMDB 迁移)

**阻塞**:
- 无

**笔记**:
- Session 持久化优先级低于 Memory，因为 Session 可选
- 考虑添加 Session 过期清理机制
- 消息序列化可选 MessagePack 或 JSON
