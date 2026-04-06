//! WASM Runtime for Extensions
//! Uses zwasm - A small, fast WebAssembly runtime written in Zig

const std = @import("std");
const zwasm = @import("zwasm");
const utils = @import("../utils/root.zig");

/// WASM module wrapper for extensions
pub const WasmModule = struct {
    allocator: std.mem.Allocator,
    inner: zwasm.WasmModule,
    name: []const u8,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, name: []const u8, wasm_bytes: []const u8) !Self {
        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);
        
        const inner = try zwasm.WasmModule.load(allocator, wasm_bytes);
        
        return .{
            .allocator = allocator,
            .inner = inner,
            .name = name_copy,
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.inner.deinit();
        self.allocator.free(self.name);
    }
    
    /// Call an exported function
    pub fn call(self: *Self, func_name: []const u8, args: []const u64) !u64 {
        var results = [_]u64{0};
        try self.inner.invoke(func_name, args, &results);
        return results[0];
    }
    
    /// Get module name
    pub fn getName(self: Self) []const u8 {
        return self.name;
    }
};

/// WASM runtime manager for extensions
pub const WasmRuntime = struct {
    allocator: std.mem.Allocator,
    modules: std.StringHashMap(*WasmModule),
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .modules = std.StringHashMap(*WasmModule).init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        var iter = self.modules.valueIterator();
        while (iter.next()) |module_ptr| {
            module_ptr.*.deinit();
            self.allocator.destroy(module_ptr.*);
        }
        self.modules.deinit();
    }
    
    /// Load a WASM module from bytes
    pub fn loadModule(self: *Self, name: []const u8, wasm_bytes: []const u8) !void {
        const module = try self.allocator.create(WasmModule);
        errdefer self.allocator.destroy(module);
        
        module.* = try WasmModule.init(self.allocator, name, wasm_bytes);
        
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);
        
        try self.modules.put(name_copy, module);
    }
    
    /// Load a WASM module from file
    pub fn loadModuleFromFile(self: *Self, name: []const u8, path: []const u8) !void {
        const wasm_bytes = try utils.readFileAlloc(self.allocator, path, 10 * 1024 * 1024);
        defer self.allocator.free(wasm_bytes);
        
        try self.loadModule(name, wasm_bytes);
    }
    
    /// Unload a module
    pub fn unloadModule(self: *Self, name: []const u8) void {
        if (self.modules.fetchRemove(name)) |entry| {
            entry.value.deinit();
            self.allocator.destroy(entry.value);
            self.allocator.free(entry.key);
        }
    }
    
    /// Get a module
    pub fn getModule(self: *Self, name: []const u8) ?*WasmModule {
        return self.modules.get(name);
    }
    
    /// Call a function in a module
    pub fn callFunction(
        self: *Self,
        module_name: []const u8,
        func_name: []const u8,
        args: []const u64,
    ) !u64 {
        const module = self.getModule(module_name) orelse return error.ModuleNotFound;
        return try module.call(func_name, args);
    }
    
    /// List all loaded modules
    pub fn listModules(self: *Self) ![][]const u8 {
        var list = std.ArrayList([]const u8).init(self.allocator);
        defer list.deinit();
        
        var iter = self.modules.keyIterator();
        while (iter.next()) |key| {
            try list.append(key.*);
        }
        
        return list.toOwnedSlice();
    }
};

/// Host functions for extension API
/// These functions are exposed to WASM extensions
pub const HostFunctions = struct {
    /// Log a message from extension
    pub fn log(ctx: *anyopaque, id: usize) !void {
        _ = ctx;
        _ = id;
        // TODO: Implement logging
    }
    
    /// Read file from host
    pub fn readFile(ctx: *anyopaque, id: usize) !void {
        _ = ctx;
        _ = id;
        // TODO: Implement file reading
    }
    
    /// Write file to host
    pub fn writeFile(ctx: *anyopaque, id: usize) !void {
        _ = ctx;
        _ = id;
        // TODO: Implement file writing
    }
};

// ============================================================================
// Tests
// ============================================================================

test "WasmModule basic operations" {
    const allocator = std.testing.allocator;
    
    // Minimal valid WASM module (empty module)
    const wasm_bytes = &[_]u8{ 0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00 };
    
    var module = try WasmModule.init(allocator, "test", wasm_bytes);
    defer module.deinit();
    
    try std.testing.expectEqualStrings("test", module.getName());
}

test "WasmRuntime basic operations" {
    const allocator = std.testing.allocator;
    
    var runtime = WasmRuntime.init(allocator);
    defer runtime.deinit();
    
    const wasm_bytes = &[_]u8{ 0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00 };
    try runtime.loadModule("test", wasm_bytes);
    
    const module = runtime.getModule("test");
    try std.testing.expect(module != null);
    
    runtime.unloadModule("test");
    
    const module2 = runtime.getModule("test");
    try std.testing.expect(module2 == null);
}
