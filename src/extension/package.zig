//! Package Manager for Kimiz Extensions
//! Install, remove, list, and publish extensions

const std = @import("std");
const utils = @import("../utils/root.zig");

/// Package manifest (kimiz.toml)
pub const PackageManifest = struct {
    name: []const u8,
    version: []const u8,
    description: []const u8,
    author: []const u8,
    main: []const u8,
    keywords: []const []const u8,
    license: ?[]const u8,
    repository: ?[]const u8,
    
    // Dependencies on other extensions
    dependencies: std.StringHashMap([]const u8),
    
    pub fn deinit(self: *PackageManifest, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.version);
        allocator.free(self.description);
        allocator.free(self.author);
        allocator.free(self.main);
        
        for (self.keywords) |kw| {
            allocator.free(kw);
        }
        allocator.free(self.keywords);
        
        if (self.license) |l| allocator.free(l);
        if (self.repository) |r| allocator.free(r);
        
        var iter = self.dependencies.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        self.dependencies.deinit();
    }
};

/// Installed package info
pub const InstalledPackage = struct {
    name: []const u8,
    version: []const u8,
    path: []const u8,
    installed_at: i64,
    
    pub fn deinit(self: *InstalledPackage, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.version);
        allocator.free(self.path);
    }
};

/// Package registry client
pub const RegistryClient = struct {
    allocator: std.mem.Allocator,
    base_url: []const u8,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, base_url: []const u8) !Self {
        return .{
            .allocator = allocator,
            .base_url = try allocator.dupe(u8, base_url),
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.base_url);
    }
    
    /// Search packages in registry
    pub fn search(self: *Self, query: []const u8) ![]PackageInfo {
        _ = self;
        _ = query;
        // TODO: Implement HTTP search
        return &[]PackageInfo{};
    }
    
    /// Download package from registry
    pub fn download(self: *Self, name: []const u8, version: []const u8, output_dir: []const u8) !void {
        _ = self;
        _ = name;
        _ = version;
        _ = output_dir;
        // TODO: Implement HTTP download
        return error.NotImplemented;
    }
    
    pub const PackageInfo = struct {
        name: []const u8,
        version: []const u8,
        description: []const u8,
        author: []const u8,
    };
};

/// Package manager
pub const PackageManager = struct {
    allocator: std.mem.Allocator,
    install_dir: []const u8,
    registry: RegistryClient,
    installed: std.StringHashMap(InstalledPackage),
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, install_dir: []const u8, registry_url: []const u8) !Self {
        const dir_copy = try allocator.dupe(u8, install_dir);
        errdefer allocator.free(dir_copy);
        
        var registry = try RegistryClient.init(allocator, registry_url);
        errdefer registry.deinit();
        
        var self = Self{
            .allocator = allocator,
            .install_dir = dir_copy,
            .registry = registry,
            .installed = std.StringHashMap(InstalledPackage).init(allocator),
        };
        
        // Load installed packages
        try self.loadInstalled();
        
        return self;
    }
    
    pub fn deinit(self: *Self) void {
        var iter = self.installed.valueIterator();
        while (iter.next()) |pkg| {
            pkg.deinit(self.allocator);
        }
        self.installed.deinit();
        
        self.registry.deinit();
        self.allocator.free(self.install_dir);
    }
    
    /// Load installed packages from metadata file
    fn loadInstalled(self: *Self) !void {
        const meta_path = try std.fs.path.join(self.allocator, &.{ self.install_dir, "installed.json" });
        defer self.allocator.free(meta_path);
        
        const content = utils.readFileAlloc(self.allocator, meta_path, 1024 * 1024) catch |err| switch (err) {
            error.FileNotFound => return, // No packages installed yet
            else => return err,
        };
        defer self.allocator.free(content);
        
        // TODO: Parse JSON and populate self.installed
    }
    
    /// Save installed packages to metadata file
    fn saveInstalled(self: *Self) !void {
        // Ensure install directory exists
        try utils.makeDirRecursive(self.install_dir);
        
        const meta_path = try std.fs.path.join(self.allocator, &.{ self.install_dir, "installed.json" });
        defer self.allocator.free(meta_path);
        
        // TODO: Serialize self.installed to JSON
        // Create empty file for now
        const file = try std.fs.cwd().createFile(meta_path, .{});
        file.close();
    }
    
    /// Install package from registry
    pub fn install(self: *Self, name: []const u8, version: ?[]const u8) !void {
        const pkg_dir = try std.fs.path.join(self.allocator, &.{ self.install_dir, name });
        defer self.allocator.free(pkg_dir);
        
        // Check if already installed
        if (self.installed.contains(name)) {
            std.debug.print("Package '{s}' is already installed\n", .{name});
            return error.AlreadyInstalled;
        }
        
        // Download from registry
        const ver = version orelse "latest";
        try self.registry.download(name, ver, pkg_dir);
        
        // Add to installed list
        const pkg = InstalledPackage{
            .name = try self.allocator.dupe(u8, name),
            .version = try self.allocator.dupe(u8, ver),
            .path = try self.allocator.dupe(u8, pkg_dir),
            .installed_at = std.time.timestamp(),
        };
        
        try self.installed.put(pkg.name, pkg);
        try self.saveInstalled();
        
        std.debug.print("Installed '{s}' v{s}\n", .{ name, ver });
    }
    
    /// Install package from local path
    pub fn installFromPath(self: *Self, path: []const u8) !void {
        // Read manifest
        const manifest_path = try std.fs.path.join(self.allocator, &.{ path, "kimiz.toml" });
        defer self.allocator.free(manifest_path);
        
        const content = try utils.readFileAlloc(self.allocator, manifest_path, 1024 * 1024);
        defer self.allocator.free(content);
        
        // TODO: Parse TOML manifest
        const name = "unknown";
        const version = "0.0.0";
        
        // Copy to install directory
        const pkg_dir = try std.fs.path.join(self.allocator, &.{ self.install_dir, name });
        defer self.allocator.free(pkg_dir);
        
        // TODO: Copy directory recursively
        
        // Add to installed list
        const pkg = InstalledPackage{
            .name = try self.allocator.dupe(u8, name),
            .version = try self.allocator.dupe(u8, version),
            .path = try self.allocator.dupe(u8, pkg_dir),
            .installed_at = std.time.timestamp(),
        };
        
        try self.installed.put(pkg.name, pkg);
        try self.saveInstalled();
        
        std.debug.print("Installed '{s}' v{s} from {s}\n", .{ name, version, path });
    }
    
    /// Remove installed package
    pub fn remove(self: *Self, name: []const u8) !void {
        const pkg = self.installed.fetchRemove(name) orelse {
            std.debug.print("Package '{s}' is not installed\n", .{name});
            return error.NotInstalled;
        };
        
        // Remove directory
        try utils.deleteTree(pkg.value.path);
        
        // Free memory
        pkg.value.deinit(self.allocator);
        
        try self.saveInstalled();
        
        std.debug.print("Removed '{s}'\n", .{name});
    }
    
    /// List installed packages
    pub fn list(self: *Self) ![]InstalledPackage {
        var pkg_list = std.ArrayList(InstalledPackage).init(self.allocator);
        defer pkg_list.deinit();
        
        var iter = self.installed.valueIterator();
        while (iter.next()) |pkg| {
            try list.append(pkg.*);
        }
        
        return list.toOwnedSlice();
    }
    
    /// Update package to latest version
    pub fn update(self: *Self, name: []const u8) !void {
        _ = self;
        _ = name;
        // TODO: Check for updates and install
        return error.NotImplemented;
    }
    
    /// Search for packages in registry
    pub fn search(self: *Self, query: []const u8) ![]RegistryClient.PackageInfo {
        return try self.registry.search(query);
    }
    
    /// Get package info
    pub fn info(self: *Self, name: []const u8) ?InstalledPackage {
        return self.installed.get(name);
    }
};

