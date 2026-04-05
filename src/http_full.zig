//! HTTP Client - Wrapper around std.http.Client
//! Provides retry logic, error mapping, and streaming support

const std = @import("std");
const utils = @import("utils/root.zig");

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
    IoManagerNotInitialized,
};

pub const HttpClient = struct {
    allocator: std.mem.Allocator,
    client: std.http.Client,
    retry_count: u3 = 3,
    timeout_ms: u32 = 30000,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        // Get IoManager instance
        const io_manager = try utils.getIoManager();
        const io = io_manager.io();

        const client = std.http.Client{
            .allocator = allocator,
            .io = io,
        };

        return .{
            .allocator = allocator,
            .client = client,
        };
    }

    pub fn deinit(self: *Self) void {
        // std.http.Client doesn't have explicit deinit in Zig 0.16
        // Resources are cleaned up when the client is dropped
        _ = self;
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

        // Setup request options
        const options = std.http.Client.RequestOptions{
            .server_header_buffer = try self.allocator.alloc(u8, 8192),
        };
        defer self.allocator.free(options.server_header_buffer);

        // Start the request
        var req = try self.client.open(.POST, uri, options);
        defer req.deinit();

        // Add headers
        try req.appendHeader("Content-Type", "application/json");
        for (headers) |header| {
            try req.appendHeader(header.name, header.value);
        }

        // Send the body
        try req.send(body);
        try req.finish();

        // Wait for response
        try req.wait();

        // Read response body
        const body_reader = req.reader();
        const body_content = try body_reader.readAllAlloc(self.allocator, 1024 * 1024); // 1MB max

        // Check status
        const status = req.response.status;
        if (status == .ok or status == .created) {
            return Response{
                .status = status,
                .body = body_content,
                .allocator = self.allocator,
            };
        } else {
            self.allocator.free(body_content);
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

        // Setup request options
        const options = std.http.Client.RequestOptions{
            .server_header_buffer = try self.allocator.alloc(u8, 8192),
        };
        defer self.allocator.free(options.server_header_buffer);

        // Start the request
        var req = try self.client.open(.POST, uri, options);
        defer req.deinit();

        // Add headers
        try req.appendHeader("Content-Type", "application/json");
        try req.appendHeader("Accept", "text/event-stream");
        for (headers) |header| {
            try req.appendHeader(header.name, header.value);
        }

        // Send the body
        try req.send(body);
        try req.finish();

        // Wait for response headers
        try req.wait();

        // Check status
        const status = req.response.status;
        if (status != .ok) {
            return mapStatusToError(status);
        }

        // Read response body line by line (SSE format)
        const body_reader = req.reader();
        var line_buf: [SSE_LINE_BUF_SIZE]u8 = undefined;
        var line_pos: usize = 0;

        while (true) {
            const byte = body_reader.readByte() catch |err| switch (err) {
                error.EndOfStream => break,
                else => return AiError.HttpResponseReadFailed,
            };

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

    // Initialize IoManager first
    try utils.initIoManager(allocator);
    defer utils.deinitIoManager();

    var client = try HttpClient.init(allocator);
    defer client.deinit();
}

test "HttpClient requires IoManager" {
    const allocator = std.testing.allocator;

    // Should fail if IoManager not initialized
    try std.testing.expectError(utils.IoManager.NotInitialized, HttpClient.init(allocator));
}
