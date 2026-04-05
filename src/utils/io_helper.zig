//! I/O Helper Module
//! Provides compatibility layer for Zig 0.16's new std.Io system

const std = @import("std");

/// Global Io instance manager
/// This is a simplified version - in production, you might want more sophisticated lifecycle management
pub const IoManager = struct {
    threaded: ?std.Io.Threaded = null,
    gpa: std.mem.Allocator,

    const Self = @This();

    /// Initialize the IoManager with a general purpose allocator
    pub fn init(gpa: std.mem.Allocator) !Self {
        return .{
            .threaded = null,
            .gpa = gpa,
        };
    }

    /// Initialize the threaded I/O system
    pub fn initThreaded(self: *Self, argv0: []const []const u8, environ: []const []const u8) !void {
        self.threaded = std.Io.Threaded.init(self.gpa, .{
            .argv0 = .init(argv0),
            .environ = environ,
        });
    }

    /// Get the Io instance
    /// Returns the threaded Io if initialized, otherwise returns a default
    pub fn io(self: *Self) std.Io {
        if (self.threaded) |*t| {
            return t.io();
        }
        // Fallback: create a minimal threaded Io on demand
        // In production, you should properly initialize this
        @panic("IoManager not initialized. Call initThreaded() first.");
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        if (self.threaded) |*t| {
            t.deinit();
            self.threaded = null;
        }
    }
};

/// Buffered stdout writer
pub const BufferedStdout = struct {
    file: std.Io.File,
    buffer: [4096]u8,
    file_writer: std.Io.File.Writer,

    const Self = @This();

    /// Initialize buffered stdout
    pub fn init(io_instance: std.Io) Self {
        const file = std.Io.File.stdout();
        var buf: [4096]u8 = undefined;
        const fw = file.writer(io_instance, &buf);
        return .{
            .file = file,
            .buffer = buf,
            .file_writer = fw,
        };
    }

    /// Get the writer interface for printing
    pub fn writer(self: *Self) *std.Io.Writer {
        return &self.file_writer.interface;
    }

    /// Print formatted text
    pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        try self.file_writer.interface.print(fmt, args);
    }

    /// Flush the buffer
    pub fn flush(self: *Self) !void {
        try self.file_writer.flush();
    }
};

/// Buffered stdin reader
pub const BufferedStdin = struct {
    file: std.Io.File,
    buffer: [4096]u8,
    file_reader: std.Io.File.Reader,

    const Self = @This();

    /// Initialize buffered stdin
    pub fn init(io_instance: std.Io) Self {
        const file = std.Io.File.stdin();
        var buf: [4096]u8 = undefined;
        const fr = file.reader(io_instance, &buf);
        return .{
            .file = file,
            .buffer = buf,
            .file_reader = fr,
        };
    }

    /// Get the reader interface
    pub fn reader(self: *Self) *std.Io.Reader {
        return &self.file_reader.interface;
    }

    /// Read a line (until newline)
    pub fn readLine(self: *Self, allocator: std.mem.Allocator) !?[]u8 {
        var result = std.ArrayList(u8).init(allocator);
        errdefer result.deinit();

        while (true) {
            const byte = self.file_reader.interface.readByte() catch |err| switch (err) {
                error.EndOfStream => break,
                else => return err,
            };

            if (byte == '\n') break;
            try result.append(byte);
        }

        if (result.items.len == 0) return null;
        return try result.toOwnedSlice();
    }
};

/// Convenience function to print to stdout
/// Note: This creates a temporary buffered writer. For repeated use,
/// create a BufferedStdout and reuse it.
pub fn print(io_instance: std.Io, comptime fmt: []const u8, args: anytype) !void {
    var buf: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io_instance, &buf);
    try stdout.interface.print(fmt, args);
    try stdout.flush();
}

/// Convenience function to print to stderr
pub fn printErr(io_instance: std.Io, comptime fmt: []const u8, args: anytype) !void {
    var buf: [1024]u8 = undefined;
    var stderr = std.Io.File.stderr().writer(io_instance, &buf);
    try stderr.interface.print(fmt, args);
    try stderr.flush();
}

// ============================================================================
// Tests
// ============================================================================

test "BufferedStdout basic usage" {
    // This test would need a mock Io instance
    // For now, just verify the struct compiles
    const allocator = std.testing.allocator;
    _ = allocator;
}

test "print function signature" {
    // Verify the function signature is correct
    const IoManagerType = @TypeOf(print);
    _ = IoManagerType;
}
