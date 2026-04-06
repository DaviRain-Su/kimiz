//! Skill Generator - Auto-generate Zig skills from natural language descriptions
//! T-100: Establish auto skill generation pipeline

const std = @import("std");
const skills = @import("./root.zig");
const ai = @import("../ai/root.zig");
const core = @import("../core/root.zig");
const config = @import("../config.zig");
const utils = @import("../utils/root.zig");

pub const Generator = struct {
    allocator: std.mem.Allocator,
    ai_client: ai.Ai,
    template: []const u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        const template = try loadTemplate(allocator);
        return .{
            .allocator = allocator,
            .ai_client = ai.Ai.init(allocator),
            .template = template,
        };
    }

    pub fn deinit(self: *Self) void {
        self.ai_client.deinit();
        self.allocator.free(self.template);
    }

    /// Generate a skill from description with up to `max_retries` compile fixes
    pub fn generate(self: *Self, name: []const u8, description: []const u8, max_retries: u32) !void {
        std.debug.print("Generating skill '{s}' from description...\n", .{name});

        var prompt_buf: std.ArrayList(u8) = .empty;
        defer prompt_buf.deinit(self.allocator);

        try self.buildPrompt(name, description, &prompt_buf);

        var attempt: u32 = 0;
        while (attempt <= max_retries) : (attempt += 1) {
            if (attempt > 0) {
                std.debug.print("Retrying compilation fix ({d}/{d})...\n", .{ attempt, max_retries });
                const errors = try self.readLastCompileErrors();
                defer self.allocator.free(errors);
                try prompt_buf.appendSlice(self.allocator, "\n\nPrevious attempt failed with these Zig compilation errors:\n");
                try prompt_buf.appendSlice(self.allocator, errors);
                try prompt_buf.appendSlice(self.allocator, "\n\nFix the code and regenerate ONLY the corrected Zig source.\n");
            }

            const code = try self.callLlm(prompt_buf.items);
            defer self.allocator.free(code);

            try self.writeSkillFile(name, code);
            try updateRegistry(self.allocator, name);

            const compile_ok = try self.compileTest();
            if (compile_ok) {
                std.debug.print("✅ Skill '{s}' generated and compiled successfully.\n", .{name});
                return;
            }
        }

        return error.MaxRetriesExceeded;
    }

    fn buildPrompt(self: *Self, name: []const u8, description: []const u8, out: *std.ArrayList(u8)) !void {
        const upper_snake = try toUpperSnake(self.allocator, name);
        defer self.allocator.free(upper_snake);

        const pascal = try toPascalCase(self.allocator, name);
        defer self.allocator.free(pascal);

        var replaced = try replaceAll(self.allocator, self.template, "{{NAME}}", upper_snake);
        defer self.allocator.free(replaced);

        replaced = try replaceAll(self.allocator, replaced, "{{Name}}", pascal);
        defer self.allocator.free(replaced);

        replaced = try replaceAll(self.allocator, replaced, "{{kebab-name}}", name);
        defer self.allocator.free(replaced);

        replaced = try replaceAll(self.allocator, replaced, "{{DESCRIPTION}}", description);
        defer self.allocator.free(replaced);

        try out.appendSlice(self.allocator, replaced);
    }

    fn callLlm(self: *Self, prompt: []const u8) ![]u8 {
        var cfg = try config.Config.init(self.allocator);
        defer cfg.deinit();
        try cfg.loadFromEnv();

        if (!cfg.hasAnyApiKey()) {
            return error.NoApiKeyConfigured;
        }

        const model = ai.models_registry.getModelById(cfg.default_model) orelse return error.ModelNotFound;

        // Create messages using new Zig 0.16 Message API
        const system_content = &[_]core.UserContentBlock{.{ .text = "You are a Zig code generator." }};
        const user_content = &[_]core.UserContentBlock{.{ .text = prompt }};
        
        const system_msg = core.Message{ .user = .{ .content = system_content } };
        const user_msg = core.Message{ .user = .{ .content = user_content } };
        const messages = &[_]core.Message{ system_msg, user_msg };

        const ctx = core.Context{
            .model = model,
            .messages = messages,
            .temperature = cfg.default_temperature,
            .max_tokens = cfg.default_max_tokens,
        };

        const response = try self.ai_client.complete(ctx);
        defer response.deinit(self.allocator);

        var text_buf: std.ArrayList(u8) = .empty;
        defer text_buf.deinit(self.allocator);
        for (response.content) |block| {
            switch (block) {
                .text => |t| try text_buf.appendSlice(self.allocator, t.text),
                else => {},
            }
        }

        const raw = try text_buf.toOwnedSlice(self.allocator);
        defer self.allocator.free(raw);
        return try extractCodeBlock(self.allocator, raw);
    }

    fn writeSkillFile(_: *Self, name: []const u8, code: []const u8) !void {
        const path = try std.fmt.allocPrint(std.heap.page_allocator, "src/skills/auto/auto_{s}.zig", .{name});
        defer std.heap.page_allocator.free(path);

        // Use utils to write file (Zig 0.16 compatible)
        try utils.writeFile(path, code);
    }

    fn compileTest(_: *Self) !bool {
        const io = @import("../utils/root.zig").getIo() catch return false;
        const result = std.process.run(std.heap.page_allocator, io, .{
            .argv = &.{ "zig", "build", "test" },        }) catch return false;
        defer {
            std.heap.page_allocator.free(result.stdout);
            std.heap.page_allocator.free(result.stderr);
        }

        if (result.term == .exited and result.term.exited == 0) {
            return true;
        }

        // Use utils to write error file (Zig 0.16 compatible)
        utils.writeFile(".zig-build-errors.txt", result.stderr) catch {};
        return false;
    }

    fn readLastCompileErrors(_: *Self) ![]u8 {
        const content = utils.readFileAlloc(std.heap.page_allocator, ".zig-build-errors.txt", 256 * 1024) catch {
            return try std.heap.page_allocator.dupe(u8, "Unknown compilation error.");
        };
        return content;
    }
};

