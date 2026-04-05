const std = @import("std");
const cli = @import("cli/root.zig");
const utils = @import("utils/root.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize global IoManager (no-op on Zig 0.15)
    try utils.initIoManager(allocator);
    defer utils.deinitIoManager();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    try cli.run(allocator, args);
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
