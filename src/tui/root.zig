//! TUI Main - Terminal User Interface Application using libvaxis

const std = @import("std");
const vaxis = @import("vaxis");
const core = @import("../core/root.zig");
const ai = @import("../ai/root.zig");
const agent = @import("../agent/root.zig");

// ============================================================================
// Event Type for Vaxis Event Loop
// ============================================================================

pub const Event = union(enum) {
    key_press: vaxis.Key,
    mouse: vaxis.Mouse,
    winsize: vaxis.Winsize,
    focus_in,
    focus_out,
    paste_start,
    paste_end,
    paste: []const u8,
    color_scheme: vaxis.Color.Scheme,
    file_monitor: vaxis.FileMonitor.Event,
};

// ============================================================================
// Message Types
// ============================================================================

pub const MessageType = enum {
    user,
    assistant,
    system,
    tool_call,
    tool_result,
};

pub const DisplayMessage = struct {
    msg_type: MessageType,
    content: []const u8,
    timestamp: i64,
    is_streaming: bool = false,
};

// ============================================================================
// TUI State
// ============================================================================

pub const TuiState = struct {
    allocator: std.mem.Allocator,
    messages: std.ArrayList(DisplayMessage),
    input_buffer: std.ArrayList(u8),
    input_cursor: usize = 0,
    scroll_offset: usize = 0,
    is_running: bool = true,
    is_streaming: bool = false,
    current_model: []const u8 = "gpt-4o",
    current_session: []const u8 = "default",
    input_history: InputHistory,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .messages = .empty,
            .input_buffer = .empty,
            .input_history = InputHistory.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.messages.deinit();
        self.input_buffer.deinit();
        self.input_history.deinit();
    }

    pub fn addMessage(self: *Self, msg_type: MessageType, content: []const u8) !void {
        try self.messages.append(.{
            .msg_type = msg_type,
            .content = content,
            .timestamp = std.time.milliTimestamp(),
        });
        self.scroll_offset = 0;
    }

    pub fn addUserMessage(self: *Self, content: []const u8) !void {
        try self.addMessage(.user, content);
    }

    pub fn addSystemMessage(self: *Self, content: []const u8) !void {
        try self.addMessage(.system, content);
    }
};

// ============================================================================
// Input History
// ============================================================================

pub const InputHistory = struct {
    items: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
    max_history: usize = 100,
    current_index: ?usize = null,
    temp_input: ?[]const u8 = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .items = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.items.items) |item| {
            self.allocator.free(item);
        }
        if (self.temp_input) |temp| {
            self.allocator.free(temp);
        }
        self.items.deinit();
    }

    pub fn add(self: *Self, input: []const u8) !void {
        if (input.len == 0) return;
        if (self.items.items.len > 0) {
            const last = self.items.items[self.items.items.len - 1];
            if (std.mem.eql(u8, last, input)) return;
        }
        if (self.items.items.len >= self.max_history) {
            const oldest = self.items.orderedRemove(0);
            self.allocator.free(oldest);
        }
        const copy = try self.allocator.dupe(u8, input);
        try self.items.append(copy);
        self.reset();
    }

    pub fn navigateUp(self: *Self, current_input: []const u8) ?[]const u8 {
        if (self.items.items.len == 0) return null;
        if (self.current_index == null) {
            if (self.temp_input) |temp| self.allocator.free(temp);
            self.temp_input = self.allocator.dupe(u8, current_input) catch null;
        }
        const new_index = if (self.current_index) |idx|
            if (idx > 0) idx - 1 else 0
        else
            self.items.items.len - 1;
        self.current_index = new_index;
        return self.items.items[new_index];
    }

    pub fn navigateDown(self: *Self) ?[]const u8 {
        if (self.current_index) |idx| {
            if (idx + 1 < self.items.items.len) {
                self.current_index = idx + 1;
                return self.items.items[self.current_index.?];
            } else {
                self.current_index = null;
                return self.temp_input;
            }
        }
        return null;
    }

    pub fn reset(self: *Self) void {
        self.current_index = null;
        if (self.temp_input) |temp| {
            self.allocator.free(temp);
            self.temp_input = null;
        }
    }
};

