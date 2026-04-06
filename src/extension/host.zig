//! Host Functions for WASM Extensions
//! Provides host capabilities to WASM extensions

const std = @import("std");
const utils = @import("../utils/root.zig");

/// Host function context
pub const HostContext = struct {
    allocator: std.mem.Allocator,
    extension_id: []const u8,
    working_dir: []const u8,
    
    /// Memory buffer for WASM <-> Host communication
    memory_buffer: []u8,
    
    pub fn init(allocator: std.mem.Allocator, extension_id: []const u8, working_dir: []const u8, buffer_size: usize) !HostContext {
        const buffer = try allocator.alloc(u8, buffer_size);
        return .{
            .allocator = allocator,
            .extension_id = extension_id,
            .working_dir = working_dir,
            .memory_buffer = buffer,
        };
    }
    
    pub fn deinit(self: *HostContext) void {
        self.allocator.free(self.memory_buffer);
    }
};

/// Host function table
pub const HostFunctionTable = struct {
    allocator: std.mem.Allocator,
    functions: std.StringHashMap(HostFunction),
    
    const Self = @This();
    
    pub const HostFunction = struct {
        name: []const u8,
        signature: FunctionSignature,
        handler: *const fn (ctx: *HostContext, args: []const u64) anyerror!u64,
    };
    
    pub const FunctionSignature = struct {
        param_count: u8,
        return_type: ValueType,
    };
    
    pub const ValueType = enum {
        i32,
        i64,
        void,
    };
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .functions = std.StringHashMap(HostFunction).init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        var iter = self.functions.valueIterator();
        while (iter.next()) |func| {
            self.allocator.free(func.name);
        }
        self.functions.deinit();
    }
    
    /// Register a host function
    pub fn register(
        self: *Self,
        name: []const u8,
        signature: FunctionSignature,
        handler: *const fn (ctx: *HostContext, args: []const u64) anyerror!u64,
    ) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);
        
        try self.functions.put(name_copy, .{
            .name = name_copy,
            .signature = signature,
            .handler = handler,
        });
    }
    
    /// Get a host function
    pub fn get(self: *Self, name: []const u8) ?HostFunction {
        return self.functions.get(name);
    }
    
    /// Call a host function
    pub fn call(
        self: *Self,
        ctx: *HostContext,
        name: []const u8,
        args: []const u64,
    ) !u64 {
        const func = self.get(name) orelse return error.HostFunctionNotFound;
        
        if (args.len != func.signature.param_count) {
            return error.InvalidArgumentCount;
        }
        
        return try func.handler(ctx, args);
    }
};

