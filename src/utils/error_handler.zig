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

/// Convert AiError to user-friendly message
pub fn getUserFriendlyError(err: core.AiError) ErrorMessage {
    return switch (err) {
        .HttpConnectionFailed => .{
            .code = "NET001",
            .title = "无法连接到 AI 服务",
            .message = "网络连接失败，无法访问 AI API 服务器。",
            .suggestion = "请检查：\n  1. 网络连接是否正常\n  2. 是否使用了代理/VPN\n  3. API 服务地址是否正确",
        },
        .HttpTlsFailed => .{
            .code = "NET002",
            .title = "TLS/SSL 连接失败",
            .message = "无法建立安全连接。",
            .suggestion = "请检查：\n  1. 系统时间是否正确\n  2. SSL 证书是否正常\n  3. 尝试更新系统 CA 证书",
        },
        .HttpRequestFailed => .{
            .code = "NET003",
            .title = "HTTP 请求失败",
            .message = "发送请求时发生错误。",
            .suggestion = "请稍后重试，或检查网络连接是否稳定。",
        },
        .ApiAuthenticationFailed => .{
            .code = "AUTH001",
            .title = "API 认证失败",
            .message = "API Key 无效或已过期。",
            .suggestion = "请检查：\n  1. KIMI_API_KEY 环境变量是否设置\n  2. API Key 是否正确\n  3. 在 https://platform.moonshot.cn 查看密钥状态",
        },
        .ApiPermissionDenied => .{
            .code = "AUTH002",
            .title = "权限不足",
            .message = "当前 API Key 没有权限执行此操作。",
            .suggestion = "请检查 API Key 的权限设置，或联系管理员。",
        },
        .ApiRateLimitExceeded => .{
            .code = "RATE001",
            .title = "请求频率限制",
            .message = "请求过于频繁，已触发速率限制。",
            .suggestion = "请等待几秒钟后重试，或升级账户以提高限制。",
        },
        .ApiServerError => .{
            .code = "SERVER001",
            .title = "AI 服务暂时不可用",
            .message = "服务器内部错误，可能是临时性问题。",
            .suggestion = "请稍后重试 (30秒后)，如果问题持续请联系支持。",
        },
        .JsonParseFailed => .{
            .code = "PARSE001",
            .title = "JSON 解析失败",
            .message = "无法解析 AI 返回的数据。",
            .suggestion = "这可能是临时性问题，请重试。如果持续发生，请报告 bug。",
        },
        .ApiKeyNotFound => .{
            .code = "CONFIG001",
            .title = "API Key 未配置",
            .message = "没有找到 API Key。",
            .suggestion = "请设置 KIMI_API_KEY 环境变量：\n  export KIMI_API_KEY=your_key_here",
        },
        .ToolExecutionFailed => .{
            .code = "TOOL001",
            .title = "工具执行失败",
            .message = "执行工具时发生错误。",
            .suggestion = "请检查参数是否正确，或查看详细错误信息。",
        },
        .ToolNotFound => .{
            .code = "TOOL002",
            .title = "工具不存在",
            .message = "请求的工具未找到。",
            .suggestion = "请检查工具名称是否正确，或查看可用工具列表。",
        },
        .OutOfMemory => .{
            .code = "SYS001",
            .title = "内存不足",
            .message = "系统内存不足，无法完成操作。",
            .suggestion = "请尝试：\n  1. 关闭其他程序释放内存\n  2. 重启应用\n  3. 处理较小的文件",
        },
        else => .{
            .code = "UNKNOWN",
            .title = "未知错误",
            .message = "发生未知错误。",
            .suggestion = "请重试，如果问题持续请报告 bug 并提供错误详情。",
        },
    };
}

// ============================================================================
// Error Recovery Strategies
// ============================================================================

pub const RecoveryStrategy = enum {
    retry,           // 立即重试
    retry_with_backoff, // 指数退避重试
    fallback,        // 使用备用方案
    abort,           // 终止操作
    ignore,          // 忽略错误继续
};

pub const ErrorRecovery = struct {
    strategy: RecoveryStrategy,
    max_retries: u32,
    retry_delay_ms: u64,
    fallback_action: ?[]const u8,

    pub fn init(strategy: RecoveryStrategy) ErrorRecovery {
        return .{
            .strategy = strategy,
            .max_retries = switch (strategy) {
                .retry => 3,
                .retry_with_backoff => 5,
                else => 0,
            },
            .retry_delay_ms = 1000,
            .fallback_action = null,
        };
    }

    pub fn withRetries(self: ErrorRecovery, count: u32) ErrorRecovery {
        return .{
            .strategy = self.strategy,
            .max_retries = count,
            .retry_delay_ms = self.retry_delay_ms,
            .fallback_action = self.fallback_action,
        };
    }
};

