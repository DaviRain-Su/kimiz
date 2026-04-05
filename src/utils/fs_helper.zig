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
/// Convenience wrapper around Io.Dir operations
pub fn readFileAlloc(
    allocator: std.mem.Allocator,
    path: []const u8,
    max_size: usize,
) ![]u8 {
    const io = try getIo();
    const dir = cwd();
    
    // Open the file
    const file = try dir.openFile(&io.interface, path, .{});
    defer file.close(&io.interface);
    
    // Get file size
    const stat = try file.stat(&io.interface);
    const size = @min(stat.size, max_size);
    
    // Allocate buffer
    const content = try allocator.alloc(u8, size);
    errdefer allocator.free(content);
    
    // Read file content
    var reader = file.reader(&io.interface, content);
    const read_size = try reader.interface.readAll(content);
    
    if (read_size < size) {
        // Shrink allocation if we read less than expected
        const resized = try allocator.realloc(content, read_size);
        return resized;
    }
    
    return content;
}

/// Write contents to file
pub fn writeFile(
    path: []const u8,
    contents: []const u8,
) !void {
    const io = try getIo();
    const dir = cwd();
    
    const file = try dir.createFile(&io.interface, path, .{});
    defer file.close(&io.interface);
    
    var writer = file.writer(&io.interface, contents);
    try writer.interface.writeAll(contents);
    try writer.flush();
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
    try dir.makeDir(&io.interface, path);
}

/// Create directory and all parent directories
pub fn makeDirRecursive(path: []const u8) !void {
    const io = try getIo();
    const dir = cwd();
    try dir.makePath(&io.interface, path);
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
