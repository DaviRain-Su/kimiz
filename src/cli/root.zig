//! kimiz-cli - Command line interface (Zig 0.16 compatible)

const std = @import("std");
const core = @import("../core/root.zig");
const ai = @import("../ai/root.zig");
const agent = @import("../agent/root.zig");
const extension = @import("../extension/root.zig");

// Use linux syscalls directly
const STDOUT_FILENO = 1;
const STDIN_FILENO = 0;

fn sysWrite(fd: usize, buf: []const u8) usize {
    return std.os.linux.syscall3(.write, fd, @intFromPtr(buf.ptr), buf.len);
}

fn sysRead(fd: usize, buf: []u8) usize {
    return std.os.linux.syscall3(.read, fd, @intFromPtr(buf.ptr), buf.len);
}

fn print(msg: []const u8) void {
    _ = sysWrite(STDOUT_FILENO, msg);
}

pub fn run(allocator: std.mem.Allocator) !void {
    _ = allocator;
    
    // Interactive mode only for now
    // TODO: Parse args when Zig 0.16 API stabilizes
    try runInteractive();
}

fn runInteractive() !void {
    const welcome = "kimiz v0.2.0 - AI Coding Agent with Extension System\nType 'exit' or 'quit' to exit.\n\n";
    print(welcome);

    var buf: [1024]u8 = undefined;
    
    while (true) {
        print("> ");
        
        const n = sysRead(STDIN_FILENO, &buf);
        if (n == 0 or n > buf.len) break;
        
        // Find newline
        var len: usize = 0;
        while (len < n and buf[len] != '\n') : (len += 1) {}
        
        const input = std.mem.trim(u8, buf[0..len], " \t\r\n");
        if (input.len == 0) continue;
        if (std.mem.eql(u8, input, "exit") or std.mem.eql(u8, input, "quit")) break;
        
        if (std.mem.eql(u8, input, "help")) {
            printHelp();
            continue;
        }
        
        print("Processing: ");
        print(input);
        print("\n(Full AI integration coming soon)\n\n");
    }

    print("Goodbye!\n");
}

fn printHelp() void {
    print("kimiz - AI Coding Agent with Extension System\n");
    print("\n");
    print("Commands:\n");
    print("  help    Show this help\n");
    print("  exit    Exit the program\n");
    print("\n");
    print("Extension commands (coming soon):\n");
    print("  ext list     List installed extensions\n");
    print("  ext add      Install extension\n");
    print("  ext remove   Remove extension\n");
    print("\n");
}
