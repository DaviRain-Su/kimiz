//! PluginRegistry - Manages WASM skill lifecycle: scan, register, hot-reload

const std = @import("std");
const zwasm = @import("zwasm");
const utils = @import("../utils/root.zig");
const wasm_skill = @import("wasm_skill.zig");
const WasmSkill = wasm_skill.WasmSkill;
const plugin_loader = @import("plugin_loader.zig");
const PluginLoader = plugin_loader.PluginLoader;

/// Registry for loaded WASM skills.
/// Scans watch directories and (re)loads all .wasm/.wat files on demand.
pub const PluginRegistry = struct {
    allocator: std.mem.Allocator,
    skills: std.StringHashMap(RegistryEntry),
    watch_dirs: []const []const u8,

    const Self = @This();

    pub const RegistryEntry = struct {
        skill: WasmSkill,
        module: *zwasm.WasmModule,
    };

    /// Initialize with default watch directories:
    ///   [0] = ~/.kimiz/skills/wasm   (user-level)
    ///   [1] = .kimiz/skills/wasm     (project-level, overrides user-level)
    pub fn init(allocator: std.mem.Allocator) !Self {
        const home = std.process.getEnvVarOwned(allocator, "HOME") catch blk: {
            const cwd_path = try std.process.getCwdAlloc(allocator);
            break :blk cwd_path;
        };
        defer allocator.free(home);

        const dirs = try allocator.alloc([]const u8, 2);
        dirs[0] = try std.fs.path.join(allocator, &.{ home, ".kimiz", "skills", "wasm" });
        dirs[1] = try std.fs.path.join(allocator, &.{ ".kimiz", "skills", "wasm" });

        return .{
            .allocator = allocator,
            .skills = std.StringHashMap(RegistryEntry).init(allocator),
            .watch_dirs = dirs,
        };
    }

    pub fn deinit(self: *Self) void {
        self.unloadAll();
        for (self.watch_dirs) |d| self.allocator.free(d);
        self.allocator.free(self.watch_dirs);
        self.skills.deinit();
    }

    /// Look up a loaded skill by name.
    pub fn get(self: *Self, skill_name: []const u8) ?*WasmSkill {
        const entry = self.skills.getPtr(skill_name) orelse return null;
        return &entry.skill;
    }

    /// Scan watch directories and reload all skills.
    /// Project-level directory is scanned after user-level, so it overrides
    /// any skills with the same name.
    pub fn scanAndReload(self: *Self) !void {
        self.unloadAll();
        var loader = PluginLoader.init(self.allocator);

        for (self.watch_dirs) |dir| {
            const d = utils.openDir(dir, .{ .iterate = true }) catch |err| {
                if (err == error.FileNotFound) continue;
                return err;
            };
            const io = try utils.getIo();
            var it = d.iterate(io);
            while (try it.next(io)) |entry| {
                if (entry.kind != .file) continue;
                const ext = std.fs.path.extension(entry.name);
                if (!std.mem.eql(u8, ext, ".wasm") and !std.mem.eql(u8, ext, ".wat")) continue;

                const skill_name = entry.name[0 .. entry.name.len - ext.len];
                const full_path = try std.fs.path.join(self.allocator, &.{ dir, entry.name });
                defer self.allocator.free(full_path);

                var skill = loader.loadFromFile(full_path) catch |err| {
                    std.log.warn("Failed to load skill from {s}: {s}", .{ full_path, @errorName(err) });
                    continue;
                };
                const module = skill.inner;

                const gop = self.skills.getOrPut(self.allocator, skill_name) catch |err| {
                    skill.deinit();
                    module.deinit();
                    return err;
                };
                if (gop.found_existing) {
                    // Override from higher-priority directory
                    gop.value_ptr.skill.deinit();
                    gop.value_ptr.module.deinit();
                } else {
                    gop.key_ptr.* = try self.allocator.dupe(u8, skill_name);
                }
                gop.value_ptr.* = .{ .skill = skill, .module = module };
            }
        }
    }

    fn unloadAll(self: *Self) void {
        var it = self.skills.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.skill.deinit();
            entry.value_ptr.module.deinit();
            self.allocator.free(entry.key_ptr.*);
        }
        self.skills.clearRetainingCapacity();
    }
};

// ============================================================================
// Tests
// ============================================================================

const base_wat =
    \\(module
    \\  (import "kimiz" "kimiz_log" (func $kimiz_log (param i32 i32 i32)))
    \\  (import "kimiz" "kimiz_alloc" (func $kimiz_alloc (param i32) (result i32)))
    \\  (import "kimiz" "kimiz_free" (func $kimiz_free (param i32 i32)))
    \\  (memory (export "memory") 1)
    \\  (data (i32.const 0) "echo")
    \\  (data (i32.const 16) "echoes input")
    \\  (global (export "kimiz_skill_version") i32 (i32.const 1))
    \\  (global (export "kimiz_skill_name") i32 (i32.const 0))
    \\  (global (export "kimiz_skill_name_len") i32 (i32.const 4))
    \\  (global (export "kimiz_skill_desc") i32 (i32.const 16))
    \\  (global (export "kimiz_skill_desc_len") i32 (i32.const 12))
    \\  (func (export "kimiz_skill_execute") (param i32 i32 i32 i32) (result i32)
    \\    i32.const 0
    \\  )
    \\)
