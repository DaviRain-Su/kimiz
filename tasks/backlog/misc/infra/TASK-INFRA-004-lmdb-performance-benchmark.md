### TASK-INFRA-004: LMDB 性能测试与基准
**状态**: pending
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 4h

**描述**:
创建 LMDB 存储层的性能测试和基准，确保满足 kimiz 性能要求。

**性能要求**:
| 操作 | 要求 | 当前 (JSON) | 目标 |
|------|------|-------------|------|
| Memory 写入 | < 1ms | ~10ms | < 1ms |
| Memory 读取 | < 0.1ms | ~5ms | < 0.1ms |
| Memory 搜索 | < 10ms/1000条 | ~50ms | < 10ms |
| 启动加载 | < 100ms/10k条 | ~200ms | < 100ms |
| Session 写入 | < 1ms | ~5ms | < 1ms |

**测试用例**:

1. **LongTermMemory 基准**
```zig
test "LMDB LongTermMemory benchmark" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    
    // 清理环境
    try std.fs.cwd().deleteTree("/tmp/kimiz_test_lmdb");
    
    // 测试数据生成
    const entries = try generateTestEntries(alloc, 10000);
    
    // 写入基准
    var store = try LMDBStore.init(alloc, "/tmp/kimiz_test_lmdb");
    defer store.deinit();
    
    const write_start = std.time.microTimestamp();
    for (entries) |entry| {
        const key = try std.fmt.allocPrint(alloc, "mem:{d}", .{entry.id});
        const value = try serializeEntry(alloc, entry);
        try store.put(key, value);
    }
    const write_time = std.time.microTimestamp() - write_start;
    
    // 读取基准
    const read_start = std.time.microTimestamp();
    for (0..1000) |_| {
        const idx = @mod(std.time.microTimestamp(), 10000);
        const key = try std.fmt.allocPrint(alloc, "mem:{d}", .{idx});
        _ = try store.get(key);
    }
    const read_time = std.time.microTimestamp() - read_start;
    
    // 搜索基准
    const search_start = std.time.microTimestamp();
    try store.iterate("mem:", struct {
        fn callback(entry: *const MemoryEntry, query: []const u8) bool {
            return std.mem.indexOf(u8, entry.content, query) != null;
        }
    }.callback, "test_query");
    const search_time = std.time.microTimestamp() - search_start;
    
    std.debug.print("Write: {d}ms/10000 entries\n", .{write_time / 1000});
    std.debug.print("Read: {d}us/1000 entries\n", .{read_time});
    std.debug.print("Search: {d}ms\n", .{search_time});
    
    // 验证
    try expect(write_time < 10000); // < 10ms
    try expect(read_time < 100);   // < 0.1ms
    try expect(search_time < 10000); // < 10ms
}
```

2. **并发访问测试**
```zig
test "LMDB concurrent access" {
    const num_threads = 4;
    const ops_per_thread = 1000;
    
    var handles: [num_threads]std.Thread = undefined;
    var results: [num_threads]u64 = undefined;
    
    for (&handles, 0..) |*handle, i| {
        handle.* = try std.Thread.spawn(.{}, struct {
            fn run(thread_id: usize) u64 {
                var store = try LMDBStore.init(allocator, "/tmp/kimiz_test_lmdb");
                defer store.deinit();
                
                var count: u64 = 0;
                var j: usize = 0;
                while (j < ops_per_thread) : (j += 1) {
                    const key = try std.fmt.allocPrint(allocator, "t{d}:op{d}", .{ thread_id, j });
                    try store.put(key, "value");
                    _ = store.get(key) catch {};
                    count += 1;
                }
                return count;
            }
        }.run, i);
    }
    
    for (handles) |handle| {
        handle.join();
    }
    
    // 验证无数据竞争
}
```

3. **崩溃恢复测试**
```zig
test "LMDB crash recovery" {
    // 写入大量数据
    var store = try LMDBStore.init(alloc, "/tmp/kimiz_test_lmdb");
    var i: usize = 0;
    while (i < 5000) : (i += 1) {
        const key = try std.fmt.allocPrint(alloc, "mem:{d}", .{i});
        const value = try serializeEntry(alloc, entries[i]);
        try store.put(key, value);
    }
    store.deinit();
    
    // 模拟崩溃后重启
    var store2 = try LMDBStore.init(alloc, "/tmp/kimiz_test_lmdb");
    defer store2.deinit();
    
    // 验证所有数据完整
    var count: usize = 0;
    try store2.iterate("mem:", struct {
        fn callback(_) void {
            count += 1;
        }
    }.callback);
    
    try expect(count == 5000);
}
```

4. **内存占用测试**
```zig
test "LMDB memory footprint" {
    const process = std.Process;
    const start_rss = try getProcessRss();
    
    var store = try LMDBStore.init(alloc, "/tmp/kimiz_test_lmdb");
    
    // 写入 10000 条记录
    for (entries) |entry| {
        const key = try std.fmt.allocPrint(alloc, "mem:{d}", .{entry.id});
        const value = try serializeEntry(alloc, entry);
        try store.put(key, value);
    }
    
    const end_rss = try getProcessRss();
    const used_rss = end_rss - start_rss;
    
    // LMDB 内存映射，RSS 应该较小
    std.debug.print("RSS increase: {d}KB for 10000 entries\n", .{used_rss / 1024});
    
    // 验证 < 50MB
    try expect(used_rss < 50 * 1024 * 1024);
    
    store.deinit();
}
```

**验收标准**:
- [ ] 所有基准测试通过
- [ ] 写入性能 < 1ms/条
- [ ] 读取性能 < 0.1ms/条
- [ ] 10000 条记录启动 < 100ms
- [ ] 并发测试无数据丢失
- [ ] 崩溃后数据完整

**依赖**:
- TASK-INFRA-002 (LongTermMemory LMDB)
- TASK-INFRA-003 (SessionStore LMDB)

**阻塞**:
- 无

**笔记**:
- 性能测试应该集成到 CI
- 记录回归情况
- LMDB 的优势在并发读取
