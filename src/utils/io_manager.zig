//! IoManager - No-op compatibility shim for Zig 0.15
//! std.Io was removed/replaced in Zig 0.16; on 0.15 std.http.Client
//! does not require an external Io instance.

const std = @import("std");

/// Global IoManager instance
var g_io_manager: ?IoManager = null;

/// IoManager is a no-op placeholder on Zig 0.15
pub const IoManager = struct {
    allocator: std.mem.Allocator,
    initialized: bool = false,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .initialized = true,
        };
    }

    pub fn deinit(self: *Self) void {
        self.initialized = false;
    }

    pub fn isInitialized(self: *Self) bool {
        return self.initialized;
    }
};

/// Initialize the global IoManager (no-op on Zig 0.15)
pub fn initIoManager(allocator: std.mem.Allocator) !void {
    if (g_io_manager != null) {
        return error.AlreadyInitialized;
    }
    g_io_manager = IoManager.init(allocator);
}

/// Deinitialize the global IoManager instance
pub fn deinitIoManager() void {
    if (g_io_manager) |*manager| {
        manager.deinit();
        g_io_manager = null;
    }
}

/// Get the global IoManager instance
pub fn getIoManager() !*IoManager {
    if (g_io_manager) |*manager| {
        return manager;
    }
    return error.NotInitialized;
}

/// Check if the global IoManager is initialized
pub fn isIoManagerInitialized() bool {
    if (g_io_manager) |manager| {
        return manager.isInitialized();
    }
    return false;
}

// ============================================================================
// Tests
// ============================================================================

test "IoManager basic" {
    const allocator = std.testing.allocator;
    var manager = IoManager.init(allocator);
    try std.testing.expect(manager.isInitialized());
    manager.deinit();
    try std.testing.expect(!manager.isInitialized());
}

test "Global IoManager not initialized" {
    try std.testing.expectError(error.NotInitialized, getIoManager());
}
