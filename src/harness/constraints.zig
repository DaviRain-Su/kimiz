//! Constraints System - Enforce harness constraints
//! Validates actions against harness rules

const std = @import("std");
const parser = @import("parser.zig");

/// Constraint checker
pub const ConstraintChecker = struct {
    allocator: std.mem.Allocator,
    constraints: parser.Constraints,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, constraints: parser.Constraints) Self {
        return .{
            .allocator = allocator,
            .constraints = constraints,
        };
    }
    
    /// Check if a file path is allowed
    pub fn isPathAllowed(self: Self, path: []const u8) bool {
        // Check blocked paths first
        for (self.constraints.blocked_paths) |blocked| {
            if (std.mem.startsWith(u8, path, blocked)) {
                return false;
            }
        }
        
        // If allowed_paths is empty, all paths are allowed (except blocked)
        if (self.constraints.allowed_paths.len == 0) {
            return true;
        }
        
        // Check if path is in allowed list
        for (self.constraints.allowed_paths) |allowed| {
            if (std.mem.startsWith(u8, path, allowed)) {
                return true;
            }
        }
        
        return false;
    }
    
    /// Check if a tool is allowed
    pub fn isToolAllowed(self: Self, tool_name: []const u8) bool {
        // Check blocked tools
        for (self.constraints.blocked_tools) |blocked| {
            if (std.mem.eql(u8, tool_name, blocked)) {
                return false;
            }
        }
        
        // If allowed_tools is null, all tools are allowed (except blocked)
        if (self.constraints.allowed_tools == null) {
            return true;
        }
        
        // Check if tool is in allowed list
        for (self.constraints.allowed_tools.?) |allowed| {
            if (std.mem.eql(u8, tool_name, allowed)) {
                return true;
            }
        }
        
        return false;
    }
    
    /// Check if approval is required for an action
    pub fn requiresApproval(self: Self, trigger: parser.ApprovalTrigger) bool {
        for (self.constraints.require_approval_for) |approval_trigger| {
            if (approval_trigger == trigger) {
                return true;
            }
        }
        return false;
    }
    
    /// Validate a bash command
    pub fn validateBashCommand(_: Self, command: []const u8, bash_config: parser.BashConfig) ?[]const u8 {
        // Check blocked commands
        for (bash_config.blocked_commands) |blocked| {
            if (std.mem.indexOf(u8, command, blocked) != null) {
                return "Command contains blocked pattern";
            }
        }
        
        // If allowed_commands is specified, check against it
        if (bash_config.allowed_commands) |allowed| {
            var is_allowed = false;
            for (allowed) |a| {
                if (std.mem.startsWith(u8, command, a)) {
                    is_allowed = true;
                    break;
                }
            }
            if (!is_allowed) {
                return "Command not in allowed list";
            }
        }
        
        return null;  // Valid
    }
    
    /// Check iteration limit
    pub fn isWithinIterationLimit(self: Self, current_iteration: u32) bool {
        return current_iteration < self.constraints.max_iterations;
    }
    
    /// Check timeout
    pub fn isWithinTimeout(self: Self, elapsed_ms: u64) bool {
        return elapsed_ms < self.constraints.timeout_ms;
    }
};

/// Constraint violation
pub const ConstraintViolation = struct {
    constraint_type: ConstraintType,
    message: []const u8,
    context: ?[]const u8,
};

pub const ConstraintType = enum {
    path_not_allowed,
    tool_not_allowed,
    command_blocked,
    iteration_limit_exceeded,
    timeout_exceeded,
    approval_required,
};

/// Result of constraint validation
pub const ValidationResult = union(enum) {
    allowed,
    blocked: ConstraintViolation,
    requires_approval: ApprovalRequest,
};

pub const ApprovalRequest = struct {
    trigger: parser.ApprovalTrigger,
    description: []const u8,
    details: []const u8,
};

