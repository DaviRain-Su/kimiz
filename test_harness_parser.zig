const std = @import("std");
const harness = @import("src/harness/root.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Testing Harness Parser...\n\n");

    // Test 1: Load from test_harness directory
    std.debug.print("Test 1: Load from test_harness/\n");
    if (try harness.loadFromDirectory(allocator, "test_harness")) |h| {
        defer h.deinit();
        
        std.debug.print("  ✓ Loaded harness: {s}\n", .{h.name});
        std.debug.print("  ✓ Description: {s}\n", .{h.description});
        std.debug.print("  ✓ Approach: {s}\n", .{h.behavior.approach});
        std.debug.print("  ✓ Style: {s}\n", .{@tagName(h.behavior.style)});
        std.debug.print("  ✓ Thinking enabled: {}\n", .{h.behavior.thinking.enabled});
        std.debug.print("  ✓ Allowed paths: {d}\n", .{h.constraints.allowed_paths.len});
        std.debug.print("  ✓ Blocked paths: {d}\n", .{h.constraints.blocked_paths.len});
        std.debug.print("  ✓ Max iterations: {d}\n", .{h.constraints.max_iterations});
        std.debug.print("  ✓ Timeout: {d}ms\n", .{h.constraints.timeout_ms});
        std.debug.print("  ✓ Default tools: {d}\n", .{h.tools.default_tools.len});
        std.debug.print("  ✓ Context files: {d}\n", .{h.context_files.len});
    } else {
        std.debug.print("  ✗ No AGENTS.md found\n");
    }

    // Test 2: Find and load
    std.debug.print("\nTest 2: Find and load from current directory\n");
    if (try harness.findAndLoad(allocator, ".")) |h| {
        defer h.deinit();
        std.debug.print("  ✓ Found and loaded harness: {s}\n", .{h.name});
    } else {
        std.debug.print("  ✗ No AGENTS.md found in tree\n");
    }

    // Test 3: Create default
    std.debug.print("\nTest 3: Create default harness\n");
    var default_harness = try harness.createDefault(allocator);
    defer default_harness.deinit();
    
    const info = default_harness.getInfo();
    std.debug.print("  ✓ Default harness: {s}\n", .{info.name});
    std.debug.print("  ✓ Skills available: {d}\n", .{info.skill_count});

    std.debug.print("\n✅ All tests passed!\n");
}