;

test "PluginRegistry scanAndReload discovers new skill" {
    const allocator = std.testing.allocator;

    // Use a temp directory as the project-level watch dir
    var registry = PluginRegistry.init(allocator) catch |err| {
        // If HOME not set, init may fail; skip gracefully
        if (err == error.EnvironmentVariableNotFound) return;
        return err;
    };
    defer registry.deinit();

    // Override watch_dirs to a controlled temp dir for the test
    for (registry.watch_dirs) |d| allocator.free(d);
    allocator.free(registry.watch_dirs);
    const tmp_dir = ".zig-cache/registry_test";
    try utils.makeDirRecursive(tmp_dir);
    defer utils.deleteTree(tmp_dir) catch {};
    const dirs = try allocator.alloc([]const u8, 1);
    dirs[0] = try allocator.dupe(u8, tmp_dir);
    registry.watch_dirs = dirs;

    const wat_path = try std.fs.path.join(allocator, &.{ tmp_dir, "echo.wat" });
    defer allocator.free(wat_path);
    try utils.writeFile(wat_path, base_wat);

    try registry.scanAndReload();

    const skill = registry.get("echo");
    try std.testing.expect(skill != null);
    try std.testing.expectEqualStrings("echo", skill.?.name);
}

test "PluginRegistry scanAndReload removes deleted skills" {
    const allocator = std.testing.allocator;

    var registry = try PluginRegistry.init(allocator);
    defer registry.deinit();

    const tmp_dir = ".zig-cache/registry_test_del";
    try utils.makeDirRecursive(tmp_dir);
    defer utils.deleteTree(tmp_dir) catch {};
    const dirs = try allocator.alloc([]const u8, 1);
    dirs[0] = try allocator.dupe(u8, tmp_dir);
    registry.watch_dirs = dirs;

    const wat_path = try std.fs.path.join(allocator, &.{ tmp_dir, "echo.wat" });
    defer allocator.free(wat_path);
    try utils.writeFile(wat_path, base_wat);

    try registry.scanAndReload();
    try std.testing.expect(registry.get("echo") != null);

    // Delete the file and rescan
    try utils.deleteFile(wat_path);
    try registry.scanAndReload();
    try std.testing.expect(registry.get("echo") == null);
}

test "PluginRegistry project-level overrides user-level" {
    const allocator = std.testing.allocator;

    var registry = try PluginRegistry.init(allocator);
    defer registry.deinit();

    const user_dir = ".zig-cache/registry_test_user";
    const proj_dir = ".zig-cache/registry_test_proj";
    try utils.makeDirRecursive(user_dir);
    try utils.makeDirRecursive(proj_dir);
    defer utils.deleteTree(user_dir) catch {};
    defer utils.deleteTree(proj_dir) catch {};

    for (registry.watch_dirs) |d| allocator.free(d);
    allocator.free(registry.watch_dirs);
    const dirs = try allocator.alloc([]const u8, 2);
    dirs[0] = try allocator.dupe(u8, user_dir);
    dirs[1] = try allocator.dupe(u8, proj_dir);
    registry.watch_dirs = dirs;

    const user_wat = try std.fs.path.join(allocator, &.{ user_dir, "echo.wat" });
    defer allocator.free(user_wat);
    try utils.writeFile(user_wat, base_wat);

    const proj_wat = try std.fs.path.join(allocator, &.{ proj_dir, "echo.wat" });
    defer allocator.free(proj_wat);
    // Same ABI but different metadata so we can tell which one won
    const proj_wat_src =
        \\(module
        \\  (import "kimiz" "kimiz_log" (func $kimiz_log (param i32 i32 i32)))
        \\  (import "kimiz" "kimiz_alloc" (func $kimiz_alloc (param i32) (result i32)))
        \\  (import "kimiz" "kimiz_free" (func $kimiz_free (param i32 i32)))
        \\  (memory (export "memory") 1)
        \\  (data (i32.const 0) "proj_echo")
        \\  (data (i32.const 32) "project level")
        \\  (global (export "kimiz_skill_version") i32 (i32.const 1))
        \\  (global (export "kimiz_skill_name") i32 (i32.const 0))
        \\  (global (export "kimiz_skill_name_len") i32 (i32.const 9))
        \\  (global (export "kimiz_skill_desc") i32 (i32.const 32))
        \\  (global (export "kimiz_skill_desc_len") i32 (i32.const 13))
        \\  (func (export "kimiz_skill_execute") (param i32 i32 i32 i32) (result i32)
        \\    i32.const 0
        \\  )
        \\)
    ;
    try utils.writeFile(proj_wat, proj_wat_src);

    try registry.scanAndReload();

    const skill = registry.get("echo").?;
    try std.testing.expectEqualStrings("proj_echo", skill.name);
    try std.testing.expectEqualStrings("project level", skill.description);
}
