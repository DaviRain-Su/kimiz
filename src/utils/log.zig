//! Logging System - Structured logging with multiple outputs
//! Provides file and console logging with rotation

const std = @import("std");

// ============================================================================
// Log Level
// ============================================================================

pub const LogLevel = enum(u8) {
    debug = 0,
    info = 1,
    warn = 2,
    err = 3,
    fatal = 4,

    pub fn asString(self: LogLevel) []const u8 {
        return switch (self) {
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
            .fatal => "FATAL",
        };
    }

    pub fn asColor(self: LogLevel) []const u8 {
        return switch (self) {
            .debug => "\x1b[90m", // Gray
            .info => "\x1b[32m", // Green
            .warn => "\x1b[33m", // Yellow
            .err => "\x1b[31m", // Red
            .fatal => "\x1b[35m", // Magenta
        };
    }
};

// ============================================================================
// Logger
// ============================================================================

pub const Logger = struct {
    allocator: std.mem.Allocator,
    min_level: LogLevel,
    log_dir: []const u8,
    current_file: ?std.fs.File,
    current_date: ?[]const u8,
    use_color: bool,
    mutex: std.Thread.Mutex,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, log_dir: []const u8, min_level: LogLevel) !Self {
        // Create log directory
        std.fs.cwd().makeDir(log_dir) catch |e| switch (e) {
            error.PathAlreadyExists => {},
            else => return e,
        };

        return .{
            .allocator = allocator,
            .min_level = min_level,
            .log_dir = try allocator.dupe(u8, log_dir),
            .current_file = null,
            .current_date = null,
            .use_color = std.io.getStdOut().isTty(),
            .mutex = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.current_file) |*file| {
            file.close();
        }
        if (self.current_date) |date| {
            self.allocator.free(date);
        }
        self.allocator.free(self.log_dir);
    }

    /// Log a message
    pub fn log(self: *Self, level: LogLevel, comptime fmt: []const u8, args: anytype) void {
        if (@intFromEnum(level) < @intFromEnum(self.min_level)) return;

        self.mutex.lock();
        defer self.mutex.unlock();

        const timestamp = std.time.timestamp();
        const local_time = timestamp;

        // Format message
        var buf: [4096]u8 = undefined;
        const message = std.fmt.bufPrint(&buf, fmt, args) catch "[format error]";

        // Get current date for file rotation
        const current_date = self.getCurrentDate();
        defer self.allocator.free(current_date);

        // Rotate file if date changed
        if (self.current_date == null or !std.mem.eql(u8, self.current_date.?, current_date)) {
            self.rotateFile(current_date) catch return;
        }

        // Write to console with color
        if (self.use_color) {
            const color = level.asColor();
            const reset = "\x1b[0m";
            std.debug.print("{s}[{s}] {s}{s}\n", .{ color, level.asString(), message, reset });
        } else {
            std.debug.print("[{s}] {s}\n", .{ level.asString(), message });
        }

        // Write to file
        if (self.current_file) |file| {
            const time_str = formatTimestamp(local_time, &buf);
            file.writer().print("[{s}] {s}: {s}\n", .{ time_str, level.asString(), message }) catch {};
        }
    }

    fn getCurrentDate(self: *Self) []const u8 {
        const timestamp = std.time.timestamp();
        var buf: [16]u8 = undefined;
        // Simple date format: YYYY-MM-DD
        const seconds_per_day = 24 * 60 * 60;
        const days_since_epoch = @divFloor(timestamp, seconds_per_day);
        // Rough conversion (not accounting for leap seconds/timezones)
        const year = 1970 + @divFloor(days_since_epoch, 365);
        const day_of_year = @mod(days_since_epoch, 365);
        // Simple approximation
        const date_str = std.fmt.bufPrint(&buf, "{d}-{d:0>2}", .{ year, @divFloor(day_of_year, 30) + 1 }) catch "unknown";
        return self.allocator.dupe(u8, date_str) catch "unknown";
    }

    fn rotateFile(self: *Self, date: []const u8) !void {
        // Close old file
        if (self.current_file) |*file| {
            file.close();
        }
        if (self.current_date) |old_date| {
            self.allocator.free(old_date);
        }

        // Open new file
        const filename = try std.fmt.allocPrint(self.allocator, "{s}/kimiz-{s}.log", .{ self.log_dir, date });
        defer self.allocator.free(filename);

        const file = try std.fs.cwd().createFile(filename, .{ .truncate = false });
        try file.seekFromEnd(0);

        self.current_file = file;
        self.current_date = try self.allocator.dupe(u8, date);
    }

    fn formatTimestamp(timestamp: i64, buf: []u8) []const u8 {
        const seconds = @mod(timestamp, 60);
        const minutes = @mod(@divFloor(timestamp, 60), 60);
        const hours = @mod(@divFloor(timestamp, 3600), 24);
        return std.fmt.bufPrint(buf, "{d:0>2}:{d:0>2}:{d:0>2}", .{ hours, minutes, seconds }) catch "00:00:00";
    }

    // Convenience methods
    pub fn debug(self: *Self, comptime fmt: []const u8, args: anytype) void {
        self.log(.debug, fmt, args);
    }

    pub fn info(self: *Self, comptime fmt: []const u8, args: anytype) void {
        self.log(.info, fmt, args);
    }

    pub fn warn(self: *Self, comptime fmt: []const u8, args: anytype) void {
        self.log(.warn, fmt, args);
    }

    pub fn err(self: *Self, comptime fmt: []const u8, args: anytype) void {
        self.log(.err, fmt, args);
    }

    pub fn fatal(self: *Self, comptime fmt: []const u8, args: anytype) void {
        self.log(.fatal, fmt, args);
    }
};

