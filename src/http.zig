//! HTTP Client - Full implementation using std.http.Client for Zig 0.15
//! Supports HTTP/HTTPS, JSON POST requests, and SSE streaming

const std = @import("std");

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
    InvalidUrl,
    DnsResolutionFailed,
    ConnectionTimeout,
};

/// HTTP Client wrapper around std.http.Client
/// Provides retry logic, error mapping, and streaming support
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
    /// Implements retry logic with exponential backoff
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
                // TODO: Add exponential backoff when std.Io is available
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
        const uri = std.Uri.parse(url) catch return AiError.InvalidUrl;

        var all_headers: std.ArrayList(std.http.Header) = .empty;
        defer all_headers.deinit(self.allocator);
        for (headers) |header| {
            try all_headers.append(self.allocator, header);
        }

        var req = self.client.request(.POST, uri, .{
            .headers = .{
                .content_type = .{ .override = "application/json" },
                .accept_encoding = .{ .override = "identity" },
            },
            .extra_headers = all_headers.items,
        }) catch return AiError.HttpRequestFailed;
        defer req.deinit();

        const body_copy = try self.allocator.dupe(u8, body);
        defer self.allocator.free(body_copy);
        req.sendBodyComplete(body_copy) catch return AiError.HttpRequestFailed;

        var redirect_buf: [8192]u8 = undefined;
        var response = req.receiveHead(&redirect_buf) catch return AiError.HttpResponseReadFailed;

        const status = response.head.status;
        var transfer_buf: [8192]u8 = undefined;
        const reader = response.reader(&transfer_buf);

        if (status == .ok or status == .created) {
            const body_content = reader.allocRemaining(self.allocator, .limited(1024 * 1024)) catch
                return AiError.HttpResponseReadFailed;
            return Response{
                .status = status,
                .body = body_content,
                .allocator = self.allocator,
            };
        } else {
            _ = reader.discardRemaining() catch 0;
            return mapStatusToError(status);
        }
    }

    /// Make a streaming POST request for SSE (Server-Sent Events)
    /// Calls the callback for each line received
    pub fn postStream(
        self: *Self,
        url: []const u8,
        headers: []const std.http.Header,
        body: []const u8,
        callback: *const fn (line: []const u8) void,
    ) !void {
        const uri = std.Uri.parse(url) catch return AiError.InvalidUrl;

        var all_headers = std.ArrayList(std.http.Header).init(self.allocator);
        defer all_headers.deinit();
        for (headers) |header| {
            try all_headers.append(self.allocator, header);
        }

        var req = self.client.request(.POST, uri, .{
            .headers = .{
                .content_type = .{ .override = "application/json" },
                .accept_encoding = .{ .override = "identity" },
            },
            .extra_headers = all_headers.items,
        }) catch return AiError.HttpRequestFailed;
        defer req.deinit();

        const body_copy = try self.allocator.dupe(u8, body);
        defer self.allocator.free(body_copy);
        req.sendBodyComplete(body_copy) catch return AiError.HttpRequestFailed;

        var redirect_buf: [8192]u8 = undefined;
        var response = req.receiveHead(&redirect_buf) catch return AiError.HttpResponseReadFailed;

        if (response.head.status != .ok) {
            return mapStatusToError(response.head.status);
        }

        var transfer_buf: [8192]u8 = undefined;
        const body_reader = response.reader(&transfer_buf);
        var line_buf: [SSE_LINE_BUF_SIZE]u8 = undefined;
        var line_pos: usize = 0;

        // Read chunks and process SSE lines
        var read_buf: [4096]u8 = undefined;
        var iov = [_][]u8{&read_buf};
        while (true) {
            const n = body_reader.readVec(&iov) catch return AiError.HttpResponseReadFailed;
            if (n == 0) break;
            for (read_buf[0..n]) |byte| {
                if (byte == '\n') {
                    if (line_pos > 0) {
                        const line_len = if (line_buf[line_pos - 1] == '\r')
                            line_pos - 1
                        else
                            line_pos;
                        callback(line_buf[0..line_len]);
                    }
                    line_pos = 0;
                } else {
                    if (line_pos < line_buf.len) {
                        line_buf[line_pos] = byte;
                        line_pos += 1;
                    }
                }
            }
        }

        if (line_pos > 0) {
            const line_len = if (line_buf[line_pos - 1] == '\r')
                line_pos - 1
            else
                line_pos;
            callback(line_buf[0..line_len]);
        }
    }
};

/// HTTP Response struct
pub const Response = struct {
    status: std.http.Status,
    body: []u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Response) void {
        self.allocator.free(self.body);
    }
};

/// Map HTTP status codes to AI errors
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

test "HttpClient parse URL" {
    const url = "https://api.openai.com/v1/chat/completions";
    const uri = try std.Uri.parse(url);
    try std.testing.expectEqualStrings("api.openai.com", uri.host.?.percent_encoded);
    try std.testing.expectEqualStrings("https", uri.scheme);
}
