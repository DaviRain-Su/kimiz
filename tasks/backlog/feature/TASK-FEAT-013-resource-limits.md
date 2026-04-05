### Task-FEAT-013: 实现 Resource Limits 系统
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 4h

**描述**:
为 kimiz 添加资源限制系统，防止 Agent 无限循环、资源耗尽或成本超支。

**背景**:
Nathan Flurry 强调生产级 agent 必须有资源限制：
- 防止无限循环
- 控制成本
- 资源隔离
- 超时保护

**目标功能**:

1. **ResourceLimits 结构**
```zig
pub const ResourceLimits = struct {
    max_steps: u32 = 50,           // 最大 Agent 循环步数
    max_tool_calls: u32 = 100,      // 最大工具调用总数
    max_memory_mb: u32 = 512,     // 最大内存使用
    timeout_ms: u64 = 300000,      // 5 分钟超时
    max_cost_usd: f64 = 10.00,     // 最大成本 ($10)
    max_output_chars: usize = 100000, // 最大输出长度
};
```

2. **ResourceUsage 追踪**
```zig
pub const ResourceUsage = struct {
    steps: u32,
    tool_calls: u32,
    memory_mb: u32,
    cost_usd: f64,
    output_chars: usize,
    elapsed_ms: u64,
};

pub fn trackUsage(self: *Harness, step: ReasoningStep) !void {
    self.usage.steps += 1;
    self.usage.tool_calls += if (step.tool_call) |_| 1 else 0;
    self.usage.elapsed_ms = step.duration_ms;
    
    // 检查限制
    try self.checkLimits();
}
```

3. **Limit 检查**
```zig
pub fn checkLimits(self: *const Harness) !void {
    const limits = self.config.limits;
    
    if (self.usage.steps > limits.max_steps) {
        return error.MaxStepsExceeded;
    }
    if (self.usage.tool_calls > limits.max_tool_calls) {
        return error.MaxToolCallsExceeded;
    }
    if (self.usage.cost_usd > limits.max_cost_usd) {
        return error.BudgetExceeded;
    }
    if (self.usage.elapsed_ms > limits.timeout_ms) {
        return error.TimeoutExceeded;
    }
}
```

4. **CLI 配置**
```bash
# 限制选项
kimiz --max-steps 30          # 最多 30 步
kimiz --max-cost 5.00        # 最多 $5
kimiz --timeout 600000       # 10 分钟超时

# 预设配置文件
kimiz --profile safe          # 安全模式 (低限制)
kimiz --profile normal         # 正常模式 (默认)
kimiz --profile unlimited      # 无限模式 (仅内部使用)
```

5. **错误处理**
```zig
pub const HarnessError = error{
    MaxStepsExceeded,
    MaxToolCallsExceeded,
    BudgetExceeded,
    TimeoutExceeded,
    MemoryExceeded,
};

pub fn formatError(err: HarnessError) []const u8 {
    return switch (err) {
        .MaxStepsExceeded => "Agent exceeded maximum steps (50). Try a more specific task.",
        .BudgetExceeded => "Agent exceeded budget ($10). Try a simpler task.",
        .TimeoutExceeded => "Agent timed out after 5 minutes.",
        // ...
    };
}
```

**验收标准**:
- [ ] 所有限制可配置
- [ ] 超限时优雅退出并显示原因
- [ ] Usage 报告可在结束时输出
- [ ] CLI 选项完整
- [ ] 与 Trace 系统集成

**依赖**:
- Task-FEAT-012 (Reasoning Trace)

**阻塞**:
- 无

**笔记**:
这是生产环境必需的安全机制。
