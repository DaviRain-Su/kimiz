//! Harness Runtime - Execute agent within a harness
//! Manages the interaction between harness definition and agent execution

const std = @import("std");
const parser = @import("parser.zig");
const constraints = @import("constraints.zig");
const core = @import("../core/root.zig");
const agent = @import("../agent/root.zig");
const utils = @import("../utils/root.zig");
const skills = @import("../skills/root.zig");

/// Harness runtime
pub const HarnessRuntime = struct {
    allocator: std.mem.Allocator,
    harness: parser.Harness,
    constraint_checker: constraints.ConstraintChecker,
    skill_registry: skills.SkillRegistry,
    skill_engine: skills.SkillEngine,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, harness_def: parser.Harness) !Self {
        var registry = skills.SkillRegistry.init(allocator);
        
        // Register built-in skills
        try skills.registerBuiltinSkills(&registry);
        
        return .{
            .allocator = allocator,
            .harness = harness_def,
            .constraint_checker = constraints.ConstraintChecker.init(allocator, harness_def.constraints),
            .skill_registry = registry,
            .skill_engine = skills.SkillEngine.init(allocator, &registry),
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.harness.deinit();
        self.skill_registry.deinit();
    }
    
    /// Execute a skill within the harness
    pub fn executeSkill(
        self: *Self,
        skill_id: []const u8,
        args: std.json.ObjectMap,
        ctx: skills.SkillContext,
    ) !skills.SkillResult {
        // Check if skill exists
        if (self.skill_registry.get(skill_id) == null) {
            return skills.SkillResult{
                .success = false,
                .output = "",
                .error_message = try std.fmt.allocPrint(
                    self.allocator,
                    "Skill not found: {s}",
                    .{skill_id},
                ),
                .execution_time_ms = 0,
            };
        }
        
        // Check constraints
        const action = constraints.Action{
            .use_tool = .{
                .name = skill_id,
                .args = "",  // Simplified
            },
        };
        
        const action_ctx = constraints.ActionContext{
            .iteration_count = 0,
            .elapsed_ms = 0,
        };
        
        const validation = constraints.validateAction(
            self.constraint_checker,
            action,
            action_ctx,
        );
        
        switch (validation) {
            .allowed => {},
            .blocked => |violation| {
                return skills.SkillResult{
                    .success = false,
                    .output = "",
                    .error_message = try std.fmt.allocPrint(
                        self.allocator,
                        "Constraint violation: {s}",
                        .{violation.message},
                    ),
                    .execution_time_ms = 0,
                };
            },
            .requires_approval => |req| {
                return skills.SkillResult{
                    .success = false,
                    .output = "",
                    .error_message = try std.fmt.allocPrint(
                        self.allocator,
                        "Approval required: {s} - {s}",
                        .{req.description, req.details},
                    ),
                    .execution_time_ms = 0,
                };
            },
        }
        
        // Execute skill
        return try self.skill_engine.execute(skill_id, args, ctx);
    }
    
    /// List available skills
    pub fn listSkills(self: Self) ![]skills.Skill {
        return try self.skill_registry.listAll();
    }
    
    /// Get harness info
    pub fn getInfo(self: Self) HarnessInfo {
        return .{
            .name = self.harness.name,
            .description = self.harness.description,
            .version = self.harness.version,
            .tool_count = self.harness.tools.default_tools.len,
            .skill_count = self.skill_registry.skills.count(),
        };
    }
};

pub const HarnessInfo = struct {
    name: []const u8,
    description: []const u8,
    version: []const u8,
    tool_count: usize,
    skill_count: usize,
};

/// Create runtime from AGENTS.md file
pub fn createFromFile(allocator: std.mem.Allocator, path: []const u8) !?HarnessRuntime {
    const content = utils.readFileAlloc(allocator, path, 1024 * 1024) catch |err| {
        if (err == error.FileNotFound) {
            return null;
        }
        return err;
    };
    defer allocator.free(content);
    
    const harness = try parser.parseAgentsMd(allocator, content);
    return try HarnessRuntime.init(allocator, harness);
}

/// Create runtime with default configuration
pub fn createDefault(allocator: std.mem.Allocator) !HarnessRuntime {
    const default_harness = parser.Harness{
        .allocator = allocator,
        .name = try allocator.dupe(u8, "Default"),
        .description = try allocator.dupe(u8, "Default harness configuration"),
        .version = try allocator.dupe(u8, "1.0.0"),
        .behavior = .{
            .approach = try allocator.dupe(u8, "Helpful assistant"),
            .style = .collaborative,
            .thinking = .{
                .enabled = false,
                .level = .medium,
            },
        },
        .constraints = .{
            .allowed_paths = &[_][]const u8{},
            .blocked_paths = &[_][]const u8{},
            .allowed_tools = null,
            .blocked_tools = &[_][]const u8{},
            .require_approval_for = &[_]parser.ApprovalTrigger{.write_file, .bash_command},
            .max_iterations = 50,
            .timeout_ms = 30000,
        },
        .tools = .{
            .default_tools = &[_][]const u8{"read", "write", "edit", "bash", "grep"},
            .bash = .{
                .allowed_commands = null,
                .blocked_commands = &[_][]const u8{"rm -rf /"},
                .require_confirmation = true,
            },
            .edit = .{
                .max_file_size = 10 * 1024 * 1024,
                .backup_before_edit = true,
            },
        },
        .context_files = try allocator.alloc([]const u8, 0),
    };
    
    return try HarnessRuntime.init(allocator, default_harness);
}

// ============================================================================
// Tests
// ============================================================================

test "create default runtime" {
    const allocator = std.testing.allocator;
    
    var runtime = try createDefault(allocator);
    defer runtime.deinit();
    
    const info = runtime.getInfo();
    try std.testing.expectEqualStrings("Default", info.name);
    try std.testing.expect(info.skill_count > 0);
}

test "list skills" {
    const allocator = std.testing.allocator;
    
    var runtime = try createDefault(allocator);
    defer runtime.deinit();
    
    const skill_list = try runtime.listSkills();
    defer allocator.free(skill_list);
    
    try std.testing.expect(skill_list.len > 0);
}
