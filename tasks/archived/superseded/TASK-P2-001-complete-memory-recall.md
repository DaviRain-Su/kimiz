### TASK-P2-001: 完善 Memory recall 功能
**状态**: pending
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 2h

**描述**:
MemoryManager.recall() 目前只搜索 ShortTermMemory，需要添加 LongTermMemory 搜索和结果合并。

**位置**: `src/memory/root.zig:824`

**当前代码**:
```zig
pub fn recall(self: *Self, query: []const u8, limit: usize) ![]MemoryEntry {
    // TODO: Also search long-term and merge results
    return self.short_term.search(query, limit);
}
```

**修复方案**:

```zig
pub fn recall(self: *Self, query: []const u8, limit: usize) ![]MemoryEntry {
    // 搜索 ShortTerm
    const short_results = try self.short_term.search(query, limit * 2);
    
    // 搜索 LongTerm (如果存在)
    var long_results: []MemoryEntry = &.{};
    if (self.long_term) |lt| {
        long_results = try lt.search(query, limit * 2);
    }
    
    // 合并并排序
    var all_results = std.ArrayList(MemoryEntry).init(self.allocator);
    defer all_results.deinit();
    
    try all_results.appendSlice(short_results);
    if (long_results.len > 0) {
        try all_results.appendSlice(long_results);
    }
    
    // 按相关性排序
    std.mem.sort(MemoryEntry, all_results.items, {}, struct {
        fn lessThan(_: void, a: MemoryEntry, b: MemoryEntry) bool {
            return a.relevanceScore(query, std.time.timestamp()) > 
                   b.relevanceScore(query, std.time.timestamp());
        }
    }.lessThan);
    
    // 返回 top N
    const result_len = @min(limit, all_results.items.len);
    const result = try self.allocator.alloc(MemoryEntry, result_len);
    @memcpy(result, all_results.items[0..result_len]);
    
    return result;
}
```

**验收标准**:
- [ ] recall 同时搜索 ShortTerm 和 LongTerm
- [ ] 结果按相关性排序
- [ ] 去重处理

**依赖**:
- TASK-INTEG-001 (集成 Memory)

**阻塞**:
- 无

**笔记**:
无
