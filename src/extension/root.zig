//! kimiz-extension - Extension System
//! WASM-based extension runtime for custom tools and skills

const std = @import("std");

// WASM runtime
pub const wasm = @import("wasm.zig");
pub const WasmRuntime = wasm.WasmRuntime;
pub const WasmModule = wasm.WasmModule;
pub const Value = wasm.Value;

// Host functions
pub const host = @import("host.zig");
pub const HostContext = host.HostContext;
pub const HostFunctionTable = host.HostFunctionTable;
pub const createStandardHostFunctions = host.createStandardHostFunctions;

// Extension loader
pub const loader = @import("loader.zig");
pub const ExtensionInstance = loader.ExtensionInstance;
pub const ExtensionLoader = loader.ExtensionLoader;

// Package manager
pub const package = @import("package.zig");
pub const PackageManager = package.PackageManager;
pub const PackageManifest = package.PackageManifest;
pub const InstalledPackage = package.InstalledPackage;
pub const RegistryClient = package.RegistryClient;
pub const PackageCommands = package.PackageCommands;

// Extension types
pub const Extension = struct {
    id: []const u8,
    name: []const u8,
    version: []const u8,
    description: []const u8,
    author: []const u8,
    wasm_path: []const u8,
    
    // Extension capabilities
    provides_tools: []const ToolDefinition,
    provides_skills: []const SkillDefinition,
    
    // Runtime state
    handle: ?*anyopaque = null,
    loaded: bool = false,
};

pub const ToolDefinition = struct {
    name: []const u8,
    description: []const u8,
    parameters: []const ParameterDef,
};

pub const SkillDefinition = struct {
    id: []const u8,
    name: []const u8,
    description: []const u8,
    category: []const u8,
};

pub const ParameterDef = struct {
    name: []const u8,
    param_type: ParamType,
    required: bool,
    description: []const u8,
};

pub const ParamType = enum {
    string,
    integer,
    boolean,
    filepath,
};

// Extension manifest (kimiz.toml)
pub const ExtensionManifest = struct {
    name: []const u8,
    version: []const u8,
    description: []const u8,
    author: []const u8,
    main: []const u8,  // Path to WASM file
    
    // Optional metadata
    keywords: []const []const u8,
    license: ?[]const u8,
    repository: ?[]const u8,
};

// Extension Registry
pub const ExtensionRegistry = struct {
    allocator: std.mem.Allocator,
    extensions: std.StringHashMap(Extension),
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .extensions = std.StringHashMap(Extension).init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        var iter = self.extensions.valueIterator();
        while (iter.next()) |ext| {
            self.allocator.free(ext.id);
            self.allocator.free(ext.name);
            self.allocator.free(ext.version);
            self.allocator.free(ext.description);
            self.allocator.free(ext.author);
            self.allocator.free(ext.wasm_path);
        }
        self.extensions.deinit();
    }
    
    /// Register an extension
    pub fn register(self: *Self, ext: Extension) !void {
        const ext_copy = Extension{
            .id = try self.allocator.dupe(u8, ext.id),
            .name = try self.allocator.dupe(u8, ext.name),
            .version = try self.allocator.dupe(u8, ext.version),
            .description = try self.allocator.dupe(u8, ext.description),
            .author = try self.allocator.dupe(u8, ext.author),
            .wasm_path = try self.allocator.dupe(u8, ext.wasm_path),
            .provides_tools = ext.provides_tools,
            .provides_skills = ext.provides_skills,
            .handle = null,
            .loaded = false,
        };
        try self.extensions.put(ext_copy.id, ext_copy);
    }
    
    /// Unregister an extension
    pub fn unregister(self: *Self, ext_id: []const u8) void {
        if (self.extensions.fetchRemove(ext_id)) |entry| {
            self.allocator.free(entry.value.id);
            self.allocator.free(entry.value.name);
            self.allocator.free(entry.value.version);
            self.allocator.free(entry.value.description);
            self.allocator.free(entry.value.author);
            self.allocator.free(entry.value.wasm_path);
        }
    }
    
    /// Get extension by ID
    pub fn get(self: *Self, ext_id: []const u8) ?Extension {
        return self.extensions.get(ext_id);
    }
    
    /// List all extensions
    pub fn listAll(self: *Self) ![]Extension {
        var list = std.ArrayList(Extension).init(self.allocator);
        defer list.deinit();
        
        var iter = self.extensions.valueIterator();
        while (iter.next()) |ext| {
            try list.append(ext.*);
        }
        
        return list.toOwnedSlice();
    }
    
    /// Load extension with WASM runtime
    pub fn load(self: *Self, ext_id: []const u8, runtime: *WasmRuntime) !void {
        var ext = self.extensions.getPtr(ext_id) orelse return error.ExtensionNotFound;
        
        if (ext.loaded) return;
        
        // Load WASM module
        try runtime.loadModuleFromFile(ext_id, ext.wasm_path);
        
        ext.loaded = true;
        ext.handle = runtime.getModule(ext_id);
    }
    
    /// Unload extension
    pub fn unload(self: *Self, ext_id: []const u8) !void {
        var ext = self.extensions.getPtr(ext_id) orelse return error.ExtensionNotFound;
        
        if (!ext.loaded) return;
        
        // TODO: Cleanup WASM runtime
        ext.loaded = false;
        ext.handle = null;
    }
};

