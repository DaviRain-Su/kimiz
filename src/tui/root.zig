//! TUI Main - Terminal User Interface Application
//! Integrates with Agent for interactive AI chat

const std = @import("std");
const terminal = @import("terminal.zig");
const core = @import("../core/root.zig");
const ai = @import("../ai/root.zig");
const agent = @import("../agent/root.zig");

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
    messages: std.ArrayList(DisplayMessage),
    input_buffer: std.ArrayList(u8),
    input_cursor: usize = 0,
    scroll_offset: usize = 0,
    is_running: bool = true,
    is_streaming: bool = false,
    current_model: []const u8 = "gpt-4o",
    current_session: []const u8 = "default",

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .messages = std.ArrayList(DisplayMessage).init(allocator),
            .input_buffer = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.messages.deinit();
        self.input_buffer.deinit();
    }

    pub fn addMessage(self: *Self, msg_type: MessageType, content: []const u8) !void {
        try self.messages.append(.{
            .msg_type = msg_type,
            .content = content,
            .timestamp = std.time.milliTimestamp(),
        });
    }

    pub fn addStreamingMessage(self: *Self, msg_type: MessageType) !void {
        try self.messages.append(.{
            .msg_type = msg_type,
            .content = "",
            .timestamp = std.time.milliTimestamp(),
            .is_streaming = true,
        });
        self.is_streaming = true;
    }

    pub fn appendToLastMessage(self: *Self, chunk: []const u8) !void {
        if (self.messages.items.len == 0) return;
        const last = &self.messages.items[self.messages.items.len - 1];
        try self.appendToBuffer(&last.content, chunk);
    }

    fn appendToBuffer(self: *Self, buffer: *[]const u8, chunk: []const u8) !void {
        // This is a workaround since we can't easily append to a []const u8
        // In a real implementation, we'd use a different data structure
        _ = self;
        _ = buffer;
        _ = chunk;
    }

    pub fn finishStreaming(self: *Self) void {
        if (self.messages.items.len == 0) return;
        const last = &self.messages.items[self.messages.items.len - 1];
        last.is_streaming = false;
        self.is_streaming = false;
    }

    pub fn addUserMessage(self: *Self, content: []const u8) !void {
        try self.addMessage(.user, content);
    }

    pub fn addSystemMessage(self: *Self, content: []const u8) !void {
        try self.addMessage(.system, content);
    }
};

// ============================================================================
// TUI Application
// ============================================================================

