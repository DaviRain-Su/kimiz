//! Debug Skill - DSL version (T-103 SPIKE)
const std = @import("std");
const skills = @import("./root.zig");

fn debugHandler(input: struct {
    filepath: []const u8,
    error_message: []const u8,
    context: ?[]const u8 = null,
}) struct {
    success: bool,
    output: []const u8,
} {
    var buf: [2048]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);

    w.print("🔍 Debug Analysis: {s}\n", .{input.filepath}) catch {};
    w.print("Error: {s}\n\n", .{input.error_message}) catch {};

    if (input.context) |ctx| {
        w.print("Context: {s}\n\n", .{ctx}) catch {};
    }

    var suggestions: u32 = 0;
    const msg = input.error_message;

    if (std.mem.indexOf(u8, msg, "undefined") != null) {
        w.print("📌 Analysis: Possible null/undefined value issue\n", .{}) catch {};
        suggestions += 1;
    }
    if (std.mem.indexOf(u8, msg, "out of bounds") != null) {
        w.print("📌 Analysis: Array index out of bounds\n", .{}) catch {};
        suggestions += 1;
    }
    if (std.mem.indexOf(u8, msg, "memory") != null) {
        w.print("📌 Analysis: Memory allocation issue\n", .{}) catch {};
        suggestions += 1;
    }
    if (std.mem.indexOf(u8, msg, "type mismatch") != null) {
        w.print("📌 Analysis: Type mismatch\n", .{}) catch {};
        suggestions += 1;
    }

    w.print("\n✅ Analysis complete. Found {d} potential issue(s).\n", .{suggestions}) catch {};

    return .{
        .success = true,
        .output = w.buffered(),
    };
}

pub const DebugDslSkill = skills.defineSkill(.{
    .name = "debug",
    .description = "Helps analyze errors and debug code issues (DSL prototype)",
    .input = struct {
        filepath: []const u8,
        error_message: []const u8,
        context: ?[]const u8 = null,
    },
    .output = struct {
        success: bool,
        output: []const u8,
    },
    .handler = debugHandler,
});

// Compatibility exports for builtin.zig
pub const SKILL_ID = DebugDslSkill.id;
pub const SKILL_NAME = DebugDslSkill.name;
pub const SKILL_DESCRIPTION = DebugDslSkill.description;
pub const SKILL_VERSION = DebugDslSkill.version;

pub fn getSkill() skills.Skill {
    return DebugDslSkill.toSkill();
}
