//! Extension Loader - Load and execute WASM extensions with Host Functions
//! Integrates zwasm with Host Function API

const std = @import("std");
const zwasm = @import("zwasm");
const host = @import("host.zig");

/// Loaded extension instance
pub const ExtensionInstance = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    wasm_module: zwasm.WasmModule,
    host_ctx: host.HostContext,
    host_table: host.HostFunctionTable,
    
    const Self = @This();
    
    pub fn init(
        allocator: std.mem.Allocator,
        id: []const u8,
        wasm_bytes: []const u8,
        working_dir: []const u8,
    ) !Self {
        const id_copy = try allocator.dupe(u8, id);
        errdefer allocator.free(id_copy);
        
        // Load WASM module
        var wasm_module = try zwasm.WasmModule.load(allocator, wasm_bytes);
        errdefer wasm_module.deinit();
        
        // Create host context with 1MB memory buffer
        var host_ctx = try host.HostContext.init(allocator, id_copy, working_dir, 1024 * 1024);
        errdefer host_ctx.deinit();
        
        // Create host function table
        var host_table = try host.createStandardHostFunctions(allocator);
        errdefer host_table.deinit();
        
        return .{
            .allocator = allocator,
            .id = id_copy,
            .wasm_module = wasm_module,
            .host_ctx = host_ctx,
            .host_table = host_table,
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.wasm_module.deinit();
        self.host_ctx.deinit();
        self.host_table.deinit();
        self.allocator.free(self.id);
    }
    
    /// Call an exported function
    pub fn call(self: *Self, func_name: []const u8, args: []const u64) !u64 {
        // TODO: Integrate host functions with zwasm
        // For now, just call directly
        var results = [_]u64{0};
        try self.wasm_module.invoke(func_name, args, &results);
        return results[0];
    }
    
    /// Initialize the extension
    pub fn initExt(self: *Self) !i32 {
        const result = try self.call("init", &[_]u64{});
        return @intCast(result);
    }
    
    /// Deinitialize the extension
    pub fn deinitExt(self: *Self) !void {
        _ = try self.call("deinit", &[_]u64{});
    }
};

/// Extension loader
pub const ExtensionLoader = struct {
    allocator: std.mem.Allocator,
    instances: std.StringHashMap(*ExtensionInstance),
    working_dir: []const u8,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, working_dir: []const u8) !Self {
        const wd_copy = try allocator.dupe(u8, working_dir);
        errdefer allocator.free(wd_copy);
        
        return .{
            .allocator = allocator,
            .instances = std.StringHashMap(*ExtensionInstance).init(allocator),
            .working_dir = wd_copy,
        };
    }
    
    pub fn deinit(self: *Self) void {
        var iter = self.instances.valueIterator();
        while (iter.next()) |instance_ptr| {
            instance_ptr.*.deinit();
            self.allocator.destroy(instance_ptr.*);
        }
        self.instances.deinit();
        self.allocator.free(self.working_dir);
    }
    
    /// Load extension from WASM bytes
    pub fn loadFromBytes(
        self: *Self,
        id: []const u8,
        wasm_bytes: []const u8,
    ) !void {
        const instance = try self.allocator.create(ExtensionInstance);
        errdefer self.allocator.destroy(instance);
        
        instance.* = try ExtensionInstance.init(
            self.allocator,
            id,
            wasm_bytes,
            self.working_dir,
        );
        
        const id_copy = try self.allocator.dupe(u8, id);
        errdefer self.allocator.free(id_copy);
        
        try self.instances.put(id_copy, instance);
        
        // Initialize the extension
        _ = try instance.initExt();
    }
    
    /// Load extension from file
    pub fn loadFromFile(
        self: *Self,
        id: []const u8,
        path: []const u8,
    ) !void {
        const wasm_bytes = try std.fs.cwd().readFileAlloc(
            self.allocator,
            path,
            10 * 1024 * 1024,
        );
        defer self.allocator.free(wasm_bytes);
        
        try self.loadFromBytes(id, wasm_bytes);
    }
    
    /// Unload extension
    pub fn unload(self: *Self, id: []const u8) !void {
        if (self.instances.fetchRemove(id)) |entry| {
            // Deinitialize the extension
            entry.value.deinitExt() catch {};
            
            entry.value.deinit();
            self.allocator.destroy(entry.value);
            self.allocator.free(entry.key);
        }
    }
    
    /// Get extension instance
    pub fn get(self: *Self, id: []const u8) ?*ExtensionInstance {
        return self.instances.get(id);
    }
    
    /// Call function in extension
    pub fn call(
        self: *Self,
        id: []const u8,
        func_name: []const u8,
        args: []const u64,
    ) !u64 {
        const instance = self.get(id) orelse return error.ExtensionNotFound;
        return try instance.call(func_name, args);
    }
    
    /// List loaded extensions
    pub fn list(self: *Self) ![][]const u8 {
        var ext_list = std.ArrayList([]const u8).init(self.allocator);
        defer ext_list.deinit();
        
        var iter = self.instances.keyIterator();
        while (iter.next()) |key| {
            try ext_list.append(key.*);
        }
        
        return ext_list.toOwnedSlice();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "ExtensionInstance basic operations" {
    const allocator = std.testing.allocator;
    
    // Use the example extension if available
    const wasm_path = "examples/extension-hello/zig-out/bin/extension-hello.wasm";
    const wasm_bytes = std.fs.cwd().readFileAlloc(allocator, wasm_path, 10 * 1024 * 1024) catch {
        // Skip test if example not built
        return;
    };
    defer allocator.free(wasm_bytes);
    
    var instance = try ExtensionInstance.init(allocator, "test", wasm_bytes, ".");
    defer instance.deinit();
    
    try std.testing.expectEqualStrings("test", instance.id);
}

test "ExtensionLoader basic operations" {
    const allocator = std.testing.allocator;
    
    var loader = try ExtensionLoader.init(allocator, ".");
    defer loader.deinit();
    
    // Use the example extension if available
    const wasm_path = "examples/extension-hello/zig-out/bin/extension-hello.wasm";
    
    loader.loadFromFile("hello", wasm_path) catch |err| switch (err) {
        error.FileNotFound => return, // Skip if not built
        else => return err,
    };
    
    const instance = loader.get("hello");
    try std.testing.expect(instance != null);
    
    // Test calling add function
    const result = try loader.call("hello", "add", &[_]u64{ 5, 3 });
    try std.testing.expectEqual(@as(u64, 8), result);
    
    try loader.unload("hello");
    
    const instance2 = loader.get("hello");
    try std.testing.expect(instance2 == null);
}
