//! Knowledge Base - FEAT-014 Knowledge Base
//! Load and query AGENTS.md content for agent context

const std = @import("std");
const utils = @import("../utils/root.zig");

/// A section within the knowledge base
pub const KnowledgeSection = struct {
    /// Section name/title
    name: []const u8,
    /// Section content
    content: []const u8,
    /// Subsections if any
    subsections: std.ArrayList(KnowledgeSection),

    const Self = @This();

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.content);
        for (self.subsections.items) |*subsection| {
            subsection.deinit(allocator);
        }
        self.subsections.deinit();
    }

    /// Get a subsection by name
    pub fn getSubsection(self: Self, name: []const u8) ?KnowledgeSection {
        for (self.subsections.items) |subsection| {
            if (std.mem.eql(u8, subsection.name, name)) {
                return subsection;
            }
        }
        return null;
    }
};

/// Knowledge base containing parsed AGENTS.md content
pub const KnowledgeBase = struct {
    allocator: std.mem.Allocator,
    /// Raw content of the file
    raw_content: []const u8,
    /// Parsed sections
    sections: std.ArrayList(KnowledgeSection),
    /// Metadata extracted from the file
    metadata: std.StringHashMap([]const u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .raw_content = &.{},
            .sections = std.ArrayList(KnowledgeSection).init(allocator),
            .metadata = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.raw_content);

        for (self.sections.items) |*section| {
            section.deinit(self.allocator);
        }
        self.sections.deinit();

        var metadata_iter = self.metadata.iterator();
        while (metadata_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.metadata.deinit();
    }

    /// Load knowledge base from AGENTS.md file
    pub fn loadFromFile(self: *Self, path: []const u8) !void {
        // Clear existing content
        self.deinit();
        self.* = Self.init(self.allocator);

        // Read file content (Zig 0.16 compatible)
        const content = try utils.readFileAlloc(self.allocator, path, 1024 * 1024);
        self.raw_content = content;

        // Parse the content
        try self.parseContent();
    }

    /// Load from string content directly
    pub fn loadFromString(self: *Self, content: []const u8) !void {
        // Clear existing content
        self.deinit();
        self.* = Self.init(self.allocator);

        // Copy content
        self.raw_content = try self.allocator.dupe(u8, content);

        // Parse the content
        try self.parseContent();
    }

    /// Parse AGENTS.md content into sections
    fn parseContent(self: *Self) !void {
        var lines = std.mem.splitScalar(u8, self.raw_content, '\n');

        var current_section: ?*KnowledgeSection = null;
        var section_content = std.ArrayList(u8).init(self.allocator);
        defer section_content.deinit();

        while (lines.next()) |line| {
            // Check for header (## or ###)
            if (std.mem.startsWith(u8, line, "## ") or std.mem.startsWith(u8, line, "### ")) {
                // Save previous section if exists
                if (current_section != null) {
                    const content_copy = try self.allocator.dupe(u8, section_content.items);
                    current_section.?.content = content_copy;
                    section_content.clearRetainingCapacity();
                }

                // Extract section name
                const header_prefix_len: usize = if (std.mem.startsWith(u8, line, "### ")) 4 else 3;
                const name = std.mem.trim(u8, line[header_prefix_len..], " \r\t");
                const name_copy = try self.allocator.dupe(u8, name);

                // Create new section
                const section = KnowledgeSection{
                    .name = name_copy,
                    .content = &.{},
                    .subsections = std.ArrayList(KnowledgeSection).init(self.allocator),
                };

                try self.sections.append(section);
                current_section = &self.sections.items[self.sections.items.len - 1];
            } else if (current_section != null) {
                // Add line to current section content
                try section_content.appendSlice(line);
                try section_content.append('\n');
            } else {
                // Content before first section goes to metadata
                if (std.mem.indexOf(u8, line, ":")) |colon_idx| {
                    const key = std.mem.trim(u8, line[0..colon_idx], " \r\t");
                    const value = std.mem.trim(u8, line[colon_idx + 1 ..], " \r\t");

                    const key_copy = try self.allocator.dupe(u8, key);
                    const value_copy = try self.allocator.dupe(u8, value);

                    try self.metadata.put(key_copy, value_copy);
                }
            }
        }

        // Save last section content
        if (current_section != null and section_content.items.len > 0) {
            const content_copy = try self.allocator.dupe(u8, section_content.items);
            current_section.?.content = content_copy;
        }
    }

    /// Get a section by name (case-insensitive)
    pub fn getSection(self: Self, name: []const u8) ?KnowledgeSection {
        for (self.sections.items) |section| {
            if (std.ascii.eqlIgnoreCase(section.name, name)) {
                return section;
            }
        }
        return null;
    }

    /// Get section content by name
    pub fn getSectionContent(self: Self, name: []const u8) ?[]const u8 {
        if (self.getSection(name)) |section| {
            return section.content;
        }
        return null;
    }

    /// Get metadata value
    pub fn getMetadata(self: Self, key: []const u8) ?[]const u8 {
        return self.metadata.get(key);
    }

    /// Check if a section exists
    pub fn hasSection(self: Self, name: []const u8) bool {
        return self.getSection(name) != null;
    }

    /// Get all section names
    pub fn getSectionNames(self: Self, allocator: std.mem.Allocator) ![][]const u8 {
        var names = std.ArrayList([]const u8).init(allocator);
        errdefer {
            for (names.items) |name| allocator.free(name);
            names.deinit();
        }

        for (self.sections.items) |section| {
            const name_copy = try allocator.dupe(u8, section.name);
            try names.append(name_copy);
        }

        return names.toOwnedSlice();
    }

    /// Search for sections containing a keyword
    pub fn searchSections(self: Self, keyword: []const u8, allocator: std.mem.Allocator) ![][]const u8 {
        var matches = std.ArrayList([]const u8).init(allocator);
        errdefer matches.deinit();

        for (self.sections.items) |section| {
            if (std.mem.indexOf(u8, section.name, keyword) != null or
                std.mem.indexOf(u8, section.content, keyword) != null)
            {
                const name_copy = try allocator.dupe(u8, section.name);
                try matches.append(name_copy);
            }
        }

        return matches.toOwnedSlice();
    }

    /// Get formatted context for agent
    pub fn getAgentContext(self: Self, allocator: std.mem.Allocator) ![]const u8 {
        var context = std.ArrayList(u8).init(allocator);
        defer context.deinit();

        const writer = context.writer();

        try writer.writeAll("# Agent Knowledge Base\n\n");

        for (self.sections.items) |section| {
            try writer.print("## {s}\n\n", .{section.name});
            try writer.writeAll(section.content);
            try writer.writeAll("\n\n");
        }

        return context.toOwnedSlice();
    }

    /// Get specific sections as context
    pub fn getSectionsContext(
        self: Self,
        section_names: []const []const u8,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        var context = std.ArrayList(u8).init(allocator);
        defer context.deinit();

        const writer = context.writer();

        for (section_names) |name| {
            if (self.getSection(name)) |section| {
                try writer.print("## {s}\n\n", .{section.name});
                try writer.writeAll(section.content);
                try writer.writeAll("\n\n");
            }
        }

        return context.toOwnedSlice();
    }
};

