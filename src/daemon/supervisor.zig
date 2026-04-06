//! Supervisor Daemon - Session lifecycle management
//! T-120: Supervisor Daemon + Session attach/detach prototype

const std = @import("std");
const utils = @import("../utils/root.zig");

pub const SessionState = enum {
    created,
    running,
    detached,
    stopped,
    error_state,
};

pub const SessionInfo = struct {
    id: []const u8,
    state: SessionState,
    pid: ?std.posix.pid_t,
    log_path: []const u8,
    created_at: i64,
    last_active: i64,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.id);
        self.allocator.free(self.log_path);
    }
};

pub const Supervisor = struct {
    allocator: std.mem.Allocator,
    sessions: std.StringHashMap(SessionInfo),
    socket_path: []const u8,
    socket_fd: ?std.posix.socket_t,
    sessions_dir: []const u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, base_dir: []const u8) !Self {
        return .{
            .allocator = allocator,
            .sessions = std.StringHashMap(SessionInfo).init(allocator),
            .socket_path = try std.fmt.allocPrint(allocator, "{s}/kimiz.sock", .{base_dir}),
            .socket_fd = null,
            .sessions_dir = try allocator.dupe(u8, base_dir),
        };
    }

    pub fn deinit(self: *Self) void {
        var it = self.sessions.iterator();
        while (it.next()) |e| {
            e.value_ptr.deinit();
        }
        self.sessions.deinit();
        self.allocator.free(self.socket_path);
        self.allocator.free(self.sessions_dir);
        if (self.socket_fd) |fd| _ = fd; // closes on process exit
    }

    pub fn createSession(self: *Self, name: []const u8) ![]const u8 {
        const ts: u64 = @intCast(utils.milliTimestamp());
        const id = try std.fmt.allocPrint(self.allocator, "{s}-{d}", .{ name, ts });
        defer self.allocator.free(id);

        const log_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}.log", .{ self.sessions_dir, id });
        defer self.allocator.free(log_path);

        const io = try utils.getIo();
        const dir = std.Io.Dir.cwd();
        _ = try dir.createFile(io, log_path, .{});

        const info = SessionInfo{
            .id = try self.allocator.dupe(u8, id),
            .state = .created,
            .pid = null,
            .log_path = try self.allocator.dupe(u8, log_path),
            .created_at = utils.milliTimestamp(),
            .last_active = utils.milliTimestamp(),
            .allocator = self.allocator,
        };

        try self.sessions.put(try self.allocator.dupe(u8, id), info);
        return try self.allocator.dupe(u8, id);
    }

    pub fn listSessions(self: *Self) ![]SessionInfo {
        var list: std.ArrayList(SessionInfo) = .empty;
        var it = self.sessions.valueIterator();
        while (it.next()) |info| {
            try list.append(self.allocator, .{
                .id = try self.allocator.dupe(u8, info.id),
                .state = info.state,
                .pid = info.pid,
                .log_path = try self.allocator.dupe(u8, info.log_path),
                .created_at = info.created_at,
                .last_active = info.last_active,
                .allocator = self.allocator,
            });
        }
        return try list.toOwnedSlice(self.allocator);
    }

    pub fn stopSession(self: *Self, session_id: []const u8) !void {
        if (self.sessions.getEntry(session_id)) |entry| {
            if (entry.value_ptr.pid) |pid| {
                std.posix.kill(pid, std.posix.SIG.TERM) catch {};
            }
            entry.value_ptr.state = .stopped;
            entry.value_ptr.last_active = utils.milliTimestamp();
        }
    }

    pub fn saveState(self: *Self) !void {
        const state_path = try std.fmt.allocPrint(self.allocator, "{s}/state.json", .{self.sessions_dir});
        defer self.allocator.free(state_path);

        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(self.allocator);

        try buf.appendSlice(self.allocator, "[\n");
        var it = self.sessions.valueIterator();
        var first = true;
        while (it.next()) |info| {
            if (!first) try buf.appendSlice(self.allocator, ",\n");
            first = false;
            const line = try std.fmt.allocPrint(self.allocator,
                "  {{\"id\":\"{s}\",\"state\":\"{s}\",\"pid\":{},\"created_at\":{d}}}",
                .{ info.id, @tagName(info.state), if (info.pid) |p| p else 0, info.created_at });
            defer self.allocator.free(line);
            try buf.appendSlice(self.allocator, line);
        }
        try buf.appendSlice(self.allocator, "\n]\n");

        const io = try utils.getIo();
        const dir = std.Io.Dir.cwd();
        if (dir.createFile(io, state_path, .{ .truncate = true })) |file| {
            defer file.close(io);
            try file.writeAll(io, buf.items);
        } else |_| {}
    }
};

pub const SessionManager = struct {
    allocator: std.mem.Allocator,
    supervisor: Supervisor,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        const home_dir = if (std.c.getenv("HOME")) |ptr|
            std.mem.sliceTo(ptr, 0)
        else
            ".";
        const base = try std.fmt.allocPrint(allocator, "{s}/.kimiz/supervisor", .{home_dir});
        defer allocator.free(base);

        return .{
            .allocator = allocator,
            .supervisor = try Supervisor.init(allocator, base),
        };
    }

    pub fn deinit(self: *Self) void {
        self.supervisor.deinit();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Supervisor create/list sessions" {
    const allocator = std.testing.allocator;
    const test_dir = "/tmp/kimiz-supervisor-test";
    var sup = try Supervisor.init(allocator, test_dir);
    defer sup.deinit();

    const id = try sup.createSession("test-session");
    defer allocator.free(id);

    const sessions = try sup.listSessions();
    defer {
        for (sessions) |*s| s.deinit();
        allocator.free(sessions);
    }
    try std.testing.expect(sessions.len >= 1);
}

test "SessionManager init/deinit" {
    const allocator = std.testing.allocator;
    var mgr = try SessionManager.init(allocator);
    defer mgr.deinit();
}

test "Supervisor stop session" {
    const allocator = std.testing.allocator;
    const test_dir = "/tmp/kimiz-supervisor-stop-test";
    var sup = try Supervisor.init(allocator, test_dir);
    defer sup.deinit();

    const id = try sup.createSession("stop-test");
    defer allocator.free(id);

    try sup.stopSession(id);
    if (sup.sessions.get(id)) |info| {
        try std.testing.expect(info.state == .stopped);
    } else {
        try std.testing.expect(false);
    }
}

test "Supervisor save state" {
    const allocator = std.testing.allocator;
    const test_dir = "/tmp/kimiz-supervisor-save-test";
    var sup = try Supervisor.init(allocator, test_dir);
    defer sup.deinit();

    _ = try sup.createSession("save-test");
    try sup.saveState();
    // If no errors, test passes
}
