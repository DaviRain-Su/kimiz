const std = @import("std");
const skills = @import("../root.zig");

fn HelloHandler(input: struct {
    name: ?[]const u8 = "world",
}, arena: std.mem.Allocator) struct {
    success: bool,
    output: []const u8,
} {
    var buf: [256]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);

    const target = input.name orelse "world";
    w.print("Hello, {s}!\n", .{target}) catch {};

    const output = arena.dupe(u8, w.buffered()) catch return .{ .success = false, .output = "" };
    return .{ .success = true, .output = output };
}

pub const HelloDslSkill = skills.defineSkill(.{
    .name = "auto-hello",
    .description = "A simple hello-world skill demonstrating auto-generation",
    .input = struct {
        name: ?[]const u8 = "world",
    },
    .output = struct {
        success: bool,
        output: []const u8,
    },
    .handler = HelloHandler,
});

pub const SKILL_ID = HelloDslSkill.id;
pub const SKILL_NAME = HelloDslSkill.name;
pub const SKILL_DESCRIPTION = HelloDslSkill.description;
pub const SKILL_VERSION = HelloDslSkill.version;

pub fn getSkill() skills.Skill {
    return HelloDslSkill.toSkill();
}
