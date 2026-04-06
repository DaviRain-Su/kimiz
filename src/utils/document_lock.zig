//! Document Lock - File-level locking for multi-agent document writes
//! T-123: Lessons learned and multi-agent consistency
//! Uses .lock files with timeout-based polling

const std = @import("std");
const utils = @import("root.zig");

pub const DocumentLock = struct {
    /// Acquire a document lock by creating a .lock file.
    /// Polls with exponential backoff until timeout.
    pub fn acquire(path: []const u8, timeout_ms: u32) !void {
        const lock_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}.lock", .{path});
        defer std.heap.page_allocator.free(lock_path);

        var delay_ms: u32 = 10;
        var elapsed: u32 = 0;

        while (true) {
            // Try to create lock file
            const file = utils.createFile(lock_path, .{}) catch |err| switch (err) {
                error.PathAlreadyExists => {
                    // Lock exists, check if it's stale (>30s old)
                    if (elapsed > 30_000) {
                        // Force remove stale lock
                        utils.deleteFile(lock_path) catch {};
                        continue;
                    }
                    if (elapsed >= timeout_ms) return error.LockTimeout;
                    std.time.sleep(@as(u64, @intCast(delay_ms)) * 1_000_000);
                    elapsed += delay_ms;
                    delay_ms = @min(delay_ms * 2, 500);
                    continue;
                },
                else => return err,
            };
            file.close();
            return;
        }
    }

    /// Release a document lock by removing the .lock file.
    pub fn release(path: []const u8) void {
        const lock_path = std.fmt.allocPrint(std.heap.page_allocator, "{s}.lock", .{path}) catch return;
        defer std.heap.page_allocator.free(lock_path);
        utils.deleteFile(lock_path) catch {};
    }
};
