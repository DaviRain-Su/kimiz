const std = @import("std");
const fs = @import("../utils/fs_helper.zig");

/// Load prompt content from a cascade of directories:
/// 1. .kimiz/prompts/review/ (project-local, highest priority)
/// 2. ~/.kimiz/prompts/review/ (user-global)
/// 3. prompts/review/ (package builtin, lowest priority)
pub const CascadePath = struct {
    path: []const u8,
    source: Source,

    pub const Source = enum { project_local, user_global, builtin };
};

pub const PromptLoader = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn resolvePromptPath(self: *const Self, role_file: []const u8) !?CascadePath {
        const home = if (std.c.getenv("HOME")) |ptr|
            std.mem.sliceTo(ptr, 0)
        else
            ".";

        const candidates = [_]struct {
            dir: []const u8,
            source: CascadePath.Source,
        }{
            .{ .dir = ".kimiz/prompts/review", .source = .project_local },
            .{ .dir = try std.fs.path.join(self.allocator, &.{ home, ".kimiz/prompts/review" }), .source = .user_global },
            .{ .dir = "prompts/review", .source = .builtin },
        };
        defer {
            self.allocator.free(candidates[1].dir); // user_global was allocated
        }

        for (candidates) |c| {
            const path = try std.fs.path.join(self.allocator, &.{ c.dir, role_file });
            if (fs.fileExists(path)) {
                return CascadePath{
                    .path = path,
                    .source = c.source,
                };
            } else {
                self.allocator.free(path);
            }
        }

        return null;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "PromptLoader - resolves known builtin role" {
    const loader = PromptLoader.init(std.testing.allocator);
    const result = try loader.resolvePromptPath("product-manager.md");
    try std.testing.expect(result != null);
    if (result) |r| {
        defer loader.allocator.free(r.path);
        try std.testing.expectEqual(CascadePath.Source.builtin, r.source);
    }
}

test "PromptLoader - resolves code-reviewer from builtin" {
    const loader = PromptLoader.init(std.testing.allocator);
    const result = try loader.resolvePromptPath("code-reviewer.md");
    try std.testing.expect(result != null);
    if (result) |r| {
        defer loader.allocator.free(r.path);
        try std.testing.expectEqual(CascadePath.Source.builtin, r.source);
    }
}

test "PromptLoader - returns null for unknown role" {
    const loader = PromptLoader.init(std.testing.allocator);
    const result = try loader.resolvePromptPath("unknown-role-that-does-not-exist.md");
    try std.testing.expect(result == null);
}

