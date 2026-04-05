//! Built-in Skills Registration
//! Registers all built-in skills with the skill registry

const std = @import("std");
const skills = @import("./root.zig");
const SkillRegistry = skills.SkillRegistry;

// Import all built-in skills
const code_review = @import("code_review.zig");
const refactor = @import("refactor.zig");
const test_gen = @import("test_gen.zig");
const doc_gen = @import("doc_gen_dsl.zig");
const debug = @import("debug_dsl.zig");
const token_optimize = @import("token_optimize.zig");

/// Register all built-in skills with the registry
pub fn registerAll(registry: *SkillRegistry) !void {
    try registry.register(code_review.getSkill());
    try registry.register(refactor.getSkill());
    try registry.register(test_gen.getSkill());
    try registry.register(doc_gen.getSkill());
    try registry.register(debug.getSkill());
    
    // RTK Token Optimizer
    try registry.register(token_optimize.getSkill());
}

/// Get list of all built-in skill IDs
pub fn getBuiltinSkillIds() []const []const u8 {
    return &[_][]const u8{
        code_review.SKILL_ID,
        refactor.SKILL_ID,
        test_gen.SKILL_ID,
        doc_gen.SKILL_ID,
        debug.SKILL_ID,
        token_optimize.SKILL_ID,
    };
}

/// Get skill info by ID
pub fn getSkillInfo(skill_id: []const u8) ?SkillInfo {
    if (std.mem.eql(u8, skill_id, code_review.SKILL_ID)) {
        return .{
            .id = code_review.SKILL_ID,
            .name = code_review.SKILL_NAME,
            .description = code_review.SKILL_DESCRIPTION,
            .version = code_review.SKILL_VERSION,
        };
    }
    if (std.mem.eql(u8, skill_id, refactor.SKILL_ID)) {
        return .{
            .id = refactor.SKILL_ID,
            .name = refactor.SKILL_NAME,
            .description = refactor.SKILL_DESCRIPTION,
            .version = refactor.SKILL_VERSION,
        };
    }
    if (std.mem.eql(u8, skill_id, test_gen.SKILL_ID)) {
        return .{
            .id = test_gen.SKILL_ID,
            .name = test_gen.SKILL_NAME,
            .description = test_gen.SKILL_DESCRIPTION,
            .version = test_gen.SKILL_VERSION,
        };
    }
    if (std.mem.eql(u8, skill_id, doc_gen.SKILL_ID)) {
        return .{
            .id = doc_gen.SKILL_ID,
            .name = doc_gen.SKILL_NAME,
            .description = doc_gen.SKILL_DESCRIPTION,
            .version = doc_gen.SKILL_VERSION,
        };
    }
    if (std.mem.eql(u8, skill_id, debug.SKILL_ID)) {
        return .{
            .id = debug.SKILL_ID,
            .name = debug.SKILL_NAME,
            .description = debug.SKILL_DESCRIPTION,
            .version = debug.SKILL_VERSION,
        };
    }
    if (std.mem.eql(u8, skill_id, token_optimize.SKILL_ID)) {
        return .{
            .id = token_optimize.SKILL_ID,
            .name = token_optimize.SKILL_NAME,
            .description = token_optimize.SKILL_DESCRIPTION,
            .version = token_optimize.SKILL_VERSION,
        };
    }
    return null;
}

pub const SkillInfo = struct {
    id: []const u8,
    name: []const u8,
    description: []const u8,
    version: []const u8,
};
