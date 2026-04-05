const std = @import("std");

// We need to use the kimiz module directly
const extension = @import("src/extension/root.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Kimiz Extension Loader Test ===\n\n", .{});

    // Test 1: Create loader
    std.debug.print("Test 1: Create ExtensionLoader\n", .{});
    var loader = try extension.ExtensionLoader.init(allocator, ".");
    defer loader.deinit();
    std.debug.print("  ✓ Created loader\n", .{});

    // Test 2: Load example extension
    std.debug.print("\nTest 2: Load example extension\n", .{});
    const wasm_path = "examples/extension-hello/zig-out/bin/extension-hello.wasm";
    
    loader.loadFromFile("hello", wasm_path) catch |err| {
        std.debug.print("  ! Failed to load extension: {s}\n", .{@errorName(err)});
        std.debug.print("  ! Make sure to build the example first:\n", .{});
        std.debug.print("    cd examples/extension-hello && zig build\n", .{});
        return;
    };
    std.debug.print("  ✓ Loaded extension 'hello'\n", .{});

    // Test 3: Call init function
    std.debug.print("\nTest 3: Call init function\n", .{});
    const init_result = try loader.call("hello", "init", &[_]u64{});
    std.debug.print("  ✓ init() returned: {d}\n", .{init_result});

    // Test 4: Call add function
    std.debug.print("\nTest 4: Call add function\n", .{});
    const add_result = try loader.call("hello", "add", &[_]u64{ 5, 3 });
    std.debug.print("  ✓ add(5, 3) = {d}\n", .{add_result});

    // Test 5: Call getTime function
    std.debug.print("\nTest 5: Call getTime function\n", .{});
    const time_result = try loader.call("hello", "getTime", &[_]u64{});
    std.debug.print("  ✓ getTime() = {d} ms\n", .{time_result});

    // Test 6: List loaded extensions
    std.debug.print("\nTest 6: List loaded extensions\n", .{});
    const ext_list = try loader.list();
    defer allocator.free(ext_list);
    std.debug.print("  ✓ Loaded {d} extension(s):\n", .{ext_list.len});
    for (ext_list) |ext_id| {
        std.debug.print("    - {s}\n", .{ext_id});
    }

    // Test 7: Unload extension
    std.debug.print("\nTest 7: Unload extension\n", .{});
    try loader.unload("hello");
    std.debug.print("  ✓ Unloaded extension 'hello'\n", .{});

    std.debug.print("\n=== All Tests Passed! ===\n", .{});
}
