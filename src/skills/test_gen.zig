//! TestGen Skill - Test generation
//! Generates unit tests for code

const std = @import("std");
const skills = @import("../root.zig");
const Skill = skills.Skill;
const SkillContext = skills.SkillContext;
const SkillResult = skills.SkillResult;
const SkillParam = skills.SkillParam;

pub const SKILL_ID = "test-gen";
pub const SKILL_NAME = "Test Generator";
pub const SKILL_DESCRIPTION = "Generates unit tests for functions and modules";
pub const SKILL_VERSION = "1.0.0";

pub const params = &[_]SkillParam{
    .{
        .name = "filepath",
        .description = "Path to the file to generate tests for",
        .param_type = .filepath,
        .required = true,
    },
    .{
        .name = "function",
        .description = "Specific function to test (or 'all' for all functions)",
        .param_type = .string,
        .required = false,
        .default_value = "all",
    },
    .{
        .name = "framework",
        .description = "Test framework: 'builtin', 'std'",
        .param_type = .selection,
        .required = false,
        .default_value = "builtin",
    },
};

pub fn execute(
    ctx: SkillContext,
    args: std.json.ObjectMap,
    arena: std.mem.Allocator,
) !SkillResult {
    const filepath_val = args.get("filepath") orelse return error.MissingRequiredParam;
    const filepath = switch (filepath_val) {
        .string => |s| s,
        else => return error.InvalidParamType,
    };

    const function_val = args.get("function") orelse .{ .string = "all" };
    const function = switch (function_val) {
        .string => |s| s,
        else => "all",
    };

    const framework_val = args.get("framework") orelse .{ .string = "builtin" };
    const framework = switch (framework_val) {
        .string => |s| s,
        else => "builtin",
    };

    var output_buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&output_buf);
    var writer = fbs.writer();
    const w: *std.Io.Writer = &writer.interface;

    try w.print("Test Generation: {s}\n", .{filepath});
    try w.print("Target: {s}\n", .{function});
    try w.print("Framework: {s}\n\n", .{framework});

    try w.print("🧪 Generated Tests:\n\n", .{});

    try w.print("```zig\n", .{});
    try w.print("test \"example function\" {{\n", .{});
    try w.print("    // Arrange\n", .{});
    try w.print("    const input = ...;\n\n", .{});
    try w.print("    // Act\n", .{});
    try w.print("    const result = function_name(input);\n\n", .{});
    try w.print("    // Assert\n", .{});
    try w.print("    try std.testing.expectEqual(expected, result);\n", .{});
    try w.print("}}\n", .{});
    try w.print("```\n\n", .{});

    try w.print("✅ Test template generated.\n", .{});
    try w.print("   Add to: {s}\n", .{filepath});
    try w.flush();

    const output = try arena.dupe(u8, fbs.getWritten());

    return SkillResult{
        .success = true,
        .output = output,
        .execution_time_ms = 0,
    };
}

pub fn getSkill() Skill {
    return .{
        .id = SKILL_ID,
        .name = SKILL_NAME,
        .description = SKILL_DESCRIPTION,
        .version = SKILL_VERSION,
        .category = .test,
        .params = params,
        .execute_fn = execute,
    };
}
