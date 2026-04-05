//! kimiz-skills - Skill-Centric Architecture
//! Core module for skill registration, discovery, and execution
//! This is the heart of kimiz's differentiating feature

const std = @import("std");
const core = @import("../core/root.zig");
const agent = @import("../agent/root.zig");

pub const dsl = @import("dsl.zig");
pub const defineSkill = dsl.defineSkill;

// ============================================================================
// Skill Types
// ============================================================================

/// Skill execution context
pub const SkillContext = struct {
    allocator: std.mem.Allocator,
    working_dir: []const u8,
    session_id: []const u8,
};

/// Skill execution result
pub const SkillResult = struct {
    success: bool,
    output: []const u8,
    error_message: ?[]const u8 = null,
    execution_time_ms: i64,
    tokens_used: ?u32 = null,
};

/// Skill parameter definition
pub const SkillParam = struct {
    name: []const u8,
    description: []const u8,
    param_type: ParamType,
    required: bool = true,
    default_value: ?[]const u8 = null,

    pub const ParamType = enum {
        string,
        integer,
        boolean,
        filepath,
        directory,
        code,
        selection,
    };
};

/// Skill metadata and definition
pub const Skill = struct {
    id: []const u8,
    name: []const u8,
    description: []const u8,
    version: []const u8,
    category: SkillCategory,
    params: []const SkillParam,
    execute_fn: *const fn (
        ctx: SkillContext,
        args: std.json.ObjectMap,
        arena: std.mem.Allocator,
    ) anyerror!SkillResult,

    pub const SkillCategory = enum {
        code,
        review,
        refactor,
        testing,
        doc,
        debug,
        analyze,
        misc,
    };
};

// ============================================================================
// Skill Registry
// ============================================================================

pub const SkillRegistry = struct {
    allocator: std.mem.Allocator,
    skills: std.StringHashMap(Skill),
    categories: std.EnumArray(Skill.SkillCategory, std.ArrayListUnmanaged([]const u8)),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .skills = std.StringHashMap(Skill).init(allocator),
            .categories = std.EnumArray(Skill.SkillCategory, std.ArrayListUnmanaged([]const u8)).initFill(
                std.ArrayListUnmanaged([]const u8).empty,
            ),
        };
    }

    pub fn deinit(self: *Self) void {
        // Iterate over all categories manually
        const categories = [_]Skill.SkillCategory{
            .code, .review, .refactor, .testing, .doc, .debug, .analyze, .misc,
        };
        for (categories) |cat| {
            const list = self.categories.get(cat);
            for (list.items) |id| {
                self.allocator.free(id);
            }
            var mutable_list = self.categories.getPtr(cat);
            mutable_list.deinit(self.allocator);
        }
        self.skills.deinit();
    }

    /// Register a skill
    pub fn register(self: *Self, skill: Skill) !void {
        try self.skills.put(skill.id, skill);
        const id_copy = try self.allocator.dupe(u8, skill.id);
        try self.categories.getPtr(skill.category).append(self.allocator, id_copy);
    }

    /// Unregister a skill
    pub fn unregister(self: *Self, skill_id: []const u8) void {
        if (self.skills.get(skill_id)) |skill| {
            const category_list = self.categories.getPtr(skill.category);
            var i: usize = 0;
            while (i < category_list.items.len) {
                if (std.mem.eql(u8, category_list.items[i], skill_id)) {
                    self.allocator.free(category_list.items[i]);
                    _ = category_list.orderedRemove(i);
                } else {
                    i += 1;
                }
            }
        }
        _ = self.skills.remove(skill_id);
    }

    /// Get a skill by ID
    pub fn get(self: *Self, skill_id: []const u8) ?Skill {
        return self.skills.get(skill_id);
    }

    /// List all skills
    pub fn listAll(self: *Self) ![]Skill {
        var list: std.ArrayList(Skill) = .empty;
        defer list.deinit(self.allocator);
        var iter = self.skills.valueIterator();
        while (iter.next()) |skill| {
            try list.append(self.allocator, skill.*);
        }

        return list.toOwnedSlice(self.allocator);
    }

    /// List skills by category
    pub fn listByCategory(self: *Self, category: Skill.SkillCategory) []const []const u8 {
        return self.categories.get(category).items;
    }

    /// Search skills by name/pattern
    pub fn search(self: *Self, pattern: []const u8) ![]Skill {
        var list: std.ArrayList(Skill) = .empty;
        defer list.deinit(self.allocator);

        var iter = self.skills.valueIterator();
        while (iter.next()) |skill| {
            if (std.mem.indexOf(u8, skill.name, pattern) != null or
                std.mem.indexOf(u8, skill.description, pattern) != null)
            {
                try list.append(self.allocator, skill.*);
            }
        }

        return list.toOwnedSlice(self.allocator);
    }
};

// ============================================================================
// Skill Execution Engine
// ============================================================================

pub const SkillEngine = struct {
    registry: *SkillRegistry,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, registry: *SkillRegistry) Self {
        return .{
            .allocator = allocator,
            .registry = registry,
        };
    }

    /// Execute a skill with given arguments
    pub fn execute(
        self: *Self,
        skill_id: []const u8,
        args: std.json.ObjectMap,
        ctx: SkillContext,
    ) !SkillResult {
        const skill = self.registry.get(skill_id) orelse return error.SkillNotFound;

        for (skill.params) |param| {
            if (param.required and !args.contains(param.name)) {
                return SkillResult{
                    .success = false,
                    .output = "",
                    .error_message = try std.fmt.allocPrint(
                        self.allocator,
                        "Missing required parameter: {s}",
                        .{param.name},
                    ),
                    .execution_time_ms = 0,
                };
            }
        }

        // Use the main allocator for the result, not arena
        // This ensures strings survive after the function returns
        const result = skill.execute_fn(ctx, args, self.allocator) catch |err| {
            const elapsed_ms: u64 = 0;
            return SkillResult{
                .success = false,
                .output = "",
                .error_message = try std.fmt.allocPrint(
                    self.allocator,
                    "Execution failed: {s}",
                    .{@errorName(err)},
                ),
                .execution_time_ms = @intCast(elapsed_ms),
            };
        };

        return result;
    }
};

// ============================================================================
// Built-in Skills Registration
// ============================================================================

const builtin = @import("builtin.zig");

pub fn registerBuiltinSkills(registry: *SkillRegistry) !void {
    try builtin.registerAll(registry);
}

// ============================================================================
// Tests
// ============================================================================

test "SkillRegistry basic operations" {
    const allocator = std.testing.allocator;
    var registry = SkillRegistry.init(allocator);
    defer registry.deinit();

    const test_skill = Skill{
        .id = "test-skill",
        .name = "Test Skill",
        .description = "A test skill",
        .version = "1.0.0",
        .category = .misc,
        .params = &[_]SkillParam{},
        .execute_fn = struct {
            fn exec(_: SkillContext, _: std.json.ObjectMap, _: std.mem.Allocator) anyerror!SkillResult {
                return SkillResult{
                    .success = true,
                    .output = "test",
                    .execution_time_ms = 0,
                };
            }
        }.exec,
    };

    try registry.register(test_skill);

    const retrieved = registry.get("test-skill");
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualStrings("Test Skill", retrieved.?.name);
}
