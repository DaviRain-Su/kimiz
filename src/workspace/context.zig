//! Workspace Context - Git and project context collection
//! Provides workspace information for AI context building

const std = @import("std");
const log = @import("../utils/log.zig");

/// Workspace information structure
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
            .recent_commits = &.{},
            .project_docs = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.cwd);
        
        if (self.repo_root) |r| self.allocator.free(r);
        if (self.branch) |b| self.allocator.free(b);
        if (self.default_branch) |b| self.allocator.free(b);
        if (self.git_status) |s| self.allocator.free(s);
        
        for (self.recent_commits) |commit| {
            self.allocator.free(commit);
        }
        self.allocator.free(self.recent_commits);
        
        var doc_iter = self.project_docs.iterator();
        while (doc_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.project_docs.deinit();
    }

    /// Collect all workspace information
    pub fn collect(self: *Self) !void {
        // Try to find git repository root
        self.repo_root = try findGitRoot(self.allocator, self.cwd);
        
        if (self.repo_root) |root| {
            // Collect git information
            self.branch = try getGitBranch(self.allocator, root);
            self.default_branch = try getGitDefaultBranch(self.allocator, root);
            self.git_status = try getGitStatus(self.allocator, root);
            self.recent_commits = try getRecentCommits(self.allocator, root, 5);
        }
        
        // Collect project documents
        try self.collectProjectDocs();
    }

    /// Collect project documentation files
    fn collectProjectDocs(self: *Self) !void {
        const doc_files = &[_][]const u8{
            "README.md",
            "AGENTS.md",
            "CLAUDE.md",
            "pyproject.toml",
            "package.json",
            "Cargo.toml",
            "build.zig.zon",
        };

        const search_dir = self.repo_root orelse self.cwd;

        for (doc_files) |filename| {
            const path = try std.fs.path.join(self.allocator, &.{ search_dir, filename });
            defer self.allocator.free(path);

            const content = try readFileLimited(self.allocator, path, 1200);
            if (content) |c| {
                const key = try self.allocator.dupe(u8, filename);
                try self.project_docs.put(key, c);
            }
        }
    }

    /// Format workspace info for prompt context
    pub fn formatContext(self: Self, allocator: std.mem.Allocator) ![]const u8 {
        var buf = std.ArrayList(u8).init(allocator);
        defer buf.deinit();
        
        const writer = buf.writer();
        
        try writer.print("<workspace_context>\n", .{});
        try writer.print("  <cwd>{s}</cwd>\n", .{self.cwd});
        
        if (self.repo_root) |root| {
            try writer.print("  <repo_root>{s}</repo_root>\n", .{root});
        }
        
        if (self.branch) |b| {
            try writer.print("  <branch>{s}</branch>\n", .{b});
        }
        
        if (self.default_branch) |b| {
            try writer.print("  <default_branch>{s}</default_branch>\n", .{b});
        }
        
        if (self.git_status) |s| {
            try writer.print("  <git_status>\n{s}\n  </git_status>\n", .{s});
        }
        
        if (self.recent_commits.len > 0) {
            try writer.print("  <recent_commits>\n", .{});
            for (self.recent_commits) |commit| {
                try writer.print("    {s}\n", .{commit});
            }
            try writer.print("  </recent_commits>\n", .{});
        }
        
        var doc_iter = self.project_docs.iterator();
        while (doc_iter.next()) |entry| {
            try writer.print("  <doc name=\"{s}\">\n{s}\n  </doc>\n", .{
                entry.key_ptr.*,
                entry.value_ptr.*,
            });
        }
        
        try writer.print("</workspace_context>", .{});
        
        return buf.toOwnedSlice();
    }
};

/// Find git repository root from a starting directory
fn findGitRoot(allocator: std.mem.Allocator, start_dir: []const u8) !?[]const u8 {
    var dir = try std.fs.cwd().openDir(start_dir, .{});
    defer dir.close();
    
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    var current_path = try std.fs.cwd().realpath(start_dir, &buf);
    
    while (true) {
        // Check if .git exists in current directory
        var current_dir = try std.fs.cwd().openDir(current_path, .{});
        defer current_dir.close();
        
        const git_exists = current_dir.access(".git", .{}) catch |err| switch (err) {
            error.FileNotFound => false,
            else => return err,
        };
        
        if (git_exists) {
            return try allocator.dupe(u8, current_path);
        }
        
        // Go up one directory
        const parent = std.fs.path.dirname(current_path);
        if (parent == null) break;
        current_path = parent.?;
    }
    
    return null;
}

