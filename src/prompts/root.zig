//! kimiz-prompts - Prompt Engineering Module
//! Prompt templates, optimization, and versioning

const std = @import("std");
const log = @import("../utils/log.zig");

pub const loader = @import("loader.zig");

pub const PromptTemplate = struct {
    id: []const u8,
    name: []const u8,
    description: []const u8,
    version: []const u8,
    template: []const u8,
    variables: []const []const u8,
    category: PromptCategory,

    pub const PromptCategory = enum {
        system,
        user,
        tool,
        skill,
        analysis,
    };

    /// Render template with variable substitutions
    /// Variables are in format: {variable_name}
    pub fn render(
        self: PromptTemplate,
        allocator: std.mem.Allocator,
        values: std.StringHashMap([]const u8),
    ) ![]const u8 {
        var result = std.ArrayList(u8).init(allocator);
        errdefer result.deinit();

        var i: usize = 0;
        while (i < self.template.len) {
            if (self.template[i] == '{') {
                // Find closing brace
                const start = i + 1;
                var end = start;
                while (end < self.template.len and self.template[end] != '}') {
                    end += 1;
                }

                if (end < self.template.len) {
                    const var_name = self.template[start..end];
                    
                    // Look up variable value
                    if (values.get(var_name)) |value| {
                        try result.appendSlice(value);
                    } else {
                        // Variable not found - keep original placeholder and log warning
                        try result.appendSlice(self.template[i..end + 1]);
                        log.warn("Prompt template '{s}': variable '{s}' not provided", .{ self.id, var_name });
                    }
                    
                    i = end + 1;
                } else {
                    // No closing brace, copy as-is
                    try result.append(self.template[i]);
                    i += 1;
                }
            } else {
                try result.append(self.template[i]);
                i += 1;
            }
        }

        return try result.toOwnedSlice();
    }

    /// Render with a simple key-value pair array
    pub fn renderSimple(
        self: PromptTemplate,
        allocator: std.mem.Allocator,
        pairs: []const struct { []const u8, []const u8 },
    ) ![]const u8 {
        var values = std.StringHashMap([]const u8).init(allocator);
        defer values.deinit();

        for (pairs) |pair| {
            try values.put(pair[0], pair[1]);
        }

        return try self.render(allocator, values);
    }
};

pub const PromptRegistry = struct {
    allocator: std.mem.Allocator,
    templates: std.StringHashMap(PromptTemplate),

    pub fn init(allocator: std.mem.Allocator) PromptRegistry {
        return .{
            .allocator = allocator,
            .templates = std.StringHashMap(PromptTemplate).init(allocator),
        };
    }

    pub fn deinit(self: *PromptRegistry) void {
        self.templates.deinit();
    }

    pub fn register(self: *PromptRegistry, template: PromptTemplate) !void {
        try self.templates.put(template.id, template);
    }

    pub fn get(self: *PromptRegistry, id: []const u8) ?PromptTemplate {
        return self.templates.get(id);
    }

    pub fn registerBuiltin(self: *PromptRegistry) !void {
        // System prompt
        try self.register(.{
            .id = "system",
            .name = "System Prompt",
            .description = "Base system prompt",
            .version = "1.0.0",
            .template = "You are kimiz, an AI coding assistant. {context}",
            .variables = &[_][]const u8{"context"},
            .category = .system,
        });

        // Code review prompt
        try self.register(.{
            .id = "code_review",
            .name = "Code Review",
            .description = "Review code for best practices and issues",
            .version = "1.0.0",
            .template = 
                \\nPlease review the following code for:
                \\- Best practices
                \\- Potential bugs
                \\- Performance issues
                \\- Style consistency
                \\
                \\Code:
                \\{code}
                \\
                \\Focus areas: {focus}
                ,
            .variables = &[_][]const u8{"code", "focus"},
            .category = .skill,
        });

        // Refactor prompt
        try self.register(.{
            .id = "refactor",
            .name = "Code Refactoring",
            .description = "Refactor code to improve quality",
            .version = "1.0.0",
            .template = 
                \\nRefactor the following code to improve {goal}:
                \\
                \\Original code:
                \\{code}
                \\
                \\Requirements:
                \\- Maintain the same functionality
                \\- Improve {goal}
                \\- Add comments where needed
                ,
            .variables = &[_][]const u8{"code", "goal"},
            .category = .skill,
        });

        // Test generation prompt
        try self.register(.{
            .id = "test_gen",
            .name = "Test Generation",
            .description = "Generate unit tests for code",
            .version = "1.0.0",
            .template = 
                \\nGenerate comprehensive unit tests for the following {language} code:
                \\
                \\Code to test:
                \\{code}
                \\
                \\Requirements:
                \\- Test all public functions
                \\- Include edge cases
                \\- Use {framework} testing framework
                \\- Aim for high coverage
                ,
            .variables = &[_][]const u8{"code", "language", "framework"},
            .category = .skill,
        });

        // Documentation prompt
        try self.register(.{
            .id = "doc_gen",
            .name = "Documentation Generation",
            .description = "Generate documentation for code",
            .version = "1.0.0",
            .template = 
                \\nGenerate {style} documentation for the following code:
                \\
                \\Code:
                \\{code}
                \\
                \\Include:
                \\- Function/class descriptions
                \\- Parameter descriptions
                \\- Return value descriptions
                \\- Usage examples
                ,
            .variables = &[_][]const u8{"code", "style"},
            .category = .skill,
        });

        // Debug prompt
        try self.register(.{
            .id = "debug",
            .name = "Debug Assistant",
            .description = "Help debug code issues",
            .version = "1.0.0",
            .template = 
                \\nHelp debug the following issue:
                \\
                \\Error message:
                \\{error_message}
                \\
                \\Code:
                \\{code}
                \\
                \\Context: {context}
                \\
                \\Please:
                \\1. Analyze the error
                \\2. Identify the root cause
                \\3. Suggest a fix
                \\4. Explain the solution
                ,
            .variables = &[_][]const u8{"error_message", "code", "context"},
            .category = .skill,
        });
    }
};

