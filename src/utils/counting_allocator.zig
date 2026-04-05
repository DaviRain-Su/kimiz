//! Counting Allocator - Track memory allocations and detect leaks
//! Based on TigerBeetle's CountingAllocator pattern

const std = @import("std");

pub const CountingAllocator = struct {
    parent_allocator: std.mem.Allocator,
    alloc_count: usize = 0,
    free_count: usize = 0,
    alloc_size: usize = 0,
    free_size: usize = 0,

    const Self = @This();

    pub fn init(parent: std.mem.Allocator) Self {
        return .{
            .parent_allocator = parent,
        };
    }

    pub fn allocator(self: *Self) std.mem.Allocator {
        std.debug.assert(self.allocations >= self.frees); // Invariant: never more frees than allocations
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
            },
        };
    }

    pub fn liveSize(self: *const Self) usize {
        std.debug.assert(self.alloc_size >= self.free_size or self.free_size == 0); // Cannot free more than allocated
        const live = self.alloc_size -| self.free_size;
        std.debug.assert(live == 0 or self.liveCount() > 0); // If bytes live, must have live allocations
        return live;
    }

    pub fn liveCount(self: *const Self) usize {
        std.debug.assert(self.alloc_count >= self.free_count or self.free_count == 0); // Cannot free more than allocated
        return self.alloc_count -| self.free_count;
    }

    pub fn reset(self: *Self) void {
        // Post-condition: all counters zero after reset
        defer {
            std.debug.assert(self.alloc_count == 0);
            std.debug.assert(self.free_count == 0);
            std.debug.assert(self.alloc_size == 0);
            std.debug.assert(self.free_size == 0);
        }
        
        self.alloc_count = 0;
        self.free_count = 0;
        self.alloc_size = 0;
        self.free_size = 0;
    }

    fn alloc(
        ctx: *anyopaque,
        len: usize,
        ptr_align: u8,
        ret_addr: usize,
    ) ?[*]u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));
        std.debug.assert(len > 0); // Must allocate non-zero bytes
        
        const prev_count = self.alloc_count;
        const prev_size = self.alloc_size;
        
        const result = self.parent_allocator.rawAlloc(len, ptr_align, ret_addr);
        if (result != null) {
            self.alloc_count += 1;
            self.alloc_size += len;
            
            // Post-conditions
            std.debug.assert(self.alloc_count == prev_count + 1);
            std.debug.assert(self.alloc_size == prev_size + len);
        }
        
        return result;
    }

    fn resize(
        ctx: *anyopaque,
        buf: []u8,
        buf_align: u8,
        new_len: usize,
        ret_addr: usize,
    ) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));
        std.debug.assert(buf.len > 0); // Buffer must be non-empty
        
        const old_len = buf.len;
        const prev_alloc_size = self.alloc_size;
        const prev_free_size = self.free_size;
        
        const result = self.parent_allocator.rawResize(buf, buf_align, new_len, ret_addr);
        if (result) {
            if (new_len > old_len) {
                const growth = new_len - old_len;
                self.alloc_size += growth;
                std.debug.assert(self.alloc_size == prev_alloc_size + growth);
            } else if (new_len < old_len) {
                const shrink = old_len - new_len;
                self.free_size += shrink;
                std.debug.assert(self.free_size == prev_free_size + shrink);
            }
            // new_len == old_len: no change
        }
        
        return result;
    }

    fn free(
        ctx: *anyopaque,
        buf: []u8,
        buf_align: u8,
        ret_addr: usize,
    ) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        std.debug.assert(buf.len > 0); // Must free non-zero bytes
        std.debug.assert(self.alloc_count > self.free_count or self.free_count == 0); // Must have live allocations
        
        const prev_count = self.free_count;
        const prev_size = self.free_size;
        
        self.free_count += 1;
        self.free_size += buf.len;
        
        // Post-conditions
        std.debug.assert(self.free_count == prev_count + 1);
        std.debug.assert(self.free_size == prev_size + buf.len);
        std.debug.assert(self.free_count <= self.alloc_count); // Never more frees than allocs
        
        self.parent_allocator.rawFree(buf, buf_align, ret_addr);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "CountingAllocator basic operations" {
    var counting = CountingAllocator.init(std.testing.allocator);
    const allocator = counting.allocator();

    // No allocations yet
    try std.testing.expectEqual(@as(usize, 0), counting.liveSize());
    try std.testing.expectEqual(@as(usize, 0), counting.liveCount());

    // Allocate 100 bytes
    const buf1 = try allocator.alloc(u8, 100);
    try std.testing.expectEqual(@as(usize, 1), counting.alloc_count);
    try std.testing.expectEqual(@as(usize, 100), counting.alloc_size);
    try std.testing.expectEqual(@as(usize, 100), counting.liveSize());

    // Allocate 200 bytes more
    const buf2 = try allocator.alloc(u8, 200);
    try std.testing.expectEqual(@as(usize, 2), counting.alloc_count);
    try std.testing.expectEqual(@as(usize, 300), counting.alloc_size);
    try std.testing.expectEqual(@as(usize, 300), counting.liveSize());

    // Free first buffer
    allocator.free(buf1);
    try std.testing.expectEqual(@as(usize, 1), counting.free_count);
    try std.testing.expectEqual(@as(usize, 100), counting.free_size);
    try std.testing.expectEqual(@as(usize, 200), counting.liveSize());

    // Free second buffer
    allocator.free(buf2);
    try std.testing.expectEqual(@as(usize, 2), counting.free_count);
    try std.testing.expectEqual(@as(usize, 300), counting.free_size);
    try std.testing.expectEqual(@as(usize, 0), counting.liveSize());
}

test "CountingAllocator detects leaks" {
    var counting = CountingAllocator.init(std.testing.allocator);
    const allocator = counting.allocator();

    // Allocate but don't free
    _ = try allocator.alloc(u8, 50);
    
    // Should show a leak
    try std.testing.expect(counting.liveSize() > 0);
    try std.testing.expectEqual(@as(usize, 1), counting.liveCount());
    
    // Reset counters (but memory is still allocated, this is just for testing)
    counting.reset();
    try std.testing.expectEqual(@as(usize, 0), counting.liveSize());
}
