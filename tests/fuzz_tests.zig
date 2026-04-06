//! Fuzz/Property-based tests for SkillRegistry and AutoRegistry
//! T-113: High-intensity randomized testing to catch boundary conditions

const std = @import("std");
const skills = @import("kimiz").skills;

// ============================================================================
// Fuzz Random Engine
// ============================================================================

fn FuzzRng(comptime Seed: u64) type {
    return struct {
        rng: std.Random.DefaultPrng,
        iter: usize = 0,
        const Self = @This();
        pub fn init() Self {
            const rng = std.Random.DefaultPrng.init(Seed);
            return .{ .rng = rng };
        }
        pub fn nextU32(self: *Self) u32 {
            defer self.iter += 1;
            return self.rng.random().int(u32);
        }
        pub fn nextRange(self: *Self, min: usize, max: usize) usize {
            defer self.iter += 1;
            return min + (self.nextU32() % @as(u32, @intCast(max - min)));
        }
        pub fn coinFlip(self: *Self) bool {
            return (self.nextU32() % 2) == 0;
        }
        pub fn pickCategory(self: *Self) skills.Skill.SkillCategory {
            const cats = [_]skills.Skill.SkillCategory{
                .code, .review, .refactor, .testing, .doc, .debug, .analyze, .misc,
            };
            return cats[self.nextRange(0, cats.len)];
        }
    };
}

fn makeTestRng() FuzzRng(12345) {
    return FuzzRng(12345).init();
}

// ============================================================================
// Fuzz: Random Register/Unregister/Get/Search
// ============================================================================

test "fuzz: SkillRegistry random operations (100k iterations)" {
    const allocator = std.testing.allocator;
    var registry = skills.SkillRegistry.init(allocator);
    defer registry.deinit();

    var rng = makeTestRng();
    var registered_ids: std.ArrayList([]const u8) = .empty;
    defer {
        for (registered_ids.items) |id| allocator.free(id);
        registered_ids.deinit(allocator);
    }

    const iterations = 100_000;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const op = rng.nextRange(0, 10);

        if (op < 4) {
            // REGISTER (40%)
            const id = try std.fmt.allocPrint(allocator, "fuzz-skill-{d}", .{i});
            defer allocator.free(id);

            const skill = createDummySkill(allocator, id, rng.pickCategory()) catch continue;

            registry.register(skill) catch |err| {
                if (err != error.OutOfMemory) unreachable;
                allocator.free(skill.id);
                allocator.free(skill.name);
                allocator.free(skill.description);
                allocator.free(skill.version);
                continue;
            };

            // Property: after register, get must succeed
            try std.testing.expect(registry.get(id) != null);
            const id_copy = try allocator.dupe(u8, id);
            try registered_ids.append(allocator, id_copy);
        } else if (op < 7) {
            // UNREGISTER (30%)
            if (registered_ids.items.len == 0) continue;
            const idx = rng.nextRange(0, registered_ids.items.len);
            const target = registered_ids.items[idx];

            registry.unregister(target);

            // Property: after unregister, get must return null
            try std.testing.expect(registry.get(target) == null);

            allocator.free(target);
            _ = orderedRemovePtr(&registered_ids, idx);
        } else {
            // GET or SEARCH (30%)
            const is_search = rng.coinFlip();
            if (is_search and registered_ids.items.len > 0) {
                // Search with partial name
                const target = registered_ids.items[rng.nextRange(0, registered_ids.items.len)];
                if (std.mem.indexOf(u8, target, "-")) |pos| {
                    const partial = target[0..pos];
                    const results = registry.search(partial) catch continue;
                    defer allocator.free(results);
                    // Property: search results must contain at least the target skill
                    var found = false;
                    for (results) |r| {
                        if (std.mem.eql(u8, r.id, target)) {
                            found = true;
                            break;
                        }
                    }
                    try std.testing.expect(found);
                }
            } else if (registered_ids.items.len > 0) {
                const target = registered_ids.items[rng.nextRange(0, registered_ids.items.len)];
                const found = registry.get(target);
                // Property: get must find all registered skills
                if (found) |skill| {
                    try std.testing.expect(std.mem.eql(u8, skill.id, target));
                } else {
                    try std.testing.expect(false);
                }
            }
        }
    }
}

test "fuzz: SkillRegistry stress - rapid register/unregister same ID" {
    const allocator = std.testing.allocator;
    var registry = skills.SkillRegistry.init(allocator);
    defer registry.deinit();

    var rng = makeTestRng();
    var i: usize = 0;
    while (i < 10_000) : (i += 1) {
        const id = try std.fmt.allocPrint(allocator, "rapid-{d}", .{rng.nextRange(0, 100)});
        defer allocator.free(id);

        if (registry.get(id) == null) {
            const cat = rng.pickCategory();
            const skill = createDummySkill(allocator, id, cat) catch continue;
            registry.register(skill) catch |err| {
                if (err != error.OutOfMemory) unreachable;
                allocator.free(skill.id);
                allocator.free(skill.name);
                allocator.free(skill.description);
                allocator.free(skill.version);
                continue;
            };
            try std.testing.expect(registry.get(id) != null);

            // Immediately unregister
            registry.unregister(id);
            try std.testing.expect(registry.get(id) == null);
        } else {
            registry.unregister(id);
            try std.testing.expect(registry.get(id) == null);
        }
    }
}

