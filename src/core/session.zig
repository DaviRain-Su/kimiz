//! Session - Simplified session management with compaction
//! Reference: Pi-Mono's session design

const std = @import("std");
const core = @import("root.zig");

/// Session - Single layer session with compaction support
pub const Session = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    created_at: i64,
    
    // Message history
    messages: std.ArrayList(core.Message),
    
    // Metadata
    metadata: SessionMetadata,
    
    // Branch support
    parent_id: ?[]const u8,
    branch_point: ?usize,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, id: []const u8) !Self {
        return .{
            .allocator = allocator,
            .id = try allocator.dupe(u8, id),
            .created_at = std.time.milliTimestamp(),
            .messages = std.ArrayList(core.Message).init(allocator),
            .metadata = .{
                .working_dir = try allocator.dupe(u8, "."),
                .model_id = try allocator.dupe(u8, "default"),
                .total_tokens = 0,
                .total_cost = 0.0,
                .message_count = .{
                    .user = 0,
                    .assistant = 0,
                    .tool_calls = 0,
                },
            },
            .parent_id = null,
            .branch_point = null,
        };
    }
    
    /// Add a message to the session
    pub fn addMessage(self: *Self, msg: core.Message) !void {
        try self.messages.append(msg);
        
        // Update counters
        switch (msg) {
            .user => self.metadata.message_count.user += 1,
            .assistant => self.metadata.message_count.assistant += 1,
            .tool_result => self.metadata.message_count.tool_calls += 1,
        }
        
        // Auto-compact if needed
        if (self.shouldCompact()) {
            try self.compact();
        }
    }
    
    /// Check if compaction is needed
    fn shouldCompact(self: Self) bool {
        return self.messages.items.len > 100; // Default threshold
    }
    
    /// Compact session by summarizing old messages
    pub fn compact(self: *Self) !void {
        if (self.messages.items.len <= 10) return;
        
        const keep_recent = 10;
        const recent = self.messages.items[self.messages.items.len - keep_recent ..];
        const older = self.messages.items[0 .. self.messages.items.len - keep_recent];
        
        // Generate summary (simplified version)
        const summary = try self.generateSummary(older);
        
        // Create new message list: [summary, ...recent]
        var new_messages = std.ArrayList(core.Message).init(self.allocator);
        
        // Add summary as system message
        try new_messages.append(core.Message{
            .system = .{
                .content = summary,
            },
        });
        
        // Copy recent messages
        for (recent) |msg| {
            try new_messages.append(msg);
        }
        
        // Replace old messages
        self.messages.deinit();
        self.messages = new_messages;
    }
    
    /// Generate summary of messages (simplified)
    fn generateSummary(self: *Self, messages: []const core.Message) ![]const u8 {
        _ = self;
        
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit();
        
        try buf.appendSlice("Previous conversation summary:\n");
        
        for (messages) |msg| {
            switch (msg) {
                .user => try buf.appendSlice("- User asked a question\n"),
                .assistant => try buf.appendSlice("- Assistant provided response\n"),
                .tool_result => try buf.appendSlice("- Tool was executed\n"),
                else => {},
            }
        }
        
        return buf.toOwnedSlice();
    }
    
    /// Create a fork of this session
    pub fn fork(self: *Self, new_id: []const u8) !Self {
        var new_session = try Self.init(self.allocator, new_id);
        
        // Copy messages
        for (self.messages.items) |_msg| {
            try new_session.messages.append(_msg);
        }
        
        // Set parent
        new_session.parent_id = try self.allocator.dupe(u8, self.id);
        new_session.branch_point = self.messages.items.len;
        
        return new_session;
    }
    
    /// Save session to JSONL file
    pub fn save(self: Self, dir: []const u8) !void {
        const file_path = try std.fs.path.join(self.allocator, &.{ dir, self.id });
        defer self.allocator.free(file_path);
        
        const file = try std.fs.cwd().createFile(file_path, .{});
        defer file.close();
        
        var writer = file.writer();
        
        // Write metadata
        try writer.print("{{\"type\":\"metadata\",\"data\":{{" ++ 
            "\"id\":\"{s}\"," ++
            "\"created_at\":{d}," ++
            "\"message_count\":{d}}}\n", .{
            self.id,
            self.created_at,
            self.messages.items.len,
        });
        
        // Write messages
        for (self.messages.items) |_| {
            try writer.print("{{\"type\":\"message\",\"data\":{{...}}}}\n", .{});
        }
    }
    
    /// Load session from JSONL file
    pub fn load(allocator: std.mem.Allocator, dir: []const u8, id: []const u8) !Self {
        const file_path = try std.fs.path.join(allocator, &.{ dir, id });
        defer allocator.free(file_path);
        
        const session = try Self.init(allocator, id);
        
        const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                return session; // Return empty session
            }
            return err;
        };
        defer file.close();
        
        // TODO: Parse JSONL and populate messages
        
        return session;
    }
    
    /// Export session to HTML
    pub fn exportHtml(self: Session, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        
        var writer = file.writer();
        
        try writer.writeAll("<!DOCTYPE html>\n<html>\n<head>\n");
        try writer.writeAll("<title>Kimiz Session</title>\n");
        try writer.writeAll("</head>\n<body>\n");
        
        for (self.messages.items) |msg| {
            switch (msg) {
                .user => try writer.writeAll("<div class=\"user\">User</div>\n"),
                .assistant => try writer.writeAll("<div class=\"assistant\">Assistant</div>\n"),
                else => {},
            }
        }
        
        try writer.writeAll("</body>\n</html>\n");
    }
    
    /// Deinitialize session
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.id);
        self.allocator.free(self.metadata.working_dir);
        self.allocator.free(self.metadata.model_id);
        if (self.parent_id) |id| {
            self.allocator.free(id);
        }
        self.messages.deinit();
    }
};

pub const SessionMetadata = struct {
    working_dir: []const u8,
    model_id: []const u8,
    total_tokens: u64,
    total_cost: f64,
    message_count: struct {
        user: u32,
        assistant: u32,
        tool_calls: u32,
    },
};

// ============================================================================
// Tests
// ============================================================================

test "Session init/deinit" {
    const allocator = std.testing.allocator;
    
    var session = try Session.init(allocator, "test-session");
    defer session.deinit();
    
    try std.testing.expectEqualStrings("test-session", session.id);
    try std.testing.expectEqual(@as(usize, 0), session.messages.items.len);
}

test "Session add message" {
    const allocator = std.testing.allocator;
    
    var session = try Session.init(allocator, "test-session");
    defer session.deinit();
    
    const msg = core.Message{
        .user = .{
            .content = &[_]core.UserContentBlock{.{ .text = "Hello" }},
        },
    };
    
    try session.addMessage(msg);
    
    try std.testing.expectEqual(@as(usize, 1), session.messages.items.len);
    try std.testing.expectEqual(@as(u32, 1), session.metadata.message_count.user);
}

test "Session fork" {
    const allocator = std.testing.allocator;
    
    var session = try Session.init(allocator, "parent");
    defer session.deinit();
    
    // Add some messages
    try session.addMessage(core.Message{ .user = .{ .content = &[_]core.UserContentBlock{.{ .text = "Hello" }} }});
    
    var forked = try session.fork("child");
    defer forked.deinit();
    
    try std.testing.expectEqualStrings("child", forked.id);
    try std.testing.expectEqualStrings("parent", forked.parent_id.?);
    try std.testing.expectEqual(@as(usize, 1), forked.messages.items.len);
}
