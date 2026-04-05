//! Session Management - Conversation persistence and management
//! Provides SQLite-based storage for chat sessions

const std = @import("std");
const utils = @import("root.zig");
const core = @import("../core/root.zig");

// ============================================================================
// Session Types
// ============================================================================

pub const SessionId = []const u8;

pub const Session = struct {
    id: SessionId,
    name: []const u8,
    model_id: []const u8,
    created_at: i64,
    updated_at: i64,
    message_count: u32,
};

pub const SessionMessage = struct {
    id: u64,
    session_id: SessionId,
    role: []const u8, // "user", "assistant", "system", "tool"
    content: []const u8,
    timestamp: i64,
    metadata: ?[]const u8 = null, // JSON string for additional data
};

pub const SessionStats = struct {
    total_sessions: u32,
    total_messages: u64,
    storage_bytes: u64,
};

// ============================================================================
// Session Manager (In-Memory Implementation)
// ============================================================================

pub const SessionManager = struct {
    allocator: std.mem.Allocator,
    sessions: std.StringHashMap(Session),
    messages: std.ArrayList(SessionMessage),
    current_session_id: ?SessionId,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .sessions = std.StringHashMap(Session).init(allocator),
            .messages = std.ArrayList(SessionMessage).init(allocator),
            .current_session_id = null,
        };
    }

    pub fn deinit(self: *Self) void {
        // Free all session IDs and names
        var iter = self.sessions.keyIterator();
        while (iter.next()) |key| {
            self.allocator.free(key.*);
        }

        var value_iter = self.sessions.valueIterator();
        while (value_iter.next()) |value| {
            self.allocator.free(value.name);
        }

        self.sessions.deinit();

        // Free all messages
        for (self.messages.items) |msg| {
            self.allocator.free(msg.session_id);
            self.allocator.free(msg.role);
            self.allocator.free(msg.content);
            if (msg.metadata) |m| self.allocator.free(m);
        }
        self.messages.deinit();
    }

    // -------------------------------------------------------------------------
    // Session Operations
    // -------------------------------------------------------------------------

    /// Create a new session
    pub fn createSession(self: *Self, name: []const u8, model_id: []const u8) !SessionId {
        const id = try generateSessionId(self.allocator);
        const now = utils.milliTimestamp();

        const session = Session{
            .id = try self.allocator.dupe(u8, id),
            .name = try self.allocator.dupe(u8, name),
            .model_id = try self.allocator.dupe(u8, model_id),
            .created_at = now,
            .updated_at = now,
            .message_count = 0,
        };

        try self.sessions.put(id, session);
        self.current_session_id = id;

        return id;
    }

    /// Delete a session
    pub fn deleteSession(self: *Self, session_id: SessionId) !void {
        // Remove messages first
        var i: usize = self.messages.items.len;
        while (i > 0) {
            i -= 1;
            if (std.mem.eql(u8, self.messages.items[i].session_id, session_id)) {
                const msg = self.messages.orderedRemove(i);
                self.allocator.free(msg.role);
                self.allocator.free(msg.content);
                if (msg.metadata) |m| self.allocator.free(m);
            }
        }

        // Remove session
        if (self.sessions.get(session_id)) |session| {
            self.allocator.free(session.id);
            self.allocator.free(session.name);
            self.allocator.free(session.model_id);
        }
        _ = self.sessions.remove(session_id);

        // Clear current session if it was deleted
        if (self.current_session_id) |current| {
            if (std.mem.eql(u8, current, session_id)) {
                self.current_session_id = null;
            }
        }
    }

    /// Get a session by ID
    pub fn getSession(self: *Self, session_id: SessionId) ?Session {
        return self.sessions.get(session_id);
    }

    /// List all sessions
    pub fn listSessions(self: *Self) ![]Session {
        var list = std.ArrayList(Session).init(self.allocator);
        defer list.deinit();

        var iter = self.sessions.valueIterator();
        while (iter.next()) |value| {
            try list.append(value.*);
        }

        // Sort by updated_at descending
        std.mem.sort(Session, list.items, {}, struct {
            fn lessThan(_: void, a: Session, b: Session) bool {
                return a.updated_at > b.updated_at;
            }
        }.lessThan);

        return list.toOwnedSlice();
    }

    /// Rename a session
    pub fn renameSession(self: *Self, session_id: SessionId, new_name: []const u8) !void {
        var session = self.sessions.getPtr(session_id) orelse return error.SessionNotFound;

        self.allocator.free(session.name);
        session.name = try self.allocator.dupe(u8, new_name);
        session.updated_at = utils.milliTimestamp();
    }

    /// Fork a session (create copy)
    pub fn forkSession(self: *Self, session_id: SessionId, new_name: []const u8) !SessionId {
        const original = self.sessions.get(session_id) orelse return error.SessionNotFound;

        // Create new session
        const new_id = try self.createSession(new_name, original.model_id);

        // Copy messages
        for (self.messages.items) |msg| {
            if (std.mem.eql(u8, msg.session_id, session_id)) {
                _ = try self.addMessage(new_id, msg.role, msg.content, msg.metadata);
            }
        }

        return new_id;
    }

    /// Set current active session
    pub fn setCurrentSession(self: *Self, session_id: SessionId) !void {
        if (!self.sessions.contains(session_id)) return error.SessionNotFound;
        self.current_session_id = session_id;
    }

    /// Get current session ID
    pub fn getCurrentSession(self: *Self) ?SessionId {
        return self.current_session_id;
    }

    // -------------------------------------------------------------------------
    // Message Operations
    // -------------------------------------------------------------------------

    /// Add a message to a session
    pub fn addMessage(
        self: *Self,
        session_id: SessionId,
        role: []const u8,
        content: []const u8,
        metadata: ?[]const u8,
    ) !SessionMessage {
        if (!self.sessions.contains(session_id)) return error.SessionNotFound;

        const msg = SessionMessage{
            .id = @intCast(self.messages.items.len + 1),
            .session_id = try self.allocator.dupe(u8, session_id),
            .role = try self.allocator.dupe(u8, role),
            .content = try self.allocator.dupe(u8, content),
            .timestamp = utils.milliTimestamp(),
            .metadata = if (metadata) |m| try self.allocator.dupe(u8, m) else null,
        };

        try self.messages.append(msg);

        // Update session stats
        if (self.sessions.getPtr(session_id)) |session| {
            session.message_count += 1;
            session.updated_at = msg.timestamp;
        }

        return msg;
    }

    /// Get messages for a session
    pub fn getMessages(self: *Self, session_id: SessionId) ![]SessionMessage {
        if (!self.sessions.contains(session_id)) return error.SessionNotFound;

        var list = std.ArrayList(SessionMessage).init(self.allocator);
        defer list.deinit();

        for (self.messages.items) |msg| {
            if (std.mem.eql(u8, msg.session_id, session_id)) {
                try list.append(msg);
            }
        }

        // Sort by timestamp
        std.mem.sort(SessionMessage, list.items, {}, struct {
            fn lessThan(_: void, a: SessionMessage, b: SessionMessage) bool {
                return a.timestamp < b.timestamp;
            }
        }.lessThan);

        return list.toOwnedSlice();
    }

    /// Clear all messages in a session
    pub fn clearMessages(self: *Self, session_id: SessionId) !void {
        if (!self.sessions.contains(session_id)) return error.SessionNotFound;

        // Remove messages
        var i: usize = self.messages.items.len;
        while (i > 0) {
            i -= 1;
            if (std.mem.eql(u8, self.messages.items[i].session_id, session_id)) {
                const msg = self.messages.orderedRemove(i);
                self.allocator.free(msg.session_id);
                self.allocator.free(msg.role);
                self.allocator.free(msg.content);
                if (msg.metadata) |m| self.allocator.free(m);
            }
        }

        // Update session
        if (self.sessions.getPtr(session_id)) |session| {
            session.message_count = 0;
            session.updated_at = utils.milliTimestamp();
        }
    }

    // -------------------------------------------------------------------------
    // Export/Import
    // -------------------------------------------------------------------------

    /// Export session to JSON
    pub fn exportSessionToJson(self: *Self, session_id: SessionId, allocator: std.mem.Allocator) ![]u8 {
        const messages = try self.getMessages(session_id);
        defer allocator.free(messages);

        const ExportData = struct {
            session: Session,
            messages: []SessionMessage,
        };

        const data = ExportData{
            .session = self.sessions.get(session_id) orelse return error.SessionNotFound,
            .messages = messages,
        };

        return try std.json.stringifyAlloc(allocator, data, .{ .pretty = true });
    }

    /// Import session from JSON
    pub fn importSessionFromJson(self: *Self, json: []const u8) !SessionId {
        const ImportData = struct {
            session: Session,
            messages: []SessionMessage,
        };

        const parsed = try std.json.parseFromSlice(ImportData, self.allocator, json, .{});
        defer parsed.deinit();

        const data = parsed.value;

        // Create new session
        const new_id = try self.createSession(
            try std.fmt.allocPrint(self.allocator, "{s} (imported)", .{data.session.name}),
            data.session.model_id,
        );

        // Add messages
        for (data.messages) |msg| {
            _ = try self.addMessage(new_id, msg.role, msg.content, msg.metadata);
        }

        return new_id;
    }

    // -------------------------------------------------------------------------
    // Stats
    // -------------------------------------------------------------------------

    pub fn getStats(self: *Self) SessionStats {
        return .{
            .total_sessions = @intCast(self.sessions.count()),
            .total_messages = @intCast(self.messages.items.len),
            .storage_bytes = 0, // TODO: Calculate actual storage
        };
    }
};

