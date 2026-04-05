//! File I/O helpers using Zig 0.16 native APIs

const std = @import("std");
const utils = @import("../../utils/root.zig");

pub fn readFileAlloc(allocator: std.mem.Allocator, path: []const u8, max_size: usize) ![]u8 {
    return utils.readFileAlloc(allocator, path, max_size);
}

pub fn writeFileAlloc(_: std.mem.Allocator, path: []const u8, data: []const u8) !void {
    return utils.writeFile(path, data);
}

// ============================================================================
// Tests
// ============================================================================

test "readFileAlloc basic" {
    const allocator = std.testing.allocator;
    try writeFileAlloc(allocator, "/tmp/kimiz_fio_test.txt", "hello");
    defer utils.deleteFile("/tmp/kimiz_fio_test.txt") catch {};

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
    defer utils.deleteFile(path) catch {};

    const data = try readFileAlloc(allocator, path, 1024);
    defer allocator.free(data);
    try std.testing.expectEqualStrings("test data", data);
}

test "writeFileAlloc creates parent dirs" {
    const allocator = std.testing.allocator;
    const path = "/tmp/kimiz_fio_nested/a/b/test.txt";
    try writeFileAlloc(allocator, path, "nested");
    defer {
        utils.deleteFile(path) catch {};
        utils.deleteTree("/tmp/kimiz_fio_nested") catch {};
    }

    const data = try readFileAlloc(allocator, path, 1024);
    defer allocator.free(data);
    try std.testing.expectEqualStrings("nested", data);
}