/// Standard host functions
pub const StandardHostFunctions = struct {
    /// Log a message
    pub fn log(ctx: *HostContext, args: []const u64) !u64 {
        // args[0] = ptr to message in WASM memory
        // args[1] = length of message
        const ptr = args[0];
        const len = args[1];
        
        if (ptr + len > ctx.memory_buffer.len) {
            return error.OutOfBounds;
        }
        
        const message = ctx.memory_buffer[ptr..ptr + len];
        std.debug.print("[{s}] {s}\n", .{ ctx.extension_id, message });
        
        return 0;
    }
    
    /// Read a file
    pub fn readFile(ctx: *HostContext, args: []const u64) !u64 {
        // args[0] = ptr to path in WASM memory
        // args[1] = length of path
        // args[2] = ptr to output buffer in WASM memory
        // args[3] = max size of output buffer
        const path_ptr = args[0];
        const path_len = args[1];
        const out_ptr = args[2];
        const out_max = args[3];
        
        if (path_ptr + path_len > ctx.memory_buffer.len or
            out_ptr + out_max > ctx.memory_buffer.len) {
            return error.OutOfBounds;
        }
        
        const path = ctx.memory_buffer[path_ptr..path_ptr + path_len];
        
        // Read file
        const content = utils.readFileAlloc(ctx.allocator, path, out_max) catch |err| {
            std.debug.print("Failed to read file '{s}': {s}\n", .{ path, @errorName(err) });
            return @intFromEnum(err);
        };
        defer ctx.allocator.free(content);
        
        const copy_len = @min(content.len, out_max);
        @memcpy(ctx.memory_buffer[out_ptr..out_ptr + copy_len], content[0..copy_len]);
        
        return copy_len;
    }
    
    /// Write a file
    pub fn writeFile(ctx: *HostContext, args: []const u64) !u64 {
        // args[0] = ptr to path in WASM memory
        // args[1] = length of path
        // args[2] = ptr to content in WASM memory
        // args[3] = length of content
        const path_ptr = args[0];
        const path_len = args[1];
        const content_ptr = args[2];
        const content_len = args[3];
        
        if (path_ptr + path_len > ctx.memory_buffer.len or
            content_ptr + content_len > ctx.memory_buffer.len) {
            return error.OutOfBounds;
        }
        
        const path = ctx.memory_buffer[path_ptr..path_ptr + path_len];
        const content = ctx.memory_buffer[content_ptr..content_ptr + content_len];
        
        // Write file
        utils.writeFile(path, content) catch |err| {
            std.debug.print("Failed to write file '{s}': {s}\n", .{ path, @errorName(err) });
            return @intFromEnum(err);
        };
        
        return 0;
    }
    
    /// Execute a command
    pub fn execCommand(ctx: *HostContext, args: []const u64) !u64 {
        // args[0] = ptr to command in WASM memory
        // args[1] = length of command
        const cmd_ptr = args[0];
        const cmd_len = args[1];
        
        if (cmd_ptr + cmd_len > ctx.memory_buffer.len) {
            return error.OutOfBounds;
        }
        
        const cmd = ctx.memory_buffer[cmd_ptr..cmd_ptr + cmd_len];
        std.debug.print("[{s}] Would execute: {s}\n", .{ ctx.extension_id, cmd });
        
        // TODO: Implement actual command execution with proper sandboxing
        return 0;
    }
    
    /// Get environment variable
    pub fn getEnv(ctx: *HostContext, args: []const u64) !u64 {
        // args[0] = ptr to key in WASM memory
        // args[1] = length of key
        // args[2] = ptr to output buffer
        // args[3] = max size of output buffer
        const key_ptr = args[0];
        const key_len = args[1];
        const out_ptr = args[2];
        const out_max = args[3];
        
        if (key_ptr + key_len > ctx.memory_buffer.len or
            out_ptr + out_max > ctx.memory_buffer.len) {
            return error.OutOfBounds;
        }
        
        const key = ctx.memory_buffer[key_ptr..key_ptr + key_len];
        
        // Get environment variable
        const value = std.process.getEnvVarOwned(ctx.allocator, key) catch |err| switch (err) {
            error.EnvironmentVariableNotFound => return 0,
            else => return err,
        };
        defer ctx.allocator.free(value);
        
        const copy_len = @min(value.len, out_max);
        @memcpy(ctx.memory_buffer[out_ptr..out_ptr + copy_len], value[0..copy_len]);
        
        return copy_len;
    }
    
    /// Get current time in milliseconds
    pub fn getTimeMs(ctx: *HostContext, args: []const u64) !u64 {
        _ = ctx;
        _ = args;
        return @intCast(utils.milliTimestamp());
    }
};

/// Create a standard host function table
pub fn createStandardHostFunctions(allocator: std.mem.Allocator) !HostFunctionTable {
    var table = HostFunctionTable.init(allocator);
    errdefer table.deinit();
    
    try table.register("log", .{ .param_count = 2, .return_type = .i64 }, StandardHostFunctions.log);
    try table.register("readFile", .{ .param_count = 4, .return_type = .i64 }, StandardHostFunctions.readFile);
    try table.register("writeFile", .{ .param_count = 4, .return_type = .i64 }, StandardHostFunctions.writeFile);
    try table.register("execCommand", .{ .param_count = 2, .return_type = .i64 }, StandardHostFunctions.execCommand);
    try table.register("getEnv", .{ .param_count = 4, .return_type = .i64 }, StandardHostFunctions.getEnv);
    try table.register("getTimeMs", .{ .param_count = 0, .return_type = .i64 }, StandardHostFunctions.getTimeMs);
    
    return table;
}

// ============================================================================
// Tests
// ============================================================================

test "HostFunctionTable basic operations" {
    const allocator = std.testing.allocator;
    
    var table = HostFunctionTable.init(allocator);
    defer table.deinit();
    
    try table.register("test", .{ .param_count = 0, .return_type = .i64 }, struct {
        fn handler(_: *HostContext, _: []const u64) !u64 {
            return 42;
        }
    }.handler);
    
    const func = table.get("test");
    try std.testing.expect(func != null);
    try std.testing.expectEqual(@as(u8, 0), func.?.signature.param_count);
}

test "StandardHostFunctions" {
    const allocator = std.testing.allocator;
    
    var table = try createStandardHostFunctions(allocator);
    defer table.deinit();
    
    try std.testing.expect(table.get("log") != null);
    try std.testing.expect(table.get("readFile") != null);
    try std.testing.expect(table.get("writeFile") != null);
    try std.testing.expect(table.get("execCommand") != null);
    try std.testing.expect(table.get("getEnv") != null);
    try std.testing.expect(table.get("getTimeMs") != null);
}
