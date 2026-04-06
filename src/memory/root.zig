//! kimiz-memory - Simplified Session-Based Memory + Obsidian Long-Term Memory
//! TASK-INFRA-006: Obsidian-compatible Markdown storage for long-term memory

const std = @import("std");
const session = @import("../core/session.zig");
const utils = @import("../utils/root.zig");

// Obsidian-compatible Markdown storage (TASK-INFRA-006)
pub const obsidian = @import("obsidian_store.zig");
pub const ObsidianStore = obsidian.ObsidianStore;
pub const ObsidianEntry = obsidian.ObsidianEntry;

// Re-export Session types
pub const Session = session.Session;
pub const SessionMetadata = session.SessionMetadata;

/// MemoryType for API compatibility
pub const MemoryType = enum {
    conversation,
    code_pattern,
    user_pref,
    project_knowledge,
    tool_usage,
    model_perf,
};

/// MemoryEntry for API compatibility  
pub const MemoryEntry = struct {
    id: u64,
    mem_type: MemoryType,
    content: []const u8,
    importance: u8,
    created_at: i64,
};

// ============================================================================
// Simplified Memory Manager (Session-Based Only)
// ============================================================================

pub const MemoryManager = struct {
    allocator: std.mem.Allocator,
    session: Session,
    db_path: ?[]const u8,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        _: ?[]const u8,
        db_path: []const u8,
    ) !Self {
        // Generate session ID
        const session_id = try std.fmt.allocPrint(allocator, "session-{d}", .{utils.timestamp()});
        errdefer allocator.free(session_id);

        return .{
            .allocator = allocator,
            .session = try Session.init(allocator, session_id),
            .db_path = try allocator.dupe(u8, db_path),
        };
    }

    pub fn deinit(self: *Self) void {
        self.session.deinit();
        if (self.db_path) |path| {
            self.allocator.free(path);
        }
    }

    /// Add entry to memory (simplified - just track metadata)
    pub fn remember(self: *Self, mem_type: MemoryType, content: []const u8, importance: u8) !void {
        // In MVP, we just track that something was remembered
        // Actual conversation history is managed by Agent's messages array
        _ = self;
        _ = mem_type;
        _ = content;
        _ = importance;
        // TODO: In future, could add to a simple in-memory list
    }

    /// Recall from memory (simplified)
    pub fn recall(self: *Self, query: []const u8, limit: usize) ![]MemoryEntry {
        _ = self;
        _ = query;
        _ = limit;
        // MVP: Return empty slice - conversation history is in Agent.messages
        return &[_]MemoryEntry{};
    }

    /// Get the underlying session
    pub fn getSession(self: *Self) *Session {
        return &self.session;
    }

    /// Save session to disk
    pub fn save(self: *Self) !void {
        if (self.db_path) |path| {
            try self.session.save(path);
        }
    }

    /// Load session from disk
    pub fn load(self: *Self) !void {
        if (self.db_path) |path| {
            const loaded = try Session.load(self.allocator, path, self.session.id);
            self.session.deinit();
            self.session = loaded;
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "MemoryManager init/deinit" {
    const allocator = std.testing.allocator;
    var mm = try MemoryManager.init(allocator, null, "/tmp/test-memory");
    defer mm.deinit();
}

test "MemoryManager remember/recall" {
    const allocator = std.testing.allocator;
    var mm = try MemoryManager.init(allocator, null, "/tmp/test-memory");
    defer mm.deinit();

    try mm.remember(.conversation, "Test entry", 50);
    
    const results = try mm.recall("Test", 5);
    _ = results; // MVP returns empty
}