// ============================================================================
// Utility Functions
// ============================================================================

fn loadTemplate(allocator: std.mem.Allocator) ![]const u8 {
    // Use utils to read template file (Zig 0.16 compatible)
    return try utils.readFileAlloc(allocator, "src/skills/auto/TEMPLATE.md", 64 * 1024);
}

fn replaceAll(allocator: std.mem.Allocator, haystack: []const u8, needle: []const u8, replacement: []const u8) ![]u8 {
    var count: usize = 0;
    var i: usize = 0;
    while (std.mem.indexOfPos(u8, haystack, i, needle)) |pos| {
        count += 1;
        i = pos + needle.len;
    }
    if (count == 0) return try allocator.dupe(u8, haystack);

    const new_len = haystack.len - (needle.len * count) + (replacement.len * count);
    var result = try allocator.alloc(u8, new_len);
    var dst: usize = 0;
    i = 0;
    while (std.mem.indexOfPos(u8, haystack, i, needle)) |pos| {
        @memcpy(result[dst .. dst + pos - i], haystack[i..pos]);
        dst += pos - i;
        @memcpy(result[dst .. dst + replacement.len], replacement);
        dst += replacement.len;
        i = pos + needle.len;
    }
    @memcpy(result[dst..], haystack[i..]);
    return result;
}

fn extractCodeBlock(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    const fence = "```zig\n";
    if (std.mem.indexOf(u8, text, fence)) |start| {
        const code_start = start + fence.len;
        if (std.mem.indexOfPos(u8, text, code_start, "\n```")) |end| {
            return try allocator.dupe(u8, text[code_start..end]);
        }
    }
    const plain_fence = "```\n";
    if (std.mem.indexOf(u8, text, plain_fence)) |start| {
        const code_start = start + plain_fence.len;
        if (std.mem.indexOfPos(u8, text, code_start, "\n```")) |end| {
            return try allocator.dupe(u8, text[code_start..end]);
        }
    }
    const trimmed = std.mem.trim(u8, text, " \n\r\t");
    return try allocator.dupe(u8, trimmed);
}

fn toUpperSnake(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    var buf = try allocator.alloc(u8, name.len);
    for (name, 0..) |c, idx| {
        buf[idx] = if (c == '-') '_' else std.ascii.toUpper(c);
    }
    return buf;
}

fn toPascalCase(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    var parts = std.mem.splitScalar(u8, name, '-');
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(allocator);
    while (parts.next()) |part| {
        if (part.len == 0) continue;
        try buf.append(allocator, std.ascii.toUpper(part[0]));
        try buf.appendSlice(allocator, part[1..]);
    }
    return try buf.toOwnedSlice(allocator);
}

// ============================================================================
// Registry Updater
// ============================================================================

pub fn updateRegistry(allocator: std.mem.Allocator, name: []const u8) !void {
    _ = name;
    // Use utils to open directory (Zig 0.16 compatible)
    const io = try utils.getIo();
    const auto_dir = try utils.openDir("src/skills/auto", .{ .iterate = true });
    defer auto_dir.close(io);

    var files: std.ArrayList([]const u8) = .empty;
    defer {
        for (files.items) |f| allocator.free(f);
        files.deinit(allocator);
    }

    var it = auto_dir.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.startsWith(u8, entry.name, "auto_")) continue;
        if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;
        if (std.mem.eql(u8, entry.name, "registry.zig")) continue;
        try files.append(allocator, try allocator.dupe(u8, entry.name));
    }

    var reg_buf: std.ArrayList(u8) = .empty;
    defer reg_buf.deinit(allocator);

    try reg_buf.appendSlice(allocator,
        \\//! Auto-generated skill registry
        \\//! This file is updated by src/skills/generator.zig when new auto skills are created
        \\
        \\const skills = @import("../root.zig");
        \\
        \\pub fn registerAutoSkills(registry: *skills.SkillRegistry) !void {
        \\    @setEvalBranchQuota(10000);
        \\
    );

    for (files.items) |filename| {
        const line = try std.fmt.allocPrint(allocator, "    try registry.register(@import(\"{s}\").getSkill());\n", .{filename});
        defer allocator.free(line);
        try reg_buf.appendSlice(allocator, line);
    }

    try reg_buf.appendSlice(allocator, "}\n");

    // Use utils to write registry file (Zig 0.16 compatible)
    try utils.writeFile("src/skills/auto/registry.zig", reg_buf.items);
}
