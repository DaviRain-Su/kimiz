//! IoManager - Manages std.Io.IoUring instance for the application
//! Provides access to async I/O operations required by std.http.Client

const std = @import("std");

/// Global IoManager instance
/// Initialized at startup and accessed throughout the application
var g_io_manager: ?IoManager = null;
var g_io_manager_mutex: std.Thread.Mutex = .{};

/// IoManager manages the lifecycle of std.Io.IoUring
pub const IoManager = struct {
    allocator: std.mem.Allocator,
    io_uring: std.Io.IoUring,
    initialized: bool = false,

    const Self = @This();

    /// Initialize the IoManager with the given allocator
    /// This must be called before any I/O operations
    pub fn init(allocator: std.mem.Allocator) !Self {
        var io_uring: std.Io.IoUring = undefined;
        try io_uring.init(allocator);

        return .{
            .allocator = allocator,
            .io_uring = io_uring,
            .initialized = true,
        };
    }

    /// Deinitialize the IoManager and free resources
    pub fn deinit(self: *Self) void {
        if (self.initialized) {
            self.io_uring.deinit();
            self.initialized = false;
        }
    }

    /// Get the std.Io interface for use with std.http.Client
    pub fn io(self: *Self) std.Io {
        return self.io_uring.io();
    }

    /// Check if the IoManager is initialized
    pub fn isInitialized(self: *Self) bool {
        return self.initialized;
    }
};

/// Initialize the global IoManager instance
/// Must be called once at application startup
pub fn initIoManager(allocator: std.mem.Allocator) !void {
    g_io_manager_mutex.lock();
    defer g_io_manager_mutex.unlock();

    if (g_io_manager != null) {
        return error.AlreadyInitialized;
    }

    var manager = try IoManager.init(allocator);
    errdefer manager.deinit();

    // Store in global variable
    g_io_manager = manager;
}

/// Deinitialize the global IoManager instance
/// Should be called at application shutdown
pub fn deinitIoManager() void {
    g_io_manager_mutex.lock();
    defer g_io_manager_mutex.unlock();

    if (g_io_manager) |*manager| {
        manager.deinit();
        g_io_manager = null;
    }
}

/// Get the global IoManager instance
/// Returns error if not initialized
pub fn getIoManager() !*IoManager {
    g_io_manager_mutex.lock();
    defer g_io_manager_mutex.unlock();

    if (g_io_manager) |*manager| {
        return manager;
    }
    return error.NotInitialized;
}

/// Get the std.Io interface from the global IoManager
/// Convenience function for direct I/O access
pub fn getIo() !std.Io {
    const manager = try getIoManager();
    return manager.io();
}

/// Check if the global IoManager is initialized
pub fn isIoManagerInitialized() bool {
    g_io_manager_mutex.lock();
    defer g_io_manager_mutex.unlock();

    if (g_io_manager) |manager| {
        return manager.isInitialized();
    }
    return false;
}

// ============================================================================
// Tests
// ============================================================================

test "IoManager init/deinit" {
    const allocator = std.testing.allocator;

    var manager = try IoManager.init(allocator);
    defer manager.deinit();

    try std.testing.expect(manager.isInitialized());
}

test "IoManager io interface" {
    const allocator = std.testing.allocator;

    var manager = try IoManager.init(allocator);
    defer manager.deinit();

    const io = manager.io();
    _ = io; // Verify we can get the io interface
}

test "Global IoManager" {
    const allocator = std.testing.allocator;

    // Should fail if not initialized
    try std.testing.expectError(error.NotInitialized, getIoManager());

    // Initialize
    try initIoManager(allocator);
    defer deinitIoManager();

    // Should succeed now
    const manager = try getIoManager();
    try std.testing.expect(manager.isInitialized());

    // Should fail if already initialized
    try std.testing.expectError(error.AlreadyInitialized, initIoManager(allocator));
}
