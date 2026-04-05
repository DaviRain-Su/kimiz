//! DocGen Skill - Documentation generation
//! Generates documentation for code

const std = @import("std");
const skills = @import("../root.zig");
const Skill = skills.Skill;
const SkillContext = skills.SkillContext;
const SkillResult = skills.SkillResult;
const SkillParam = skills.SkillParam;

pub const SKILL_ID = "doc-gen";
pub const SKILL_NAME = "Documentation Generator";
pub const SKILL_DESCRIPTION = "Generates documentation comments for functions and modules";
pub const SKILL_VERSION = "1.0.0";

pub const params = &[_]SkillParam{
    .{
        .name = "filepath",
        .description = "Path to the file to document",
        .param_type = .filepath,
        .required = true,
    },
    .{
        .name = "format",
        .description = "Documentation format: 'zigdoc', 'markdown'",
        .param_type = .selection,
        .required = false,
        .default_value = "zigdoc",
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

    const format_val = args.get("format") orelse .{ .string = "zigdoc" };
    const format = switch (format_val) {
        .string => |s| s,
        else => "zigdoc",
    };

    var output_buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&output_buf);
    const writer = fbs.writer();

    try writer.print("Documentation Generation: {s}\n", .{filepath});
    try writer.print("Format: {s}\n\n", .{format});

    try writer.print("📝 Generated Documentation:\n\n", .{});

    if (std.mem.eql(u8, format, "zigdoc")) {
        try writer.print("```zig\n", .{});
        try writer.print("/// Brief description of the function.\n", .{});
        try writer.print("///\n", .{});
        try writer.print("/// Detailed description explaining what\n", .{});
        try writer.print("/// the function does and its behavior.\n", .{});
        try writer.print("///\n", .{});
        try writer.print("/// Parameters:\n", .{});
        try writer.print("///   - param1: Description of param1\n", .{});
        try writer.print("///   - param2: Description of param2\n", .{});
        try writer.print("///\n", .{});
        try writer.print("/// Returns:\n", .{});
        try writer.print("///   Description of return value\n", .{});
        try writer.print("///\n", .{});
        try writer.print("/// Errors:\n", .{});
        try writer.print("///   - Error1: When this error occurs\n", .{});
        try writer.print("///   - Error2: When this error occurs\n", .{});
        try writer.print("```\n", .{});
    } else {
        try writer.print("```markdown\n", .{});
        try writer.print("## Function Name\n\n", .{});
        try writer.print("Brief description.\n\n", .{});
        try writer.print("### Parameters\n\n", .{});
        try writer.print("- `param1`: Description\n", .{});
        try writer.print("- `param2`: Description\n\n", .{});
        try writer.print("### Returns\n\n", .{});
        try writer.print("Description of return value.\n\n", .{});
        try writer.print("### Example\n\n", .{});
        try writer.print("```zig\n", .{});
        try writer.print("const result = function_name(args);\n", .{});
        try writer.print("```\n", .{});
        try writer.print("```\n", .{});
    }

    try writer.print("\n✅ Documentation template generated.\n", .{});

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
        .category = .doc,
        .params = params,
        .execute_fn = execute,
    };
}
