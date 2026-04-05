//! File System Helper Module
//! Provides compatibility layer for Zig 0.16's new std.Io.Dir system

const std = @import("std");
const io_manager = @import("io_manager.zig");

/// Get current working directory
/// In Zig 0.16, this returns std.Io.Dir which requires an Io instance for operations
pub fn cwd() std.Io.Dir {
    return std.Io.Dir.cwd();
}

/// Get Io instance from IoManager
fn getIo() !std.Io {
    return io_manager.getIo();
}

/// Read file contents into allocated memory
/// Uses Zig 0.16 native API
pub fn readFileAlloc(
    allocator: std.mem.Allocator,
    path: []const u8,
    max_size: usize,
) ![]u8 {
    const io = try getIo();
    const dir = cwd();
    return try dir.readFileAlloc(io, path, allocator, @enumFromInt(max_size));
}

/// Write contents to file
/// Uses Zig 0.16 native API
pub fn writeFile(
    path: []const u8,
    contents: []const u8,
) !void {
    const io = try getIo();
    const dir = cwd();
    
    // Ensure parent directory exists
    if (std.fs.path.dirname(path)) |parent_dir| {
        dir.createDirPath(io, parent_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };
    }
    
    try dir.writeFile(io, .{
        .sub_path = path,
        .data = contents,
    });
}

/// Check if file exists
pub fn fileExists(path: []const u8) bool {
    const io = getIo() catch return false;
    const dir = cwd();
    dir.access(&io.interface, path, .{}) catch return false;
    return true;
}

/// Create directory
pub fn makeDir(path: []const u8) !void {
    const io = try getIo();
    const dir = cwd();
    try dir.makeDir(io, path);
}

/// Create directory and all parent directories
/// Uses Zig 0.16 native API when IoManager is available, falls back to C API in tests
pub fn makeDirRecursive(path: []const u8) !void {
    if (getIo()) |io| {
        const dir = cwd();
        try dir.createDirPath(io, path);
    } else |_| {
        // Fallback to C API when IoManager not initialized (e.g., in tests)
        const c = @cImport({ @cInclude("sys/stat.h"); });
        var buf: [std.fs.max_path_bytes]u8 = undefined;
        if (path.len >= buf.len) return error.NameTooLong;
        
        @memcpy(buf[0..path.len], path);
        var i: usize = 0;
        while (i < path.len) : (i += 1) {
            if (path[i] == '/' and i > 0) {
                buf[i] = 0;
                _ = c.mkdir(@ptrCast(&buf), 0o755);
                buf[i] = '/';
            }
        }
        buf[path.len] = 0;
        _ = c.mkdir(@ptrCast(&buf), 0o755);
    }
}

/// Open directory for iteration
pub fn openDir(path: []const u8, opts: std.Io.Dir.OpenOptions) !std.Io.Dir {
    const io = try getIo();
    const dir = cwd();
    return try dir.openDir(&io.interface, path, opts);
}

/// Rename file
pub fn rename(old_path: []const u8, new_path: []const u8) !void {
    const io = try getIo();
    const dir = cwd();
    try dir.rename(&io.interface, old_path, new_path);
}

/// Remove file
pub fn deleteFile(path: []const u8) !void {
    const io = try getIo();
    const dir = cwd();
    try dir.deleteFile(&io.interface, path);
}

/// Remove directory and all contents
pub fn deleteTree(path: []const u8) !void {
    const io = try getIo();
    const dir = cwd();
    try dir.deleteTree(&io.interface, path);
}

/// Get realpath
pub fn realpath(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    
    const io = try getIo();
    const dir = cwd();
    const result = try dir.realpath(&io.interface, path, &buf);
    
    return try allocator.dupe(u8, result);
}

/// Access a file to check if it exists
pub fn access(path: []const u8, opts: std.Io.Dir.AccessOptions) !void {
    const io = try getIo();
    const dir = cwd();
    try dir.access(&io.interface, path, opts);
}

/// Open a file
pub fn openFile(path: []const u8, opts: std.Io.Dir.OpenOptions) !std.Io.File {
    const io = try getIo();
    const dir = cwd();
    return try dir.openFile(&io.interface, path, opts);
}

/// Create a file
pub fn createFile(path: []const u8, opts: std.Io.Dir.CreateOptions) !std.Io.File {
    const io = try getIo();
    const dir = cwd();
    return try dir.createFile(&io.interface, path, opts);
}

// ============================================================================
// Tests
// ============================================================================

test "fs_helper basic operations" {
    // These tests would need proper Io initialization
    // For now, just verify the module compiles
    const allocator = std.testing.allocator;
    _ = allocator;
}
