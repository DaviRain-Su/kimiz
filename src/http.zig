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
    retry_count: u3 = 3,
    timeout_ms: u32 = 30000,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .client = .{ .allocator = allocator },
        };
    }

    pub fn deinit(self: *Self) void {
        self.client.deinit();
    }

    /// Make a POST request with JSON body
    pub fn postJson(
        self: *Self,
        url: []const u8,
        headers: std.http.Headers,
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
        headers: std.http.Headers,
        body: []const u8,
    ) !Response {
        const uri = std.Uri.parse(url) catch return AiError.HttpRequestFailed;

        var request = self.client.request(uri, .{
            .method = .POST,
            .headers = headers,
        }, .{}) catch return AiError.HttpConnectionFailed;
        defer request.deinit();

        // Write body
        request.writeAll(body) catch return AiError.HttpRequestFailed;
        request.finish() catch return AiError.HttpRequestFailed;
        request.wait() catch return AiError.HttpResponseReadFailed;

        // Check status
        const status = request.response.status;
        if (status == .ok or status == .created) {
            // Read response body
            var body_list = std.ArrayList(u8).init(self.allocator);
            defer body_list.deinit();

            var buf: [4096]u8 = undefined;
            while (true) {
                const bytes_read = request.read(&buf) catch break;
                if (bytes_read == 0) break;
                try body_list.appendSlice(buf[0..bytes_read]);
            }

            return Response{
                .status = status,
                .body = try body_list.toOwnedSlice(),
                .allocator = self.allocator,
            };
        } else {
            return mapStatusToError(status);
        }
    }

    /// Make a streaming POST request
    pub fn postStream(
        self: *Self,
        url: []const u8,
        headers: std.http.Headers,
        body: []const u8,
        callback: *const fn (line: []const u8) void,
    ) !void {
        const uri = std.Uri.parse(url) catch return AiError.HttpRequestFailed;

        var request = self.client.request(uri, .{
            .method = .POST,
            .headers = headers,
        }, .{}) catch return AiError.HttpConnectionFailed;
        defer request.deinit();

        request.writeAll(body) catch return AiError.HttpRequestFailed;
        request.finish() catch return AiError.HttpRequestFailed;
        request.wait() catch return AiError.HttpResponseReadFailed;

        // Check status
        const status = request.response.status;
        if (status != .ok) {
            return mapStatusToError(status);
        }

        // Read stream line by line
        var line_buf: [SSE_LINE_BUF_SIZE]u8 = undefined;
        var line_pos: usize = 0;

        var buf: [4096]u8 = undefined;
        while (true) {
            const bytes_read = request.read(&buf) catch break;
            if (bytes_read == 0) break;

            for (buf[0..bytes_read]) |byte| {
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
        }
    }
};

pub const Response = struct {
    status: std.http.Status,
    body: []u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Response) void {
        self.allocator.free(self.body);
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
