### TASK-BUG-027: 修复未使用的 task_type 参数
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 5分钟

**描述**:
`src/learning/root.zig:160` 处 `task_type` 参数未使用，导致编译错误。

**错误信息**:
```
src/learning/root.zig:160:9: error: unused function parameter
        task_type: []const u8,
        ^~~~~~~~~
```

**修复方案**:

方案 1: 使用 `_ = task_type;` 消除警告
```zig
pub fn trackModelPerformance(
    self: *Self,
    model_id: []const u8,
    success: bool,
    latency_ms: i64,
    token_cost: f64,
    task_type: []const u8,
) !void {
    _ = task_type; // TODO: 实现按任务类型分类统计
    
    // 现有代码...
}
```

方案 2: 实际使用参数 (如果业务需要)
```zig
// 将 task_type 存入性能记录
const record = PerformanceRecord{
    .model_id = try self.allocator.dupe(u8, model_id),
    .task_type = try self.allocator.dupe(u8, task_type), // 使用参数
    .success = success,
    .latency_ms = latency_ms,
    .token_cost = token_cost,
    .timestamp = std.time.timestamp(),
};
```

**文件位置**:
- `src/learning/root.zig:160`

**验收标准**:
- [ ] `zig build` 编译成功
- [ ] 无未使用参数警告

**依赖**:
- 无

**阻塞**:
- 无

**备注**:
- 建议先使用方案 1 快速修复
- 后续如果需要按任务类型分析，再实现方案 2
