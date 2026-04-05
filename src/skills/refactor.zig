//! Refactor Skill - Code refactoring assistance
//! Helps refactor code for better structure, naming, and patterns

const std = @import("std");
const skills = @import("./root.zig");
const Skill = skills.Skill;
const SkillContext = skills.SkillContext;
const SkillResult = skills.SkillResult;
const SkillParam = skills.SkillParam;

pub const SKILL_ID = "refactor";
pub const SKILL_NAME = "Refactor";
pub const SKILL_DESCRIPTION = "Refactors code for better structure and readability";
pub const SKILL_VERSION = "1.0.0";

pub const params = &[_]SkillParam{
    .{
        .name = "filepath",
        .description = "Path to the file to refactor",
        .param_type = .filepath,
        .required = true,
    },
    .{
        .name = "operation",
        .description = "Refactoring operation: 'rename', 'extract', 'inline', 'reorder'",
        .param_type = .selection,
        .required = true,
    },
    .{
        .name = "target",
        .description = "Target symbol or line range to refactor",
        .param_type = .string,
        .required = true,
    },
    .{
        .name = "new_name",
        .description = "New name (for rename operation)",
        .param_type = .string,
        .required = false,
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

    const operation_val = args.get("operation") orelse return error.MissingRequiredParam;
    const operation = switch (operation_val) {
        .string => |s| s,
        else => return error.InvalidParamType,
    };

    const target_val = args.get("target") orelse return error.MissingRequiredParam;
    const target = switch (target_val) {
        .string => |s| s,
        else => return error.InvalidParamType,
    };

    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(arena);

    try output.appendSlice(arena, try std.fmt.allocPrint(arena, "Refactoring: {s}\n", .{filepath}));
    try output.appendSlice(arena, try std.fmt.allocPrint(arena, "Operation: {s}\n", .{operation}));
    try output.appendSlice(arena, try std.fmt.allocPrint(arena, "Target: {s}\n\n", .{target}));

    // In real implementation, this would use AI to generate refactoring
    try output.appendSlice(arena, "📝 Refactoring plan:\n");
    try output.appendSlice(arena, "  1. Analyze current code structure\n");
    try output.appendSlice(arena, try std.fmt.allocPrint(arena, "  2. Identify {s} locations\n", .{target}));
    try output.appendSlice(arena, try std.fmt.allocPrint(arena, "  3. Apply {s} refactoring\n", .{operation}));
    try output.appendSlice(arena, "  4. Verify changes\n\n");

    try output.appendSlice(arena, "⚠️  Note: This is a preview. Use --apply to execute changes.\n");

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
        .category = .refactor,
        .params = params,
        .execute_fn = execute,
    };
}
