### Task-FEAT-012: 实现 Reasoning Trace 系统
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 6h

**描述**:
参考生产级 coding agent 的实现，为 kimiz 添加完整的 Reasoning Trace 系统，用于追踪 Agent 的思考过程和决策路径。

**背景**:
Nathan Flurry (Rivet/agentOS 创始人) 强调：生产级 agent 必须有完整的 reasoning trace，让用户能：
1. **调试**：为什么 Agent 做了这个决定？
2. **审计**：Agent 做了什么操作？
3. **复现**：完全相同的输入是否产生相同输出？

**目标功能**:

1. **ReasoningStep 结构**
```zig
pub const ReasoningStep = struct {
    step_number: u32,
    thought: []const u8,           // Agent 的思考过程
    tool_call: ?ToolCall,         // 调用的工具
    tool_result: ?[]const u8,      // 工具输出
    timestamp: i64,
    duration_ms: u64,
    tokens_used: ?TokenUsage,
};
```

2. **Trace 结构**
```zig
pub const Trace = struct {
    session_id: []const u8,
    task: []const u8,
    workspace: []const u8,
    started_at: i64,
    completed_at: ?i64,
    steps: std.ArrayList(ReasoningStep),
    final_answer: []const u8,
    total_cost_usd: f64,
    total_tokens: ?TokenUsage,
    error: ?[]const u8,
};
```

3. **Trace 收集**
```zig
pub fn recordStep(self: *Trace, step: ReasoningStep) !void {
    try self.steps.append(step);
}

pub fn finalize(self: *Trace, answer: []const u8, usage: TokenUsage) void {
    self.final_answer = answer;
    self.total_tokens = usage;
    self.completed_at = std.time.now();
}
```

4. **CLI 命令**
```bash
kimiz --trace                  # 启用 trace
kimiz --trace-file trace.json  # 指定输出文件
kimiz trace show              # 查看上次 trace
```

5. **可视化输出**
```json
{
  "session_id": "20260405-143022-abcd",
  "task": "Fix the memory leak in http.zig",
  "steps": [
    {
      "step": 1,
      "thought": "I need to understand the codebase structure first...",
      "tool": "read_file",
      "args": {"path": "src/http.zig"},
      "duration_ms": 45
    },
    {
      "step": 2,
      "thought": "Found a potential issue in postStream...",
      "tool": "grep",
      "args": {"pattern": "defer"},
      "duration_ms": 23
    }
  ],
  "total_cost_usd": 0.023,
  "completed_at": "2026-04-05T14:35:00Z"
}
```

**验收标准**:
- [ ] 完整记录每步的 thought → action → observation
- [ ] Trace 可保存到 JSON 文件
- [ ] CLI 命令查看/分析 trace
- [ ] 错误时记录 error 信息
- [ ] 与 Session 持久化集成

**依赖**:
- Task-FEAT-010 (Session Persistence)

**阻塞**:
- 无

**笔记**:
这是生产级 Agent 的关键特性，让用户能理解和调试 Agent 行为。