test "fuzz: SkillRegistry - register same ID twice does not corrupt state" {
    const allocator = std.testing.allocator;
    var registry = skills.SkillRegistry.init(allocator);
    defer registry.deinit();

    const id = "duplicate-test";
    const cat: skills.Skill.SkillCategory = .misc;

    // Register first time
    const skill1 = createDummySkill(allocator, id, cat) catch return error.OutOfMemory;
    try registry.register(skill1);
    try std.testing.expect(registry.get(id) != null);

    // Register same ID again (should overwrite in HashMap)
    const skill2 = createDummySkillEx(allocator, id, "NewName", cat) catch return error.OutOfMemory;
    try registry.register(skill2);

    // Should still be findable
    const found = registry.get(id);
    try std.testing.expect(found != null);
    try std.testing.expect(found.?.name.len > 0);
}

// ============================================================================
// Fuzz: listByCategory consistency
// ============================================================================

test "fuzz: listByCategory stays consistent with register/unregister" {
    const allocator = std.testing.allocator;
    var registry = skills.SkillRegistry.init(allocator);
    defer registry.deinit();

    var rng = makeTestRng();
    var registered: std.ArrayList(struct { id: []const u8, cat: skills.Skill.SkillCategory }) = .empty;
    defer {
        for (registered.items) |e| allocator.free(e.id);
        registered.deinit(allocator);
    }

    var i: usize = 0;
    while (i < 50_000) : (i += 1) {
        const cat = rng.pickCategory();
        const id = try std.fmt.allocPrint(allocator, "cat-fuzz-{d}", .{i});

        const skill = createDummySkill(allocator, id, cat) catch {
            allocator.free(id);
            continue;
        };
        registry.register(skill) catch {
            allocator.free(id);
            allocator.free(skill.id);
            allocator.free(skill.name);
            allocator.free(skill.description);
            allocator.free(skill.version);
            continue;
        };

        try registered.append(allocator, .{ .id = try allocator.dupe(u8, id), .cat = cat });

        // Periodically verify category counts
        if (i % 5000 == 0) {
            const cats = [_]skills.Skill.SkillCategory{
                .code, .review, .refactor, .testing, .doc, .debug, .analyze, .misc,
            };
            for (cats) |c| {
                const list = registry.listByCategory(c);
                // Count how many registered items have this category
                var expected_count: usize = 0;
                for (registered.items) |e| {
                    if (e.cat == c) expected_count += 1;
                }
                try std.testing.expectEqual(expected_count, list.len);
            }
        }
    }
}

// ============================================================================
// Fuzz: listAll matches HashMap count
// ============================================================================

test "fuzz: listAll returns correct count" {
    const allocator = std.testing.allocator;
    var registry = skills.SkillRegistry.init(allocator);
    defer registry.deinit();

    var rng = makeTestRng();
    var count: usize = 0;
    var i: usize = 0;
    while (i < 10_000) : (i += 1) {
        const id = try std.fmt.allocPrint(allocator, "listall-{d}", .{rng.nextRange(0, 200)});
        defer allocator.free(id);

        if (registry.get(id) == null) {
            const skill = createDummySkill(allocator, id, rng.pickCategory()) catch continue;
            registry.register(skill) catch |err| {
                if (err != error.OutOfMemory) unreachable;
                allocator.free(skill.id);
                allocator.free(skill.name);
                allocator.free(skill.description);
                allocator.free(skill.version);
                continue;
            };
            count += 1;
        } else {
            registry.unregister(id);
            count -= 1;
        }

        // Every 1000 ops, verify listAll count
        if (i % 1000 == 0) {
            const all = registry.listAll() catch continue;
            defer allocator.free(all);
            try std.testing.expectEqual(count, all.len);
        }
    }
}

// ============================================================================
// Fuzz: search with overlapping patterns
// ============================================================================

test "fuzz: search correctness with overlapping patterns" {
    const allocator = std.testing.allocator;
    var registry = skills.SkillRegistry.init(allocator);
    defer registry.deinit();

    // Register skills with known names
    const prefixes = &[_][]const u8{ "alpha", "beta", "gamma", "alpha-beta", "gamma-delta" };
    var i: usize = 0;
    while (i < prefixes.len) : (i += 1) {
        const id = prefixes[i];
        const skill = createDummySkillEx(allocator, id, id, .code) catch continue;
        registry.register(skill) catch continue;
    }

    // Search for "alpha" should find alpha and alpha-beta
    {
        const results = try registry.search("alpha");
        defer allocator.free(results);
        try std.testing.expect(results.len >= 2);
        var alpha_count: usize = 0;
        for (results) |r| {
            if (std.mem.indexOf(u8, r.name, "alpha") != null) alpha_count += 1;
        }
        try std.testing.expect(alpha_count >= 2);
    }

    // Search for nonexistent should return empty
    {
        const results = try registry.search("nonexistent-xyz");
        defer allocator.free(results);
        try std.testing.expectEqual(@as(usize, 0), results.len);
    }
}

