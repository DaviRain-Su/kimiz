//! Worktree Memory Leak Test
//! Verifies that WorktreeManager doesn't leak memory

const std = @import("std");
const utils = @import("utils");
const CountingAllocator = utils.counting_allocator.CountingAllocator;
const WorktreeManager = utils.worktree.WorktreeManager;

test "WorktreeManager no memory leaks on operations" {
    var counting = CountingAllocator.init(std.testing.allocator);
    const allocator = counting.allocator();

    // Initialize WorktreeManager
    var wtm = try WorktreeManager.init(allocator, "/tmp/test-repo");
    defer wtm.deinit();

    const initial_live = counting.liveSize();

    // Perform multiple operations
    for (0..10) |i| {
        const name = try wtm.generateName("test");
        defer allocator.free(name);
        
        _ = i;
        // Don't actually create worktrees in test, just generate names
    }

    // After operations, should not have accumulated leaks
    // (only the initial WorktreeManager structures remain)
    const final_live = counting.liveSize();
    
    // The live memory should be stable (only the manager itself)
    try std.testing.expect(final_live >= initial_live);
    
    // The difference should be minimal (no accumulated leaks from operations)
    const leaked = final_live - initial_live;
    try std.testing.expect(leaked == 0); // No leaks from operations
}

test "WorktreeManager arena cleanup" {
    var counting = CountingAllocator.init(std.testing.allocator);
    const allocator = counting.allocator();

    {
        var wtm = try WorktreeManager.init(allocator, "/tmp/test-repo-arena");
        defer wtm.deinit();

        // Simulate execShell-like operations that use arena
        const base_dir = try wtm.getWorktreeBaseDir();
        _ = base_dir; // arena-allocated, will be freed on deinit

        const name1 = try wtm.generateName("subagent");
        defer allocator.free(name1);

        const name2 = try wtm.generateName("subagent");
        defer allocator.free(name2);
    }

    // After deinit, only the generateName strings should remain
    // (they use self.allocator, not arena)
    const leaked = counting.liveSize();
    try std.testing.expectEqual(@as(usize, 0), leaked);
}
