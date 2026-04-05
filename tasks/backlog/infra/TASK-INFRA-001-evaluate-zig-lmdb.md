### TASK-INFRA-001: 评估并添加 zig-lmdb 依赖
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 2h

**描述**:
评估现有 Zig LMDB bindings，选择最适合的方案并集成到项目构建系统。

**候选方案**:

| 方案 | Stars | 成熟度 | 推荐度 |
|------|-------|--------|--------|
| nDimensional/zig-lmdb | 36 | 高 | ✅ 首选 |
| lithdew/lmdb-zig | 87 | 高 | ✅ 备选 |
| theseyan/lmdbx-zig | 9 | 中 | 备选 |

**评估标准**:
1. API 设计是否 idiomatic Zig
2. 是否支持事务 (MVCC)
3. 是否支持游标 (cursor)
4. 错误处理是否清晰
5. 文档完整性

**实施步骤**:

1. **添加依赖到 build.zig.zon**
```zig
.dependencies = .{
    .zig_lmdb = .{
        .url = "https://github.com/nDimensional/zig-lmdb/archive/refs/tags/v0.3.2.tar.gz",
        .hash = "...",
    },
},
```

2. **创建 lmdb 包封装**
```zig
// src/db/lmdb.zig
pub const LMDBStore = struct {
    allocator: std.mem.Allocator,
    env: *lmdb.MDB_env,
    dbi: lmdb.MDB_dbi,
    
    pub fn init(allocator: std.mem.Allocator, path: []const u8) !Self { ... }
    pub fn deinit(self: *Self) void { ... }
    pub fn put(self: *Self, key: []const u8, value: []const u8) !void { ... }
    pub fn get(self: *Self, key: []const u8) ![]const u8 { ... }
    pub fn del(self: *Self, key: []const u8) !void { ... }
    pub fn iterate(self: *Self, callback: *const fn ([]const u8, []const u8) void) !void { ... }
};
```

3. **验证依赖解析**
```bash
zig build
```

**验收标准**:
- [ ] `zig build` 成功编译
- [ ] LMDB 仓库正确下载
- [ ] 基本连接测试通过

**依赖**:
- 无

**阻塞**:
- 后续 LMDB 集成任务

**笔记**:
- zig-lmdb v0.3.2 是最新稳定版
- 需要检查 hash 是否正确
