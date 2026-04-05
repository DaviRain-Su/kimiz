//! Refactor Skill - DSL version
//! Helps refactor code for better structure, naming, and patterns

const std = @import("std");
const skills = @import("./root.zig");

fn refactorHandler(input: struct {
    filepath: []const u8,
    operation: []const u8,
    target: []const u8,
    new_name: ?[]const u8 = null,
}, arena: std.mem.Allocator) struct {
    success: bool,
    output: []const u8,
} {
    var buf: [4096]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);

    w.print("Refactoring: {s}\n", .{input.filepath}) catch {};
    w.print("Operation: {s}\n", .{input.operation}) catch {};
    w.print("Target: {s}\n\n", .{input.target}) catch {};

    w.writeAll("📝 Refactoring plan:\n") catch {};
    w.print("  1. Analyze current code structure\n", .{}) catch {};
    w.print("  2. Identify {s} locations\n", .{input.target}) catch {};
    w.print("  3. Apply {s} refactoring\n", .{input.operation}) catch {};
    w.writeAll("  4. Verify changes\n\n") catch {};

    w.writeAll("⚠️  Note: This is a preview. Use --apply to execute changes.\n") catch {};

    const preview = w.buffered();
    const output = std.fmt.allocPrint(arena, "{s}", .{preview}) catch return .{ .success = false, .output = "" };
    return .{ .success = true, .output = output };
}

pub const RefactorDslSkill = skills.defineSkill(.{
    .name = "refactor",
    .description = "Refactors code for better structure and readability",
    .input = struct {
        filepath: []const u8,
        operation: []const u8,
        target: []const u8,
        new_name: ?[]const u8 = null,
    },
    .output = struct {
        success: bool,
        output: []const u8,
    },
    .handler = refactorHandler,
});

pub const SKILL_ID = RefactorDslSkill.id;
pub const SKILL_NAME = RefactorDslSkill.name;
pub const SKILL_DESCRIPTION = RefactorDslSkill.description;
pub const SKILL_VERSION = RefactorDslSkill.version;

pub fn getSkill() skills.Skill {
    return RefactorDslSkill.toSkill();
}
