### Task-FEAT-008: 实现 Context Truncation 机制
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 3h

**描述**:
防止上下文无限增长导致 context window overflow。

**目标功能**:

1. **消息历史限制**
```zig
const MAX_CONTEXT_BYTES = 100000;  // ~100KB
const MAX_MESSAGES = 50;          // 最大消息数
```

2. **工具输出截断**
```zig
const MAX_TOOL_OUTPUT = 4000;     // 工具输出最大字符

fn clipOutput(output: []const u8) []const u8 {
    if (output.len <= MAX_TOOL_OUTPUT) return output;
    return output[0..MAX_TOOL_OUTPUT];
}
```

3. **历史去重**
   - 同一文件的重复 read_file 只保留最后一次
   - 连续相似消息合并

4. **上下文管理函数**
```zig
pub fn enforceContextLimit(self: *Agent, max_bytes: usize) !void {
    // 计算总大小，超限时从最旧消息开始删除
    // 保留 system prompt 和最近的消息
}

pub fn deduplicateHistory(self: *Agent) void {
    // 去重逻辑
}
```

**验收标准**:
- [ ] 长对话不再导致 context overflow
- [ ] 工具输出正确截断
- [ ] 去重功能正常工作
- [ ] 基准测试验证

**依赖**:
- Task-FEAT-007 (Prompt Caching)

**阻塞**:
- Session Persistence (Task-FEAT-009)

**笔记**:
参考 Raschka 的 clip() 和 history_text() 实现。
