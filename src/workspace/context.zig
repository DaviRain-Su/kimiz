//! Workspace Context - Git and project context collection
//! TASK-INFRA-010: Full implementation with Zig 0.16

const std = @import("std");
const utils = @import("../utils/root.zig");

pub const WorkspaceInfo = struct {
    allocator: std.mem.Allocator,
    cwd: []const u8,
    repo_root: ?[]const u8,
    branch: ?[]const u8,
    default_branch: ?[]const u8,
    git_status: ?[]const u8,
    recent_commits: [][]const u8,
    project_docs: std.StringHashMap([]const u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, cwd: []const u8) !Self {
        return .{
            .allocator = allocator,
            .cwd = try allocator.dupe(u8, cwd),
            .repo_root = null,
            .branch = null,
            .default_branch = null,
            .git_status = null,
            .recent_commits = &[_][]const u8{},
            .project_docs = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.cwd);
        if (self.repo_root) |r| self.allocator.free(r);
        if (self.branch) |b| self.allocator.free(b);
        if (self.default_branch) |b| self.allocator.free(b);
        if (self.git_status) |s| self.allocator.free(s);
        for (self.recent_commits) |c| self.allocator.free(c);
        self.allocator.free(self.recent_commits);
        var it = self.project_docs.iterator();
        while (it.next()) |e| {
            self.allocator.free(e.key_ptr.*);
            self.allocator.free(e.value_ptr.*);
        }
        self.project_docs.deinit();
    }

    pub fn collect(self: *Self) !void {
        if (self.branch) |b| { self.allocator.free(b); self.branch = null; }
        if (self.default_branch) |b| { self.allocator.free(b); self.default_branch = null; }
        if (self.git_status) |s| { self.allocator.free(s); self.git_status = null; }
        for (self.recent_commits) |c| self.allocator.free(c);
        self.allocator.free(self.recent_commits);
        self.recent_commits = &[_][]const u8{};

        self.repo_root = findGitRoot(self.allocator, self.cwd) catch null;
        if (self.repo_root) |root| {
            self.branch = getGitBranch(self.allocator, root) catch null;
            self.default_branch = getGitDefaultBranch(self.allocator, root) catch null;
            self.git_status = getGitStatus(self.allocator, root) catch null;
            self.recent_commits = getRecentCommits(self.allocator, root, 5) catch &[_][]const u8{};
        }
        self.collectProjectDocs() catch {};
    }

    fn collectProjectDocs(self: *Self) !void {
        const doc_files = &[_][]const u8{
            "README.md", "AGENTS.md", "CLAUDE.md",
            "pyproject.toml", "package.json",
            "Cargo.toml", "build.zig.zon",
        };
        const search_dir = self.repo_root orelse self.cwd;
        for (doc_files) |filename| {
            const path = try std.fs.path.join(self.allocator, &.{ search_dir, filename });
            defer self.allocator.free(path);
            const content = try readFileLimited(self.allocator, path, 1200) orelse continue;
            const key = try self.allocator.dupe(u8, filename);
            try self.project_docs.put(key, content);
        }
    }

    pub fn formatContext(self: *const Self, allocator: std.mem.Allocator) ![]const u8 {
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(allocator);
        try buf.appendSlice(allocator, "<workspace_context>\n");
        {
            const s = try std.fmt.allocPrint(allocator, "  <cwd>{s}</cwd>\n", .{self.cwd});
            defer allocator.free(s);
            try buf.appendSlice(allocator, s);
        }
        if (self.repo_root) |root| {
            const s = try std.fmt.allocPrint(allocator, "  <git_repo>{s}</git_repo>\n", .{root});
            defer allocator.free(s);
            try buf.appendSlice(allocator, s);
        }
        if (self.branch) |b| {
            const s = try std.fmt.allocPrint(allocator, "  <branch>{s}</branch>\n", .{b});
            defer allocator.free(s);
            try buf.appendSlice(allocator, s);
        }
        if (self.default_branch) |db| {
            const s = try std.fmt.allocPrint(allocator, "  <default_branch>{s}</default_branch>\n", .{db});
            defer allocator.free(s);
            try buf.appendSlice(allocator, s);
        }
        if (self.git_status) |s_orig| {
            const t = if (s_orig.len > 2000) s_orig[0..2000] else s_orig;
            const s = try std.fmt.allocPrint(allocator, "  <git_status>\n{s}\n  </git_status>\n", .{t});
            defer allocator.free(s);
            try buf.appendSlice(allocator, s);
        }
        if (self.recent_commits.len > 0) {
            try buf.appendSlice(allocator, "  <recent_commits>\n");
            for (self.recent_commits) |c| {
                const s = try std.fmt.allocPrint(allocator, "    <commit>{s}</commit>\n", .{c});
                defer allocator.free(s);
                try buf.appendSlice(allocator, s);
            }
            try buf.appendSlice(allocator, "  </recent_commits>\n");
        }
        var it = self.project_docs.iterator();
        while (it.next()) |e| {
            const p = if (e.value_ptr.*.len > 300) e.value_ptr.*[0..300] else e.value_ptr.*;
            const s = try std.fmt.allocPrint(allocator, "  <file name=\"{s}\">\n{s}\n  </file>\n", .{ e.key_ptr.*, p });
            defer allocator.free(s);
            try buf.appendSlice(allocator, s);
        }
        try buf.appendSlice(allocator, "</workspace_context>");
        return try buf.toOwnedSlice(allocator);
    }
};

