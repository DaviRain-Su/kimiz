//! TUI - Terminal User Interface
//! Provides a rich terminal interface for kimiz

const std = @import("std");
const core = @import("../core/root.zig");
const ai = @import("../ai/root.zig");
const agent = @import("../agent/root.zig");

// ============================================================================
// Terminal Control
// ============================================================================

pub const Terminal = struct {
    original_termios: std.posix.termios,
    is_raw_mode: bool = false,

    const Self = @This();

    pub fn init() !Self {
        const stdout = std.io.getStdOut();
        const termios = try std.posix.tcgetattr(stdout.handle);

        return .{
            .original_termios = termios,
            .is_raw_mode = false,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.is_raw_mode) {
            self.disableRawMode() catch {};
        }
    }

    /// Enable raw mode for terminal
    pub fn enableRawMode(self: *Self) !void {
        if (self.is_raw_mode) return;

        const stdout = std.io.getStdOut();
        var raw = self.original_termios;

        // Disable canonical mode and echo
        raw.lflag.ICANON = false;
        raw.lflag.ECHO = false;
        raw.lflag.ISIG = false;

        // Disable input processing
        raw.iflag.IXON = false;
        raw.iflag.ICRNL = false;
        raw.iflag.INLCR = false;
        raw.iflag.IGNCR = false;
        raw.iflag.ISTRIP = false;

        // Set minimum characters and timeout
        raw.cc[@intFromEnum(std.posix.V.MIN)] = 0;
        raw.cc[@intFromEnum(std.posix.V.TIME)] = 1;

        try std.posix.tcsetattr(stdout.handle, .FLUSH, raw);
        self.is_raw_mode = true;
    }

    /// Disable raw mode and restore original settings
    pub fn disableRawMode(self: *Self) !void {
        if (!self.is_raw_mode) return;

        const stdout = std.io.getStdOut();
        try std.posix.tcsetattr(stdout.handle, .FLUSH, self.original_termios);
        self.is_raw_mode = false;
    }

    /// Clear screen
    pub fn clearScreen() !void {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("\x1B[2J\x1B[H", .{});
    }

    /// Hide cursor
    pub fn hideCursor() !void {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("\x1B[?25l", .{});
    }

    /// Show cursor
    pub fn showCursor() !void {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("\x1B[?25h", .{});
    }

    /// Move cursor to position (1-indexed)
    pub fn moveCursor(row: usize, col: usize) !void {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("\x1B[{d};{d}H", .{ row, col });
    }

    /// Get terminal size
    pub fn getSize() !struct { rows: usize, cols: usize } {
        const stdout = std.io.getStdOut();
        var ws: std.posix.winsize = undefined;

        const rc = std.posix.system.ioctl(stdout.handle, std.posix.T.IOCGWINSZ, @intFromPtr(&ws));
        if (rc != 0) return error.IoctlFailed;

        return .{
            .rows = ws.ws_row,
            .cols = ws.ws_col,
        };
    }
};

// ============================================================================
// Key Events
// ============================================================================

pub const Key = union(enum) {
    // Special keys
    enter,
    escape,
    backspace,
    delete,
    tab,
    space,

    // Arrow keys
    up,
    down,
    left,
    right,

    // Function keys
    f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12,

    // Control combinations
    ctrl_c,
    ctrl_d,
    ctrl_l,

    // Regular character
    char: u8,

    // Unknown
    unknown,
};

pub const KeyEvent = struct {
    key: Key,
};

/// Read a key from stdin (non-blocking in raw mode)
pub fn readKey() !Key {
    const stdin = std.io.getStdIn();
    var buf: [4]u8 = undefined;

    const n = try stdin.read(&buf);
    if (n == 0) return .unknown;

    // Check for escape sequences
    if (buf[0] == '\x1B') {
        if (n >= 3 and buf[1] == '[') {
            return switch (buf[2]) {
                'A' => .up,
                'B' => .down,
                'C' => .right,
                'D' => .left,
                '3' => if (n >= 4 and buf[3] == '~') .delete else .unknown,
                else => .unknown,
            };
        }
        return .escape;
    }

    // Check for control characters
    return switch (buf[0]) {
        '\r', '\n' => .enter,
        '\t' => .tab,
        ' ' => .space,
        127 => .backspace,
        0...8, 11...31 => switch (buf[0]) {
            3 => .ctrl_c,
            4 => .ctrl_d,
            12 => .ctrl_l,
            else => .{ .char = '?' }, // Unknown control
        },
        else => .{ .char = buf[0] },
    };
}

