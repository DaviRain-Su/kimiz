//! TUI Main - Terminal User Interface Application
//! Integrates with Agent for interactive AI chat

const std = @import("std");
const utils = @import("../utils/root.zig");
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
    input_history: InputHistory,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .messages = std.ArrayList(DisplayMessage).init(allocator),
            .input_buffer = std.ArrayList(u8).init(allocator),
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
            .timestamp = utils.milliTimestamp(),
        });
        // Auto-scroll to bottom on new message
        self.scroll_offset = 0;
    }

    pub fn addStreamingMessage(self: *Self, msg_type: MessageType) !void {
        try self.messages.append(.{
            .msg_type = msg_type,
            .content = "",
            .timestamp = utils.milliTimestamp(),
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
// Input History
// ============================================================================

pub const InputHistory = struct {
    items: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
    max_history: usize = 100,
    current_index: ?usize = null,
    temp_input: ?[]const u8 = null, // Store current input when navigating

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .items = std.ArrayList([]const u8).init(allocator),
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

    /// Add input to history
    pub fn add(self: *Self, input: []const u8) !void {
        // Don't add empty input
        if (input.len == 0) return;
        
        // Don't add duplicate of last entry
        if (self.items.items.len > 0) {
            const last = self.items.items[self.items.items.len - 1];
            if (std.mem.eql(u8, last, input)) return;
        }

        // Remove oldest if at capacity
        if (self.items.items.len >= self.max_history) {
            const oldest = self.items.orderedRemove(0);
            self.allocator.free(oldest);
        }

        const copy = try self.allocator.dupe(u8, input);
        try self.items.append(copy);
        self.reset();
    }

    /// Navigate up in history (older entries)
    pub fn navigateUp(self: *Self, current_input: []const u8) ?[]const u8 {
        if (self.items.items.len == 0) return null;

        // Save current input if starting navigation
        if (self.current_index == null) {
            if (self.temp_input) |temp| {
                self.allocator.free(temp);
            }
            self.temp_input = self.allocator.dupe(u8, current_input) catch null;
        }

        // Move to older entry
        const new_index = if (self.current_index) |idx|
            if (idx > 0) idx - 1 else 0
        else
            self.items.items.len - 1;

        self.current_index = new_index;
        return self.items.items[new_index];
    }

    /// Navigate down in history (newer entries)
    pub fn navigateDown(self: *Self) ?[]const u8 {
        if (self.current_index) |idx| {
            if (idx + 1 < self.items.items.len) {
                self.current_index = idx + 1;
                return self.items.items[self.current_index.?];
            } else {
                // Return to current input (before navigation started)
                self.current_index = null;
                return self.temp_input;
            }
        }
        return null;
    }

    /// Reset navigation state
    pub fn reset(self: *Self) void {
        self.current_index = null;
        if (self.temp_input) |temp| {
            self.allocator.free(temp);
            self.temp_input = null;
        }
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
                // Check if Shift is held (for multi-line input)
                // For now, we use a simple heuristic: if the line starts with whitespace or previous char is newline, insert newline
                const insert_newline = self.state.input_buffer.items.len > 0 and 
                    (self.state.input_cursor == 0 or 
                     self.state.input_buffer.items[self.state.input_cursor - 1] == '\n' or
                     (self.state.input_cursor < self.state.input_buffer.items.len and 
                      self.state.input_buffer.items[self.state.input_cursor] == ' '));
                
                if (insert_newline and !std.mem.eql(u8, self.state.input_buffer.items, "")) {
                    // Insert newline for multi-line input
                    try self.state.input_buffer.insert(self.state.input_cursor, '\n');
                    self.state.input_cursor += 1;
                } else if (self.state.input_buffer.items.len > 0 and !self.state.is_streaming) {
                    // Submit message
                    const input = try self.allocator.dupe(u8, self.state.input_buffer.items);
                    
                    // Add to history before clearing
                    try self.state.input_history.add(input);
                    
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
                // History navigation
                if (self.state.input_history.navigateUp(self.state.input_buffer.items)) |history_input| {
                    self.state.input_buffer.clearRetainingCapacity();
                    try self.state.input_buffer.appendSlice(history_input);
                    self.state.input_cursor = self.state.input_buffer.items.len;
                } else if (self.state.scroll_offset > 0) {
                    self.state.scroll_offset -= 1;
                }
            },
            .down => {
                // History navigation
                if (self.state.input_history.navigateDown()) |history_input| {
                    self.state.input_buffer.clearRetainingCapacity();
                    try self.state.input_buffer.appendSlice(history_input);
                    self.state.input_cursor = self.state.input_buffer.items.len;
                } else {
                    self.state.scroll_offset += 1;
                }
            },
            .char => |c| {
                try self.state.input_buffer.insert(self.state.input_cursor, c);
                self.state.input_cursor += 1;
                // Reset history navigation when typing
                self.state.input_history.reset();
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
        const visible_rows = area.height - 2;
        
        // First pass: calculate how many rows each message needs
        var message_rows = std.ArrayList(usize).init(self.allocator);
        defer message_rows.deinit();
        
        var total_rows: usize = 0;
        for (self.state.messages.items) |msg| {
            const prefix_len = switch (msg.msg_type) {
                .user => 5, // "You: "
                .assistant => 4, // "AI: "
                .system => 2, // "! "
                .tool_call => 0, // "[Tool: xxx]" - handled separately
                .tool_result => 0, // "[Result: xxx]" - handled separately
            };
            const content_width = area.width - prefix_len - 2; // -2 for margins
            const rows_needed = calculateWrappedRows(msg.content, content_width);
            try message_rows.append(rows_needed);
            total_rows += rows_needed;
        }
        
        // Calculate start index based on scroll and total rows
        var start_idx: usize = 0;
        if (total_rows > visible_rows and self.state.scroll_offset > 0) {
            var rows_to_skip = self.state.scroll_offset;
            for (message_rows.items, 0..) |rows_needed, i| {
                if (rows_to_skip >= rows_needed) {
                    rows_to_skip -= rows_needed;
                    start_idx = i + 1;
                } else {
                    break;
                }
            }
        }

        var row: usize = area.y + 1;
        var msg_idx = start_idx;
        while (msg_idx < self.state.messages.items.len and row < area.y + area.height - 1) {
            const msg = self.state.messages.items[msg_idx];
            
            // Message type indicator and style
            const prefix = switch (msg.msg_type) {
                .user => "You: ",
                .assistant => "AI: ",
                .system => "! ",
                .tool_call => "[Tool: ",
                .tool_result => "[Result: ",
            };
            const prefix_len = prefix.len;
            
            try terminal.Terminal.moveCursor(row, area.x + 1);
            
            // Format timestamp
            const timestamp_str = try formatTimestamp(self.allocator, msg.timestamp);
            defer self.allocator.free(timestamp_str);
            
            switch (msg.msg_type) {
                .user => {
                    try terminal.applyStyle(.{ .fg = .bright_black });
                    try stdout.print("[{s}] ", .{timestamp_str});
                    try terminal.resetStyle();
                    try terminal.applyStyle(.{ .fg = .green, .bold = true });
                    try stdout.print("{s}", .{prefix});
                    try terminal.resetStyle();
                    
                    // Wrap and print content
                    const content_width = area.width - prefix_len - 11; // -11 for timestamp
                    row = try self.printWrappedText(msg.content, content_width, row, area.x + 11 + prefix_len, area);
                },
                .assistant => {
                    try terminal.applyStyle(.{ .fg = .bright_black });
                    try stdout.print("[{s}] ", .{timestamp_str});
                    try terminal.resetStyle();
                    try terminal.applyStyle(.{ .fg = .blue, .bold = true });
                    try stdout.print("{s}", .{prefix});
                    try terminal.resetStyle();
                    
                    // Wrap and print content
                    const content_width = area.width - prefix_len - 11; // -11 for timestamp
                    const display_content = if (msg.is_streaming)
                        try std.fmt.allocPrint(self.allocator, "{s}▊", .{msg.content})
                    else
                        msg.content;
                    defer if (msg.is_streaming) self.allocator.free(display_content);
                    
                    row = try self.printWrappedText(display_content, content_width, row, area.x + 11 + prefix_len, area);
                },
                .system => {
                    try terminal.applyStyle(.{ .fg = .bright_black });
                    try stdout.print("[{s}] ", .{timestamp_str});
                    try terminal.resetStyle();
                    try terminal.applyStyle(.{ .fg = .yellow });
                    try stdout.print("{s}", .{prefix});
                    try terminal.resetStyle();
                    
                    const content_width = area.width - prefix_len - 11;
                    row = try self.printWrappedText(msg.content, content_width, row, area.x + 11 + prefix_len, area);
                },
                .tool_call => {
                    try terminal.applyStyle(.{ .fg = .magenta });
                    try stdout.print("{s}{s}]", .{ prefix, msg.content });
                    try terminal.resetStyle();
                    row += 1;
                },
                .tool_result => {
                    try terminal.applyStyle(.{ .fg = .cyan });
                    try stdout.print("{s}{s}]", .{ prefix, msg.content });
                    try terminal.resetStyle();
                    row += 1;
                },
            }
            
            msg_idx += 1;
        }
    }
    
    /// Calculate how many rows needed to display text with given width
    fn calculateWrappedRows(text: []const u8, width: usize) usize {
        if (width == 0) return text.len;
        var rows: usize = 1;
        var col: usize = 0;
        for (text) |byte| {
            if (byte == '\n') {
                rows += 1;
                col = 0;
            } else {
                col += 1;
                if (col >= width) {
                    rows += 1;
                    col = 0;
                }
            }
        }
        return rows;
    }
    
    /// Format timestamp to HH:MM:SS
    fn formatTimestamp(allocator: std.mem.Allocator, timestamp_ms: i64) ![]const u8 {
        const seconds = @divTrunc(timestamp_ms, 1000);
        const hours = @mod(@divTrunc(seconds, 3600), 24);
        const minutes = @mod(@divTrunc(seconds, 60), 60);
        const secs = @mod(seconds, 60);
        return try std.fmt.allocPrint(allocator, "{d:0>2}:{d:0>2}:{d:0>2}", .{hours, minutes, secs});
    }
    
    /// Print text with word wrapping, returns next row
    fn printWrappedText(self: *Self, text: []const u8, width: usize, start_row: usize, start_col: usize, area: terminal.Rect) !usize {
        const stdout = std.io.getStdOut().writer();
        var row = start_row;
        var line_start: usize = 0;
        
        while (line_start < text.len and row < area.y + area.height - 1) {
            // Find the end of this line
            var line_end = line_start;
            var col: usize = 0;
            
            // Try to find a good break point (word boundary)
            while (line_end < text.len and col < width) {
                if (text[line_end] == '\n') {
                    break;
                }
                col += 1;
                line_end += 1;
            }
            
            // If we're in the middle of a word, try to back up to a space
            if (line_end < text.len and text[line_end] != '\n' and text[line_end] != ' ') {
                var word_boundary = line_end;
                while (word_boundary > line_start and text[word_boundary - 1] != ' ') {
                    word_boundary -= 1;
                }
                if (word_boundary > line_start) {
                    line_end = word_boundary;
                }
            }
            
            // Print this line
            try terminal.Terminal.moveCursor(row, start_col);
            try stdout.print("{s}", .{text[line_start..line_end]});
            
            row += 1;
            
            // Skip newline if present, or skip space at break
            if (line_end < text.len and text[line_end] == '\n') {
                line_start = line_end + 1;
            } else if (line_end < text.len and text[line_end] == ' ') {
                line_start = line_end + 1;
            } else {
                line_start = line_end;
            }
        }
        
        return row;
    }

    fn renderInputArea(self: *Self, rows: usize, cols: usize) !void {
        const area = self.layout.getInputArea(cols, rows);
        const stdout = std.io.getStdOut().writer();
        const max_input_lines = 5; // Maximum visible lines for input
        
        // Draw border line
        try terminal.Terminal.moveCursor(area.y, area.x);
        try stdout.print("─" ** 100, .{});
        
        // Calculate cursor position in multi-line buffer
        var cursor_line: usize = 0;
        var cursor_col: usize = 0;
        var line_start_indices = std.ArrayList(usize).init(self.allocator);
        defer line_start_indices.deinit();
        try line_start_indices.append(0);
        
        for (self.state.input_buffer.items, 0..) |char, i| {
            if (i == self.state.input_cursor) {
                cursor_line = line_start_indices.items.len - 1;
                cursor_col = i - line_start_indices.items[cursor_line];
            }
            if (char == '\n') {
                try line_start_indices.append(i + 1);
            }
        }
        
        // Handle cursor at end of buffer
        if (self.state.input_cursor >= self.state.input_buffer.items.len) {
            cursor_line = line_start_indices.items.len - 1;
            cursor_col = self.state.input_buffer.items.len - line_start_indices.items[cursor_line];
        }
        
        // Calculate which lines to show (scrolling within input area)
        var first_visible_line: usize = 0;
        if (line_start_indices.items.len > max_input_lines) {
            first_visible_line = if (cursor_line >= max_input_lines)
                cursor_line - max_input_lines + 1
            else
                0;
        }
        
        // Input prompt
        try terminal.Terminal.moveCursor(area.y + 1, area.x + 1);
        try terminal.applyStyle(.{ .fg = .green, .bold = true });
        try stdout.print("> ", .{});
        try terminal.resetStyle();
        
        // Display input content (multiple lines)
        const content_width = area.width - 4; // -4 for "> " and margins
        var display_line: usize = 0;
        
        for (first_visible_line..line_start_indices.items.len) |line_idx| {
            if (display_line >= max_input_lines) break;
            
            const start_idx = line_start_indices.items[line_idx];
            const end_idx = if (line_idx + 1 < line_start_indices.items.len)
                line_start_indices.items[line_idx + 1] - 1
            else
                self.state.input_buffer.items.len;
            
            const line_content = self.state.input_buffer.items[start_idx..end_idx];
            
            // Wrap long lines
            var col: usize = 0;
            var line_row: usize = 0;
            while (col < line_content.len and line_row < max_input_lines - display_line) {
                const remaining = line_content.len - col;
                const chunk_len = @min(remaining, content_width);
                
                try terminal.Terminal.moveCursor(area.y + 1 + display_line + line_row, area.x + 3 + if (line_row == 0) @as(usize, 0) else @as(usize, 0));
                if (line_row > 0) {
                    // Continuation line - indent slightly
                    try terminal.Terminal.moveCursor(area.y + 1 + display_line + line_row, area.x + 5);
                }
                try stdout.print("{s}", .{line_content[col..col + chunk_len]});
                
                col += chunk_len;
                line_row += 1;
            }
            
            display_line += line_row;
        }
        
        // Show hint for multi-line input
        if (std.mem.indexOfScalar(u8, self.state.input_buffer.items, '\n') != null) {
            try terminal.Terminal.moveCursor(area.y + area.height - 1, area.x + 1);
            try terminal.applyStyle(.{ .fg = .bright_black });
            try stdout.print("[Ctrl+Enter to submit]", .{});
            try terminal.resetStyle();
        }
        
        // Cursor positioning
        if (!self.state.is_streaming) {
            const cursor_display_line = cursor_line - first_visible_line;
            const cursor_display_col = if (cursor_display_line == 0) 
                cursor_col + 3  // +3 for "> "
            else 
                cursor_col + 5; // +5 for continuation indent
            try terminal.Terminal.moveCursor(area.y + 1 + cursor_display_line, area.x + cursor_display_col);
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
