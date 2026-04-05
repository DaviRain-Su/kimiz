//! Harness Parser - Parse AGENTS.md and RULES.md files
//! Defines the Harness configuration from markdown files

const std = @import("std");

/// Harness definition parsed from AGENTS.md
pub const Harness = struct {
    allocator: std.mem.Allocator,
    
    // Basic info
    name: []const u8,
    description: []const u8,
    version: []const u8,
    
    // Behavior definition
    behavior: Behavior,
    
    // Constraints
    constraints: Constraints,
    
    // Tools configuration
    tools: ToolConfig,
    
    // Context files to load
    context_files: []const []const u8,
    
    pub fn deinit(self: *Harness) void {
        self.allocator.free(self.name);
        self.allocator.free(self.description);
        self.allocator.free(self.version);
        self.allocator.free(self.behavior.approach);
        
        for (self.constraints.allowed_paths) |path| {
            self.allocator.free(path);
        }
        self.allocator.free(self.constraints.allowed_paths);
        
        for (self.constraints.blocked_paths) |path| {
            self.allocator.free(path);
        }
        self.allocator.free(self.constraints.blocked_paths);
        
        for (self.constraints.blocked_tools) |tool| {
            self.allocator.free(tool);
        }
        self.allocator.free(self.constraints.blocked_tools);
        
        self.allocator.free(self.constraints.require_approval_for);
        
        for (self.tools.default_tools) |tool| {
            self.allocator.free(tool);
        }
        self.allocator.free(self.tools.default_tools);
        
        for (self.tools.bash.blocked_commands) |cmd| {
            self.allocator.free(cmd);
        }
        self.allocator.free(self.tools.bash.blocked_commands);
        
        for (self.context_files) |file| {
            self.allocator.free(file);
        }
        self.allocator.free(self.context_files);
    }
};

pub const Behavior = struct {
    // How the agent should approach tasks
    approach: []const u8,
    
    // Communication style
    style: CommunicationStyle,
    
    // Thinking preferences
    thinking: ThinkingPreference,
};

pub const CommunicationStyle = enum {
    concise,      // Brief, to-the-point responses
    detailed,     // Comprehensive explanations
    socratic,     // Ask questions to guide user
    collaborative, // Work together with user
    
    pub fn fromString(s: []const u8) CommunicationStyle {
        if (std.mem.eql(u8, s, "concise")) return .concise;
        if (std.mem.eql(u8, s, "detailed")) return .detailed;
        if (std.mem.eql(u8, s, "socratic")) return .socratic;
        if (std.mem.eql(u8, s, "collaborative")) return .collaborative;
        return .collaborative; // default
    }
};

pub const ThinkingPreference = struct {
    enabled: bool,
    level: ThinkingLevel,
};

pub const ThinkingLevel = enum {
    minimal,
    low,
    medium,
    high,
    maximum,
    
    pub fn fromString(s: []const u8) ThinkingLevel {
        if (std.mem.eql(u8, s, "minimal")) return .minimal;
        if (std.mem.eql(u8, s, "low")) return .low;
        if (std.mem.eql(u8, s, "medium")) return .medium;
        if (std.mem.eql(u8, s, "high")) return .high;
        if (std.mem.eql(u8, s, "maximum")) return .maximum;
        return .medium; // default
    }
};

pub const Constraints = struct {
    // File system constraints
    allowed_paths: []const []const u8,
    blocked_paths: []const []const u8,
    
    // Tool constraints
    allowed_tools: ?[]const []const u8,  // null = all allowed
    blocked_tools: []const []const u8,
    
    // Execution constraints
    require_approval_for: []const ApprovalTrigger,
    max_iterations: u32,
    timeout_ms: u32,
};

pub const ApprovalTrigger = enum {
    write_file,
    delete_file,
    bash_command,
    network_request,
    tool_execution,
    
    pub fn fromString(s: []const u8) ?ApprovalTrigger {
        if (std.mem.eql(u8, s, "write_file")) return .write_file;
        if (std.mem.eql(u8, s, "delete_file")) return .delete_file;
        if (std.mem.eql(u8, s, "bash_command")) return .bash_command;
        if (std.mem.eql(u8, s, "network_request")) return .network_request;
        if (std.mem.eql(u8, s, "tool_execution")) return .tool_execution;
        return null;
    }
};

