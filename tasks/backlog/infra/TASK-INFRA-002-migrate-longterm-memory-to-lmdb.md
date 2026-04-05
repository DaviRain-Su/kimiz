### TASK-INFRA-002: 创建 LMDB 存储后端替代 JSON 持久化
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 8h

**描述**:
将 LongTermMemory 的 JSON 文件持久化迁移到 LMDB，提升性能和可靠性。

**当前状态**:
```zig
// LongTermMemory (当前 JSON 实现)
// src/memory/root.zig:426-732
pub const LongTermMemory = struct {
    allocator: std.mem.Allocator,
    db_path: []const u8,      // JSON 文件路径
    entries: std.ArrayList(MemoryEntry),  // 全量加载到内存
    dirty: bool,
    
    fn save(self: *Self) !void {  // JSON 序列化到文件
        // ...
    }
    
    fn load(self: *Self) !void {  // 从文件加载 JSON
        // ...
    }
};
```

**目标状态**:
```zig
// LongTermMemory (新 LMDB 实现)
// src/memory/root.zig (修改)
pub const LongTermMemory = struct {
    allocator: std.mem.Allocator,
    store: LMDBStore,         // LMDB 存储
    entries: std.ArrayList(MemoryEntry),  // 索引缓存
    dirty: bool,
    
    // LMDB 支持增量写入，不需要全量保存
    pub fn store(self: *Self, entry: MemoryEntry) !void {
        // 直接写入 LMDB
        const key = try std.fmt.allocPrint(self.allocator, "mem:{d}", .{entry.id});
        defer self.allocator.free(key);
        const value = try self.serializeEntry(entry);
        try self.store.put(key, value);
        self.dirty = true;
    }
    
    pub fn load(self: *Self) !void {
        // 启动时扫描所有 key 重建索引
        try self.store.iterate("mem:", struct {
            fn callback(key: []const u8, value: []const u8) void {
                // 解析并添加到 entries
            }
        }.callback);
    }
};
```

**实施步骤**:

1. **创建 db 模块目录结构**
```
src/db/
├── root.zig      // 模块导出
├── lmdb.zig      // LMDB 封装
└── mem_store.zig // Memory 专用存储
```

2. **实现 LMDBStore 封装** (参考 nDimensional/zig-lmdb)
```zig
// src/db/lmdb.zig
const lmdb = @cImport(@cInclude("lmdb.h"));

pub const LMDBStore = struct {
    allocator: std.mem.Allocator,
    env: *lmdb.MDB_env,
    dbi: lmdb.MDB_dbi,
    
    pub fn init(allocator: std.mem.Allocator, path: []const u8) !Self {
        var env: *lmdb.MDB_env = undefined;
        try throw(lmdb.mdb_env_create(&env));
        
        // 设置地图大小 (1GB)
        try throw(lmdb.mdb_env_set_mapsize(env, 1024 * 1024 * 1024));
        
        // 打开数据库
        try throw(lmdb.mdb_env_open(env, path, lmdb.MDB_NOTLS, 0o644));
        
        var dbi: lmdb.MDB_dbi = undefined;
        var txn: *lmdb.MDB_txn = undefined;
        try throw(lmdb.mdb_txn_begin(env, null, 0, &txn));
        try throw(lmdb.mdb_dbi_open(txn, null, 0, &dbi));
        try throw(lmdb.mdb_txn_commit(txn));
        
        return Self{
            .allocator = allocator,
            .env = env,
            .dbi = dbi,
        };
    }
    
    pub fn put(self: *Self, key: []const u8, value: []const u8) !void {
        var txn: *lmdb.MDB_txn = undefined;
        try throw(lmdb.mdb_txn_begin(self.env, null, 0, &txn));
        defer _ = lmdb.mdb_txn_abort(txn);
        
        var k: lmdb.MDB_val = .{ .mv_size = key.len, .mv_data = key.ptr };
        var v: lmdb.MDB_val = .{ .mv_size = value.len, .mv_data = value.ptr };
        
        try throw(lmdb.mdb_put(txn, self.dbi, &k, &v, 0));
        try throw(lmdb.mdb_txn_commit(txn));
    }
    
    pub fn get(self: *Self, key: []const u8) ![]u8 { ... }
    pub fn del(self: *Self, key: []const u8) !void { ... }
    pub fn iterate(self: *Self, prefix: []const u8, callback: ...) !void { ... }
    
    pub fn deinit(self: *Self) void {
        lmdb.mdb_dbi_close(self.env, self.dbi);
        lmdb.mdb_env_close(self.env);
    }
};
```

3. **修改 LongTermMemory 使用 LMDBStore**
```zig
// src/memory/root.zig
pub const LongTermMemory = struct {
    allocator: std.mem.Allocator,
    store: LMDBStore,  // 替换 db_path
    entries: std.ArrayList(MemoryEntry),  // 保留内存索引
    dirty: bool,
    
    pub fn init(allocator: std.mem.Allocator, db_path: []const u8) !Self {
        return .{
            .allocator = allocator,
            .store = try LMDBStore.init(allocator, db_path),
            .entries = .empty,
            .dirty = false,
        };
    }
    
    // 修改 store() 为增量写入
    pub fn store(self: *Self, entry: MemoryEntry) !void {
        const key = try std.fmt.allocPrint(self.allocator, "mem:{d}", .{entry.id});
        defer self.allocator.free(key);
        const value = try self.serializeEntry(entry);
        defer self.allocator.free(value);
        
        try self.store.put(key, value);
        try self.entries.append(self.allocator, try self.copyEntry(entry));
        self.dirty = true;
    }
    
    // 修改 load() 为启动时重建索引
    fn load(self: *Self) !void {
        try self.store.iterate("mem:", struct {
            fn callback(self: *Self, key: []const u8, value: []const u8) !void {
                const entry = try self.deserializeEntry(value);
                try self.entries.append(self.allocator, entry);
            }
        }.callback, self);
    }
    
    // 删除 save() - 不再需要全量保存
    // LMDB 支持增量写入
};
```

4. **添加序列化辅助函数**
```zig
fn serializeEntry(self: *Self, entry: MemoryEntry) ![]u8 { ... }
fn deserializeEntry(self: *Self, data: []const u8) !MemoryEntry { ... }
```

**验收标准**:
- [ ] `zig build` 编译通过
- [ ] `zig build test` 测试通过
- [ ] Memory 持久化正常工作
- [ ] 启动时间 < 100ms (10000 条记录)
- [ ] 单次写入 < 1ms

**依赖**:
- TASK-INFRA-001 (添加 zig-lmdb 依赖)

**阻塞**:
- Session 持久化迁移

**笔记**:
- LMDB 使用 Copy-on-Write B-tree，写入性能比 SQLite 好
- 需要处理序列化/反序列化边界
- 考虑添加压缩 (zstd) 减少存储大小