fn runGit(allocator: std.mem.Allocator, _cwd: []const u8, argv: []const []const u8) !?[]const u8 {
    _ = _cwd;
    const io = try utils.getIo();
    const result = std.process.run(allocator, io, .{
        .argv = argv,    }) catch return null;
    defer { allocator.free(result.stdout); allocator.free(result.stderr); }
    if (result.term == .exited and result.term.exited == 0 and result.stdout.len > 0)
        return try allocator.dupe(u8, std.mem.trim(u8, result.stdout, " \t\n\r"));
    return null;
}

fn findGitRoot(allocator: std.mem.Allocator, _start_dir: []const u8) !?[]const u8 {
    _ = _start_dir;
    return try runGit(allocator, ".", &[_][]const u8{ "git", "rev-parse", "--show-toplevel" });
}

fn getGitBranch(allocator: std.mem.Allocator, _repo_root: []const u8) !?[]const u8 {
    _ = _repo_root;
    if (try runGit(allocator, ".", &[_][]const u8{ "git", "branch", "--show-current" })) |b| {
        if (b.len > 0) return b;
        allocator.free(b);
    }
    return try runGit(allocator, ".", &[_][]const u8{ "git", "rev-parse", "--abbrev-ref", "HEAD" });
}

fn getGitDefaultBranch(allocator: std.mem.Allocator, _repo_root: []const u8) !?[]const u8 {
    _ = _repo_root;
    const out = try runGit(allocator, ".", &[_][]const u8{ "git", "remote", "show", "origin" }) orelse return null;
    defer allocator.free(out);
    var lines = std.mem.splitScalar(u8, out, '\n');
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, "HEAD branch:")) |pos| {
            const name = std.mem.trim(u8, line[pos + "HEAD branch:".len ..], " \t\n\r");
            if (name.len > 0) return try allocator.dupe(u8, name);
        }
    }
    return null;
}

fn getGitStatus(allocator: std.mem.Allocator, _repo_root: []const u8) !?[]const u8 {
    _ = _repo_root;
    return try runGit(allocator, ".", &[_][]const u8{ "git", "status", "--short", "--branch" });
}

fn getRecentCommits(allocator: std.mem.Allocator, _repo_root: []const u8, count: usize) ![][]const u8 {
    _ = _repo_root;
    const cnt = try std.fmt.allocPrint(allocator, "{d}", .{count});
    defer allocator.free(cnt);
    const argv = &[_][]const u8{ "git", "log", "--oneline", "-n", cnt };
    const maybe_out = try runGit(allocator, ".", argv);
    if (maybe_out) |out| {
        var commits: std.ArrayList([]const u8) = .empty;
        defer {
            for (commits.items) |c| allocator.free(c);
            commits.deinit(allocator);
        }
        var lines = std.mem.splitScalar(u8, std.mem.trim(u8, out, " \t\n\r"), '\n');
        while (lines.next()) |line| {
            const entry = std.mem.trim(u8, line, " \t\n\r");
            if (entry.len > 0) {
                const duped = try allocator.dupe(u8, entry);
                commits.append(allocator, duped) catch |err| {
                    allocator.free(duped);
                    return err;
                };
            }
        }
        const result = try commits.toOwnedSlice(allocator);
        allocator.free(out);
        return result;
    }
    return &[_][]const u8{};
}

fn readFileLimited(allocator: std.mem.Allocator, path: []const u8, max_bytes: usize) !?[]const u8 {
    return utils.readFileAlloc(allocator, path, max_bytes) catch |err| switch (err) {
        error.FileNotFound, error.AccessDenied => null,
        else => null,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "WorkspaceInfo init/deinit" {
    const alloc = std.testing.allocator;
    var info = try WorkspaceInfo.init(alloc, "/tmp");
    defer info.deinit();
    try std.testing.expectEqualStrings("/tmp", info.cwd);
}

test "findGitRoot finds repo" {
    const alloc = std.testing.allocator;
    const root = try findGitRoot(alloc, ".");
    if (root) |r| {
        defer alloc.free(r);
        try std.testing.expect(r.len > 0);
    }
}

test "formatContext includes branch" {
    const alloc = std.testing.allocator;
    var info = try WorkspaceInfo.init(alloc, "/home/user/project");
    defer info.deinit();
    info.branch = try alloc.dupe(u8, "main");
    const ctx = try info.formatContext(alloc);
    defer alloc.free(ctx);
    try std.testing.expect(std.mem.indexOf(u8, ctx, "main") != null);
}

test "WorkspaceInfo collect in git repo" {
    const alloc = std.testing.allocator;
    var info = try WorkspaceInfo.init(alloc, ".");
    defer info.deinit();
    try info.collect();
    try std.testing.expect(info.repo_root != null);
}
