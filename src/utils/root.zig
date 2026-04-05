//! kimiz-utils - Utility modules
//! Provides helper functions and compatibility layers

const std = @import("std");

// Re-export utility modules
pub const io = @import("io_helper.zig");
pub const fs = @import("fs_helper.zig");
pub const log = @import("log.zig");
pub const config = @import("config.zig");
pub const session = @import("session.zig");
pub const io_manager = @import("io_manager.zig");

// Re-export IoManager
pub const IoManager = io_manager.IoManager;
pub const getIoManager = io_manager.getIoManager;
pub const getIo = io_manager.getIo;
pub const initIoManager = io_manager.initIoManager;
pub const deinitIoManager = io_manager.deinitIoManager;

// Compatibility re-exports for easier migration
pub const cwd = fs.cwd;
pub const readFileAlloc = fs.readFileAlloc;
pub const writeFile = fs.writeFile;
pub const fileExists = fs.fileExists;
pub const makeDir = fs.makeDir;
pub const makeDirRecursive = fs.makeDirRecursive;
pub const rename = fs.rename;
pub const deleteFile = fs.deleteFile;
pub const realpath = fs.realpath;

// Time compatibility functions using C library
const c = @cImport({
    @cInclude("time.h");
});

/// Get current timestamp in milliseconds
pub fn milliTimestamp() i64 {
    var ts: c.struct_timespec = undefined;
    if (c.clock_gettime(c.CLOCK_REALTIME, &ts) != 0) {
        return 0;
    }
    return @as(i64, ts.tv_sec) * 1000 + @divFloor(@as(i64, ts.tv_nsec), 1_000_000);
}

/// Get current timestamp in seconds
pub fn timestamp() i64 {
    var ts: c.struct_timespec = undefined;
    if (c.clock_gettime(c.CLOCK_REALTIME, &ts) != 0) {
        return 0;
    }
    return ts.tv_sec;
}
