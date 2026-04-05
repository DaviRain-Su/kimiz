### Task-FEAT-010: 实现 Session Persistence 和 Resumption
**状态**: pending
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 6h

**描述**:
实现会话持久化和中断恢复功能。

**目标功能**:

1. **Session 结构**
```zig
pub const Session = struct {
    id: []const u8,
    created_at: i64,
    workspace_root: []const u8,
    history: []const Message,        // 完整消息历史
    memory: WorkingMemory,           // 精炼的工作记忆
    task: []const u8,                // 当前任务描述
    tracked_files: []const []const u8, // 追踪的文件
};
```

2. **持久化**
```zig
pub fn saveSession(agent: *Agent, path: []const u8) !void {
    const session = Session{
        .id = generateSessionId(),
        .created_at = std.time.now(),
        .history = agent.messages.items,
        .memory = agent.memory_manager.working,
        .task = agent.current_task,
        .tracked_files = agent.tracked_files.items,
    };
    try std.json.stringifyFile(session, path);
}
```

3. **恢复**
```bash
kimiz --resume latest           # 恢复最新会话
kimiz --resume 20260401-144025  # 恢复指定会话
```

4. **会话存储**
```
~/.kimiz/sessions/
├── 20260401-144025-2dd0aa.json
├── 20260401-150203-a1b2c3.json
└── latest -> 20260401-150203-a1b2c3.json
```

**验收标准**:
- [ ] 会话正确保存到磁盘
- [ ] 能恢复指定会话
- [ ] REPL 内可用 /reset 命令
- [ ] 恢复后 Agent 状态完整

**依赖**:
- Task-FEAT-008 (Context Truncation)

**阻塞**:
- Subagent (Task-FEAT-011)

**笔记**:
参考 Raschka 的 SessionStore 实现。
