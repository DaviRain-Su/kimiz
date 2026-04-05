### Task-FEAT-001: 完整实现 TUI 界面
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 12h

**描述**:
当前 TUI 框架只有骨架实现，需要完整实现终端用户界面，包括消息显示、输入处理、滚动、历史记录等功能。

**当前状态**:
- 基础结构存在 (`src/tui/root.zig`, `src/tui/terminal.zig`)
- 布局系统已定义
- 但许多功能未实现或为空

**需要实现的功能**:

1. **消息显示**
   - [ ] 用户消息（绿色）
   - [ ] AI 消息（蓝色，支持流式显示）
   - [ ] 系统消息（黄色）
   - [ ] 工具调用（洋红色）
   - [ ] 工具结果（青色）
   - [ ] 消息时间戳
   - [ ] 消息气泡/边框

2. **输入处理**
   - [ ] 多行输入支持
   - [ ] 光标移动（左右、行首、行尾）
   - [ ] 文本选择（可选）
   - [ ] 粘贴支持
   - [ ] 输入历史（上下键浏览）

3. **滚动功能**
   - [ ] 鼠标滚轮支持
   - [ ] PageUp/PageDown
   - [ ] 滚动条显示
   - [ ] 智能滚动（新消息自动滚动到底部）

4. **侧边栏**
   - [ ] 会话列表
   - [ ] 模型信息显示
   - [ ] 快捷键提示
   - [ ] 可折叠/展开

5. **状态栏**
   - [ ] 当前模型
   - [ ] 连接状态
   - [ ] Token 使用量
   - [ ] 当前时间

6. **主题支持**
   - [ ] 深色主题（默认）
   - [ ] 浅色主题
   - [ ] 系统主题
   - [ ] 颜色配置

**技术要点**:

```zig
// 消息显示示例
fn renderMessage(self: *TuiApp, msg: DisplayMessage, row: usize) !void {
    switch (msg.msg_type) {
        .user => {
            try terminal.applyStyle(.{ .fg = .green, .bold = true });
            try stdout.print(" You ", .{});
            try terminal.resetStyle();
            try self.renderWrappedText(msg.content, row, 6);
        },
        .assistant => {
            try terminal.applyStyle(.{ .fg = .blue, .bold = true });
            try stdout.print(" AI ", .{});
            try terminal.resetStyle();
            if (msg.is_streaming) {
                try self.renderStreamingText(msg.content, row, 5);
            } else {
                try self.renderWrappedText(msg.content, row, 5);
            }
        },
        // ...
    }
}

// 文本自动换行
fn renderWrappedText(self: *TuiApp, text: []const u8, start_row: usize, indent: usize) !void {
    const width = self.layout.chat_width - indent - 2;
    var row = start_row;
    var start: usize = 0;
    
    while (start < text.len) {
        const end = @min(start + width, text.len);
        try terminal.moveCursor(row, indent);
        try stdout.print("{s}", .{text[start..end]});
        row += 1;
        start = end;
    }
}
```

**依赖库**:
- 考虑使用 `libvaxis` 或 `crossterm` 简化 TUI 开发
- 或继续使用原始终端控制（更轻量）

**需要修改的文件**:
- [ ] src/tui/root.zig
- [ ] src/tui/terminal.zig
- [ ] 可能需要新增 src/tui/widgets.zig

**验收标准**:
- [ ] 启动 `kimiz tui` 显示完整界面
- [ ] 可以输入消息并发送
- [ ] AI 响应实时显示（流式）
- [ ] 可以浏览历史消息（滚动）
- [ ] 快捷键工作正常（Ctrl+C 退出等）
- [ ] 不同终端尺寸自适应
- [ ] 无闪烁、无乱码

**依赖**:
- URGENT-FIX-compilation-errors
- TASK-BUG-014-fix-cli-unimplemented
- TASK-BUG-018-fix-http-streaming-implementation（用于实时显示）

**阻塞**:
- 用户友好的交互体验

**笔记**:
这是用户体验的关键。可以先实现基础功能，再逐步添加高级特性。考虑参考 `lazygit`、`k9s` 等项目的 TUI 设计。