/// CLI commands for package management
pub const PackageCommands = struct {
    /// Run 'add' command
    pub fn add(manager: *PackageManager, args: []const []const u8) !void {
        if (args.len < 1) {
            std.debug.print("Usage: kimiz add <package> [version]\n", .{});
            return error.InvalidArguments;
        }
        
        const name = args[0];
        const version = if (args.len > 1) args[1] else null;
        
        try manager.install(name, version);
    }
    
    /// Run 'remove' command
    pub fn remove(manager: *PackageManager, args: []const []const u8) !void {
        if (args.len < 1) {
            std.debug.print("Usage: kimiz remove <package>\n", .{});
            return error.InvalidArguments;
        }
        
        try manager.remove(args[0]);
    }
    
    /// Run 'list' command
    pub fn list(manager: *PackageManager) !void {
        const packages = try manager.list();
        defer manager.allocator.free(packages);
        
        if (packages.len == 0) {
            std.debug.print("No packages installed\n", .{});
            return;
        }
        
        std.debug.print("Installed packages:\n", .{});
        for (packages) |pkg| {
            std.debug.print("  {s} v{s} ({s})\n", .{ pkg.name, pkg.version, pkg.path });
        }
    }
    
    /// Run 'search' command
    pub fn search(manager: *PackageManager, args: []const []const u8) !void {
        if (args.len < 1) {
            std.debug.print("Usage: kimiz search <query>\n", .{});
            return error.InvalidArguments;
        }
        
        const results = try manager.search(args[0]);
        defer manager.allocator.free(results);
        
        std.debug.print("Search results:\n", .{});
        for (results) |pkg| {
            std.debug.print("  {s} v{s} - {s} by {s}\n", .{
                pkg.name,
                pkg.version,
                pkg.description,
                pkg.author,
            });
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "PackageManager basic operations" {
    const allocator = std.testing.allocator;
    
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    
    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);
    
    var manager = try PackageManager.init(allocator, tmp_path, "https://registry.kimiz.dev");
    defer manager.deinit();
    
    // Test list (should be empty)
    const packages = try manager.list();
    defer allocator.free(packages);
    try std.testing.expectEqual(@as(usize, 0), packages.len);
}

test "RegistryClient init" {
    const allocator = std.testing.allocator;
    
    var client = try RegistryClient.init(allocator, "https://registry.kimiz.dev");
    defer client.deinit();
    
    try std.testing.expectEqualStrings("https://registry.kimiz.dev", client.base_url);
}
