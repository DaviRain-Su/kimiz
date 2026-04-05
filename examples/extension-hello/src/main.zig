//! Example WASM Extension for Kimiz
//! Demonstrates host function usage

// External host functions provided by Kimiz
extern fn log(ptr: [*]const u8, len: usize) i64;
extern fn getTimeMs() i64;
extern fn readFile(path_ptr: [*]const u8, path_len: usize, out_ptr: [*]u8, out_max: usize) i64;
extern fn writeFile(path_ptr: [*]const u8, path_len: usize, content_ptr: [*]const u8, content_len: usize) i64;
extern fn getEnv(key_ptr: [*]const u8, key_len: usize, out_ptr: [*]u8, out_max: usize) i64;

/// Helper to log a message
fn logMessage(msg: []const u8) void {
    _ = log(msg.ptr, msg.len);
}

/// Extension initialization
export fn init() i32 {
    logMessage("Hello Extension initialized!");
    return 0; // Success
}

/// Add two numbers
export fn add(a: i64, b: i64) i64 {
    const result = a + b;
    
    // Format message (simplified)
    var buf: [256]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Adding {d} + {d} = {d}", .{ a, b, result }) catch "Error formatting";
    logMessage(msg);
    
    return result;
}

/// Get current time
export fn getTime() i64 {
    return getTimeMs();
}

/// Read file and log content
export fn readAndLog(path_ptr: [*]const u8, path_len: usize) i64 {
    var buffer: [1024]u8 = undefined;
    
    const bytes_read = readFile(path_ptr, path_len, &buffer, buffer.len);
    
    if (bytes_read > 0) {
        const content = buffer[0..@intCast(bytes_read)];
        
        var msg_buf: [1280]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "Read file content: {s}", .{content}) catch "Error formatting";
        logMessage(msg);
        
        return bytes_read;
    } else {
        logMessage("Failed to read file");
        return -1;
    }
}

/// Write content to file
export fn writeContent(path_ptr: [*]const u8, path_len: usize, content_ptr: [*]const u8, content_len: usize) i64 {
    return writeFile(path_ptr, path_len, content_ptr, content_len);
}

/// Get environment variable
export fn getEnvValue(key_ptr: [*]const u8, key_len: usize, out_ptr: [*]u8, out_max: usize) i64 {
    return getEnv(key_ptr, key_len, out_ptr, out_max);
}

/// Extension cleanup
export fn deinit() void {
    logMessage("Hello Extension shutting down...");
}

const std = @import("std");