/// Get current git branch
fn getGitBranch(allocator: std.mem.Allocator, repo_root: []const u8) !?[]const u8 {
    return try runGitCommand(allocator, repo_root, &.{ "git", "branch", "--show-current" });
}

/// Get default git branch
fn getGitDefaultBranch(allocator: std.mem.Allocator, repo_root: []const u8) !?[]const u8 {
    return try runGitCommand(allocator, repo_root, &.{ "git", "symbolic-ref", "refs/remotes/origin/HEAD" });
}

/// Get git status
fn getGitStatus(allocator: std.mem.Allocator, repo_root: []const u8) !?[]const u8 {
    return try runGitCommand(allocator, repo_root, &.{ "git", "status", "--short" });
}

/// Get recent commits
fn getRecentCommits(allocator: std.mem.Allocator, repo_root: []const u8, count: usize) ![][]const u8 {
    const output = try runGitCommand(allocator, repo_root, &.{ "git", "log", "--oneline", try std.fmt.allocPrint(allocator, "-{d}", .{count}) });
    defer if (output) |o| allocator.free(o);
    
    if (output == null) return &[]const []const u8{};
    
    // Parse lines
    var lines = std.ArrayList([]const u8).init(allocator);
    errdefer {
        for (lines.items) |line| allocator.free(line);
        lines.deinit();
    }
    
    var iter = std.mem.splitScalar(u8, output.?, '\n');
    while (iter.next()) |line| {
        if (line.len == 0) continue;
        try lines.append(try allocator.dupe(u8, line));
    }
    
    return lines.toOwnedSlice();
}

/// Run a git command and return output
fn runGitCommand(allocator: std.mem.Allocator, cwd: []const u8, argv: []const []const u8) !?[]const u8 {
    var child = std.process.Child.init(argv, allocator);
    child.cwd = cwd;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Ignore;
    
    try child.spawn();
    defer {
        _ = child.kill() catch {};
    }
    
    const stdout = try child.stdout.?.reader().readAllAlloc(allocator, 65536);
    errdefer allocator.free(stdout);
    
    const term = try child.wait();
    if (term != .Exited or term.Exited != 0) {
        allocator.free(stdout);
        return null;
    }
    
    // Trim trailing newline
    const trimmed = std.mem.trimRight(u8, stdout, "\n\r");
    if (trimmed.len == 0) {
        allocator.free(stdout);
        return null;
    }
    
    // Return trimmed copy
    const result = try allocator.dupe(u8, trimmed);
    allocator.free(stdout);
    return result;
}

/// Read file with size limit
fn readFileLimited(allocator: std.mem.Allocator, path: []const u8, max_bytes: usize) !?[]const u8 {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer file.close();
    
    const size = try file.getEndPos();
    const read_size = @min(size, max_bytes);
    
    const content = try allocator.alloc(u8, read_size);
    errdefer allocator.free(content);
    
    const bytes_read = try file.reader().readAll(content);
    if (bytes_read < read_size) {
        // Resize to actual bytes read
        const resized = try allocator.realloc(content, bytes_read);
        return resized;
    }
    
    return content;
}

// ============================================================================
// Tests
// ============================================================================

test "WorkspaceInfo init/deinit" {
    const allocator = std.testing.allocator;
    var info = try WorkspaceInfo.init(allocator, "/tmp");
    defer info.deinit();
    
    try std.testing.expectEqualStrings("/tmp", info.cwd);
}

test "findGitRoot" {
    const allocator = std.testing.allocator;
    
    // Test with current directory (should find git root)
    const root = try findGitRoot(allocator, ".");
    if (root) |r| {
        defer allocator.free(r);
        // Should contain .git
        try std.testing.expect(std.mem.indexOf(u8, r, ".git") != null or 
                              std.fs.cwd().access(".git", .{}) == {});
    }
}

test "formatContext" {
    const allocator = std.testing.allocator;
    var info = try WorkspaceInfo.init(allocator, "/home/user/project");
    defer info.deinit();
    
    // Manually set some fields
    info.branch = try allocator.dupe(u8, "main");
    
    const context = try info.formatContext(allocator);
    defer allocator.free(context);
    
    try std.testing.expect(std.mem.indexOf(u8, context, "<workspace_context>") != null);
    try std.testing.expect(std.mem.indexOf(u8, context, "main") != null);
}
