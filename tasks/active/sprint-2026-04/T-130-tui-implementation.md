# T-130: TUI Implementation - Terminal User Interface

**Status**: `research`  
**Priority**: P1  
**Estimated effort**: 8h  
**Created**: 2026-04-06  
**Owner**: Droid  
**Branch**: `feature/tui-implementation`

---

## Background

KimiZ已经集成了libvaxis TUI库（vendor/libvaxis/），并有基础的TUI框架代码（src/tui/root.zig, terminal.zig），但功能不完整。需要实现完整的终端用户界面，包括消息显示、输入处理、滚动、历史记录等功能。

### 当前状态

**已有基础**：
- ✅ libvaxis库已集成（vendor/libvaxis/）
- ✅ TUI框架骨架（src/tui/root.zig - 631行）
- ✅ Terminal helper（src/tui/terminal.zig - 9479字节）
- ✅ CLI入口点（kimiz --tui / -t）
- ✅ 基础数据结构（Event, MessageType, DisplayMessage, TuiState）

**待完成功能**：
- ❌ 消息渲染（用户/AI/系统/工具）
- ❌ 流式显示支持
- ❌ 输入处理（多行、历史、光标）
- ❌ 滚动功能（鼠标滚轮、PageUp/Down）
- ❌ 侧边栏（会话列表、模型信息）
- ❌ 状态栏（Token统计、连接状态）
- ❌ 主题支持

**当前问题**：
- 🔴 编译错误：vendor/fff.nvim缺少Cargo.toml
- 🔴 编译错误：uucode包Zig 0.16 API不兼容（std.Io.Clock.awake.now()）

---

## Research

### Phase 1: 理解现有代码

- [ ] `src/tui/root.zig` — 631行，理解TuiState和事件循环
- [ ] `src/tui/terminal.zig` — 理解terminal控制函数
- [ ] `vendor/libvaxis/` — libvaxis API和widget系统
- [ ] `tasks/backlog/phase-8-platform/TASK-FEAT-001-implement-tui-complete.md` — 原任务需求

### Phase 2: 参考实现

- [ ] libvaxis examples — 学习官方示例用法
- [ ] lazygit TUI — 参考成熟的Zig TUI项目
- [ ] k9s TUI — 参考Kubernetes CLI的TUI设计
- [ ] Anthropic Claude Desktop — 参考AI对话界面设计

### Phase 3: 架构设计

- [ ] 消息渲染pipeline（从core.Message到TUI显示）
- [ ] 流式显示机制（Agent events → TUI updates）
- [ ] 输入处理状态机（normal/editing/history）
- [ ] 布局计算（sidebar/chat/statusbar的响应式布局）

---

## Specification

**Spec文件**: `docs/specs/T-130-tui-implementation.md` (待创建)

### 核心功能

#### 1. 消息显示系统

```zig
pub const MessageRenderer = struct {
    allocator: Allocator,
    window: vaxis.Window,
    theme: Theme,
    
    pub fn render(self: *Self, msg: DisplayMessage, row: usize) !void {
        switch (msg.msg_type) {
            .user => try self.renderUserMessage(msg, row),
            .assistant => try self.renderAIMessage(msg, row),
            .system => try self.renderSystemMessage(msg, row),
            .tool_call => try self.renderToolCall(msg, row),
            .tool_result => try self.renderToolResult(msg, row),
        }
    }
    
    fn renderUserMessage(self: *Self, msg: DisplayMessage, row: usize) !void {
        // 绿色背景 + 用户图标
        try self.window.writeCell(row, 0, .{
            .char = .{ .grapheme = "👤" },
            .style = .{ .fg = .green, .bold = true },
        });
        try self.renderWrappedText(msg.content, row, 2);
    }
};
```

#### 2. 流式显示支持

```zig
pub const StreamingRenderer = struct {
    current_line: ArrayList(u8),
    cursor_pos: usize,
    
    pub fn appendChunk(self: *Self, chunk: []const u8) !void {
        try self.current_line.appendSlice(chunk);
        try self.redrawLine();
    }
    
    fn redrawLine(self: *Self) !void {
        // 只重绘当前行，避免全屏刷新
        const wrapped = try self.wrapText(self.current_line.items);
        for (wrapped) |line, i| {
            try self.window.print(self.start_row + i, 2, line, .{});
        }
    }
};
```

#### 3. 输入处理

