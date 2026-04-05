//! TestGen Skill - DSL version
//! Generates unit tests for code

const std = @import("std");
const skills = @import("./root.zig");

fn testGenHandler(input: struct {
    filepath: []const u8,
    function: ?[]const u8 = "all",
    framework: ?[]const u8 = "builtin",
}) struct {
    success: bool,
    output: []const u8,
} {
    var buf: [4096]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);

    w.print("Test Generation: {s}\n", .{input.filepath}) catch {};
    w.print("Target: {s}\n", .{input.function orelse "all"}) catch {};
    w.print("Framework: {s}\n\n", .{input.framework orelse "builtin"}) catch {};

    w.writeAll("🧪 Generated Tests:\n\n") catch {};

    w.writeAll("```zig\n") catch {};
    w.writeAll("test \"example function\" {\n") catch {};
    w.writeAll("    // Arrange\n") catch {};
    w.writeAll("    const input = ...;\n\n") catch {};
    w.writeAll("    // Act\n") catch {};
    w.writeAll("    const result = function_name(input);\n\n") catch {};
    w.writeAll("    // Assert\n") catch {};
    w.writeAll("    try std.testing.expectEqual(expected, result);\n") catch {};
    w.writeAll("}\n") catch {};
    w.writeAll("```\n\n") catch {};

    w.writeAll("✅ Test template generated.\n") catch {};
    w.print("   Add to: {s}\n", .{input.filepath}) catch {};

    return .{
        .success = true,
        .output = w.buffered(),
    };
}

pub const TestGenDslSkill = skills.defineSkill(.{
    .name = "test-gen",
    .description = "Generates unit tests for functions and modules",
    .input = struct {
        filepath: []const u8,
        function: ?[]const u8 = "all",
        framework: ?[]const u8 = "builtin",
    },
    .output = struct {
        success: bool,
        output: []const u8,
    },
    .handler = testGenHandler,
});

pub const SKILL_ID = TestGenDslSkill.id;
pub const SKILL_NAME = TestGenDslSkill.name;
pub const SKILL_DESCRIPTION = TestGenDslSkill.description;
pub const SKILL_VERSION = TestGenDslSkill.version;

pub fn getSkill() skills.Skill {
    return TestGenDslSkill.toSkill();
}
