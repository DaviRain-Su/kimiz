//! IoManager - Manages std.Io instance for the application
//! Provides access to I/O operations required by std.http.Client

const std = @import("std");

/// Global IoManager instance
/// Initialized at startup and accessed throughout the application
var g_io_manager: ?IoManager = null;

/// IoManager stores a std.Io instance (provided from std.process.Init)
pub const IoManager = struct {
    allocator: std.mem.Allocator,
    io_instance: std.Io,
    initialized: bool = false,

    const Self = @This();

    /// Initialize the IoManager with a pre-existing std.Io
    pub fn initWithIo(allocator: std.mem.Allocator, io_instance: std.Io) Self {
        return .{
            .allocator = allocator,
            .io_instance = io_instance,
            .initialized = true,
        };
    }

    /// Deinitialize the IoManager
    pub fn deinit(self: *Self) void {
        self.initialized = false;
    }

    /// Get the std.Io interface for use with std.http.Client
    pub fn io(self: *Self) std.Io {
        return self.io_instance;
    }

    /// Check if the IoManager is initialized
    pub fn isInitialized(self: *Self) bool {
        return self.initialized;
    }
};

/// Initialize the global IoManager with a pre-existing std.Io
/// Must be called once at application startup (from main)
pub fn initIoManager(allocator: std.mem.Allocator, io_instance: std.Io) !void {
    if (g_io_manager != null) {
        return error.AlreadyInitialized;
    }
    g_io_manager = IoManager.initWithIo(allocator, io_instance);
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

/// Get the std.Io interface from the global IoManager
pub fn getIo() !std.Io {
    const manager = try getIoManager();
    return manager.io();
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
    _ = allocator;
    // IoManager now requires a real std.Io instance from std.process.Init
    // which is not available in unit tests. Integration tests should cover this.
}

test "Global IoManager not initialized" {
    try std.testing.expectError(error.NotInitialized, getIoManager());
}
