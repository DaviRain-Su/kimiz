//! DocGen Skill - Documentation generation
//! Generates documentation for code

const std = @import("std");
const skills = @import("./root.zig");
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
    _: SkillContext,
    args: std.json.ObjectMap,
    arena: std.mem.Allocator,
) !SkillResult {
    const filepath_val = args.get("filepath") orelse return error.MissingRequiredParam;
    const filepath = switch (filepath_val) {
        .string => |s| s,
        else => return error.InvalidParamType,
    };

    const format_val = args.get("format") orelse return error.MissingRequiredParam;
    const format = switch (format_val) {
        .string => |s| s,
        else => "zigdoc",
    };

    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(arena);

    try output.appendSlice(arena, try std.fmt.allocPrint(arena, "Documentation Generation: {s}\n", .{filepath}));
    try output.appendSlice(arena, try std.fmt.allocPrint(arena, "Format: {s}\n\n", .{format}));
    try output.appendSlice(arena, "📝 Generated Documentation:\n\n");

    if (std.mem.eql(u8, format, "zigdoc")) {
        try output.appendSlice(arena, "```zig\n");
        try output.appendSlice(arena, "/// Brief description of the function.\n");
        try output.appendSlice(arena, "///\n");
        try output.appendSlice(arena, "/// Detailed description explaining what\n");
        try output.appendSlice(arena, "/// the function does and its behavior.\n");
        try output.appendSlice(arena, "///\n");
        try output.appendSlice(arena, "/// Parameters:\n");
        try output.appendSlice(arena, "///   - param1: Description of param1\n");
        try output.appendSlice(arena, "///   - param2: Description of param2\n");
        try output.appendSlice(arena, "///\n");
        try output.appendSlice(arena, "/// Returns:\n");
        try output.appendSlice(arena, "///   Description of return value\n");
        try output.appendSlice(arena, "///\n");
        try output.appendSlice(arena, "/// Errors:\n");
        try output.appendSlice(arena, "///   - Error1: When this error occurs\n");
        try output.appendSlice(arena, "///   - Error2: When this error occurs\n");
        try output.appendSlice(arena, "```\n");
    } else {
        try output.appendSlice(arena, "```markdown\n");
        try output.appendSlice(arena, "## Function Name\n\n");
        try output.appendSlice(arena, "Brief description.\n\n");
        try output.appendSlice(arena, "### Parameters\n\n");
        try output.appendSlice(arena, "- `param1`: Description\n");
        try output.appendSlice(arena, "- `param2`: Description\n\n");
        try output.appendSlice(arena, "### Returns\n\n");
        try output.appendSlice(arena, "Description of return value.\n\n");
        try output.appendSlice(arena, "### Example\n\n");
        try output.appendSlice(arena, "```zig\n");
        try output.appendSlice(arena, "const result = function_name(args);\n");
        try output.appendSlice(arena, "```\n");
        try output.appendSlice(arena, "```\n");
    }

    try output.appendSlice(arena, "\n✅ Documentation template generated.\n");

    const output_final = try output.toOwnedSlice(arena);

    return SkillResult{
        .success = true,
        .output = output_final,
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
