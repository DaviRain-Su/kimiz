//! Git Worktree Manager - T-119
//! Provides lightweight filesystem isolation for subagents via git worktree

const std = @import("std");

pub const WorktreeError = error{
    NotAGitRepo,
    WorktreeCreateFailed,
    WorktreeRemoveFailed,
    WorktreeListFailed,
    InvalidWorktreePath,
    OutOfMemory,
};

pub const WorktreeManager = struct {
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    repo_path: []const u8,

    const Self = @This();

    /// Initialize a WorktreeManager for the given repo path
    pub fn init(allocator: std.mem.Allocator, repo_path: []const u8) !Self {
        return .{
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
            .repo_path = try allocator.dupe(u8, repo_path),
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        self.arena.deinit();
        self.allocator.free(self.repo_path);
    }

    /// Create a new worktree with the given name
    /// Returns the absolute path to the worktree directory
    pub fn createWorktree(self: *Self, name: []const u8) WorktreeError![]const u8 {
        const arena_alloc = self.arena.allocator();
        
        const base_dir = try self.getWorktreeBaseDir();
        
        const worktree_path = try self.allocator.dupe(u8, try std.fs.path.join(arena_alloc, &.{ base_dir, name }));
        errdefer self.allocator.free(worktree_path);

        // Ensure parent directory exists
        const utils = @import("root.zig");
        utils.makeDirRecursive(base_dir) catch |e| {
            if (e != error.PathAlreadyExists) return WorktreeError.WorktreeCreateFailed;
        };

        const cmd = try std.fmt.allocPrint(arena_alloc, "cd '{s}' && git worktree add '{s}' -b {s} 2>&1", .{
            self.repo_path,
            worktree_path,
            name,
        });

        const output = self.execShell(cmd) catch return WorktreeError.WorktreeCreateFailed;

        // Check for errors in output (git worktree add returns 0 but may warn)
        if (std.mem.containsAtLeast(u8, output, 1, "fatal:")) {
            return WorktreeError.WorktreeCreateFailed;
        }

        return worktree_path;
    }

    /// Remove a worktree at the given path
    pub fn removeWorktree(self: *Self, path: []const u8) WorktreeError!void {
        const arena_alloc = self.arena.allocator();
        
        const cmd = try std.fmt.allocPrint(arena_alloc, "cd '{s}' && git worktree remove --force '{s}' 2>&1", .{
            self.repo_path,
            path,
        });

        _ = self.execShell(cmd) catch return WorktreeError.WorktreeRemoveFailed;
    }

    /// List all worktrees for this repo
    /// Caller owns returned slice and each string inside
    pub fn listWorktrees(self: *Self) WorktreeError![][]const u8 {
        const arena_alloc = self.arena.allocator();
        
        const cmd = try std.fmt.allocPrint(arena_alloc, "cd '{s}' && git worktree list --porcelain 2>&1", .{
            self.repo_path,
        });

        const output = self.execShell(cmd) catch return WorktreeError.WorktreeListFailed;

        var paths = std.ArrayList([]const u8).init(self.allocator);
        errdefer {
            for (paths.items) |p| self.allocator.free(p);
            paths.deinit();
        }

        var lines = std.mem.splitScalar(u8, output, '\n');
        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "worktree ")) {
                const path = line[9..];
                if (path.len == 0) continue;
                const copy = try self.allocator.dupe(u8, path);
                try paths.append(copy);
            }
        }

        return paths.toOwnedSlice();
    }

    /// Generate a unique worktree name based on timestamp and random suffix
    pub fn generateName(self: *Self, prefix: []const u8) WorktreeError![]const u8 {
        const utils = @import("root.zig");
        const ts = utils.milliTimestamp();
        var prng = std.Random.DefaultPrng.init(@intCast(ts));
        const rand = prng.random().int(u32);
        return try std.fmt.allocPrint(self.allocator, "{s}-{d}-{x}", .{ prefix, ts, rand });
    }

    fn getWorktreeBaseDir(self: *Self) WorktreeError![]const u8 {
        const arena_alloc = self.arena.allocator();
        
        const home = if (std.c.getenv("HOME")) |ptr|
            std.mem.sliceTo(ptr, 0)
        else
            "/tmp";

        // Use repo basename as namespace
        const basename = std.fs.path.basename(self.repo_path);
        if (basename.len == 0) return WorktreeError.InvalidWorktreePath;

        return try std.fs.path.join(arena_alloc, &.{ home, ".kimiz", "worktrees", basename });
    }

    fn execShell(self: *Self, command: []const u8) ![]const u8 {
        const utils = @import("root.zig");
        const io = utils.getIo() catch return error.CommandFailed;
        
        const arena_alloc = self.arena.allocator();

        // Execute using Zig 0.16 native API with arena allocator
        const result = std.process.run(arena_alloc, io, .{
            .argv = &.{ "sh", "-c", command },
            .stdout_limit = @enumFromInt(1024 * 1024),
            .stderr_limit = @enumFromInt(1024 * 1024),
        }) catch return error.CommandFailed;

        // Combine stdout and stderr - all allocated in arena, auto-freed on deinit
        if (result.stdout.len > 0 and result.stderr.len > 0) {
            return try std.fmt.allocPrint(arena_alloc, "{s}{s}", .{ result.stdout, result.stderr });
        } else if (result.stdout.len > 0) {
            return result.stdout;
        } else if (result.stderr.len > 0) {
            return result.stderr;
        }
        return "";
    }
};

// ============================================================================
// Tests
// ============================================================================

test "WorktreeManager generateName" {
    const allocator = std.testing.allocator;
    var manager = try WorktreeManager.init(allocator, "/tmp/test-repo");
    defer manager.deinit();
    
    const name = try manager.generateName("subagent");
    defer allocator.free(name);
    try std.testing.expect(std.mem.startsWith(u8, name, "subagent-"));
}

test "WorktreeManager getWorktreeBaseDir" {
    const allocator = std.testing.allocator;
    var manager = try WorktreeManager.init(allocator, "/tmp/test-repo");
    defer manager.deinit();
    
    const dir = try manager.getWorktreeBaseDir();
    // dir is allocated in arena, no need to free manually
    try std.testing.expect(std.mem.endsWith(u8, dir, "test-repo"));
}
