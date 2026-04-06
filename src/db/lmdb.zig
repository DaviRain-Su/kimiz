//! LMDB Storage Wrapper (TASK-INFRA-001)
//! Provides a simple key-value store interface backed by LMDB

const std = @import("std");
const lmdb = @import("lmdb");

pub const LMDBStore = struct {
    allocator: std.mem.Allocator,
    env: lmdb.Environment,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, path: [:0]const u8) !Self {
        const env = try lmdb.Environment.init(path, .{
            .map_size = 100 * 1024 * 1024, // 100MB
            .max_dbs = 10,
        });
        return .{
            .allocator = allocator,
            .env = env,
        };
    }

    pub fn deinit(self: *Self) void {
        self.env.deinit();
    }

    pub fn put(self: *Self, key: []const u8, value: []const u8) !void {
        const txn = try lmdb.Transaction.init(self.env, .{ .mode = .ReadWrite });
        errdefer txn.abort();
        try txn.set(key, value);
        try txn.commit();
    }

    pub fn get(self: *Self, allocator: std.mem.Allocator, key: []const u8) !?[]const u8 {
        const txn = try lmdb.Transaction.init(self.env, .{ .mode = .ReadOnly });
        defer txn.abort(); // Read-only transactions don't need commit
        if (try txn.get(key)) |val| {
            return try allocator.dupe(u8, val);
        }
        return null;
    }

    pub fn del(self: *Self, key: []const u8) !void {
        const txn = try lmdb.Transaction.init(self.env, .{ .mode = .ReadWrite });
        errdefer txn.abort();
        try txn.delete(key);
        try txn.commit();
    }
};

test "LMDBStore basic operations" {
    const dir = std.testing.tmpDir(.{});
    defer dir.cleanup();

    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrintZ(&path_buf, "{s}/testdb", .{dir.cwd.path});

    var store = try LMDBStore.init(std.testing.allocator, path);
    defer store.deinit();

    // Put
    try store.put("key1", "value1");
    try store.put("key2", "value2");

    // Get
    const val1 = try store.get(std.testing.allocator, "key1");
    try std.testing.expect(val1 != null);
    try std.testing.expectEqualStrings("value1", val1.?);
    defer std.testing.allocator.free(val1.?);

    const val2 = try store.get(std.testing.allocator, "key2");
    try std.testing.expect(val2 != null);
    try std.testing.expectEqualStrings("value2", val2.?);
    defer std.testing.allocator.free(val2.?);

    // Get non-existent
    const val3 = try store.get(std.testing.allocator, "nonexistent");
    try std.testing.expect(val3 == null);

    // Delete
    try store.del("key1");
    const val4 = try store.get(std.testing.allocator, "key1");
    try std.testing.expect(val4 == null);
}
