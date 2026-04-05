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
    /// TODO: Full implementation for Zig 0.16
    pub fn formatContext(self: Self, allocator: std.mem.Allocator) ![]const u8 {
        // Simplified implementation for Zig 0.16 compatibility
        // Returns a basic context string
        _ = self;
        return try allocator.dupe(u8, "<workspace_context>\n  <cwd>.</cwd>\n</workspace_context>");
    }
};

/// Find git repository root from a starting directory
/// TODO: Full implementation in TASK-INFRA-010
fn findGitRoot(allocator: std.mem.Allocator, start_dir: []const u8) !?[]const u8 {
    _ = allocator;
    _ = start_dir;
    // Simplified for Zig 0.16 compatibility - full implementation pending
    return null;
}

/// Get current git branch
/// TODO: Full implementation in TASK-INFRA-010
fn getGitBranch(allocator: std.mem.Allocator, repo_root: []const u8) !?[]const u8 {
    _ = allocator;
    _ = repo_root;
    return null;
}

/// Get default git branch
/// TODO: Full implementation in TASK-INFRA-010
fn getGitDefaultBranch(allocator: std.mem.Allocator, repo_root: []const u8) !?[]const u8 {
    _ = allocator;
    _ = repo_root;
    return null;
}

/// Get git status
/// TODO: Full implementation in TASK-INFRA-010
fn getGitStatus(allocator: std.mem.Allocator, repo_root: []const u8) !?[]const u8 {
    _ = allocator;
    _ = repo_root;
    return null;
}

/// Get recent commits
/// TODO: Full implementation in TASK-INFRA-010
fn getRecentCommits(allocator: std.mem.Allocator, repo_root: []const u8, count: usize) ![][]const u8 {
    _ = repo_root;
    _ = count;
    // Return empty slice allocated with allocator
    return try allocator.alloc([]const u8, 0);
}

/// Run a git command and return output using POSIX
/// TODO: Full implementation in TASK-INFRA-010 using Zig 0.16 std.Io
fn runGitCommand(allocator: std.mem.Allocator, cwd: []const u8, argv: []const []const u8) !?[]const u8 {
    _ = allocator;
    _ = cwd;
    _ = argv;
    // Simplified for Zig 0.16 compatibility - full implementation pending
    return null;
}

/// Read file with size limit using POSIX
/// TODO: Full implementation in TASK-INFRA-010 using Zig 0.16 std.Io
fn readFileLimited(allocator: std.mem.Allocator, path: []const u8, max_bytes: usize) !?[]const u8 {
    _ = allocator;
    _ = path;
    _ = max_bytes;
    // Simplified for Zig 0.16 compatibility - full implementation pending
    return null;
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