pub const ToolConfig = struct {
    // Default tools to enable
    default_tools: []const []const u8,
    
    // Tool-specific configuration
    bash: BashConfig,
    edit: EditConfig,
};

pub const BashConfig = struct {
    allowed_commands: ?[]const []const u8,  // null = all allowed
    blocked_commands: []const []const u8,
    require_confirmation: bool,
};

pub const EditConfig = struct {
    max_file_size: usize,
    backup_before_edit: bool,
};

/// Parse AGENTS.md file
pub fn parseAgentsMd(allocator: std.mem.Allocator, content: []const u8) !Harness {
    var parser = MarkdownParser.init(allocator, content);
    
    // Parse sections
    const name = try parser.extractTitle() orelse try allocator.dupe(u8, "Default Harness");
    errdefer allocator.free(name);
    
    const description = try parser.extractSection("Description") orelse try allocator.dupe(u8, "");
    errdefer allocator.free(description);
    
    // Parse behavior
    const behavior = try parseBehavior(allocator, &parser);
    errdefer allocator.free(behavior.approach);
    
    // Parse constraints
    const constraints = try parseConstraints(allocator, &parser);
    errdefer {
        for (constraints.allowed_paths) |path| allocator.free(path);
        allocator.free(constraints.allowed_paths);
        for (constraints.blocked_paths) |path| allocator.free(path);
        allocator.free(constraints.blocked_paths);
        for (constraints.blocked_tools) |tool| allocator.free(tool);
        allocator.free(constraints.blocked_tools);
        allocator.free(constraints.require_approval_for);
    }
    
    // Parse tools
    const tools = try parseTools(allocator, &parser);
    errdefer {
        for (tools.default_tools) |tool| allocator.free(tool);
        allocator.free(tools.default_tools);
        for (tools.bash.blocked_commands) |cmd| allocator.free(cmd);
        allocator.free(tools.bash.blocked_commands);
    }
    
    // Parse context files
    const context_files = try parseContextFiles(allocator, &parser);
    errdefer {
        for (context_files) |file| allocator.free(file);
        allocator.free(context_files);
    }
    
    return Harness{
        .allocator = allocator,
        .name = name,
        .description = description,
        .version = try allocator.dupe(u8, "1.0.0"),
        .behavior = behavior,
        .constraints = constraints,
        .tools = tools,
        .context_files = context_files,
    };
}

fn parseBehavior(allocator: std.mem.Allocator, parser: *MarkdownParser) !Behavior {
    const approach = try parser.extractSubsection("Behavior", "Approach") 
        orelse try allocator.dupe(u8, "Helpful assistant");
    
    const style_str = try parser.extractSubsection("Behavior", "Communication Style") orelse "collaborative";
    const style = CommunicationStyle.fromString(style_str);
    
    // Parse thinking section
    const thinking_enabled = blk: {
        const thinking_section = try parser.extractSection("Thinking") orelse break :blk false;
        defer allocator.free(thinking_section);
        break :blk std.mem.indexOf(u8, thinking_section, "Enabled: true") != null;
    };
    
    const thinking_level = blk: {
        const thinking_section = try parser.extractSection("Thinking") orelse break :blk ThinkingLevel.medium;
        defer allocator.free(thinking_section);
        if (std.mem.indexOf(u8, thinking_section, "Level:")) |idx| {
            const level_start = idx + 6; // "Level: ".len
            const rest = thinking_section[level_start..];
            const end = std.mem.indexOfAny(u8, rest, "\n\r") orelse rest.len;
            const level_str = std.mem.trim(u8, rest[0..end], " \t");
            break :blk ThinkingLevel.fromString(level_str);
        }
        break :blk ThinkingLevel.medium;
    };
    
    return Behavior{
        .approach = approach,
        .style = style,
        .thinking = .{
            .enabled = thinking_enabled,
            .level = thinking_level,
        },
    };
}