// ============================================================================
// Colors
// ============================================================================

pub const Color = enum {
    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,
    default,

    // Bright variants
    bright_black,
    bright_red,
    bright_green,
    bright_yellow,
    bright_blue,
    bright_magenta,
    bright_cyan,
    bright_white,
};

pub const Style = struct {
    fg: Color = .default,
    bg: Color = .default,
    bold: bool = false,
    italic: bool = false,
    underline: bool = false,
};

/// Apply style to text
pub fn applyStyle(style: Style) !void {
    const stdout = std.io.getStdOut().writer();

    var codes: [8]u8 = undefined;
    var idx: usize = 0;

    // Reset first
    codes[idx] = 0;
    idx += 1;

    if (style.bold) {
        codes[idx] = 1;
        idx += 1;
    }
    if (style.italic) {
        codes[idx] = 3;
        idx += 1;
    }
    if (style.underline) {
        codes[idx] = 4;
        idx += 1;
    }

    // Foreground color
    const fg_code: u8 = switch (style.fg) {
        .black => 30,
        .red => 31,
        .green => 32,
        .yellow => 33,
        .blue => 34,
        .magenta => 35,
        .cyan => 36,
        .white => 37,
        .default => 39,
        .bright_black => 90,
        .bright_red => 91,
        .bright_green => 92,
        .bright_yellow => 93,
        .bright_blue => 94,
        .bright_magenta => 95,
        .bright_cyan => 96,
        .bright_white => 97,
    };
    codes[idx] = fg_code;
    idx += 1;

    try stdout.print("\x1B[", .{});
    for (codes[0..idx], 0..) |code, i| {
        if (i > 0) try stdout.print(";", .{});
        try stdout.print("{d}", .{code});
    }
    try stdout.print("m", .{});
}

/// Reset style
pub fn resetStyle() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("\x1B[0m", .{});
}

// ============================================================================
// Layout
// ============================================================================

pub const Rect = struct {
    x: usize,
    y: usize,
    width: usize,
    height: usize,

    pub fn contains(self: Rect, row: usize, col: usize) bool {
        return row >= self.y and row < self.y + self.height and
            col >= self.x and col < self.x + self.width;
    }
};

pub const Layout = struct {
    sidebar_width: usize = 25,
    status_height: usize = 1,
    input_height: usize = 3,

    pub fn getChatArea(self: Layout, term_width: usize, term_height: usize) Rect {
        return .{
            .x = self.sidebar_width,
            .y = 0,
            .width = term_width - self.sidebar_width,
            .height = term_height - self.status_height - self.input_height,
        };
    }

    pub fn getSidebarArea(self: Layout, term_width: usize, term_height: usize) Rect {
        _ = term_width;
        return .{
            .x = 0,
            .y = 0,
            .width = self.sidebar_width,
            .height = term_height,
        };
    }

    pub fn getInputArea(self: Layout, term_width: usize, term_height: usize) Rect {
        return .{
            .x = self.sidebar_width,
            .y = term_height - self.status_height - self.input_height,
            .width = term_width - self.sidebar_width,
            .height = self.input_height,
        };
    }

    pub fn getStatusArea(self: Layout, term_width: usize, term_height: usize) Rect {
        return .{
            .x = self.sidebar_width,
            .y = term_height - self.status_height,
            .width = term_width - self.sidebar_width,
            .height = self.status_height,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Terminal size detection" {
    const size = try Terminal.getSize();
    try std.testing.expect(size.rows > 0);
    try std.testing.expect(size.cols > 0);
}

test "Layout calculations" {
    const layout = Layout{};
    const term_width: usize = 100;
    const term_height: usize = 30;

    const chat = layout.getChatArea(term_width, term_height);
    try std.testing.expectEqual(@as(usize, 25), chat.x);
    try std.testing.expectEqual(@as(usize, 75), chat.width);

    const sidebar = layout.getSidebarArea(term_width, term_height);
    try std.testing.expectEqual(@as(usize, 25), sidebar.width);

    const input = layout.getInputArea(term_width, term_height);
    try std.testing.expectEqual(@as(usize, 27), input.y); // 30 - 1 - 3 = 26, but +1 for 1-indexed
}