/// Find AGENTS.md file starting from a directory and walking up
pub fn findAgentsMd(start_dir: []const u8, allocator: std.mem.Allocator) !?[]const u8 {
    var dir_path = try allocator.dupe(u8, start_dir);
    defer allocator.free(dir_path);

    const max_iterations = 20;
    var iterations: usize = 0;

    while (iterations < max_iterations) : (iterations += 1) {
        const agents_path = try std.fs.path.join(allocator, &.{ dir_path, "AGENTS.md" });
        errdefer allocator.free(agents_path);

        // Check if file exists (Zig 0.16 compatible)
        if (!utils.fileExists(agents_path)) {
            allocator.free(agents_path);
            // Try parent directory
            const parent = std.fs.path.dirname(dir_path);
            if (parent == null) break;
            const new_path = try allocator.dupe(u8, parent.?);
            allocator.free(dir_path);
            dir_path = new_path;
            continue;
        }

        return agents_path;
    }

    return null;
}

/// Load knowledge base from nearest AGENTS.md
pub fn loadNearest(allocator: std.mem.Allocator, start_dir: []const u8) !?KnowledgeBase {
    if (try findAgentsMd(start_dir, allocator)) |path| {
        defer allocator.free(path);

        var kb = KnowledgeBase.init(allocator);
        try kb.loadFromFile(path);
        return kb;
    }
    return null;
}

// ============================================================================
// Tests
// ============================================================================

test "KnowledgeBase init/deinit" {
    const allocator = std.testing.allocator;
    var kb = KnowledgeBase.init(allocator);
    defer kb.deinit();

    try std.testing.expectEqual(@as(usize, 0), kb.sections.items.len);
}

test "KnowledgeBase loadFromString" {
    const allocator = std.testing.allocator;
    const content =
        \\Name: Test Agent
        \\Version: 1.0
        \\## Overview
        \\This is the overview section.
        \\## Tools
        \\Available tools listed here.
    ;

    var kb = KnowledgeBase.init(allocator);
    defer kb.deinit();

    try kb.loadFromString(content);

    try std.testing.expectEqual(@as(usize, 2), kb.sections.items.len);
    try std.testing.expect(kb.hasSection("Overview"));
    try std.testing.expect(kb.hasSection("Tools"));
}

test "KnowledgeBase getSection" {
    const allocator = std.testing.allocator;
    const content =
        \\## Overview
        \\This is the overview section.
        \\## Tools
        \\Available tools listed here.
    ;

    var kb = KnowledgeBase.init(allocator);
    defer kb.deinit();

    try kb.loadFromString(content);

    const section = kb.getSection("Overview");
    try std.testing.expect(section != null);
    try std.testing.expect(std.mem.indexOf(u8, section.?.content, "overview section") != null);
}

test "KnowledgeBase getSectionContent" {
    const allocator = std.testing.allocator;
    const content =
        \\## Overview
        \\This is the overview.
        \\## Tools
        \\Tool info here.
    ;

    var kb = KnowledgeBase.init(allocator);
    defer kb.deinit();

    try kb.loadFromString(content);

    const section_content = kb.getSectionContent("Overview");
    try std.testing.expect(section_content != null);
    try std.testing.expect(std.mem.indexOf(u8, section_content.?, "overview") != null);
}

test "KnowledgeBase case insensitive section lookup" {
    const allocator = std.testing.allocator;
    const content =
        \\## Overview Section
        \\Content here.
    ;

    var kb = KnowledgeBase.init(allocator);
    defer kb.deinit();

    try kb.loadFromString(content);

    try std.testing.expect(kb.hasSection("overview section"));
    try std.testing.expect(kb.hasSection("OVERVIEW SECTION"));
    try std.testing.expect(kb.hasSection("Overview Section"));
}

test "KnowledgeBase getAgentContext" {
    const allocator = std.testing.allocator;
    const content =
        \\## Overview
        \\Overview content.
    ;

    var kb = KnowledgeBase.init(allocator);
    defer kb.deinit();

    try kb.loadFromString(content);

    const context = try kb.getAgentContext(allocator);
    defer allocator.free(context);

    try std.testing.expect(std.mem.indexOf(u8, context, "Agent Knowledge Base") != null);
    try std.testing.expect(std.mem.indexOf(u8, context, "Overview") != null);
}
