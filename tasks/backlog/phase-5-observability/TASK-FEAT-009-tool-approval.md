### Task-FEAT-009: 实现 Tool Approval 交互流程
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 4h

**描述**:
完成危险工具的用户审批流程，参考 Raschka 的 approval 系统。

**目标功能**:

1. **Approval 策略**
```zig
pub const ApprovalPolicy = enum {
    ask,    // 每次询问 (默认)
    auto,   // 自动批准 (YOLO 模式)
    never,  // 始终拒绝
};

pub const ToolDefinition = struct {
    // ... 现有字段
    risky: bool = false,  // 是否危险
};
```

2. **交互式确认**
```zig
pub fn requestApproval(name: []const u8, args: []const u8) !bool {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Approve {s} with {s}? [y/N]: ", .{name, args});
    
    var buf: [10]u8 = undefined;
    const input = try std.io.getStdIn().reader().readUntilDelimiter(&buf, '\n');
    
    return std.mem.eql(u8, input, "y") or std.mem.eql(u8, input, "yes");
}
```

3. **危险工具分类**
```zig
const RISKY_TOOLS = [_][]const u8{
    "bash",        // 执行命令
    "write_file",  // 写文件
    // "read_file" 是安全的
};
```

4. **CLI 集成**
```bash
kimiz --approval ask    # 默认，每次询问
kimiz --approval auto    # YOLO 模式
kimiz --approval never   # 只读模式
```

**验收标准**:
- [ ] 危险工具执行前正确询问用户
- [ ] YOLO 模式自动批准
- [ ] 审批历史记录到 learning 系统
- [ ] Ctrl+C 可中断

**依赖**:
- Task-FEAT-006 (WorkspaceContext)

**阻塞**:
- 无

**笔记**:
这是安全性关键功能。