// Extension Manager
pub const ExtensionManager = struct {
    allocator: std.mem.Allocator,
    registry: ExtensionRegistry,
    extension_dir: []const u8,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, extension_dir: []const u8) !Self {
        return .{
            .allocator = allocator,
            .registry = ExtensionRegistry.init(allocator),
            .extension_dir = try allocator.dupe(u8, extension_dir),
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.registry.deinit();
        self.allocator.free(self.extension_dir);
    }
    
    /// Load all extensions from extension directory
    pub fn loadAll(self: *Self) !void {
        var dir = std.fs.cwd().openDir(self.extension_dir, .{ .iterate = true }) catch |err| {
            if (err == error.FileNotFound) return;
            return err;
        };
        defer dir.close();
        
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .directory) {
                const manifest_path = try std.fs.path.join(self.allocator, &.{ 
                    self.extension_dir, entry.name, "kimiz.toml" 
                });
                defer self.allocator.free(manifest_path);
                
                if (self.loadFromManifest(manifest_path)) |ext| {
                    try self.registry.register(ext);
                } else |_| {
                    // Skip invalid extensions
                    continue;
                }
            }
        }
    }
    
    /// Load extension from manifest file
    fn loadFromManifest(self: *Self, manifest_path: []const u8) !Extension {
        _ = self;
        _ = manifest_path;
        // TODO: Parse TOML manifest
        return error.NotImplemented;
    }
    
    /// Install extension from URL or path
    pub fn install(self: *Self, source: []const u8) !void {
        _ = self;
        _ = source;
        // TODO: Download and install extension
        return error.NotImplemented;
    }
    
    /// Uninstall extension
    pub fn uninstall(self: *Self, ext_id: []const u8) !void {
        try self.registry.unload(ext_id);
        self.registry.unregister(ext_id);
        
        // TODO: Remove extension files
    }
    
    /// Get registry reference
    pub fn getRegistry(self: *Self) *ExtensionRegistry {
        return &self.registry;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "ExtensionRegistry basic operations" {
    const allocator = std.testing.allocator;
    var registry = ExtensionRegistry.init(allocator);
    defer registry.deinit();
    
    const ext = Extension{
        .id = "test-ext",
        .name = "Test Extension",
        .version = "1.0.0",
        .description = "A test extension",
        .author = "Test Author",
        .wasm_path = "/path/to/ext.wasm",
        .provides_tools = &[_]ToolDefinition{},
        .provides_skills = &[_]SkillDefinition{},
    };
    
    try registry.register(ext);
    
    const retrieved = registry.get("test-ext");
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualStrings("Test Extension", retrieved.?.name);
}

test "ExtensionManager init" {
    const allocator = std.testing.allocator;
    var manager = try ExtensionManager.init(allocator, "/tmp/kimiz/extensions");
    defer manager.deinit();
    
    try std.testing.expectEqualStrings("/tmp/kimiz/extensions", manager.extension_dir);
}