// ============================================================================
// Fuzz: SkillEngine execution with random args
// ============================================================================

test "fuzz: SkillEngine executes registered skills safely" {
    const allocator = std.testing.allocator;
    var registry = skills.SkillRegistry.init(allocator);
    defer registry.deinit();

    // Register a simple skill
    const skill = skills.Skill{
        .id = "fuzz-exec",
        .name = "Fuzz Exec",
        .description = "Fuzz test execution skill",
        .version = "1.0",
        .category = .misc,
        .params = &[_]skills.SkillParam{},
        .execute_fn = struct {
            fn exec(
                _: skills.SkillContext,
                _: std.json.ObjectMap,
                alloc: std.mem.Allocator,
            ) anyerror!skills.SkillResult {
                return .{
                    .success = true,
                    .output = try alloc.dupe(u8, "ok"),
                    .execution_time_ms = 1,
                };
            }
        }.exec,
    };
    try registry.register(skill);

    var engine = skills.SkillEngine.init(allocator, &registry);

    var rng = makeTestRng();
    var i: usize = 0;
    while (i < 50_000) : (i += 1) {
        if (rng.coinFlip()) {
            // Execute known skill
            const result = engine.execute("fuzz-exec", .{}, .{
                .allocator = allocator,
                .working_dir = ".",
                .session_id = "test",
            }) catch continue;
            try std.testing.expect(result.success);
            try std.testing.expectEqualStrings("ok", result.output);
            allocator.free(result.output);
        } else {
            // Execute unknown skill - should fail gracefully
            const bad_id = try std.fmt.allocPrint(allocator, "nonexistent-{d}", .{rng.nextU32()});
            defer allocator.free(bad_id);
            const err = engine.execute(bad_id, .{}, .{
                .allocator = allocator,
                .working_dir = ".",
                .session_id = "test",
            });
            try std.testing.expectError(error.SkillNotFound, err);
        }
    }
}

// ============================================================================
// Fuzz: registerBuiltinSkills + AutoRegistry
// ============================================================================

test "fuzz: registerBuiltinSkills is idempotent" {
    const allocator = std.testing.allocator;
    var registry = skills.SkillRegistry.init(allocator);
    defer registry.deinit();

    // Register builtins N times
    // Should not crash or duplicate (HashMap handles dupes)
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        skills.registerBuiltinSkills(&registry) catch continue;
    }

    // Auto hello should be present
    try std.testing.expect(registry.get("auto-hello") != null);

    // Code review should be present
    try std.testing.expect(registry.get("code-review") != null);
}

test "fuzz: search after builtin registration returns valid results" {
    const allocator = std.testing.allocator;
    var registry = skills.SkillRegistry.init(allocator);
    defer registry.deinit();

    try skills.registerBuiltinSkills(&registry);

    // Search should not crash with any pattern
    var rng = makeTestRng();
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        const pattern = switch (rng.nextRange(0, 4)) {
            0 => "",
            1 => "a",
            2 => "code",
            3 => "nonexistent-zzz",
            else => "test",
        };
        const results = registry.search(pattern) catch continue;
        defer allocator.free(results);
        // Every returned skill must actually match
        for (results) |r| {
            try std.testing.expect(
                std.mem.indexOf(u8, r.name, pattern) != null or
                    std.mem.indexOf(u8, r.description, pattern) != null,
            );
        }
    }
}

// ============================================================================
// Helpers
// ============================================================================

fn createDummySkill(
    allocator: std.mem.Allocator,
    id: []const u8,
    category: skills.Skill.SkillCategory,
) !skills.Skill {
    return createDummySkillEx(allocator, id, id, category);
}

fn createDummySkillEx(
    allocator: std.mem.Allocator,
    id: []const u8,
    name: []const u8,
    category: skills.Skill.SkillCategory,
) !skills.Skill {
    return skills.Skill{
        .id = try allocator.dupe(u8, id),
        .name = try allocator.dupe(u8, name),
        .description = try allocator.dupe(u8, "Fuzz test skill"),
        .version = try allocator.dupe(u8, "0.1"),
        .category = category,
        .params = &[_]skills.SkillParam{},
        .execute_fn = struct {
            fn exec(
                _: skills.SkillContext,
                _: std.json.ObjectMap,
                alloc: std.mem.Allocator,
            ) anyerror!skills.SkillResult {
                return .{
                    .success = true,
                    .output = try alloc.dupe(u8, "executed"),
                    .execution_time_ms = 1,
                };
            }
        }.exec,
    };
}

fn orderedRemovePtr(list: *std.ArrayList([]const u8), idx: usize) void {
    _ = list.orderedRemove(idx);
}
