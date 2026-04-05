//! Tool Approval System
//! Manages approval requirements for different tool risk levels

const std = @import("std");
const utils = @import("../utils/root.zig");
const core = @import("../core/root.zig");

/// Tool risk levels
pub const ToolRisk = enum {
    /// Read-only tools (safe)
    safe,
    /// Write to existing files (caution)
    cautious,
    /// Create new files or modify important files (dangerous)
    dangerous,
    /// Execute commands or delete files (very dangerous)
    critical,
};

/// Approval policy
pub const ApprovalPolicy = enum {
    /// No approval needed
    auto,
    /// Require approval for cautious and above
    moderate,
    /// Require approval for all non-safe tools
    strict,
    /// Require approval for all tools
    always,
};

/// Approval request
pub const ApprovalRequest = struct {
    tool_name: []const u8,
    tool_risk: ToolRisk,
    description: []const u8,
    timestamp_ms: i64,
};

/// Approval result
pub const ApprovalResult = struct {
    approved: bool,
    one_time: bool, // If true, only approve this single request
    remember: bool, // If true, remember this decision
};

/// Tool approval manager
pub const ApprovalManager = struct {
    allocator: std.mem.Allocator,
    policy: ApprovalPolicy,
    // Tools that have been permanently approved
    approved_tools: std.StringHashMap(void),
    // Tools that have been permanently denied
    denied_tools: std.StringHashMap(void),
    // Callback for interactive approval
    approval_callback: ?*const fn (request: ApprovalRequest) ApprovalResult,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, policy: ApprovalPolicy) Self {
        return .{
            .allocator = allocator,
            .policy = policy,
            .approved_tools = std.StringHashMap(void).init(allocator),
            .denied_tools = std.StringHashMap(void).init(allocator),
            .approval_callback = null,
        };
    }

    pub fn deinit(self: *Self) void {
        // Free all stored tool names
        var approved_iter = self.approved_tools.keyIterator();
        while (approved_iter.next()) |key| {
            self.allocator.free(key.*);
        }
        var denied_iter = self.denied_tools.keyIterator();
        while (denied_iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.approved_tools.deinit();
        self.denied_tools.deinit();
    }

    /// Set approval callback for interactive mode
    pub fn setApprovalCallback(
        self: *Self,
        callback: *const fn (request: ApprovalRequest) ApprovalResult,
    ) void {
        self.approval_callback = callback;
    }

    /// Check if a tool needs approval
    pub fn needsApproval(self: *Self, tool_name: []const u8, risk: ToolRisk) bool {
        // Check if permanently approved
        if (self.approved_tools.contains(tool_name)) return false;
        // Check if permanently denied
        if (self.denied_tools.contains(tool_name)) return true;

        return switch (self.policy) {
            .auto => risk == .critical,
            .moderate => risk == .cautious or risk == .dangerous or risk == .critical,
            .strict => risk != .safe,
            .always => true,
        };
    }

    /// Request approval for a tool
    pub fn requestApproval(
        self: *Self,
        tool_name: []const u8,
        risk: ToolRisk,
        description: []const u8,
    ) !ApprovalResult {
        const request = ApprovalRequest{
            .tool_name = tool_name,
            .tool_risk = risk,
            .description = description,
            .timestamp_ms = utils.milliTimestamp(),
        };

        if (self.approval_callback) |callback| {
            const result = callback(request);

            if (result.remember) {
                if (result.approved) {
                    try self.approveTool(tool_name);
                } else {
                    try self.denyTool(tool_name);
                }
            }

            return result;
        }

        // No callback set - auto-approve based on policy
        return ApprovalResult{
            .approved = !self.needsApproval(tool_name, risk),
            .one_time = true,
            .remember = false,
        };
    }

    /// Permanently approve a tool
    pub fn approveTool(self: *Self, tool_name: []const u8) !void {
        const copy = try self.allocator.dupe(u8, tool_name);
        try self.approved_tools.put(copy, {});
        _ = self.denied_tools.remove(tool_name);
    }

    /// Permanently deny a tool
    pub fn denyTool(self: *Self, tool_name: []const u8) !void {
        const copy = try self.allocator.dupe(u8, tool_name);
        try self.denied_tools.put(copy, {});
        _ = self.approved_tools.remove(tool_name);
    }

    /// Remove a tool from both approved and denied lists
    pub fn clearToolDecision(self: *Self, tool_name: []const u8) void {
        if (self.approved_tools.fetchRemove(tool_name)) |entry| {
            self.allocator.free(entry.key);
        }
        if (self.denied_tools.fetchRemove(tool_name)) |entry| {
            self.allocator.free(entry.key);
        }
    }

    /// Clear all remembered decisions
    pub fn clearAllDecisions(self: *Self) void {
        var approved_iter = self.approved_tools.keyIterator();
        while (approved_iter.next()) |key| {
            self.allocator.free(key.*);
        }
        var denied_iter = self.denied_tools.keyIterator();
        while (denied_iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.approved_tools.clearRetainingCapacity();
        self.denied_tools.clearRetainingCapacity();
    }
};

/// Get risk level for a tool
pub fn getToolRisk(tool_name: []const u8) ToolRisk {
    const safe_tools = &[_][]const u8{ "read", "grep", "ls" };
    const cautious_tools = &[_][]const u8{ "write", "edit" };
    const dangerous_tools = &[_][]const u8{ "create", "move", "rename" };
    const critical_tools = &[_][]const u8{ "bash", "exec", "delete", "rm" };

    for (safe_tools) |name| {
        if (std.mem.eql(u8, tool_name, name)) return .safe;
    }
    for (cautious_tools) |name| {
        if (std.mem.eql(u8, tool_name, name)) return .cautious;
    }
    for (dangerous_tools) |name| {
        if (std.mem.eql(u8, tool_name, name)) return .dangerous;
    }
    for (critical_tools) |name| {
        if (std.mem.eql(u8, tool_name, name)) return .critical;
    }

    // Default based on keywords
    if (std.mem.indexOf(u8, tool_name, "read") != null or
        std.mem.indexOf(u8, tool_name, "get") != null or
        std.mem.indexOf(u8, tool_name, "list") != null)
    {
        return .safe;
    }
    if (std.mem.indexOf(u8, tool_name, "write") != null or
        std.mem.indexOf(u8, tool_name, "edit") != null or
        std.mem.indexOf(u8, tool_name, "modify") != null)
    {
        return .cautious;
    }
    if (std.mem.indexOf(u8, tool_name, "create") != null or
        std.mem.indexOf(u8, tool_name, "delete") != null or
        std.mem.indexOf(u8, tool_name, "remove") != null)
    {
        return .dangerous;
    }
    if (std.mem.indexOf(u8, tool_name, "exec") != null or
        std.mem.indexOf(u8, tool_name, "run") != null or
        std.mem.indexOf(u8, tool_name, "bash") != null)
    {
        return .critical;
    }

    return .safe; // Default to safe
}

// ============================================================================
// Tests
// ============================================================================

test "ToolRisk classification" {
    try std.testing.expectEqual(ToolRisk.safe, getToolRisk("read"));
    try std.testing.expectEqual(ToolRisk.cautious, getToolRisk("write"));
    try std.testing.expectEqual(ToolRisk.dangerous, getToolRisk("create"));
    try std.testing.expectEqual(ToolRisk.critical, getToolRisk("bash"));
    try std.testing.expectEqual(ToolRisk.safe, getToolRisk("grep"));
}

test "ApprovalManager basic operations" {
    const allocator = std.testing.allocator;
    var manager = ApprovalManager.init(allocator, .moderate);
    defer manager.deinit();

    // Test needs approval
    try std.testing.expect(!manager.needsApproval("read", .safe));
    try std.testing.expect(manager.needsApproval("write", .cautious));
    try std.testing.expect(manager.needsApproval("bash", .critical));

    // Test approving a tool
    try manager.approveTool("write");
    try std.testing.expect(!manager.needsApproval("write", .cautious));

    // Test denying a tool
    try manager.denyTool("bash");
    try std.testing.expect(manager.needsApproval("bash", .critical));

    // Test clearing decision
    manager.clearToolDecision("write");
    try std.testing.expect(manager.needsApproval("write", .cautious));
}
