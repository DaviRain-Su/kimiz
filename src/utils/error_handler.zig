//! Error Handling System
//! User-friendly error messages and recovery strategies
//! MVP-B1: Error Handling System

const std = @import("std");
const core = @import("../core/root.zig");

// ============================================================================
// Error Context
// ============================================================================

pub const ErrorContext = struct {
    operation: []const u8,
    file: []const u8,
    line: u32,
    details: ?[]const u8,

    pub fn init(operation: []const u8, file: []const u8, line: u32) ErrorContext {
        return .{
            .operation = operation,
            .file = file,
            .line = line,
            .details = null,
        };
    }

    pub fn withDetails(self: ErrorContext, details: []const u8) ErrorContext {
        return .{
            .operation = self.operation,
            .file = self.file,
            .line = self.line,
            .details = details,
        };
    }
};

// ============================================================================
// Error Recovery Strategies
// ============================================================================

pub const RecoveryStrategy = enum {
    abort,               // Fatal error, stop execution
    retry,               // Simple retry
    retry_with_backoff,  // Retry with exponential backoff
};

pub const ErrorRecovery = struct {
    strategy: RecoveryStrategy,
    max_retries: u32,

    pub fn init(strategy: RecoveryStrategy) ErrorRecovery {
        return .{
            .strategy = strategy,
            .max_retries = 0,
        };
    }

    pub fn withRetries(self: ErrorRecovery, max_retries: u32) ErrorRecovery {
        return .{
            .strategy = self.strategy,
            .max_retries = max_retries,
        };
    }
};

// ============================================================================
// User-Friendly Error Messages
// ============================================================================

pub const ErrorMessage = struct {
    code: []const u8,
    title: []const u8,
    message: []const u8,
    suggestion: []const u8,

    pub fn format(
        self: ErrorMessage,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("❌ [{s}] {s}\n\n{s}\n\n💡 {s}\n", .{
            self.code,
            self.title,
            self.message,
            self.suggestion,
        });
    }
};

/// Convert error name to user-friendly message
pub fn getUserFriendlyMessage(err_name: []const u8) ?ErrorMessage {
    const map = [_]struct { name: []const u8, msg: ErrorMessage }{
        .{ .name = "HttpConnectionFailed", .msg = .{ .code = "NET001", .title = "Cannot connect to AI service", .message = "Network connection failed.", .suggestion = "Check your internet connection and proxy settings." } },
        .{ .name = "HttpTlsFailed", .msg = .{ .code = "NET002", .title = "TLS/SSL connection failed", .message = "Cannot establish secure connection.", .suggestion = "Check system time and SSL certificates." } },
        .{ .name = "HttpRequestFailed", .msg = .{ .code = "NET003", .title = "HTTP request failed", .message = "Error sending request.", .suggestion = "Please retry later." } },
        .{ .name = "ApiAuthenticationFailed", .msg = .{ .code = "AUTH001", .title = "API authentication failed", .message = "API Key is invalid or expired.", .suggestion = "Check your KIMI_API_KEY environment variable." } },
        .{ .name = "ApiRateLimitExceeded", .msg = .{ .code = "RATE001", .title = "Rate limit exceeded", .message = "Too many requests.", .suggestion = "Wait a few seconds and retry." } },
        .{ .name = "ApiServerError", .msg = .{ .code = "SERVER001", .title = "AI service temporarily unavailable", .message = "Server error.", .suggestion = "Retry in 30 seconds." } },
        .{ .name = "ApiKeyNotFound", .msg = .{ .code = "CONFIG001", .title = "API Key not configured", .message = "No API Key found.", .suggestion = "Set KIMI_API_KEY: export KIMI_API_KEY=your_key" } },
        .{ .name = "JsonParseFailed", .msg = .{ .code = "PARSE001", .title = "Response parse failed", .message = "Cannot parse AI response.", .suggestion = "This may be temporary. Please retry." } },
        .{ .name = "OutOfMemory", .msg = .{ .code = "SYS001", .title = "Out of memory", .message = "System memory insufficient.", .suggestion = "Close other programs or restart." } },
        .{ .name = "ToolNotFound", .msg = .{ .code = "TOOL002", .title = "Tool not found", .message = "Requested tool does not exist.", .suggestion = "Check tool name." } },
    };
    for (&map) |entry| {
        if (std.mem.eql(u8, err_name, entry.name)) return entry.msg;
    }
    return null;
}

/// Get recommended recovery strategy for error by name
pub fn getRecoveryStrategy(err_name: []const u8) ErrorRecovery {
    const abort_errors = [_][]const u8{ "HttpTlsFailed", "ApiAuthenticationFailed", "ApiPermissionDenied", "ApiKeyNotFound", "ToolNotFound", "OutOfMemory" };
    const backoff_errors = [_][]const u8{ "HttpConnectionFailed", "ApiRateLimitExceeded", "ApiServerError" };
    for (&abort_errors) |name| {
        if (std.mem.eql(u8, err_name, name)) return ErrorRecovery.init(.abort);
    }
    for (&backoff_errors) |name| {
        if (std.mem.eql(u8, err_name, name)) return ErrorRecovery.init(.retry_with_backoff).withRetries(3);
    }
    return ErrorRecovery.init(.retry).withRetries(2);
}

// ============================================================================
// Error Logger
// ============================================================================

/// Log errors to stderr for debugging
pub fn logError(allocator: std.mem.Allocator, err: anyerror, context: ErrorContext) void {
    const log_entry = std.fmt.allocPrint(allocator,
        "[ERROR] {s} | op={s} file={s}:{d} | {s}\n",
        .{
            @errorName(err),
            context.operation,
            context.file,
            context.line,
            context.details orelse "",
        },
    ) catch return;
    defer allocator.free(log_entry);
    std.debug.print("{s}", .{log_entry});
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Format any error into a user-friendly string.
pub fn formatError(allocator: std.mem.Allocator, err: anyerror) ![]u8 {
    const name = @errorName(err);
    if (getUserFriendlyMessage(name)) |msg| {
        return std.fmt.allocPrint(allocator, "[{s}] {s}\n{s}\n{s}", .{ msg.code, msg.title, msg.message, msg.suggestion });
    }
    return std.fmt.allocPrint(allocator, "Error: {s}", .{name});
}

// ============================================================================
// Tests
// ============================================================================

test "getUserFriendlyMessage returns valid messages" {
    const msg = getUserFriendlyMessage("ApiKeyNotFound");
    try std.testing.expect(msg != null);
    try std.testing.expect(msg.?.code.len > 0);
}

test "formatError known error" {
    const allocator = std.testing.allocator;
    const result = try formatError(allocator, core.AiError.ApiKeyNotFound);
    defer allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "CONFIG001") != null);
}

test "formatError unknown error" {
    const allocator = std.testing.allocator;
    const result = try formatError(allocator, error.SomeRandomError);
    defer allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "SomeRandomError") != null);
}