pub const TuiApp = struct {
    allocator: std.mem.Allocator,
    term: terminal.Terminal,
    state: TuiState,
    layout: terminal.Layout,
    ai_agent: ?agent.Agent,
    ai_client: ?ai.Ai,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        return .{
            .allocator = allocator,
            .term = try terminal.Terminal.init(),
            .state = TuiState.init(allocator),
            .layout = .{},
            .ai_agent = null,
            .ai_client = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.state.deinit();
        self.term.deinit();
        if (self.ai_agent) |*a| a.deinit();
        if (self.ai_client) |*c| c.deinit();
    }

    /// Initialize with Agent
    pub fn setupAgent(self: *Self, _: core.Model, options: agent.AgentOptions) !void {
        self.ai_agent = try agent.Agent.init(self.allocator, options);

        // Set up event callback
        self.ai_agent.?.setEventCallback(struct {
            var app_ptr: *Self = undefined;

            pub fn setAppPtr(ptr: *Self) void {
                app_ptr = ptr;
            }

            pub fn callback(evt: agent.AgentEvent) void {
                handleAgentEvent(app_ptr, evt) catch {};
            }
        }.callback);

        // Store the app pointer for the callback
        const CallbackSetter = struct {
            var app_ptr: *Self = undefined;
            pub fn set(ptr: *Self) void {
                app_ptr = ptr;
            }
        };
        CallbackSetter.set(self);
    }

    fn handleAgentEvent(self: *Self, evt: agent.AgentEvent) !void {
        switch (evt) {
            .message_start => {
                try self.state.addStreamingMessage(.assistant);
            },
            .message_delta => |delta| {
                try self.state.appendToLastMessage(delta);
                try self.render();
            },
            .message_complete => |msg| {
                self.state.finishStreaming();
                // Convert AssistantMessage to string
                var content = std.ArrayList(u8).init(self.allocator);
                defer content.deinit();
                for (msg.content) |block| {
                    switch (block) {
                        .text => |t| try content.appendSlice(t.text),
                        .thinking => {},
                        .tool_call => |tc| {
                            try std.fmt.format(content.writer(), "\n[Tool call: {s}]\n", .{tc.tool_call.name});
                        },
                    }
                }
                try self.state.addMessage(.assistant, try content.toOwnedSlice());
            },
            .tool_call_start => |info| {
                try self.state.addMessage(.tool_call, info.name);
            },
            .tool_result => |result| {
                const status = if (result.result.is_error) "Error" else "Success";
                try self.state.addSystemMessage(try std.fmt.allocPrint(self.allocator, "Tool {s}: {s}", .{
                    result.tool_name,
                    status,
                }));
            },
            .err => |err| {
                try self.state.addSystemMessage(try std.fmt.allocPrint(self.allocator, "Error: {s}", .{err}));
            },
            .done => {
                self.state.is_streaming = false;
            },
            else => {},
        }
        try self.render();
    }

    /// Main run loop
    pub fn run(self: *Self) !void {
        try self.term.enableRawMode();
        try terminal.Terminal.hideCursor();
        try terminal.Terminal.clearScreen();

        // Add welcome message
        try self.state.addSystemMessage("Welcome to kimiz TUI! Press Ctrl+C to exit.");

        try self.render();

        while (self.state.is_running) {
            const key = try terminal.readKey();
            try self.handleInput(key);

            if (self.state.is_running) {
                try self.render();
            }
        }

        try terminal.Terminal.showCursor();
        try terminal.Terminal.clearScreen();
    }

    fn handleInput(self: *Self, key: terminal.Key) !void {
        switch (key) {
            .ctrl_c => {
                self.state.is_running = false;
            },
            .ctrl_l => {
                try terminal.Terminal.clearScreen();
            },
            .enter => {
                if (self.state.input_buffer.items.len > 0 and !self.state.is_streaming) {
                    const input = try self.allocator.dupe(u8, self.state.input_buffer.items);
                    try self.state.addUserMessage(input);

                    // Clear input
                    self.state.input_buffer.clearAndFree();
                    self.state.input_cursor = 0;

                    // Send to agent
                    if (self.ai_agent) |*a| {
                        a.prompt(input) catch |err| {
                            try self.state.addSystemMessage(try std.fmt.allocPrint(
                                self.allocator,
                                "Agent error: {s}",
                                .{@errorName(err)},
                            ));
                        };
                    } else {
                        try self.state.addSystemMessage("No agent connected.");
                    }
                }
            },
            .backspace => {
                if (self.state.input_cursor > 0) {
                    _ = self.state.input_buffer.orderedRemove(self.state.input_cursor - 1);
                    self.state.input_cursor -= 1;
                }
            },
            .delete => {
                if (self.state.input_cursor < self.state.input_buffer.items.len) {
                    _ = self.state.input_buffer.orderedRemove(self.state.input_cursor);
                }
            },
            .left => {
                if (self.state.input_cursor > 0) {
                    self.state.input_cursor -= 1;
                }
            },
            .right => {
                if (self.state.input_cursor < self.state.input_buffer.items.len) {
                    self.state.input_cursor += 1;
                }
            },
            .up => {
                // TODO: History navigation
                if (self.state.scroll_offset > 0) {
                    self.state.scroll_offset -= 1;
                }
            },
            .down => {
                // TODO: History navigation
                self.state.scroll_offset += 1;
            },
            .char => |c| {
                try self.state.input_buffer.insert(self.state.input_cursor, c);
                self.state.input_cursor += 1;
            },
            else => {},
        }
    }

    fn render(self: *Self) !void {
        const size = try terminal.Terminal.getSize();

        // Clear screen
        try terminal.Terminal.clearScreen();

        // Render sidebar
        try self.renderSidebar(size.rows, size.cols);

        // Render chat area
        try self.renderChatArea(size.rows, size.cols);

        // Render input area
        try self.renderInputArea(size.rows, size.cols);

        // Render status bar
        try self.renderStatusBar(size.rows, size.cols);
    }

    fn renderSidebar(self: *Self, rows: usize, cols: usize) !void {
        _ = cols;
        const area = self.layout.getSidebarArea(0, rows);
        const stdout = std.io.getStdOut().writer();

        // Draw sidebar border
        for (area.y..area.y + area.height) |row| {
            try terminal.Terminal.moveCursor(row + 1, area.width);
            try stdout.print("│", .{});
        }

        // Title
        try terminal.Terminal.moveCursor(1, 1);
        try terminal.applyStyle(.{ .fg = .cyan, .bold = true });
        try stdout.print(" kimiz ", .{});
        try terminal.resetStyle();

        // Session info
        try terminal.Terminal.moveCursor(3, 1);
        try terminal.applyStyle(.{ .fg = .yellow });
        try stdout.print("Session:", .{});
        try terminal.resetStyle();
        try terminal.Terminal.moveCursor(4, 1);
        try stdout.print(" {s}", .{self.state.current_session});

        // Model info
        try terminal.Terminal.moveCursor(6, 1);
        try terminal.applyStyle(.{ .fg = .yellow });
        try stdout.print("Model:", .{});
        try terminal.resetStyle();
        try terminal.Terminal.moveCursor(7, 1);
        try stdout.print(" {s}", .{self.state.current_model});

        // Shortcuts
        try terminal.Terminal.moveCursor(area.height - 5, 1);
        try terminal.applyStyle(.{ .fg = .magenta });
        try stdout.print("Shortcuts:", .{});
        try terminal.resetStyle();
        try terminal.Terminal.moveCursor(area.height - 4, 1);
        try stdout.print(" ^C Exit", .{});
        try terminal.Terminal.moveCursor(area.height - 3, 1);
        try stdout.print(" ^L Clear", .{});
    }

    fn renderChatArea(self: *Self, rows: usize, cols: usize) !void {
        const area = self.layout.getChatArea(cols, rows);
        const stdout = std.io.getStdOut().writer();

        // Calculate visible messages
        const visible_count = area.height - 2;
        const start_idx = if (self.state.messages.items.len > visible_count)
            self.state.messages.items.len - visible_count + self.state.scroll_offset
        else
            0;

        var row: usize = area.y + 1;
        for (self.state.messages.items[start_idx..]) |msg| {
            if (row >= area.y + area.height - 1) break;

            try terminal.Terminal.moveCursor(row, area.x + 1);

            // Message type indicator and style
            switch (msg.msg_type) {
                .user => {
                    try terminal.applyStyle(.{ .fg = .green, .bold = true });
                    try stdout.print("You: ", .{});
                    try terminal.resetStyle();
                    try stdout.print("{s}", .{msg.content});
                },
                .assistant => {
                    try terminal.applyStyle(.{ .fg = .blue, .bold = true });
                    try stdout.print("AI: ", .{});
                    try terminal.resetStyle();
                    if (msg.is_streaming) {
                        try stdout.print("{s}▊", .{msg.content});
                    } else {
                        try stdout.print("{s}", .{msg.content});
                    }
                },
                .system => {
                    try terminal.applyStyle(.{ .fg = .yellow });
                    try stdout.print("! {s}", .{msg.content});
                    try terminal.resetStyle();
                },
                .tool_call => {
                    try terminal.applyStyle(.{ .fg = .magenta });
                    try stdout.print("[Tool: {s}]", .{msg.content});
                    try terminal.resetStyle();
                },
                .tool_result => {
                    try terminal.applyStyle(.{ .fg = .cyan });
                    try stdout.print("[Result: {s}]", .{msg.content});
                    try terminal.resetStyle();
                },
            }

            row += 1;
        }
    }

    fn renderInputArea(self: *Self, rows: usize, cols: usize) !void {
        const area = self.layout.getInputArea(cols, rows);
        const stdout = std.io.getStdOut().writer();

        // Draw border line
        try terminal.Terminal.moveCursor(area.y, area.x);
        try stdout.print("─" ** 100, .{});

        // Input prompt
        try terminal.Terminal.moveCursor(area.y + 1, area.x + 1);
        try terminal.applyStyle(.{ .fg = .green, .bold = true });
        try stdout.print("> ", .{});
        try terminal.resetStyle();

        // Input content
        try stdout.print("{s}", .{self.state.input_buffer.items});

        // Cursor
        if (!self.state.is_streaming) {
            try terminal.Terminal.moveCursor(area.y + 1, area.x + 3 + self.state.input_cursor);
            try terminal.Terminal.showCursor();
        } else {
            try terminal.Terminal.hideCursor();
        }
    }

    fn renderStatusBar(self: *Self, rows: usize, cols: usize) !void {
        const area = self.layout.getStatusArea(cols, rows);
        const stdout = std.io.getStdOut().writer();

        try terminal.Terminal.moveCursor(area.y + 1, area.x + 1);

        // Background style for status bar
        try terminal.applyStyle(.{ .bg = .bright_black });

        if (self.state.is_streaming) {
            try stdout.print(" Streaming... ", .{});
        } else {
            try stdout.print(" Ready | Messages: {d} | Press Ctrl+C to exit ", .{self.state.messages.items.len});
        }

        // Fill rest of status bar
        const status_len = if (self.state.is_streaming) 15 else 50;
        for (status_len..area.width) |_| {
            try stdout.print(" ", .{});
        }

        try terminal.resetStyle();
    }
};

// ============================================================================
// Public API
// ============================================================================

/// Run TUI with default configuration
pub fn runTui(allocator: std.mem.Allocator, model: core.Model, options: agent.AgentOptions) !void {
    var app = try TuiApp.init(allocator);
    defer app.deinit();

    try app.setupAgent(model, options);
    try app.run();
}

// ============================================================================
// Tests
// ============================================================================

test "TuiState basic operations" {
    const allocator = std.testing.allocator;
    var state = TuiState.init(allocator);
    defer state.deinit();

    try state.addUserMessage("Hello");
    try std.testing.expectEqual(@as(usize, 1), state.messages.items.len);
    try std.testing.expectEqual(MessageType.user, state.messages.items[0].msg_type);
}
