//! Configuration Management
//! User settings, API keys, preferences

const std = @import("std");
const utils = @import("root.zig");

pub const Config = struct {
    default_model: []const u8,
    api_keys: std.StringHashMap([]const u8),
    theme: Theme,
    auto_approve_tools: bool,
    yolo_mode: bool,

    pub const Theme = enum {
        dark,
        light,
        system,
    };
};

pub const ConfigManager = struct {
    allocator: std.mem.Allocator,
    config_path: []const u8,

    pub fn init(allocator: std.mem.Allocator) !ConfigManager {
        const home = std.process.getEnvVarOwned(allocator, "HOME") catch ".";
        defer allocator.free(home);
        
        const config_dir = try std.fs.path.join(allocator, &.{ home, ".kimiz" });
        defer allocator.free(config_dir);
        
        // Create config directory if not exists
        utils.makeDirRecursive(config_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
        
        const config_path = try std.fs.path.join(allocator, &.{ config_dir, "config.json" });
        
        return .{
            .allocator = allocator,
            .config_path = config_path,
        };
    }

    pub fn deinit(self: *ConfigManager) void {
        self.allocator.free(self.config_path);
    }

    /// Load config from JSON file, create default if not exists
    pub fn load(self: *ConfigManager) !Config {
        // Try to read existing config
        const content = utils.readFileAlloc(
            self.allocator,
            self.config_path,
            1024 * 1024, // Max 1MB
        ) catch |err| switch (err) {
            error.FileNotFound => {
                // Create default config
                const default_config = try self.createDefault();
                try self.save(&default_config);
                return default_config;
            },
            else => return err,
        };
        defer self.allocator.free(content);

        // Parse JSON
        return try self.parseConfig(content);
    }

    /// Save config to JSON file
    pub fn save(self: *ConfigManager, config: *const Config) !void {
        var buf: [4096]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buf);
        var writer = fbs.writer();
        const w: *std.Io.Writer = &writer.interface;

        try w.print("{{\n", .{});
        try w.print("  \"default_model\": \"{s}\",\n", .{config.default_model});
        try w.print("  \"theme\": \"{s}\",\n", .{@tagName(config.theme)});
        try w.print("  \"auto_approve_tools\": {},\n", .{config.auto_approve_tools});
        try w.print("  \"yolo_mode\": {}\n", .{config.yolo_mode});
        try w.print("}}\n", .{});
        try w.flush();

        const file = try std.fs.cwd().createFile(self.config_path, .{});
        defer file.close();
        try file.writeAll(fbs.getWritten());
    }

    /// Set API key for a provider
    pub fn setApiKey(self: *ConfigManager, config: *Config, provider: []const u8, key: []const u8) !void {
        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);
        
        // Remove old key if exists
        if (config.api_keys.get(provider)) |old_key| {
            self.allocator.free(old_key);
            _ = config.api_keys.remove(provider);
        }
        
        try config.api_keys.put(provider, key_copy);
        try self.save(config);
    }

    /// Get API key for a provider
    pub fn getApiKey(config: *const Config, provider: []const u8) ?[]const u8 {
        return config.api_keys.get(provider);
    }

    fn createDefault(self: *ConfigManager) !Config {
        return .{
            .default_model = try self.allocator.dupe(u8, "kimi-k2.5"),
            .api_keys = std.StringHashMap([]const u8).init(self.allocator),
            .theme = .system,
            .auto_approve_tools = false,
            .yolo_mode = false,
        };
    }

    fn parseConfig(self: *ConfigManager, content: []const u8) !Config {
        var config = try self.createDefault();
        errdefer config.deinit(self.allocator);

        // Parse JSON using std.json
        var parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            content,
            .{},
        );
        defer parsed.deinit();

        const root = parsed.value.object;

        if (root.get("default_model")) |v| {
            if (v == .string) {
                self.allocator.free(config.default_model);
                config.default_model = try self.allocator.dupe(u8, v.string);
            }
        }

        if (root.get("theme")) |v| {
            if (v == .string) {
                config.theme = std.meta.stringToEnum(Config.Theme, v.string) orelse .system;
            }
        }

        if (root.get("auto_approve_tools")) |v| {
            if (v == .bool) config.auto_approve_tools = v.bool;
        }

        if (root.get("yolo_mode")) |v| {
            if (v == .bool) config.yolo_mode = v.bool;
        }

        if (root.get("api_keys")) |v| {
            if (v == .object) {
                var it = v.object.iterator();
                while (it.next()) |entry| {
                    if (entry.value_ptr.* == .string) {
                        const key = try self.allocator.dupe(u8, entry.value_ptr.*.string);
                        errdefer self.allocator.free(key);
                        try config.api_keys.put(entry.key_ptr.*, key);
                    }
                }
            }
        }

        return config;
    }
};

/// Deinitialize Config and free all allocated memory
pub fn configDeinit(config: *Config, allocator: std.mem.Allocator) void {
    allocator.free(config.default_model);
    var it = config.api_keys.iterator();
    while (it.next()) |entry| {
        allocator.free(entry.value_ptr.*);
    }
    config.api_keys.deinit();
}

// ============================================================================
// Tests
// ============================================================================

test "ConfigManager init/deinit" {
    const allocator = std.testing.allocator;
    var manager = try ConfigManager.init(allocator);
    defer manager.deinit();

    try std.testing.expect(manager.config_path.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, manager.config_path, ".kimiz") != null);
}

test "Config load default" {
    const allocator = std.testing.allocator;
    var manager = try ConfigManager.init(allocator);
    defer manager.deinit();

    var config = try manager.load();
    defer configDeinit(&config, allocator);

    try std.testing.expectEqualStrings("gpt-4o", config.default_model);
    try std.testing.expectEqual(Config.Theme.system, config.theme);
    try std.testing.expectEqual(false, config.auto_approve_tools);
    try std.testing.expectEqual(false, config.yolo_mode);
}

test "Config save and load" {
    const allocator = std.testing.allocator;

    var manager = try ConfigManager.init(allocator);
    defer manager.deinit();

    // Modify config
    var config = try manager.load();
    defer configDeinit(&config, allocator);

    allocator.free(config.default_model);
    config.default_model = try allocator.dupe(u8, "kimi-k2.5");
    config.theme = .dark;
    config.yolo_mode = true;

    // Save
    try manager.save(&config);

    // Reload and verify
    var config2 = try manager.load();
    defer configDeinit(&config2, allocator);

    try std.testing.expectEqualStrings("kimi-k2.5", config2.default_model);
    try std.testing.expectEqual(.dark, config2.theme);
    try std.testing.expectEqual(true, config2.yolo_mode);
}

test "Config API key management" {
    const allocator = std.testing.allocator;
    var manager = try ConfigManager.init(allocator);
    defer manager.deinit();

    var config = try manager.load();
    defer configDeinit(&config, allocator);

    // Set API key
    try manager.setApiKey(&config, "openai", "sk-test123");

    // Verify using the ConfigManager method
    const key = ConfigManager.getApiKey(&config, "openai");
    try std.testing.expect(key != null);
    try std.testing.expectEqualStrings("sk-test123", key.?);

    // Update key
    try manager.setApiKey(&config, "openai", "sk-new456");
    const new_key = ConfigManager.getApiKey(&config, "openai");
    try std.testing.expectEqualStrings("sk-new456", new_key.?);

    // Non-existent key
    const missing = ConfigManager.getApiKey(&config, "unknown");
    try std.testing.expect(missing == null);
}
