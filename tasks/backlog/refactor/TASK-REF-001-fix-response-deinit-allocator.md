### TASK-REF-001: 修复 Response.deinit allocator 使用不一致
**状态**: pending
**优先级**: P3
**创建**: 2026-04-05
**预计耗时**: 30分钟

**描述**:
Response 结构体存储了 allocator 字段，但 deinit 方法却要求传入 allocator 参数，导致使用不一致。

**问题代码**: src/http.zig:183
```zig
pub const Response = struct {
    status: std.http.Status,
    body: []const u8,
    allocator: std.mem.Allocator,  // ✅ 存储了 allocator
    
    pub fn deinit(self: Response, allocator: std.mem.Allocator) void {
        allocator.free(self.body);  // ❌ 但 deinit 又要求传入
        // 没有使用 self.allocator
    }
};
```

**问题**:
1. 设计不一致 - 既存储又要求传入
2. 可能传入错误的 allocator 导致内存错误
3. allocator 字段浪费内存

**修复方案**:

**选项1**: 使用存储的 allocator（推荐）
```zig
pub const Response = struct {
    status: std.http.Status,
    body: []const u8,
    allocator: std.mem.Allocator,
    
    pub fn deinit(self: Response) void {
        self.allocator.free(self.body);  // ✅ 使用 self.allocator
    }
};
```

**选项2**: 移除 allocator 字段
```zig
pub const Response = struct {
    status: std.http.Status,
    body: []const u8,
    
    pub fn deinit(self: Response, allocator: std.mem.Allocator) void {
        allocator.free(self.body);
    }
};
```

**验收标准**:
- [ ] 选择一种方案并统一使用
- [ ] 更新所有 Response.deinit 调用点
- [ ] 编译通过
- [ ] 测试内存正确释放

**依赖**: 
- URGENT-FIX (编译错误修复)

**相关文件**:
- src/http.zig
- src/ai/providers/*.zig (所有调用 Response 的地方)

**笔记**:
推荐选项1，符合 Zig 的常见模式。
