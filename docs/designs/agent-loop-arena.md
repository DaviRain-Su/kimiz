# Agent Loop Arena 设计方案

**日期**: 2026-04-06  
**状态**: 实施中  
**参考**: TigerBeetle Shell 模式

---

## 目标

减少 Agent 主循环中的内存碎片化，提升性能。

---

## 当前问题

Agent::runLoop 在每次迭代中有大量临时分配：
- 错误消息格式化 (`allocPrint`)
- Tool approval 拒绝消息
- 临时字符串拷贝
- 等等...

这些临时对象在循环中累积，导致内存碎片化。

---

## 方案设计

### 方案 A：Agent struct 添加 loop_arena 字段（复杂）

```zig
pub const Agent = struct {
    allocator: std.mem.Allocator,
    loop_arena: std.heap.ArenaAllocator,  // 添加字段
    
    pub fn init(...) !Self {
        return .{
            .allocator = allocator,
            .loop_arena = std.heap.ArenaAllocator.init(allocator),
            // ...
        };
    }
    
    fn runLoop(self: *Self) !void {
        while (...) {
            defer {
                _ = self.loop_arena.reset(.retain_capacity);
            }
            
            const loop_alloc = self.loop_arena.allocator();
            // 使用 loop_alloc 进行临时分配
        }
    }
};
```

**优点**：
- 可以在多次循环间复用arena内存
- 符合TigerBeetle模式

**缺点**：
- 修改struct，增加复杂性
- 需要仔细区分哪些用loop_alloc，哪些用self.allocator
- 容易出错

---

### 方案 B：runLoop 内部局部 arena（推荐）✅

```zig
fn runLoop(self: *Self) !void {
    self.iteration_count = 0;

    while (self.iteration_count < self.options.max_iterations) {
        // 每次迭代创建局部 arena
        var loop_arena = std.heap.ArenaAllocator.init(self.allocator);
        defer loop_arena.deinit();
        const loop_alloc = loop_arena.allocator();
        
        self.iteration_count += 1;
        
        // 临时分配用 loop_alloc
        const err_msg = error_handler.formatError(loop_alloc, err) catch
            try std.fmt.allocPrint(loop_alloc, "AI call failed: {s}", .{@errorName(err)});
        // 不需要 defer，arena.deinit() 时自动释放
        
        // 需要保存到messages的内容仍然用 self.allocator（深拷贝）
    }
}
```

**优点**：
- ✅ 不修改 Agent struct
- ✅ 实现简单，不易出错
- ✅ 每次迭代自动清理
- ✅ 向后兼容

**缺点**：
- 每次迭代重新分配 arena（性能影响可忽略）

---

## 实施方案

**采用方案 B**：局部 arena

### 阶段 1：识别临时分配

在 runLoop 中需要改用 loop_alloc 的分配：

| 位置 | 当前 | 修改后 |
|------|------|--------|
| 错误消息 (line 410) | `self.allocator` | `loop_alloc` |
| 错误恢复 dupe (line 457) | `self.allocator` | `loop_alloc` |
| Approval 拒绝消息 (line 526) | `self.allocator` | `loop_alloc` |

**保持使用 self.allocator 的**：
- messages 列表的内容（长期保存）
- tool_call_id, tool_name 的深拷贝（添加到 messages）

### 阶段 2：实施

1. 在 runLoop while 循环顶部添加 arena
2. 修改临时分配使用 loop_alloc
3. 移除对应的 defer free（由 arena 管理）
4. 测试验证

### 阶段 3：验证

- ✅ make build
- ✅ make test
- 📊 内存分析（可选）：使用 CountingAllocator 对比优化前后

---

## 预期收益

- **减少内存碎片化**：每次迭代的临时对象统一释放
- **简化代码**：减少手动 `defer free`
- **性能提升**：arena 分配比单独 alloc/free 快

---

## 风险评估

🟢 **低风险**
- 不修改 struct 布局
- 局部变更，易于回滚
- 完全向后兼容

---

## 参考

- [TigerBeetle Shell 模式](../research/TIGERBEETLE-PATTERNS-ANALYSIS.md)
- [Arena Allocator Pattern](https://www.rfleury.com/p/untangling-lifetimes-the-arena-allocator)
