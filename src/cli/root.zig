//! kimiz-cli - Command line interface (Zig 0.16 compatible)

const std = @import("std");
const core = @import("../core/root.zig");
const ai = @import("../ai/root.zig");
const agent = @import("../agent/root.zig");

// Use linux syscalls directly
const STDOUT_FILENO = 1;
const STDIN_FILENO = 0;

fn sysWrite(fd: usize, buf: []const u8) usize {
    return std.os.linux.syscall3(.write, fd, @intFromPtr(buf.ptr), buf.len);
}

fn sysRead(fd: usize, buf: []u8) usize {
    return std.os.linux.syscall3(.read, fd, @intFromPtr(buf.ptr), buf.len);
}

pub fn run(allocator: std.mem.Allocator) !void {
    _ = allocator;
    
    const welcome = "kimiz v0.1.0 - AI Coding Agent\nType 'exit' or 'quit' to exit.\n\n";
    _ = sysWrite(STDOUT_FILENO, welcome);

    var buf: [1024]u8 = undefined;
    
    while (true) {
        _ = sysWrite(STDOUT_FILENO, "> ");
        
        const n = sysRead(STDIN_FILENO, &buf);
        if (n == 0 or n > buf.len) break;
        
        // Find newline
        var len: usize = 0;
        while (len < n and buf[len] != '\n') : (len += 1) {}
        
        const input = std.mem.trim(u8, buf[0..len], " \t\r\n");
        if (input.len == 0) continue;
        if (std.mem.eql(u8, input, "exit") or std.mem.eql(u8, input, "quit")) break;

        _ = sysWrite(STDOUT_FILENO, "Processing: ");
        _ = sysWrite(STDOUT_FILENO, input);
        _ = sysWrite(STDOUT_FILENO, "\n(Full integration coming soon)\n\n");
    }

    _ = sysWrite(STDOUT_FILENO, "Goodbye!\n");
}
