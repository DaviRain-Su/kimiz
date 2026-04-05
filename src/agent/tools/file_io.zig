//! File I/O helpers using Zig 0.16 native APIs

const std = @import("std");

pub fn readFileAlloc(allocator: std.mem.Allocator, path: []const u8, max_size: usize) ![]u8 {
    return std.fs.cwd().readFileAlloc(allocator, path, max_size);
}

pub fn writeFileAlloc(_: std.mem.Allocator, path: []const u8, data: []const u8) !void {
    // Ensure parent directories exist
    if (std.fs.path.dirname(path)) |dir| {
        try std.fs.cwd().makePath(dir);
    }

    try std.fs.cwd().writeFile(.{
        .sub_path = path,
        .data = data,
    });
}

// ============================================================================
// Tests
// ============================================================================

test "readFileAlloc basic" {
    const allocator = std.testing.allocator;
    try std.fs.cwd().writeFile(.{ .sub_path = "/tmp/kimiz_fio_test.txt", .data = "hello" });
    defer std.fs.cwd().deleteFile("/tmp/kimiz_fio_test.txt") catch {};

    const data = try readFileAlloc(allocator, "/tmp/kimiz_fio_test.txt", 1024);
    defer allocator.free(data);
    try std.testing.expectEqualStrings("hello", data);
}

test "readFileAlloc not found" {
    try std.testing.expectError(error.FileNotFound, readFileAlloc(std.testing.allocator, "/nonexistent_path_xyz", 1024));
}

test "writeFileAlloc and read back" {
    const allocator = std.testing.allocator;
    const path = "/tmp/kimiz_fio_write_test.txt";
    try writeFileAlloc(allocator, path, "test data");
    defer std.fs.cwd().deleteFile(path) catch {};

    const data = try readFileAlloc(allocator, path, 1024);
    defer allocator.free(data);
    try std.testing.expectEqualStrings("test data", data);
}

test "writeFileAlloc creates parent dirs" {
    const allocator = std.testing.allocator;
    const path = "/tmp/kimiz_fio_nested/a/b/test.txt";
    try writeFileAlloc(allocator, path, "nested");
    defer {
        std.fs.cwd().deleteFile(path) catch {};
        std.fs.cwd().deleteDir("/tmp/kimiz_fio_nested/a/b") catch {};
        std.fs.cwd().deleteDir("/tmp/kimiz_fio_nested/a") catch {};
        std.fs.cwd().deleteDir("/tmp/kimiz_fio_nested") catch {};
    }

    const data = try readFileAlloc(allocator, path, 1024);
    defer allocator.free(data);
    try std.testing.expectEqualStrings("nested", data);
}
