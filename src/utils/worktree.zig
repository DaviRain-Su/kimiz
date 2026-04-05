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
    repo_path: []const u8,

    const Self = @This();

    /// Initialize a WorktreeManager for the given repo path
    pub fn init(allocator: std.mem.Allocator, repo_path: []const u8) Self {
        return .{
            .allocator = allocator,
            .repo_path = repo_path,
        };
    }

    /// Create a new worktree with the given name
    /// Returns the absolute path to the worktree directory
    pub fn createWorktree(self: *const Self, name: []const u8) WorktreeError![]const u8 {
        const base_dir = try self.getWorktreeBaseDir();
        defer self.allocator.free(base_dir);

        const worktree_path = try std.fs.path.join(self.allocator, &.{ base_dir, name });
        errdefer self.allocator.free(worktree_path);

        // Ensure parent directory exists
        const c = @cImport({ @cInclude("sys/stat.h"); @cInclude("string.h"); });
        var parent_buf: [std.fs.max_path_bytes]u8 = undefined;
        const parent = std.fs.path.dirname(worktree_path) orelse "/";
        @memcpy(parent_buf[0..parent.len], parent);
        parent_buf[parent.len] = 0;
        _ = c.mkdir(@ptrCast(&parent_buf), 0o755);

        const cmd = try std.fmt.allocPrint(self.allocator, "cd '{s}' && git worktree add '{s}' -b {s} 2>&1", .{
            self.repo_path,
            worktree_path,
            name,
        });
        defer self.allocator.free(cmd);

        const output = self.execShell(cmd) catch return WorktreeError.WorktreeCreateFailed;
        defer self.allocator.free(output);

        // Check for errors in output (git worktree add returns 0 but may warn)
        if (std.mem.containsAtLeast(u8, output, 1, "fatal:")) {
            return WorktreeError.WorktreeCreateFailed;
        }

        return worktree_path;
    }

    /// Remove a worktree at the given path
    pub fn removeWorktree(self: *const Self, path: []const u8) WorktreeError!void {
        const cmd = try std.fmt.allocPrint(self.allocator, "cd '{s}' && git worktree remove --force '{s}' 2>&1", .{
            self.repo_path,
            path,
        });
        defer self.allocator.free(cmd);

        const output = self.execShell(cmd) catch return WorktreeError.WorktreeRemoveFailed;
        defer self.allocator.free(output);
    }

    /// List all worktrees for this repo
    /// Caller owns returned slice and each string inside
    pub fn listWorktrees(self: *const Self) WorktreeError![][]const u8 {
        const cmd = try std.fmt.allocPrint(self.allocator, "cd '{s}' && git worktree list --porcelain 2>&1", .{
            self.repo_path,
        });
        defer self.allocator.free(cmd);

        const output = self.execShell(cmd) catch return WorktreeError.WorktreeListFailed;
        defer self.allocator.free(output);

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
    pub fn generateName(self: *const Self, prefix: []const u8) WorktreeError![]const u8 {
        const c = @cImport({ @cInclude("time.h"); @cInclude("stdlib.h"); });
        const ts: i64 = c.time(null);
        const rand = c.arc4random();
        return try std.fmt.allocPrint(self.allocator, "{s}-{d}-{x}", .{ prefix, ts, rand });
    }

    fn getWorktreeBaseDir(self: *const Self) WorktreeError![]const u8 {
        const home = if (std.c.getenv("HOME")) |ptr|
            std.mem.sliceTo(ptr, 0)
        else
            "/tmp";

        // Use repo basename as namespace
        const basename = std.fs.path.basename(self.repo_path);
        if (basename.len == 0) return WorktreeError.InvalidWorktreePath;

        return try std.fs.path.join(self.allocator, &.{ home, ".kimiz", "worktrees", basename });
    }

    fn execShell(self: *const Self, command: []const u8) ![]const u8 {
        const cc = @cImport({ @cInclude("stdio.h"); @cInclude("stdlib.h"); });
        const c_cmd = try self.allocator.dupeZ(u8, command);
        defer self.allocator.free(c_cmd);

        const pipe = cc.popen(c_cmd.ptr, "r") orelse return error.CommandFailed;
        defer _ = cc.pclose(pipe);

        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(self.allocator);

        var buf: [4096]u8 = undefined;
        while (true) {
            const n = cc.fread(&buf, 1, buf.len, pipe);
            if (n == 0) break;
            try output.appendSlice(self.allocator, buf[0..n]);
        }

        return output.toOwnedSlice(self.allocator);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "WorktreeManager generateName" {
    const allocator = std.testing.allocator;
    const manager = WorktreeManager.init(allocator, "/tmp/test-repo");
    const name = try manager.generateName("subagent");
    defer allocator.free(name);
    try std.testing.expect(std.mem.startsWith(u8, name, "subagent-"));
}

test "WorktreeManager getWorktreeBaseDir" {
    const allocator = std.testing.allocator;
    const manager = WorktreeManager.init(allocator, "/tmp/test-repo");
    const dir = try manager.getWorktreeBaseDir();
    defer allocator.free(dir);
    try std.testing.expect(std.mem.endsWith(u8, dir, "test-repo"));
}
