const std = @import("std");
const cli = @import("cli/root.zig");
const utils = @import("utils/root.zig");

pub fn main(init: std.process.Init) !u8 {
    const allocator = init.gpa;

    // Initialize global IoManager with the Io from process Init
    try utils.initIoManager(allocator, init.io);
    defer utils.deinitIoManager();

    try cli.run(allocator, init.environ_map, init.minimal.args);
    return 0;
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
