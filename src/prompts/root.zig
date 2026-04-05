//! kimiz-prompts - Prompt Engineering Module
//! Prompt templates, optimization, and versioning

const std = @import("std");

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

    pub fn registerBuiltin(self: *PromptRegistry) !void {
        // System prompt
        try self.templates.put("system", .{
            .id = "system",
            .name = "System Prompt",
            .description = "Base system prompt",
            .version = "1.0.0",
            .template = "You are kimiz, an AI coding assistant. {context}",
            .variables = &[_][]const u8{"context"},
            .category = .system,
        });
    }
};
