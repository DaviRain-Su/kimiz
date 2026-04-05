//! DocGen Skill - DSL version (T-103 SPIKE)
const std = @import("std");
const skills = @import("./root.zig");

fn docGenHandler(input: struct {
    filepath: []const u8,
    format: ?[]const u8 = null,
}) struct {
    success: bool,
    output: []const u8,
} {
    const fmt = input.format orelse "zigdoc";
    var buf: [4096]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);

    w.print("Documentation Generation: {s}\n", .{input.filepath}) catch {};
    w.print("Format: {s}\n\n", .{fmt}) catch {};
    w.writeAll("📝 Generated Documentation:\n\n") catch {};

    if (std.mem.eql(u8, fmt, "zigdoc")) {
        w.writeAll("```zig\n") catch {};
        w.writeAll("/// Brief description of the function.\n") catch {};
        w.writeAll("///\n") catch {};
        w.writeAll("/// Detailed description explaining what\n") catch {};
        w.writeAll("/// the function does and its behavior.\n") catch {};
        w.writeAll("///\n") catch {};
        w.writeAll("/// Parameters:\n") catch {};
        w.writeAll("///   - param1: Description of param1\n") catch {};
        w.writeAll("///   - param2: Description of param2\n") catch {};
        w.writeAll("///\n") catch {};
        w.writeAll("/// Returns:\n") catch {};
        w.writeAll("///   Description of return value\n") catch {};
        w.writeAll("///\n") catch {};
        w.writeAll("/// Errors:\n") catch {};
        w.writeAll("///   - Error1: When this error occurs\n") catch {};
        w.writeAll("///   - Error2: When this error occurs\n") catch {};
        w.writeAll("```\n") catch {};
    } else {
        w.writeAll("```markdown\n") catch {};
        w.writeAll("## Function Name\n\n") catch {};
        w.writeAll("Brief description.\n\n") catch {};
        w.writeAll("### Parameters\n\n") catch {};
        w.writeAll("- `param1`: Description\n") catch {};
        w.writeAll("- `param2`: Description\n\n") catch {};
        w.writeAll("### Returns\n\n") catch {};
        w.writeAll("Description of return value.\n\n") catch {};
        w.writeAll("### Example\n\n") catch {};
        w.writeAll("```zig\n") catch {};
        w.writeAll("const result = function_name(args);\n") catch {};
        w.writeAll("```\n") catch {};
        w.writeAll("```\n") catch {};
    }

    w.writeAll("\n✅ Documentation template generated.\n") catch {};

    return .{
        .success = true,
        .output = w.buffered(),
    };
}

pub const DocGenDslSkill = skills.defineSkill(.{
    .name = "doc-gen",
    .description = "Generates documentation comments for functions and modules (DSL prototype)",
    .input = struct {
        filepath: []const u8,
        format: ?[]const u8 = null,
    },
    .output = struct {
        success: bool,
        output: []const u8,
    },
    .handler = docGenHandler,
});

pub const SKILL_ID = DocGenDslSkill.id;
pub const SKILL_NAME = DocGenDslSkill.name;
pub const SKILL_DESCRIPTION = DocGenDslSkill.description;
pub const SKILL_VERSION = DocGenDslSkill.version;

pub fn getSkill() skills.Skill {
    return DocGenDslSkill.toSkill();
}
