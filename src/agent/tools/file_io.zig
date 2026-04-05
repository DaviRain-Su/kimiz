//! File I/O helpers using C stdlib for Zig 0.16 compatibility

const std = @import("std");

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    @cInclude("string.h");
    @cInclude("sys/stat.h");
    @cInclude("errno.h");
});

pub fn readFileAlloc(allocator: std.mem.Allocator, path: []const u8, max_size: usize) ![]u8 {
    const c_path = try allocator.dupeZ(u8, path);
    defer allocator.free(c_path);

    const fp = c.fopen(c_path.ptr, "rb") orelse return error.FileNotFound;
    defer _ = c.fclose(fp);

    _ = c.fseek(fp, 0, c.SEEK_END);
    const raw_size = c.ftell(fp);
    if (raw_size < 0) return error.FileNotFound;
    const size: usize = @intCast(raw_size);
    _ = c.fseek(fp, 0, c.SEEK_SET);

    const read_size = @min(size, max_size);
    const buf = try allocator.alloc(u8, read_size);
    errdefer allocator.free(buf);

    const n = c.fread(buf.ptr, 1, read_size, fp);
    if (n < read_size) {
        return allocator.realloc(buf, n);
    }
    return buf;
}

pub fn writeFileAlloc(allocator: std.mem.Allocator, path: []const u8, data: []const u8) !void {
    // Ensure parent directories exist
    if (std.fs.path.dirname(path)) |dir| {
        mkdirRecursive(allocator, dir) catch {};
    }

    const c_path = try allocator.dupeZ(u8, path);
    defer allocator.free(c_path);

    const fp = c.fopen(c_path.ptr, "wb") orelse return error.FileNotFound;
    defer _ = c.fclose(fp);

    const n = c.fwrite(data.ptr, 1, data.len, fp);
    if (n < data.len) return error.WriteError;
}

fn mkdirRecursive(allocator: std.mem.Allocator, path: []const u8) !void {
    const c_path = try allocator.dupeZ(u8, path);
    defer allocator.free(c_path);

    if (c.mkdir(c_path.ptr, 0o755) == 0) return;

    // Check errno via C function
    const err = std.c._errno().*;
    if (err == @intFromEnum(std.c.E.EXIST)) return;

    if (err == @intFromEnum(std.c.E.NOENT)) {
        if (std.fs.path.dirname(path)) |parent| {
            if (parent.len > 0 and !std.mem.eql(u8, parent, "/")) {
                try mkdirRecursive(allocator, parent);
                if (c.mkdir(c_path.ptr, 0o755) == 0) return;
                if (std.c._errno().* == @intFromEnum(std.c.E.EXIST)) return;
            }
        }
    }

    return error.MkdirFailed;
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
