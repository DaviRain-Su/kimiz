### TASK-INFRA-005: 添加 LMDB 压缩支持 (可选)
**状态**: pending
**优先级**: P3
**创建**: 2026-04-05
**预计耗时**: 6h

**描述**:
为 LMDB 存储添加 zstd 压缩，减少存储空间占用同时保持性能。

**背景**:
- Memory 数据有大量文本，压缩率高
- LMDB 本身不压缩
- zstd 提供 3-10x 压缩比，速度接近内存带宽

**方案设计**:

```zig
// src/db/compressed_store.zig
pub const CompressedLMDBStore = struct {
    allocator: std.mem.Allocator,
    inner: LMDBStore,
    compression_level: i9,  // zstd 压缩级别
    
    pub fn put(self: *Self, key: []const u8, value: []const u8) !void {
        // 压缩
        const compressed = try compress(self.allocator, value, self.compression_level);
        defer self.allocator.free(compressed);
        
        // 存储: key + [4字节长度] + 压缩数据
        var final_value = try self.allocator.alloc(u8, compressed.len + 4);
        std.mem.writeInt(u32, final_value[0..4], @intCast(value.len), .little);
        @memcpy(final_value[4..], compressed);
        
        try self.inner.put(key, final_value);
    }
    
    pub fn get(self: *Self, key: []const u8) ![]u8 {
        const compressed = try self.inner.get(key);
        
        // 解压
        const original_len = std.mem.readInt(u32, compressed[0..4], .little);
        return try decompress(self.allocator, compressed[4..], original_len);
    }
};
```

**实施步骤**:

1. **添加 zstd 依赖或使用内置压缩**
```zig
// 方案 A: 使用 Zig 内置压缩 (std.compress)
const zlib = std.compress.zlib;

// 方案 B: 添加 zstd-zig
// .zstd = .{ .url = "...", .hash = "..." };
```

2. **实现压缩 Store 封装**

3. **添加压缩级别配置**
```zig
pub const CompressionOptions = struct {
    enabled: bool = true,
    level: i9 = 3,  // 1-22, 默认 3
    min_size: usize = 64,  // < 64 字节不压缩
};
```

4. **基准对比**
```zig
test "Compression overhead" {
    const test_data = generateTextData(1024 * 1024); // 1MB
    
    // 无压缩
    var store_no_compress = try LMDBStore.init(...);
    const t1 = measureTime();
    try store_no_compress.put("key", test_data);
    const no_compress_time = measureTime() - t1;
    
    // 有压缩
    var store_compressed = try CompressedLMDBStore.init(...);
    const t2 = measureTime();
    try store_compressed.put("key", test_data);
    const compressed_time = measureTime() - t2;
    
    // 验证压缩率
    const original_size = test_data.len;
    const compressed_size = (try store_compressed.get("key")).len;
    const ratio = @as(f64, @intCast(compressed_size)) / @as(f64, @intCast(original_size));
    
    std.debug.print("No compress: {d}ms\n", .{no_compress_time});
    std.debug.print("Compressed: {d}ms, ratio: {d:.2}\n", .{ compressed_time, ratio });
}
```

**验收标准**:
- [ ] 1MB 文本压缩率 > 3x
- [ ] 压缩/解压开销 < 压缩时间 50%
- [ ] 配置可开关
- [ ] 基准测试通过

**依赖**:
- TASK-INFRA-002 (LongTermMemory LMDB)

**阻塞**:
- 无

**笔记**:
- 这是优化任务，核心功能不需要
- zstd 压缩库: https://github.com/wasmerio/zstd-zig
