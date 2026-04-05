//! Refactor Skill - Code refactoring assistance
//! Helps refactor code for better structure, naming, and patterns

const std = @import("std");
const skills = @import("../root.zig");
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

    var output_buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&output_buf);
    var writer = fbs.writer();
    const w: *std.Io.Writer = &writer.interface;

    try w.print("Refactoring: {s}\n", .{filepath});
    try w.print("Operation: {s}\n", .{operation});
    try w.print("Target: {s}\n\n", .{target});

    // In real implementation, this would use AI to generate refactoring
    try w.print("📝 Refactoring plan:\n", .{});
    try w.print("  1. Analyze current code structure\n", .{});
    try w.print("  2. Identify {s} locations\n", .{target});
    try w.print("  3. Apply {s} refactoring\n", .{operation});
    try w.print("  4. Verify changes\n\n", .{});

    try w.print("⚠️  Note: This is a preview. Use --apply to execute changes.\n", .{});
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
        .category = .refactor,
        .params = params,
        .execute_fn = execute,
    };
}
