### TASK-P2-002: 完成 Learning recommendModel 实现
**状态**: pending
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 4h

**描述**:
LearningEngine.recommendModel() 是空实现，需要根据历史性能数据推荐最优模型。

**位置**: `src/learning/root.zig:275-281`

**当前代码**:
```zig
pub fn recommendModel(
    self: *Self,
    task_type: []const u8,
    preferred: ?[]const u8,
) ?[]const u8 {
    // TODO: Implement model recommendation logic
    _ = self;
    _ = task_type;
    _ = preferred;
    return null;
}
```

**修复方案**:

```zig
pub fn recommendModel(
    self: *Self,
    task_type: []const u8,
    preferred: ?[]const u8,
) ?[]const u8 {
    // 1. 如果有用户偏好且该模型历史表现良好，直接返回
    if (preferred) |p| {
        if (self.model_metrics.get(p)) |metrics| {
            if (metrics.user_satisfaction_score > 0.7) {
                return p;
            }
        }
    }
    
    // 2. 查找该任务类型的历史最佳模型
    var best_model: ?[]const u8 = null;
    var best_score: f64 = 0.0;
    
    var it = self.model_metrics.iterator();
    while (it.next()) |entry| {
        const model_id = entry.key_ptr.*;
        const metrics = entry.value_ptr.*;
        
        // 计算综合分数
        const score = calculateModelScore(metrics, task_type);
        
        if (score > best_score) {
            best_score = score;
            best_model = model_id;
        }
    }
    
    // 3. 如果没有历史数据，返回默认模型
    return best_model orelse "gpt-4o";
}

fn calculateModelScore(metrics: ModelMetrics, task_type: []const u8) f64 {
    var score: f64 = 0.0;
    
    // 成功率 (40%)
    const success_rate = @as(f64, @floatFromInt(metrics.success_count)) / 
                        @as(f64, @max(1, metrics.total_requests));
    score += success_rate * 40.0;
    
    // 用户满意度 (30%)
    score += metrics.user_satisfaction_score * 30.0;
    
    // 速度分数 (20%) - 越快越好
    const speed_score = @max(0, 100.0 - @as(f64, @floatFromInt(metrics.average_latency_ms)) / 100.0);
    score += speed_score * 20.0;
    
    // 成本效率 (10%) - 越便宜越好
    const cost_score = @max(0, 10.0 - metrics.average_token_cost);
    score += cost_score * 10.0;
    
    return score;
}
```

**验收标准**:
- [ ] recommendModel 返回推荐模型
- [ ] 考虑用户偏好
- [ ] 基于历史性能选择最优
- [ ] 有兜底默认值

**依赖**:
- TASK-INTEG-002 (集成 Learning)

**阻塞**:
- 无

**笔记**:
无