// ============================================================================
// Tests
// ============================================================================

test "PromptTemplate render with variables" {
    const allocator = std.testing.allocator;

    const template = PromptTemplate{
        .id = "test",
        .name = "Test",
        .description = "Test template",
        .version = "1.0.0",
        .template = "Hello {name}, welcome to {place}!",
        .variables = &[_][]const u8{"name", "place"},
        .category = .user,
    };

    var values = std.StringHashMap([]const u8).init(allocator);
    defer values.deinit();
    try values.put("name", "Alice");
    try values.put("place", "Wonderland");

    const result = try template.render(allocator, values);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello Alice, welcome to Wonderland!", result);
}

test "PromptTemplate render with missing variable" {
    const allocator = std.testing.allocator;

    const template = PromptTemplate{
        .id = "test",
        .name = "Test",
        .description = "Test template",
        .version = "1.0.0",
        .template = "Hello {name}, welcome to {place}!",
        .variables = &[_][]const u8{"name", "place"},
        .category = .user,
    };

    var values = std.StringHashMap([]const u8).init(allocator);
    defer values.deinit();
    try values.put("name", "Alice");
    // 'place' is missing

    const result = try template.render(allocator, values);
    defer allocator.free(result);

    // Missing variable should keep placeholder
    try std.testing.expectEqualStrings("Hello Alice, welcome to {place}!", result);
}

test "PromptTemplate renderSimple" {
    const allocator = std.testing.allocator;

    const template = PromptTemplate{
        .id = "test",
        .name = "Test",
        .description = "Test template",
        .version = "1.0.0",
        .template = "Code:\n{code}\nFocus: {focus}",
        .variables = &[_][]const u8{"code", "focus"},
        .category = .skill,
    };

    const pairs = &[_]struct { []const u8, []const u8 }{
        .{ "code", "fn main() {}" },
        .{ "focus", "performance" },
    };

    const result = try template.renderSimple(allocator, pairs);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Code:\nfn main() {}\nFocus: performance", result);
}

test "PromptRegistry builtin templates" {
    const allocator = std.testing.allocator;

    var registry = PromptRegistry.init(allocator);
    defer registry.deinit();

    try registry.registerBuiltin();

    // Check system prompt exists
    const system = registry.get("system");
    try std.testing.expect(system != null);
    try std.testing.expectEqualStrings("system", system.?.id);

    // Check code_review prompt exists
    const code_review = registry.get("code_review");
    try std.testing.expect(code_review != null);
    try std.testing.expectEqualStrings("code_review", code_review.?.id);
}