fn parseConstraints(allocator: std.mem.Allocator, parser: *MarkdownParser) !Constraints {
    // Parse allowed paths
    const allowed_paths = try parser.extractList("Constraints", "Allowed Paths", allocator);
    
    // Parse blocked paths
    const blocked_paths = try parser.extractList("Constraints", "Blocked Paths", allocator);
    
    // Parse blocked tools
    const blocked_tools = try parser.extractList("Constraints", "Blocked", allocator);
    
    // Parse approval requirements
    var approval_list = std.ArrayList(ApprovalTrigger).init(allocator);
    defer approval_list.deinit();
    
    if (try parser.extractSubsection("Constraints", "Approval Required")) |approval_section| {
        defer allocator.free(approval_section);
        
        var lines = std.mem.split(u8, approval_section, "\n");
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t-");
            if (std.mem.indexOf(u8, trimmed, ": yes")) |idx| {
                const trigger_name = trimmed[0..idx];
                if (ApprovalTrigger.fromString(trigger_name)) |trigger| {
                    try approval_list.append(trigger);
                }
            }
        }
    }
    
    // Parse limits
    const max_iterations = blk: {
        if (try parser.extractSubsection("Constraints", "Limits")) |limits| {
            defer allocator.free(limits);
            if (std.mem.indexOf(u8, limits, "Max iterations:")) |idx| {
                const num_start = idx + 15;
                const rest = limits[num_start..];
                const end = std.mem.indexOfAny(u8, rest, "\n\r") orelse rest.len;
                const num_str = std.mem.trim(u8, rest[0..end], " \t");
                break :blk std.fmt.parseInt(u32, num_str, 10) catch 50;
            }
        }
        break :blk 50;
    };
    
    const timeout_ms = blk: {
        if (try parser.extractSubsection("Constraints", "Limits")) |limits| {
            defer allocator.free(limits);
            if (std.mem.indexOf(u8, limits, "Timeout:")) |idx| {
                const num_start = idx + 8;
                const rest = limits[num_start..];
                const end = std.mem.indexOfAny(u8, rest, "\n\r") orelse rest.len;
                const num_str = std.mem.trim(u8, rest[0..end], " \t");
                // Parse "30 seconds" -> 30000
                if (std.mem.indexOf(u8, num_str, "second")) |_| {
                    const seconds = std.fmt.parseInt(u32, num_str[0..std.mem.indexOf(u8, num_str, " ").?], 10) catch 30;
                    break :blk seconds * 1000;
                }
            }
        }
        break :blk 30000;
    };
    
    return Constraints{
        .allowed_paths = allowed_paths,
        .blocked_paths = blocked_paths,
        .allowed_tools = null,
        .blocked_tools = blocked_tools,
        .require_approval_for = try approval_list.toOwnedSlice(),
        .max_iterations = max_iterations,
        .timeout_ms = timeout_ms,
    };
}

fn parseTools(allocator: std.mem.Allocator, parser: *MarkdownParser) !ToolConfig {
    // Parse default tools
    const default_tools = try parser.extractList("Tool Permissions", "Allowed", allocator);
    
    // Parse bash config
    var bash_blocked = std.ArrayList([]const u8).init(allocator);
    defer {
        for (bash_blocked.items) |cmd| allocator.free(cmd);
        bash_blocked.deinit();
    }
    
    if (try parser.extractSubsection("Tools Configuration", "Bash")) |bash_section| {
        defer allocator.free(bash_section);
        
        if (std.mem.indexOf(u8, bash_section, "Blocked commands:")) |idx| {
            const list_start = idx + 17;
            const rest = bash_section[list_start..];
            const end = std.mem.indexOfAny(u8, rest, "\n\r") orelse rest.len;
            const list = rest[0..end];
            
            var items = std.mem.split(u8, list, ",");
            while (items.next()) |item| {
                const trimmed = std.mem.trim(u8, item, " \t");
                if (trimmed.len > 0) {
                    try bash_blocked.append(try allocator.dupe(u8, trimmed));
                }
            }
        }
    }
    
    // Parse edit config
    const max_file_size = blk: {
        if (try parser.extractSubsection("Tools Configuration", "Edit")) |edit_section| {
            defer allocator.free(edit_section);
            if (std.mem.indexOf(u8, edit_section, "Max file size:")) |idx| {
                const num_start = idx + 14;
                const rest = edit_section[num_start..];
                const end = std.mem.indexOfAny(u8, rest, "\n\r") orelse rest.len;
                const num_str = std.mem.trim(u8, rest[0..end], " \t");
                // Parse "10MB" -> 10 * 1024 * 1024
                if (std.mem.indexOf(u8, num_str, "MB")) |_| {
                    const mb = std.fmt.parseInt(usize, num_str[0..std.mem.indexOf(u8, num_str, "MB").?], 10) catch 10;
                    break :blk mb * 1024 * 1024;
                }
            }
        }
        break :blk 10 * 1024 * 1024; // 10MB default
    };
    
    const backup = blk: {
        if (try parser.extractSubsection("Tools Configuration", "Edit")) |edit_section| {
            defer allocator.free(edit_section);
            break :blk std.mem.indexOf(u8, edit_section, "Backup before edit: true") != null;
        }
        break :blk true;
    };
    
    return ToolConfig{
        .default_tools = default_tools,
        .bash = .{
            .allowed_commands = null,
            .blocked_commands = try bash_blocked.toOwnedSlice(),
            .require_confirmation = true,
        },
        .edit = .{
            .max_file_size = max_file_size,
            .backup_before_edit = backup,
        },
    };
}

