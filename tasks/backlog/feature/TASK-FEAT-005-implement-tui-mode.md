### Task-FEAT-005: 实现 TUI 交互模式
**状态**: pending
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 8h

**描述**:
`src/cli/root.zig` 中的 `runTui` 函数仅输出提示信息，TUI 模式未实现。需要基于 `src/tui/` 目录下的框架实现完整的终端 UI。

**当前代码** (cli/root.zig:166-172):
```zig
fn runTui(allocator: std.mem.Allocator, options: CliOptions) !void {
    _ = allocator;
    _ = options;
    try stdout.print("TUI mode not yet implemented. Use 'repl' mode instead.\n", .{});
}
```

**已有 TUI 框架**:
- `src/tui/root.zig` - TUI 模块
- `src/tui/terminal.zig` - 终端工具

**需要实现**:

1. **主界面布局** - 消息显示、输入区域、状态栏
2. **交互功能** - 滚动查看历史、语法高亮、工具输出展示
3. **快捷键** - Ctrl+C 中断、Ctrl+L 清除、方向键滚动

**验收标准**:
- [ ] TUI 能启动并显示界面
- [ ] 能滚动查看消息历史
- [ ] 能执行 Agent 并显示结果

**依赖**:
- CLI 参数解析完成 (TASK-BUG-014)
- Agent Loop 完成

**阻塞**:
- 用户体验（TUI vs REPL）

**笔记**:
TUI 是可选的，REPL 模式已可用。发现于 2026-04-05 代码审查。