/// Validate an action against constraints
pub fn validateAction(
    checker: ConstraintChecker,
    action: Action,
    _: ActionContext,
) ValidationResult {
    switch (action) {
        .read_file => |path| {
            if (!checker.isPathAllowed(path)) {
                return .{ .blocked = .{
                    .constraint_type = .path_not_allowed,
                    .message = "Path not allowed",
                    .context = path,
                } };
            }
            return .allowed;
        },
        .write_file => |info| {
            if (!checker.isPathAllowed(info.path)) {
                return .{ .blocked = .{
                    .constraint_type = .path_not_allowed,
                    .message = "Path not allowed",
                    .context = info.path,
                } };
            }
            if (checker.requiresApproval(.write_file)) {
                return .{ .requires_approval = .{
                    .trigger = .write_file,
                    .description = "Write file",
                    .details = info.path,
                } };
            }
            return .allowed;
        },
        .bash_command => |cmd| {
            if (checker.requiresApproval(.bash_command)) {
                return .{ .requires_approval = .{
                    .trigger = .bash_command,
                    .description = "Execute bash command",
                    .details = cmd,
                } };
            }
            return .allowed;
        },
        .use_tool => |tool| {
            if (!checker.isToolAllowed(tool.name)) {
                return .{ .blocked = .{
                    .constraint_type = .tool_not_allowed,
                    .message = "Tool not allowed",
                    .context = tool.name,
                } };
            }
            return .allowed;
        },
    }
}

pub const Action = union(enum) {
    read_file: []const u8,
    write_file: FileWriteInfo,
    bash_command: []const u8,
    use_tool: ToolUseInfo,
};

pub const FileWriteInfo = struct {
    path: []const u8,
    content_length: usize,
};

pub const ToolUseInfo = struct {
    name: []const u8,
    args: []const u8,
};

pub const ActionContext = struct {
    iteration_count: u32,
    elapsed_ms: u64,
};

// ============================================================================
// Tests
// ============================================================================

test "path constraints" {
    const allocator = std.testing.allocator;
    
    const constraints = parser.Constraints{
        .allowed_paths = &[_][]const u8{"/home/user/project"},
        .blocked_paths = &[_][]const u8{"/home/user/project/secret"},
        .allowed_tools = null,
        .blocked_tools = &[_][]const u8{},
        .require_approval_for = &[_]parser.ApprovalTrigger{},
        .max_iterations = 50,
        .timeout_ms = 30000,
    };
    
    const checker = ConstraintChecker.init(allocator, constraints);
    
    try std.testing.expect(checker.isPathAllowed("/home/user/project/src/main.zig"));
    try std.testing.expect(!checker.isPathAllowed("/home/user/other/file.txt"));
    try std.testing.expect(!checker.isPathAllowed("/home/user/project/secret/password.txt"));
}

test "tool constraints" {
    const allocator = std.testing.allocator;
    
    const constraints = parser.Constraints{
        .allowed_paths = &[_][]const u8{},
        .blocked_paths = &[_][]const u8{},
        .allowed_tools = &[_][]const u8{"read", "write"},
        .blocked_tools = &[_][]const u8{"delete"},
        .require_approval_for = &[_]parser.ApprovalTrigger{},
        .max_iterations = 50,
        .timeout_ms = 30000,
    };
    
    const checker = ConstraintChecker.init(allocator, constraints);
    
    try std.testing.expect(checker.isToolAllowed("read"));
    try std.testing.expect(checker.isToolAllowed("write"));
    try std.testing.expect(!checker.isToolAllowed("delete"));
    try std.testing.expect(!checker.isToolAllowed("bash"));
}

test "approval requirements" {
    const allocator = std.testing.allocator;
    
    const constraints = parser.Constraints{
        .allowed_paths = &[_][]const u8{},
        .blocked_paths = &[_][]const u8{},
        .allowed_tools = null,
        .blocked_tools = &[_][]const u8{},
        .require_approval_for = &[_]parser.ApprovalTrigger{.write_file, .bash_command},
        .max_iterations = 50,
        .timeout_ms = 30000,
    };
    
    const checker = ConstraintChecker.init(allocator, constraints);
    
    try std.testing.expect(checker.requiresApproval(.write_file));
    try std.testing.expect(checker.requiresApproval(.bash_command));
    try std.testing.expect(!checker.requiresApproval(.delete_file));
}