// ============================================================================
// Draw Helpers
// ============================================================================

fn drawText(win: *vaxis.Window, text: []const u8, style: vaxis.Style, wrap_width: u16) void {
    if (text.len == 0) return;
    var row: u16 = 0;
    var col: u16 = 0;
    var i: usize = 0;
    while (i < text.len) {
        const ch = text[i];
        if (ch == '\n') {
            row += 1;
            col = 0;
            i += 1;
            continue;
        }
        if (col >= wrap_width) {
            row += 1;
            col = 0;
        }
        if (row >= win.height) break;
        win.cell[col][row] = .{
            .char = .{ .grapheme = &.{ch} },
            .style = style,
        };
        col += 1;
        i += 1;
    }
}

fn drawCenteredText(win: *vaxis.Window, text: []const u8, row: u16, style: vaxis.Style) void {
    const pad = (win.width -| @as(u16, @intCast(text.len))) / 2;
    var col = pad;
    for (text) |ch| {
        if (col >= win.width) break;
        win.cell[col][row] = .{
            .char = .{ .grapheme = &.{ch} },
            .style = style,
        };
        col += 1;
    }
}

// ============================================================================
// TUI Application (Vaxis-based)
// ============================================================================

pub const TuiApp = struct {
    allocator: std.mem.Allocator,
    vx: vaxis.Vaxis,
    tty: vaxis.Tty,
    state: TuiState,
    ai_agent: ?agent.Agent,
    ai_client: ?ai.Ai,
    tty_buf: [4096]u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        var self: Self = .{
            .allocator = allocator,
            .vx = try vaxis.init(allocator, .{}),
            .tty = undefined,
            .tty_buf = undefined,
            .state = TuiState.init(allocator),
            .ai_agent = null,
            .ai_client = null,
        };
        self.tty = try vaxis.Tty.init(&self.tty_buf);
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.state.deinit();
        self.vx.deinit(self.allocator, self.tty.writer());
        self.tty.deinit();
        if (self.ai_agent) |*a| a.deinit();
        if (self.ai_client) |*c| c.deinit();
    }

    pub fn setupAgent(self: *Self, _: core.Model, options: agent.AgentOptions) !void {
        self.ai_agent = try agent.Agent.init(self.allocator, options);
    }

    /// Main run loop using Vaxis
    pub fn run(self: *Self) !void {
        try self.vx.enterAltScreen(self.tty.writer());
        try self.vx.setBracketedPaste(self.tty.writer(), true);
        try self.vx.setMouseMode(self.tty.writer(), true);

        var loop = vaxis.Loop(Event){ .vaxis = &self.vx, .tty = self.tty };
        try loop.init();
        try loop.start();
        defer loop.stop();

        try self.vx.queryTerminal(self.tty.writer(), 1_000_000_000);

        try self.state.addSystemMessage("Welcome to KimiZ TUI! Press Ctrl+C or :q to exit.");

        while (self.state.is_running) {
            loop.pollEvent();
            while (loop.tryEvent()) |evt| {
                try self.handleEvent(evt);
                if (!self.state.is_running) break;
            }

            const winsize = try self.tty.getWinsize();
            try self.vx.resize(self.allocator, self.tty.writer(), winsize);

            try self.drawFrame(winsize);

            try self.vx.render(self.tty.writer());

            std.time.sleep(16_000_000);
        }

        try self.tty.writer().writeAll(vaxis.ctlseqs.rmcup);
        try self.tty.writer().flush();
    }

    fn handleEvent(self: *Self, evt: Event) !void {
        switch (evt) {
            .key_press => |key| {
                // Ctrl+C or :q -> exit
                if (key.codepoint == 'c' and key.mods.ctrl) {
                    self.state.is_running = false;
                    return;
                }

                if (key.codepoint == 27) { // ESC
                    // Could be part of :q or standalone ESC
                    return;
                }

                if (key.codepoint == '\r' or key.codepoint == '\n') {
                    // Enter - submit message
                    if (self.state.input_buffer.items.len > 0 and !self.state.is_streaming) {
                        const input = try self.allocator.dupe(u8, self.state.input_buffer.items);
                        try self.state.input_history.add(input);
                        try self.state.addUserMessage(input);
                        self.state.input_buffer.clearAndFree();
                        self.state.input_cursor = 0;
                        // TODO: send to agent
                    }
                    return;
                }

                if (key.codepoint == 127 or key.codepoint == 8) { // Backspace
                    if (self.state.input_cursor > 0) {
                        _ = self.state.input_buffer.orderedRemove(self.state.input_cursor - 1);
                        self.state.input_cursor -= 1;
                    }
                    return;
                }

                if (key.codepoint == 0x7F) { // Delete
                    if (self.state.input_cursor < self.state.input_buffer.items.len) {
                        _ = self.state.input_buffer.orderedRemove(self.state.input_cursor);
                    }
                    return;
                }

                // Arrow keys / navigation (CSI sequence codepoints)
                if (key.codepoint == 'A' and key.mods.ctrl == false) {
                    // Up - history or scroll
                    if (self.state.input_history.navigateUp(self.state.input_buffer.items)) |history_input| {
                        self.state.input_buffer.clearRetainingCapacity();
                        try self.state.input_buffer.appendSlice(history_input);
                        self.state.input_cursor = self.state.input_buffer.items.len;
                    }
                    return;
                }

                if (key.codepoint == 'B' and key.mods.ctrl == false) {
                    // Down
                    if (self.state.input_history.navigateDown()) |history_input| {
                        self.state.input_buffer.clearRetainingCapacity();
                        try self.state.input_buffer.appendSlice(history_input);
                        self.state.input_cursor = self.state.input_buffer.items.len;
                    }
                    return;
                }

                if (key.codepoint == 'D' and key.mods.ctrl == false) {
                    // Left
                    if (self.state.input_cursor > 0) self.state.input_cursor -= 1;
                    return;
                }

                if (key.codepoint == 'C' and key.mods.ctrl == false) {
                    // Right
                    if (self.state.input_cursor < self.state.input_buffer.items.len) self.state.input_cursor += 1;
                    return;
                }

                if (key.codepoint == 'l' and key.mods.ctrl) {
                    // Ctrl+L - clear screen (handled by next render)
                    return;
                }

                // Printable characters - add to input buffer
                if (key.codepoint >= 32 and key.codepoint < 127) {
                    try self.state.input_buffer.insert(self.state.input_cursor, @as(u8, @intCast(key.codepoint)));
                    self.state.input_cursor += 1;
                    self.state.input_history.reset();
                }
            },
            .winsize => |ws| {
                _ = ws; // Handled in main loop
            },
            .mouse => |mouse| {
                _ = mouse; // TODO: handle mouse clicks for scrolling
            },
            .paste_start => {
                // TODO: handle bracketed paste
            },
            .paste_end => {},
            .paste => |text| {
                _ = text;
                // TODO: handle paste
            },
            .focus_in => {},
            .focus_out => {},
            .color_scheme => {},
            .file_monitor => {},
        }
    }

    fn drawFrame(self: *Self, winsize: vaxis.Winsize) !void {
        const cols = winsize.cols;
        const rows = winsize.rows;
        var main_win = self.vx.window();
        main_win.fill(' ');

        const sidebar_width: u16 = 20;
        const input_height: u16 = 3;

        // --- Sidebar ---
        if (cols > sidebar_width + 10) {
            var sidebar = main_win.child(.{ .x_off = 0, .y_off = 0, .width = sidebar_width, .height = rows });

            // Sidebar background
            const sidebar_style: vaxis.Style = .{
                .bg = .{ .index = 235 }, // dark gray
                .fg = .{ .index = 248 }, // light gray
            };
            sidebar.fillStyle(' ', sidebar_style);

            const border_style: vaxis.Style = .{ .fg = .{ .index = 240 } };
            for (0..rows) |r| {
                if (r < sidebar.height) {
                    sidebar.cell[sidebar_width - 1][r] = .{
                        .char = .{ .grapheme = "│" },
                        .style = border_style,
                    };
                }
            }

            // Title
            const title_style: vaxis.Style = .{ .fg = .{ .index = 75 }, .bold = true };
            drawCenteredText(&sidebar, "KimiZ", 1, title_style);

            // Session info
            const label_style: vaxis.Style = .{ .fg = .{ .index = 220 }, .bold = true };
            drawText(&sidebar, "Session:", label_style, sidebar_width - 2);
            const session_style: vaxis.Style = .{ .fg = .{ .index = 248 } };
            drawText(&sidebar, self.state.current_session, session_style, sidebar_width - 2);
            drawText(&sidebar, "Model:", label_style, sidebar_width - 2);
            drawText(&sidebar, self.state.current_model, session_style, sidebar_width - 2);

            // Shortcuts
            const shortcut_style: vaxis.Style = .{ .fg = .{ .index = 177 } };
            drawText(&sidebar, "Shortcuts:", shortcut_style, sidebar_width - 2);
            drawText(&sidebar, " ^C Exit", session_style, sidebar_width - 2);
        }

        // --- Chat Area ---
        const chat_x: u16 = if (cols > sidebar_width + 10) sidebar_width + 1 else 0;
        const chat_width = cols - chat_x;
        const chat_height = rows -| input_height -| 1;
        if (chat_height > 0) {
            var chat_area = main_win.child(.{ .x_off = chat_x, .y_off = 0, .width = chat_width, .height = chat_height });
            chat_area.fill(' ');

            // Render messages
            var current_row: u16 = 0;
            for (self.state.messages.items) |msg| {
                if (current_row >= chat_height - 1) break;

                const prefix_style: vaxis.Style = switch (msg.msg_type) {
                    .user => .{ .fg = .{ .index = 82 }, .bold = true },
                    .assistant => .{ .fg = .{ .index = 75 }, .bold = true },
                    .system => .{ .fg = .{ .index = 220 }, .bold = true },
                    .tool_call => .{ .fg = .{ .index = 177 }, .bold = true },
                    .tool_result => .{ .fg = .{ .index = 80 }, .bold = true },
                };

                const content_style: vaxis.Style = .{ .fg = .{ .index = 248 } };

                const prefix = switch (msg.msg_type) {
                    .user => "You: ",
                    .assistant => "AI: ",
                    .system => "! ",
                    .tool_call => "[Tool] ",
                    .tool_result => "[Result] ",
                };

                if (current_row < chat_area.height) {
                    drawText(&chat_area, prefix, prefix_style, chat_width - 1);
                }
                current_row += 1;

                if (current_row < chat_area.height and msg.content.len > 0) {
                    // Simple word-wrap content
                    drawText(&chat_area, msg.content, content_style, chat_width - 1);
                    const content_width: u16 = if (chat_width > 2) chat_width - 2 else 1;
                    const lines_needed: u16 = @as(u16, @intCast(msg.content.len)) / content_width + 1;
                    current_row += @min(lines_needed, chat_height -| current_row);
                }

                // Separator
                if (current_row < chat_area.height) {
                    const sep_style: vaxis.Style = .{ .fg = .{ .index = 240 } };
                    var sep_col: u16 = 0;
                    while (sep_col < chat_width and current_row < chat_area.height) : (sep_col += 1) {
                        chat_area.cell[sep_col][current_row] = .{
                            .char = .{ .grapheme = "·" },
                            .style = sep_style,
                        };
                    }
                    current_row += 1;
                }
            }
        }

        // --- Separator Line ---
        const sep_y = rows -| input_height -| 1;
        if (sep_y < rows) {
            const sep_style: vaxis.Style = .{ .fg = .{ .index = 240 } };
            var c: u16 = chat_x;
            while (c < cols) : (c += 1) {
                main_win.cell[c][sep_y] = .{
                    .char = .{ .grapheme = "─" },
                    .style = sep_style,
                };
            }
        }

        // --- Input Area ---
        const input_y = rows -| input_height;
        if (input_y < rows) {
            var input_win = main_win.child(.{ .x_off = chat_x, .y_off = input_y, .width = chat_width, .height = input_height });

            // Input background
            const input_bg_style: vaxis.Style = .{
                .bg = .{ .index = 236 },
                .fg = .{ .index = 248 },
            };
            input_win.fillStyle(' ', input_bg_style);

            // Prompt
            const prompt_style: vaxis.Style = .{ .fg = .{ .index = 82 }, .bold = true };
            drawText(&input_win, "> ", prompt_style, chat_width - 2);

            // Input text
            const input_style: vaxis.Style = .{ .fg = .{ .index = 248 } };
            if (self.state.input_buffer.items.len > 0) {
                drawText(&input_win, self.state.input_buffer.items, input_style, chat_width - 3);
            }

            // Cursor position
            const cursor_col: u16 = @as(u16, @intCast(self.state.input_cursor)) + 2; // +2 for "> "
            const cursor_row: u16 = 0;

            if (cursor_col < input_win.width and cursor_row < input_win.height and !self.state.is_streaming) {
                main_win.setCell(
                    chat_x + cursor_col,
                    input_y + cursor_row,
                    .{
                        .char = .{ .grapheme = "▊" },
                        .style = .{ .fg = .{ .index = 82 } },
                    },
                );
            }
        }

        // --- Status Bar ---
        const status_y = rows - 1;
        if (status_y < rows) {
            const status_style: vaxis.Style = .{
                .bg = .{ .index = 237 },
                .fg = .{ .index = 248 },
            };
            var s: u16 = 0;
            while (s < cols) : (s += 1) {
                main_win.cell[s][status_y] = .{
                    .char = .{ .grapheme = " " },
                    .style = status_style,
                };
            }

            const status_text = if (self.state.is_streaming)
                " Streaming..."
            else
                try std.fmt.allocPrint(self.allocator, " Ready | Messages: {d} | Ctrl+C:exit", .{self.state.messages.items.len});
            defer if (!self.state.is_streaming) self.allocator.free(status_text);

            drawText(&main_win, status_text, status_style, cols);
            main_win.setCursorPos(chat_x, input_y);
        }
    }
};

// ============================================================================
// Public API
// ============================================================================

pub fn runTui(allocator: std.mem.Allocator, model: core.Model, options: agent.AgentOptions) !void {
    var app = try TuiApp.init(allocator);
    defer app.deinit();
    try app.setupAgent(model, options);
    try app.run();
}

// ============================================================================
// Tests
// ============================================================================

test "InputHistory add and navigate" {
    const allocator = std.testing.allocator;
    var history = InputHistory.init(allocator);
    defer history.deinit();

    try history.add("hello");
    try history.add("world");
    try history.add("hello"); // duplicate, should be ignored

    try std.testing.expectEqual(@as(usize, 2), history.items.items.len);

    const nav = history.navigateUp(&.{});
    try std.testing.expect(nav != null);
    try std.testing.expectEqualStrings("world", nav.?);
}

test "TuiState basic operations" {
    const allocator = std.testing.allocator;
    var state = TuiState.init(allocator);
    defer state.deinit();

    try state.addUserMessage("Hello");
    try std.testing.expectEqual(@as(usize, 1), state.messages.items.len);
    try std.testing.expectEqual(MessageType.user, state.messages.items[0].msg_type);
}