/// Get recommended recovery strategy for error
pub fn getRecoveryStrategy(err: core.AiError) ErrorRecovery {
    return switch (err) {
        .HttpConnectionFailed => ErrorRecovery.init(.retry_with_backoff).withRetries(3),
        .HttpTlsFailed => ErrorRecovery.init(.abort),
        .HttpRequestFailed => ErrorRecovery.init(.retry).withRetries(2),
        .ApiAuthenticationFailed => ErrorRecovery.init(.abort),
        .ApiPermissionDenied => ErrorRecovery.init(.abort),
        .ApiRateLimitExceeded => ErrorRecovery.init(.retry_with_backoff).withRetries(5),
        .ApiServerError => ErrorRecovery.init(.retry_with_backoff).withRetries(3),
        .JsonParseFailed => ErrorRecovery.init(.retry).withRetries(2),
        .ApiKeyNotFound => ErrorRecovery.init(.abort),
        .ToolExecutionFailed => ErrorRecovery.init(.retry).withRetries(1),
        .ToolNotFound => ErrorRecovery.init(.abort),
        .OutOfMemory => ErrorRecovery.init(.abort),
        else => ErrorRecovery.init(.retry).withRetries(2),
    };
}

// ============================================================================
// Error Logger
// ============================================================================

pub const ErrorLogger = struct {
    allocator: std.mem.Allocator,
    log_file: ?std.fs.File,
    verbose: bool,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, log_path: ?[]const u8, verbose: bool) !Self {
        var log_file: ?std.fs.File = null;
        if (log_path) |path| {
            log_file = try std.fs.cwd().createFile(path, .{ .truncate = false });
            try log_file.?.seekFromEnd(0);
        }

        return .{
            .allocator = allocator,
            .log_file = log_file,
            .verbose = verbose,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.log_file) |*file| {
            file.close();
            self.log_file = null;
        }
    }

    pub fn logError(
        self: *Self,
        err: anyerror,
        context: ErrorContext,
        recovery: ErrorRecovery,
    ) !void {
        const timestamp = std.time.timestamp();

        const log_entry = try std.fmt.allocPrint(self.allocator,
            "[{d}] ERROR: {s}\n  Operation: {s}\n  File: {s}:{d}\n  Recovery: {s} (retries: {d})\n  Details: {s}\n\n",
            .{
                timestamp,
                @errorName(err),
                context.operation,
                context.file,
                context.line,
                @tagName(recovery.strategy),
                recovery.max_retries,
                context.details orelse "N/A",
            },
        );
        defer self.allocator.free(log_entry);

        // Write to log file if available
        if (self.log_file) |file| {
            _ = try file.write(log_entry);
        }

        // Print to stderr if verbose
        if (self.verbose) {
            std.debug.print("{s}", .{log_entry});
        }
    }
};

// ============================================================================
// Helper Functions
// ============================================================================

/// Try operation with retry and error handling
pub fn tryWithRetry(
    allocator: std.mem.Allocator,
    comptime Operation: type,
    operation: Operation,
    context: ErrorContext,
) !void {
    const result = operation();
    
    if (result) |_| {
        return;
    } else |err| {
        const ai_err: core.AiError = err;
        const recovery = getRecoveryStrategy(ai_err);
        
        if (recovery.strategy == .abort) {
            const msg = getUserFriendlyError(ai_err);
            std.debug.print("{}", .{msg});
            return err;
        }

        // Try retries
        var retry_count: u32 = 0;
        while (retry_count < recovery.max_retries) : (retry_count += 1) {
            std.time.sleep(recovery.retry_delay_ms * 1_000_000);
            
            if (operation()) |_| {
                return;
            } else |_| {
                continue;
            }
        }

        // All retries exhausted
        const msg = getUserFriendlyError(ai_err);
        std.debug.print("{}", .{msg});
        return err;
    }
}

// ============================================================================
// Tests
// ============================================================================

test "getUserFriendlyError returns valid messages" {
    const err = core.AiError.ApiKeyNotFound;
    const msg = getUserFriendlyError(err);
    
    try std.testing.expect(msg.code.len > 0);
    try std.testing.expect(msg.title.len > 0);
    try std.testing.expect(msg.message.len > 0);
    try std.testing.expect(msg.suggestion.len > 0);
}

test "getRecoveryStrategy returns appropriate strategy" {
    const rate_limit = getRecoveryStrategy(core.AiError.ApiRateLimitExceeded);
    try std.testing.expectEqual(.retry_with_backoff, rate_limit.strategy);
    try std.testing.expect(rate_limit.max_retries > 0);

    const auth_fail = getRecoveryStrategy(core.AiError.ApiAuthenticationFailed);
    try std.testing.expectEqual(.abort, auth_fail.strategy);
}
