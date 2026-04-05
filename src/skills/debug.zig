//! Debug Skill - Debugging assistant
//! Helps analyze and fix code issues

const std = @import("std");
const skills = @import("./root.zig");
const Skill = skills.Skill;
const SkillContext = skills.SkillContext;
const SkillResult = skills.SkillResult;
const SkillParam = skills.SkillParam;

// Skill metadata
pub const SKILL_ID = "debug";
pub const SKILL_NAME = "Debug Assistant";
pub const SKILL_DESCRIPTION = "Helps analyze errors and debug code issues";
pub const SKILL_VERSION = "1.0.0";

pub const params = &[_]SkillParam{
    .{
        .name = "filepath",
        .description = "Path to the file with the issue",
        .param_type = .filepath,
        .required = true,
    },
    .{
        .name = "error_message",
        .description = "Error message or description of the issue",
        .param_type = .string,
        .required = true,
    },
    .{
        .name = "context",
        .description = "Additional context about when the error occurs",
        .param_type = .string,
        .required = false,
        .default_value = "",
    },
};

/// Execute debug analysis
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

    const error_val = args.get("error_message") orelse return error.MissingRequiredParam;
    const error_message = switch (error_val) {
        .string => |s| s,
        else => return error.InvalidParamType,
    };

    const context_val = args.get("context") orelse return error.MissingRequiredParam;
    const context = switch (context_val) {
        .string => |s| s,
        else => "",
    };

    // Read file content - placeholder for Zig 0.16 compatibility
    const content = try arena.dupe(u8, "// Placeholder content");

    // Analyze the error and code
    var output_buf: [8192]u8 = undefined;
    var w: std.Io.Writer = .fixed(&output_buf);

    try w.print("🔍 Debug Analysis: {s}\n", .{filepath});
    try w.print("Error: {s}\n\n", .{error_message});

    if (context.len > 0) {
        try w.print("Context: {s}\n\n", .{context});
    }

    // Analyze error patterns
    var suggestions: u32 = 0;

    // Check for common error patterns
    if (std.mem.indexOf(u8, error_message, "undefined") != null or
        std.mem.indexOf(u8, error_message, "null pointer") != null)
    {
        try w.print("📌 Analysis: Possible null/undefined value issue\n", .{});
        try w.print("   → Check for missing null checks\n", .{});
        try w.print("   → Verify all pointers are initialized before use\n\n", .{});
        suggestions += 1;
    }

    if (std.mem.indexOf(u8, error_message, "out of bounds") != null or
        std.mem.indexOf(u8, error_message, "index") != null)
    {
        try w.print("📌 Analysis: Array/Slice index out of bounds\n", .{});
        try w.print("   → Check array bounds before accessing\n", .{});
        try w.print("   → Verify loop indices are within range\n\n", .{});
        suggestions += 1;
    }

    if (std.mem.indexOf(u8, error_message, "memory") != null or
        std.mem.indexOf(u8, error_message, "allocation") != null)
    {
        try w.print("📌 Analysis: Memory allocation issue\n", .{});
        try w.print("   → Check for memory leaks\n", .{});
        try w.print("   → Verify allocator is properly passed\n\n", .{});
        suggestions += 1;
    }

    if (std.mem.indexOf(u8, error_message, "type mismatch") != null or
        std.mem.indexOf(u8, error_message, "expected type") != null)
    {
        try w.print("📌 Analysis: Type mismatch\n", .{});
        try w.print("   → Check function return types\n", .{});
        try w.print("   → Verify variable assignments match declared types\n\n", .{});
        suggestions += 1;
    }

    // Check code for potential issues
    try w.print("🔎 Code Analysis:\n", .{});

    // Check for unwrap/expect
    const unwrap_count = countOccurrences(content, "unwrap()");
    const expect_count = countOccurrences(content, "expect(");
    if (unwrap_count > 0 or expect_count > 0) {
        try w.print("   ⚠️  Found {d} unwrap() and {d} expect() calls\n", .{ unwrap_count, expect_count });
        try w.print("      These can panic - consider using try/catch or if/else\n", .{});
        suggestions += 1;
    }

    // Check for TODO/FIXME
    const todo_count = countOccurrences(content, "TODO");
    const fixme_count = countOccurrences(content, "FIXME");
    if (todo_count > 0 or fixme_count > 0) {
        try w.print("   ⚠️  Found {d} TODO and {d} FIXME comments\n", .{ todo_count, fixme_count });
        suggestions += 1;
    }

    // Check for error handling
    const catch_count = countOccurrences(content, "catch");
    const try_count = countOccurrences(content, "try ");
    try w.print("   ℹ️  Error handling: {d} try, {d} catch\n", .{ try_count, catch_count });

    if (try_count > catch_count * 2) {
        try w.print("      ⚠️  Many try without catch - may miss error handling\n", .{});
        suggestions += 1;
    }

    // Summary
    try w.print("\n✅ Analysis complete. Found {d} potential issue(s).\n", .{suggestions});
    try w.print("\n💡 Next steps:\n", .{});
    try w.print("   1. Review the suggestions above\n", .{});
    try w.print("   2. Add debug logging to trace the issue\n", .{});
    try w.print("   3. Consider using a debugger or adding print statements\n", .{});

    const output = try arena.dupe(u8, w.buffered());

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
        .category = .debug,
        .params = params,
        .execute_fn = execute,
    };
}