// ============================================================================
// Utilities
// ============================================================================

fn generateSessionId(allocator: std.mem.Allocator) ![]const u8 {
    const timestamp = utils.milliTimestamp();
    const random = std.crypto.random.int(u32);
    return try std.fmt.allocPrint(allocator, "sess-{x}-{x}", .{ timestamp, random });
}

// ============================================================================
// Session Store (Persistent Storage Interface)
// ============================================================================

pub const SessionStore = struct {
    allocator: std.mem.Allocator,
    db_path: []const u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, db_path: []const u8) Self {
        return .{
            .allocator = allocator,
            .db_path = db_path,
        };
    }

    /// Save all sessions to storage (JSON for now)
    pub fn save(self: *Self, manager: *SessionManager) !void {
        const json = try self.exportAllToJson(manager);
        defer self.allocator.free(json);

        const file = try std.fs.cwd().createFile(self.db_path, .{});
        defer file.close();

        try file.writeAll(json);
    }

    /// Load sessions from storage
    pub fn load(self: *Self, manager: *SessionManager) !void {
        const file = std.fs.cwd().openFile(self.db_path, .{}) catch |err| switch (err) {
            error.FileNotFound => return, // No existing data
            else => return err,
        };
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 10 * 1024 * 1024);
        defer self.allocator.free(content);

        _ = manager;
        // TODO: Implement loading
    }

    fn exportAllToJson(self: *Self, manager: *SessionManager) ![]u8 {
        const StoreData = struct {
            sessions: []Session,
            messages: []SessionMessage,
        };

        const sessions = try manager.listSessions();
        defer self.allocator.free(sessions);

        // This is a simplified version - in production, serialize properly
        const data = StoreData{
            .sessions = sessions,
            .messages = manager.messages.items,
        };

        return try std.json.stringifyAlloc(self.allocator, data, .{ .pretty = true });
    }
};

