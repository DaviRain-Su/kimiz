//! Skill Generator - Auto-generate Zig skills from natural language descriptions
//! T-100: Establish auto skill generation pipeline

const std = @import("std");
const skills = @import("./root.zig");
const ai = @import("../ai/root.zig");
const core = @import("../core/root.zig");
const config = @import("../config.zig");

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
                // Append compilation errors to prompt
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
        var replaced = try replaceAll(self.allocator, self.template, "{{NAME}}", toUpperSnake(name));
        defer self.allocator.free(replaced);

        replaced = try replaceAll(self.allocator, replaced, "{{Name}}", toPascalCase(name));
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

        var ctx = core.Context{
            .allocator = self.allocator,
            .model = try core.Model.fromString(cfg.default_model),
            .messages = &[_]core.Message{
                .{ .role = .system, .content = "You are a Zig code generator." },
                .{ .role = .user, .content = prompt },
            },
            .temperature = cfg.default_temperature,
            .max_tokens = cfg.default_max_tokens,
        };

        const response = try self.ai_client.complete(ctx);
        defer response.deinit(self.allocator);

        // Extract raw text from assistant message
        var text_buf: std.ArrayList(u8) = .empty;
        defer text_buf.deinit(self.allocator);
        for (response.content) |block| {
            switch (block) {
                .text => |t| try text_buf.appendSlice(self.allocator, t.text),
                else => {},
            }
        }

        const raw = try text_buf.toOwnedSlice(self.allocator);
        const code = try extractCodeBlock(self.allocator, raw);
        self.allocator.free(raw);
        return code;
    }

    fn writeSkillFile(_: *Self, name: []const u8, code: []const u8) !void {
        const path = try std.fmt.allocPrint(std.heap.page_allocator, "src/skills/auto/auto_{s}.zig", .{name});
        defer std.heap.page_allocator.free(path);

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        try file.writeAll(code);
    }

    fn compileTest(_: *Self) !bool {
        const result = std.process.run(.{
            .allocator = std.heap.page_allocator,
            .argv = &.{ "zig", "build", "test" },
        }) catch return false;
        defer {
            std.heap.page_allocator.free(result.stdout);
            std.heap.page_allocator.free(result.stderr);
        }

        if (result.term == .exited and result.term.exited == 0) {
            return true;
        }

        // Save stderr for next retry prompt
        const err_file = std.fs.cwd().createFile(".zig-build-errors.txt", .{}) catch return false;
        defer err_file.close();
        _ = err_file.write(result.stderr) catch {};
        return false;
    }

    fn readLastCompileErrors(_: *Self) ![]u8 {
        const file = std.fs.cwd().openFile(".zig-build-errors.txt", .{}) catch {
            return try std.heap.page_allocator.dupe(u8, "Unknown compilation error.");
        };
        defer file.close();
        return try file.readToEndAlloc(std.heap.page_allocator, 256 * 1024);
    }
};

// ============================================================================
// Utility Functions
// ============================================================================

fn loadTemplate(allocator: std.mem.Allocator) ![]const u8 {
    const file = try std.fs.cwd().openFile("src/skills/auto/TEMPLATE.md", .{});
    defer file.close();
    return try file.readToEndAlloc(allocator, 64 * 1024);
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
    // Try to find ```zig ... ``` block
    const fence = "```zig\n";
    if (std.mem.indexOf(u8, text, fence)) |start| {
        const code_start = start + fence.len;
        if (std.mem.indexOfPos(u8, text, code_start, "\n```")) |end| {
            return try allocator.dupe(u8, text[code_start..end]);
        }
    }
    // Fallback: find plain ``` block
    const plain_fence = "```\n";
    if (std.mem.indexOf(u8, text, plain_fence)) |start| {
        const code_start = start + plain_fence.len;
        if (std.mem.indexOfPos(u8, text, code_start, "\n```")) |end| {
            return try allocator.dupe(u8, text[code_start..end]);
        }
    }
    // No fence found, return trimmed text
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
    const auto_dir = try std.fs.cwd().openDir("src/skills/auto", .{ .iterate = true });
    defer auto_dir.close();

    var files: std.ArrayList([]const u8) = .empty;
    defer {
        for (files.items) |f| allocator.free(f);
        files.deinit(allocator);
    }

    var it = auto_dir.iterate();
    while (try it.next()) |entry| {
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
        \const skills = @import("../root.zig");
        \\
        \pub fn registerAutoSkills(registry: *skills.SkillRegistry) !void {
        \    @setEvalBranchQuota(10000);
        \\
    );

    for (files.items) |filename| {
        const import_name = filename[0 .. filename.len - 4]; // strip .zig
        const line = try std.fmt.allocPrint(allocator, "    try registry.register(@import(\"{s}\").getSkill());\n", .{import_name});
        defer allocator.free(line);
        try reg_buf.appendSlice(allocator, line);
    }

    try reg_buf.appendSlice(allocator, "}\n");

    const reg_file = try std.fs.cwd().createFile("src/skills/auto/registry.zig", .{});
    defer reg_file.close();
    try reg_file.writeAll(reg_buf.items);
}
