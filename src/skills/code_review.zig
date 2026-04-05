//! CodeReview Skill - Automated code review
//! Reviews code for best practices, potential bugs, and style issues

const std = @import("std");
const skills = @import("../root.zig");
const Skill = skills.Skill;
const SkillContext = skills.SkillContext;
const SkillResult = skills.SkillResult;
const SkillParam = skills.SkillParam;

// Skill metadata
pub const SKILL_ID = "code-review";
pub const SKILL_NAME = "Code Review";
pub const SKILL_DESCRIPTION = "Reviews code for best practices, potential bugs, and style issues";
pub const SKILL_VERSION = "1.0.0";

pub const params = &[_]SkillParam{
    .{
        .name = "filepath",
        .description = "Path to the file to review",
        .param_type = .filepath,
        .required = true,
    },
    .{
        .name = "focus",
        .description = "Review focus: 'all', 'bugs', 'style', 'performance'",
        .param_type = .selection,
        .required = false,
        .default_value = "all",
    },
};

/// Execute code review
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

    const focus_val = args.get("focus") orelse .{ .string = "all" };
    const focus = switch (focus_val) {
        .string => |s| s,
        else => "all",
    };

    // Read file content
    const content = std.fs.cwd().readFileAlloc(arena, filepath, 1024 * 1024) catch |err| {
        return SkillResult{
            .success = false,
            .output = "",
            .error_message = try std.fmt.allocPrint(arena, "Failed to read file: {s}", .{@errorName(err)}),
            .execution_time_ms = 0,
        };
    };

    // Analyze code (simplified - in real implementation, use AI)
    var output_buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&output_buf);
    var writer = fbs.writer();
    const w = &writer.interface;

    try w.print("Code Review: {s}\n", .{filepath});
    try w.print("Focus: {s}\n\n", .{focus});

    // Basic checks
    var issues_found: u32 = 0;

    // Check for TODO/FIXME
    if (std.mem.indexOf(u8, content, "TODO") != null) {
        try w.print("⚠️  Found TODO comments - {d} occurrences\n", .{countOccurrences(content, "TODO")});
        issues_found += 1;
    }
    if (std.mem.indexOf(u8, content, "FIXME") != null) {
        try w.print("⚠️  Found FIXME comments - {d} occurrences\n", .{countOccurrences(content, "FIXME")});
        issues_found += 1;
    }

    // Check for unwrap/expect in Rust-style or unwrap() in Zig
    if (std.mem.indexOf(u8, content, "unwrap()") != null or
        std.mem.indexOf(u8, content, "expect(") != null)
    {
        try w.print("⚠️  Found potential panic points (unwrap/expect)\n", .{});
        issues_found += 1;
    }

    // Check line length
    var long_lines: u32 = 0;
    var it = std.mem.splitScalar(u8, content, '\n');
    while (it.next()) |line| {
        if (line.len > 100) long_lines += 1;
    }
    if (long_lines > 0) {
        try w.print("⚠️  {d} lines exceed 100 characters\n", .{long_lines});
        issues_found += 1;
    }

    // Summary
    try w.print("\n✅ Review complete. Found {d} issue(s).\n", .{issues_found});
    try w.flush();

    const output = try arena.dupe(u8, fbs.getWritten());

    return SkillResult{
        .success = true,
        .output = output,
        .execution_time_ms = 0,
    };
}

fn countOccurrences(haystack: []const u8, needle: []const u8) u32 {
    var count: u32 = 0;
    var start: usize = 0;
    while (std.mem.indexOfPos(u8, haystack, start, needle)) |pos| {
        count += 1;
        start = pos + needle.len;
    }
    return count;
}

/// Get skill definition
pub fn getSkill() Skill {
    return .{
        .id = SKILL_ID,
        .name = SKILL_NAME,
        .description = SKILL_DESCRIPTION,
        .version = SKILL_VERSION,
        .category = .review,
        .params = params,
        .execute_fn = execute,
    };
}