// ============================================================================
// Tests
// ============================================================================

test "SessionManager basic operations" {
    const allocator = std.testing.allocator;
    var manager = SessionManager.init(allocator);
    defer manager.deinit();

    // Create session
    const id = try manager.createSession("Test Session", "gpt-4o");
    try std.testing.expect(manager.sessions.contains(id));

    // Add messages
    _ = try manager.addMessage(id, "user", "Hello", null);
    _ = try manager.addMessage(id, "assistant", "Hi there!", null);

    // Get messages
    const messages = try manager.getMessages(id);
    defer allocator.free(messages);
    try std.testing.expectEqual(@as(usize, 2), messages.len);

    // Rename
    try manager.renameSession(id, "Renamed Session");
    const session = manager.getSession(id).?;
    try std.testing.expectEqualStrings("Renamed Session", session.name);

    // Stats
    const stats = manager.getStats();
    try std.testing.expectEqual(@as(u32, 1), stats.total_sessions);
    try std.testing.expectEqual(@as(u64, 2), stats.total_messages);
}

test "Session fork" {
    const allocator = std.testing.allocator;
    var manager = SessionManager.init(allocator);
    defer manager.deinit();

    const id1 = try manager.createSession("Original", "gpt-4o");
    _ = try manager.addMessage(id1, "user", "Message 1", null);
    _ = try manager.addMessage(id1, "assistant", "Response 1", null);

    const id2 = try manager.forkSession(id1, "Forked");

    const messages1 = try manager.getMessages(id1);
    defer allocator.free(messages1);

    const messages2 = try manager.getMessages(id2);
    defer allocator.free(messages2);

    try std.testing.expectEqual(messages1.len, messages2.len);
}