// ============================================================================
// Global Logger
// ============================================================================

var global_logger: ?Logger = null;
var logger_mutex: std.Thread.Mutex = .{};

/// Initialize global logger
pub fn initGlobalLogger(allocator: std.mem.Allocator, log_dir: []const u8, min_level: LogLevel) !void {
    logger_mutex.lock();
    defer logger_mutex.unlock();

    if (global_logger != null) {
        global_logger.?.deinit();
    }

    global_logger = try Logger.init(allocator, log_dir, min_level);
}

/// Deinitialize global logger
pub fn deinitGlobalLogger() void {
    logger_mutex.lock();
    defer logger_mutex.unlock();

    if (global_logger) |*logger| {
        logger.deinit();
        global_logger = null;
    }
}

/// Get global logger (returns a no-op logger if not initialized)
pub fn getLogger() *Logger {
    logger_mutex.lock();
    defer logger_mutex.unlock();

    if (global_logger) |*logger| {
        return logger;
    }

    // Return a static no-op logger
    const noop = struct {
        var instance = Logger{
            .allocator = std.heap.page_allocator,
            .min_level = .fatal,
            .log_dir = &.{},
            .current_file = null,
            .current_date = null,
            .use_color = false,
            .mutex = .{},
        };
    };
    return &noop.instance;
}

// ============================================================================
// Convenience macros
// ============================================================================

pub fn debug(comptime fmt: []const u8, args: anytype) void {
    getLogger().debug(fmt, args);
}

pub fn info(comptime fmt: []const u8, args: anytype) void {
    getLogger().info(fmt, args);
}

pub fn warn(comptime fmt: []const u8, args: anytype) void {
    getLogger().warn(fmt, args);
}

pub fn err(comptime fmt: []const u8, args: anytype) void {
    getLogger().err(fmt, args);
}

pub fn fatal(comptime fmt: []const u8, args: anytype) void {
    getLogger().fatal(fmt, args);
}

// ============================================================================
// Tests
// ============================================================================

test "Logger init/deinit" {
    const allocator = std.testing.allocator;
    var logger = try Logger.init(allocator, ".test_logs", .debug);
    defer {
        // Clean up test log dir
        logger.deinit();
        std.fs.cwd().deleteDir(".test_logs") catch {};
    }

    try std.testing.expectEqual(.debug, logger.min_level);
}

test "Log level asString" {
    try std.testing.expectEqualStrings("DEBUG", LogLevel.debug.asString());
    try std.testing.expectEqualStrings("INFO", LogLevel.info.asString());
    try std.testing.expectEqualStrings("WARN", LogLevel.warn.asString());
    try std.testing.expectEqualStrings("ERROR", LogLevel.err.asString());
    try std.testing.expectEqualStrings("FATAL", LogLevel.fatal.asString());
}

test "Log level asColor" {
    // Just verify they return non-empty strings
    try std.testing.expect(LogLevel.debug.asColor().len > 0);
    try std.testing.expect(LogLevel.info.asColor().len > 0);
    try std.testing.expect(LogLevel.err.asColor().len > 0);
}

test "Logger levels filtering" {
    const allocator = std.testing.allocator;
    var logger = try Logger.init(allocator, ".test_logs_filter", .warn);
    defer {
        logger.deinit();
        std.fs.cwd().deleteDir(".test_logs_filter") catch {};
    }

    // These should not log (level too low)
    logger.debug("debug message", .{});
    logger.info("info message", .{});

    // These should log
    logger.warn("warn message", .{});
    logger.err("error message", .{});
}

test "Global logger initialization" {
    const allocator = std.testing.allocator;

    // Initialize global logger
    try initGlobalLogger(allocator, ".test_logs_global", .info);
    defer {
        deinitGlobalLogger();
        std.fs.cwd().deleteDir(".test_logs_global") catch {};
    }

    // Get logger and use it
    const logger = getLogger();
    logger.info("Test message from global logger", .{});
}

test "Convenience logging functions" {
    const allocator = std.testing.allocator;

    try initGlobalLogger(allocator, ".test_logs_conv", .debug);
    defer {
        deinitGlobalLogger();
        std.fs.cwd().deleteDir(".test_logs_conv") catch {};
    }

    // Test all convenience functions (should not crash)
    debug("Debug: {s}", .{"test"});
    info("Info: {d}", .{42});
    warn("Warn: {}", .{true});
    err("Error: {s}", .{"error message"});
    fatal("Fatal: {s}", .{"fatal error"});
}

test "Logger formatting" {
    const allocator = std.testing.allocator;
    var logger = try Logger.init(allocator, ".test_logs_fmt", .debug);
    defer {
        logger.deinit();
        std.fs.cwd().deleteDir(".test_logs_fmt") catch {};
    }

    // Test various format specifiers
    logger.info("String: {s}", .{"hello"});
    logger.info("Integer: {d}", .{123});
    logger.info("Float: {d:.2}", .{3.14159});
    logger.info("Boolean: {}", .{true});
    logger.info("Multiple: {s} {d} {}", .{"a", 1, false});
}

test "Logger thread safety" {
    const allocator = std.testing.allocator;
    var logger = try Logger.init(allocator, ".test_logs_thread", .debug);
    defer {
        logger.deinit();
        std.fs.cwd().deleteDir(".test_logs_thread") catch {};
    }

    // Simulate concurrent logging (single-threaded test)
    for (0..10) |i| {
        logger.info("Message {d}", .{i});
    }
}

test "No-op logger when not initialized" {
    // Get logger without initialization
    const logger = getLogger();

    // Should not crash, just do nothing
    logger.info("This should not crash", .{});
    logger.err("Neither should this", .{});
}
