//! HTTP Client - Wrapper around std.http.Client
//! Provides retry logic, error mapping, and streaming support

const std = @import("std");

// Define constants locally since http.zig is at src/ level
pub const SSE_LINE_BUF_SIZE = 65536;

pub const AiError = error{
    // HTTP Layer
    HttpConnectionFailed,
    HttpTlsFailed,
    HttpRequestFailed,
    HttpResponseReadFailed,
    HttpRedirectFailed,
    // API Layer
    ApiAuthenticationFailed,
    ApiPermissionDenied,
    ApiNotFound,
    ApiRateLimitExceeded,
    ApiServerError,
    ApiUnexpectedResponse,
    // Configuration
    ApiKeyNotFound,
    ProviderNotSupported,
    OutOfMemory,
};

pub const HttpClient = struct {
    allocator: std.mem.Allocator,
    client: std.http.Client,
    io_uring: std.Io.IoUring,
    retry_count: u3 = 3,
    timeout_ms: u32 = 30000,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        // Zig 0.16: std.http.Client requires IoUring for async I/O
        var io_uring: std.Io.IoUring = undefined;
        try io_uring.init(allocator);
        errdefer io_uring.deinit();
        
        const io = io_uring.io();
        
        var client = std.http.Client{
            .allocator = allocator,
            .io = io,
        };
        // Note: client.deinit() doesn't deinit io, we need to do it separately
        
        return .{
            .allocator = allocator,
            .client = client,
            .io_uring = io_uring,
        };
    }

    pub fn deinit(self: *Self) void {
        self.client.deinit();
        self.io_uring.deinit();
    }

    /// Make a POST request with JSON body
    pub fn postJson(
        self: *Self,
        url: []const u8,
        headers: []const std.http.Header,
        body: []const u8,
    ) !Response {
        var attempts: u3 = 0;
        var last_error: ?anyerror = null;

        while (attempts < self.retry_count) : (attempts += 1) {
            return self.postJsonOnce(url, headers, body) catch |err| {
                last_error = err;
                if (attempts + 1 < self.retry_count) {
                    // Exponential backoff: 100ms, 200ms, 400ms
                    const delay_ms = @as(u64, 100) << attempts;
                    std.time.sleep(delay_ms * std.time.ns_per_ms);
                }
                continue;
            };
        }

        return last_error orelse AiError.HttpRequestFailed;
    }

    fn postJsonOnce(
        self: *Self,
        url: []const u8,
        headers: []const std.http.Header,
        body: []const u8,
    ) !Response {
        const uri = std.Uri.parse(url) catch return AiError.HttpRequestFailed;

        // Buffer to collect response body
        var body_list: std.ArrayList(u8) = .empty;
        errdefer body_list.deinit(self.allocator);

        // Use fetch API with response_writer
        const fetch_result = self.client.fetch(.{
            .location = .{ .uri = uri },
            .method = .POST,
            .extra_headers = headers,
            .payload = body,
            .response_writer = body_list.writer(self.allocator),
        }) catch return AiError.HttpRequestFailed;

        // Check status
        const status = fetch_result.status;
        if (status == .ok or status == .created) {
            return Response{
                .status = status,
                .body = try body_list.toOwnedSlice(self.allocator),
                .allocator = self.allocator,
            };
        } else {
            body_list.deinit(self.allocator);
            return mapStatusToError(status);
        }
    }

    /// Make a streaming POST request
    pub fn postStream(
        self: *Self,
        url: []const u8,
        headers: []const std.http.Header,
        body: []const u8,
        callback: *const fn (line: []const u8) void,
    ) !void {
        const uri = std.Uri.parse(url) catch return AiError.HttpRequestFailed;

        // Buffer to collect response body
        var body_list: std.ArrayList(u8) = .empty;
        errdefer body_list.deinit(self.allocator);

        // Use fetch API with response_writer
        const fetch_result = self.client.fetch(.{
            .location = .{ .uri = uri },
            .method = .POST,
            .extra_headers = headers,
            .payload = body,
            .response_writer = body_list.writer(self.allocator),
        }) catch return AiError.HttpRequestFailed;

        // Check status
        const status = fetch_result.status;
        if (status != .ok) {
            body_list.deinit(self.allocator);
            return mapStatusToError(status);
        }

        // Process body line by line (SSE format)
        var line_buf: [SSE_LINE_BUF_SIZE]u8 = undefined;
        var line_pos: usize = 0;

        for (body_list.items) |byte| {
            if (byte == '\n') {
                // Line complete
                if (line_pos > 0) {
                    // Remove \r if present
                    const line_len = if (line_pos > 0 and line_buf[line_pos - 1] == '\r')
                        line_pos - 1
                    else
                        line_pos;
                    callback(line_buf[0..line_len]);
                    line_pos = 0;
                }
            } else {
                if (line_pos < line_buf.len) {
                    line_buf[line_pos] = byte;
                    line_pos += 1;
                }
            }
        }

        // Handle last line if no trailing newline
        if (line_pos > 0) {
            const line_len = if (line_pos > 0 and line_buf[line_pos - 1] == '\r')
                line_pos - 1
            else
                line_pos;
            callback(line_buf[0..line_len]);
        }

        body_list.deinit(self.allocator);
    }
};

pub const Response = struct {
    status: std.http.Status,
    body: []u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Response, allocator: std.mem.Allocator) void {
        allocator.free(self.body);
    }
};

fn mapStatusToError(status: std.http.Status) AiError {
    return switch (status) {
        .unauthorized => AiError.ApiAuthenticationFailed,
        .forbidden => AiError.ApiPermissionDenied,
        .not_found => AiError.ApiNotFound,
        .too_many_requests => AiError.ApiRateLimitExceeded,
        .internal_server_error, .bad_gateway, .service_unavailable => AiError.ApiServerError,
        else => AiError.ApiUnexpectedResponse,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "HttpClient init/deinit" {
    const allocator = std.testing.allocator;
    var client = HttpClient.init(allocator);
    defer client.deinit();
}
