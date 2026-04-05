//! Auto-generated skill registry
//! This file is updated by src/skills/generator.zig when new auto skills are created

const skills = @import("../root.zig");

pub fn registerAutoSkills(registry: *skills.SkillRegistry) !void {
    @setEvalBranchQuota(10000);
    try registry.register(@import("auto_hello.zig").getSkill());
}
