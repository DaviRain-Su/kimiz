//! File I/O helpers using C stdlib for Zig 0.16 compatibility

const std = @import("std");

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    @cInclude("string.h");
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
    const c_path = try allocator.dupeZ(u8, path);
    defer allocator.free(c_path);

    const fp = c.fopen(c_path.ptr, "wb") orelse return error.FileNotFound;
    defer _ = c.fclose(fp);

    const n = c.fwrite(data.ptr, 1, data.len, fp);
    if (n < data.len) return error.WriteError;
}