```zig
pub const InputHandler = struct {
    buffer: ArrayList(u8),
    cursor: usize,
    history: ArrayList([]const u8),
    history_index: ?usize,
    
    pub fn handleKey(self: *Self, key: vaxis.Key) !void {
        switch (key.codepoint) {
            '\n' => try self.submit(),
            vaxis.Key.backspace => try self.deleteChar(),
            vaxis.Key.left => self.cursor = if (self.cursor > 0) self.cursor - 1 else 0,
            vaxis.Key.right => self.cursor = @min(self.cursor + 1, self.buffer.items.len),
            vaxis.Key.up => try self.historyPrev(),
            vaxis.Key.down => try self.historyNext(),
            else => try self.insertChar(key.codepoint),
        }
    }
};
```

---

## Implementation Plan

### Phase 0: 修复编译错误 (1h)

#### Step 1: 修复vendor/fff.nvim问题
```bash
# 选项A：移除fff.nvim依赖（如果不需要）
rm -rf vendor/fff.nvim
# 修改build.zig移除对它的引用

# 选项B：修复Cargo配置
cd vendor/fff.nvim
cargo init --lib
```

#### Step 2: 修复uucode Zig 0.16兼容性
```zig
// zig-pkg/uucode/.../tables.zig:26
// OLD:
const total_start = try std.Io.Clock.awake.now(io);

// NEW:
const total_start = std.Io.Clock.awake.now(io); // 移除try
```

---

### Phase 1: 基础消息渲染 (2h)

- [ ] MessageRenderer结构体
- [ ] 5种消息类型的渲染函数
- [ ] 文本自动换行（wrapText）
- [ ] 颜色主题配置
- [ ] 单元测试

---

### Phase 2: 流式显示 (1.5h)

- [ ] StreamingRenderer实现
- [ ] Agent event订阅（message_delta）
- [ ] 增量渲染（只更新变化部分）
- [ ] 性能优化（避免全屏重绘）

---

### Phase 3: 输入处理 (1.5h)

- [ ] InputHandler状态机
- [ ] 多行输入支持
- [ ] 光标移动（左右、Home/End）
- [ ] 输入历史（上下键）
- [ ] Ctrl+C/D快捷键

---

### Phase 4: 滚动功能 (1h)

- [ ] ScrollView widget
- [ ] 鼠标滚轮事件
- [ ] PageUp/PageDown
- [ ] 自动滚动到底部（新消息）
- [ ] 滚动条显示

---

### Phase 5: 布局和主题 (1h)

- [ ] 响应式布局（终端尺寸变化）
- [ ] 侧边栏（可折叠）
- [ ] 状态栏（Token/模型信息）
- [ ] 深色/浅色主题切换

---

## Acceptance Criteria

### Phase 0 (编译修复)
- [ ] `zig build` 编译成功
- [ ] 无vendor依赖错误

### Phase 1 (基础功能)
- [ ] `kimiz --tui` 启动成功
- [ ] 可以显示历史消息（不同颜色）
- [ ] 可以输入并发送消息
- [ ] AI响应显示在屏幕上

### Phase 2 (流式显示)
- [ ] AI响应实时流式显示（逐字显示）
- [ ] 无闪烁、无乱码
- [ ] 性能流畅（60fps）

### Phase 3 (完整体验)
- [ ] 多行输入支持
- [ ] 历史记录浏览（上下键）
- [ ] 滚动历史消息（鼠标滚轮）
- [ ] 侧边栏和状态栏显示
- [ ] 主题切换工作

### Phase 4 (生产就绪)
- [ ] 在不同终端尺寸自适应
- [ ] 长时间运行无内存泄漏
- [ ] 异常情况graceful handling
- [ ] 快捷键提示清晰

---

## Log

### 2026-04-06 09:20 - 任务创建
- 创建feature/tui-implementation分支
- 基于最新main（包含libvaxis）
- 状态：research阶段

### 2026-04-06 09:25 - 发现编译错误
- vendor/fff.nvim缺少Cargo.toml（Rust依赖问题）
- uucode包Zig 0.16 API不兼容：`std.Io.Clock.awake.now(io)` 不再返回error
- 需要先修复编译才能继续

### Next Steps
- 修复编译错误
- 阅读src/tui/root.zig理解现有实现
- 查看libvaxis examples
- 开始Phase 1实施

---

## Lessons Learned

_(任务完成后填写)_

---

## Related

- **Parent**: 无
- **Depends on**: libvaxis集成（已完成）
- **Blocks**: 无
- **Related**: 
  - TASK-FEAT-001-implement-tui-complete（原任务，已标记完成但实际未完成）
  - T-128 ABD Phase（autonomous mode可能需要TUI交互）