fn parseContextFiles(allocator: std.mem.Allocator, parser: *MarkdownParser) ![]const []const u8 {
    return try parser.extractList("Context Files", null, allocator);
}

/// Markdown parser helper
const MarkdownParser = struct {
    allocator: std.mem.Allocator,
    content: []const u8,
    
    fn init(allocator: std.mem.Allocator, content: []const u8) MarkdownParser {
        return .{
            .allocator = allocator,
            .content = content,
        };
    }
    
    fn extractTitle(self: *MarkdownParser) !?[]const u8 {
        // Find first # line
        var lines = std.mem.split(u8, self.content, "\n");
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (std.mem.startsWith(u8, trimmed, "# ")) {
                return try self.allocator.dupe(u8, std.mem.trim(u8, trimmed[2..], " \t"));
            }
        }
        return null;
    }
    
    fn extractSection(self: *MarkdownParser, section_name: []const u8) !?[]const u8 {
        const pattern = try std.fmt.allocPrint(self.allocator, "## {s}", .{section_name});
        defer self.allocator.free(pattern);
        
        if (std.mem.indexOf(u8, self.content, pattern)) |start| {
            const section_start = start + pattern.len;
            const rest = self.content[section_start..];
            
            // Find next ## or ###
            var end = rest.len;
            if (std.mem.indexOf(u8, rest, "\n## ")) |next| {
                end = next;
            }
            
            const section_content = std.mem.trim(u8, rest[0..end], " \t\n\r");
            return try self.allocator.dupe(u8, section_content);
        }
        
        return null;
    }
    
    fn extractSubsection(self: *MarkdownParser, section_name: []const u8, subsection_name: []const u8) !?[]const u8 {
        if (try self.extractSection(section_name)) |section| {
            defer self.allocator.free(section);
            
            const pattern = try std.fmt.allocPrint(self.allocator, "### {s}", .{subsection_name});
            defer self.allocator.free(pattern);
            
            if (std.mem.indexOf(u8, section, pattern)) |start| {
                const subsection_start = start + pattern.len;
                const rest = section[subsection_start..];
                
                // Find next ### or end
                var end = rest.len;
                if (std.mem.indexOf(u8, rest, "\n### ")) |next| {
                    end = next;
                }
                
                const content = std.mem.trim(u8, rest[0..end], " \t\n\r");
                return try self.allocator.dupe(u8, content);
            }
        }
        
        return null;
    }
    
    fn extractList(self: *MarkdownParser, section_name: ?[]const u8, subsection_name: ?[]const u8, allocator: std.mem.Allocator) ![]const []const u8 {
        var list = std.ArrayList([]const u8).init(allocator);
        errdefer {
            for (list.items) |item| allocator.free(item);
            list.deinit();
        }
        
        var content: []const u8 = undefined;
        var content_owned = false;
        
        if (section_name) |sn| {
            if (subsection_name) |ssn| {
                if (try self.extractSubsection(sn, ssn)) |c| {
                    content = c;
                    content_owned = true;
                } else {
                    return try list.toOwnedSlice();
                }
            } else {
                if (try self.extractSection(sn)) |c| {
                    content = c;
                    content_owned = true;
                } else {
                    return try list.toOwnedSlice();
                }
            }
        } else {
            content = self.content;
        }
        defer if (content_owned) self.allocator.free(content);
        
        // Parse list items (- item or - item: value)
        var lines = std.mem.split(u8, content, "\n");
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (std.mem.startsWith(u8, trimmed, "- ")) {
                const item = std.mem.trim(u8, trimmed[2..], " \t");
                if (item.len > 0) {
                    // Extract just the item name (before : if present)
                    const end = std.mem.indexOf(u8, item, ":") orelse item.len;
                    const item_name = std.mem.trim(u8, item[0..end], " \t");
                    try list.append(try allocator.dupe(u8, item_name));
                }
            }
        }
        
        return try list.toOwnedSlice();
    }
};

/// Load harness from directory
pub fn loadFromDirectory(allocator: std.mem.Allocator, dir: []const u8) !?Harness {
    const agents_path = try std.fs.path.join(allocator, &.{ dir, "AGENTS.md" });
    defer allocator.free(agents_path);
    
    const content = std.fs.cwd().readFileAlloc(allocator, agents_path, 1024 * 1024) catch |err| {
        if (err == error.FileNotFound) {
            return null;  // No AGENTS.md found
        }
        return err;
    };
    defer allocator.free(content);
    
    return try parseAgentsMd(allocator, content);
}

/// Find and load nearest AGENTS.md (walking up directory tree)
pub fn findAndLoad(allocator: std.mem.Allocator, start_dir: []const u8) !?Harness {
    // Try current directory first
    if (try loadFromDirectory(allocator, start_dir)) |harness| {
        return harness;
    }
    
    // Walk up directory tree
    var current = start_dir;
    while (true) {
        const parent = std.fs.path.dirname(current) orelse break;
        if (try loadFromDirectory(allocator, parent)) |harness| {
            return harness;
        }
        current = parent;
    }
    
    // Try global config
    const home = std.process.getEnvVarOwned(allocator, "HOME") catch return null;
    defer allocator.free(home);
    const global_config = try std.fs.path.join(allocator, &.{ home, ".kimiz" });
    defer allocator.free(global_config);
    
    return try loadFromDirectory(allocator, global_config);
}

// ============================================================================
// Tests
// ============================================================================

test "parse harness from AGENTS.md" {
    const allocator = std.testing.allocator;
    
    const content = 
        \\# Test Harness
        \\
        \\## Description
        \\This is a test harness.
        \\
        \\## Behavior
        \\
        \\### Approach
        \\Helpful assistant
        \\
        \\### Communication Style
        \\collaborative
        \\
        \\## Constraints
        \\
        \\### Allowed Paths
        \\- /home/user/project
        \\- /tmp
        \\
        \\### Blocked Paths
        \\- /etc
        \\
        \\### Limits
        \\- Max iterations: 100
        \\- Timeout: 60 seconds
    ;
    
    var harness = try parseAgentsMd(allocator, content);
    defer harness.deinit();
    
    try std.testing.expectEqualStrings("Test Harness", harness.name);
    try std.testing.expectEqualStrings("This is a test harness.", harness.description);
    try std.testing.expectEqualStrings("Helpful assistant", harness.behavior.approach);
    try std.testing.expectEqual(@as(usize, 2), harness.constraints.allowed_paths.len);
    try std.testing.expectEqual(@as(u32, 100), harness.constraints.max_iterations);
    try std.testing.expectEqual(@as(u32, 60000), harness.constraints.timeout_ms);
}

test "load from non-existent directory" {
    const allocator = std.testing.allocator;
    
    const result = try loadFromDirectory(allocator, "/non/existent/path");
    try std.testing.expect(result == null);
}

test "communication style parsing" {
    try std.testing.expectEqual(CommunicationStyle.concise, CommunicationStyle.fromString("concise"));
    try std.testing.expectEqual(CommunicationStyle.detailed, CommunicationStyle.fromString("detailed"));
    try std.testing.expectEqual(CommunicationStyle.collaborative, CommunicationStyle.fromString("collaborative"));
    try std.testing.expectEqual(CommunicationStyle.collaborative, CommunicationStyle.fromString("unknown"));
}

test "thinking level parsing" {
    try std.testing.expectEqual(ThinkingLevel.minimal, ThinkingLevel.fromString("minimal"));
    try std.testing.expectEqual(ThinkingLevel.medium, ThinkingLevel.fromString("medium"));
    try std.testing.expectEqual(ThinkingLevel.high, ThinkingLevel.fromString("high"));
    try std.testing.expectEqual(ThinkingLevel.medium, ThinkingLevel.fromString("unknown"));
}
