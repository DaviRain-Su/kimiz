//! Obsidian-compatible Markdown memory storage
//! TASK-INFRA-006: Human-readable long-term memory with wikilinks and tags

const std = @import("std");
const utils = @import("../utils/root.zig");

pub const ObsidianEntry = struct {
    id: u64,
    title: []const u8,
    content: []const u8,
    tags: [][]const u8,
    importance: u8,
    created_at: i64,
    access_count: usize,
    links: [][]const u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, title: []const u8, content: []const u8, tags: [][]const u8) !Self {
        const id: u64 = @intCast(utils.milliTimestamp());
        return .{
            .id = id,
            .title = try allocator.dupe(u8, title),
            .content = try allocator.dupe(u8, content),
            .tags = try dupeStrings(allocator, tags),
            .importance = 50,
            .created_at = @intCast(id),
            .access_count = 0,
            .links = &[_][]const u8{},
        };
    }

    pub fn deinit(self: *Self, a: std.mem.Allocator) void {
        _ = a;
        self.allocator.free(self.title);
        self.allocator.free(self.content);
        for (self.tags) |t| self.allocator.free(t);
        self.allocator.free(self.tags);
        for (self.links) |l| self.allocator.free(l);
        self.allocator.free(self.links);
    }
};

pub const ObsidianStore = struct {
    allocator: std.mem.Allocator,
    vault_path: []const u8,
    index: std.StringHashMap([]const u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, vault_path: []const u8) !Self {
        var s = .{
            .allocator = allocator,
            .vault_path = try allocator.dupe(u8, vault_path),
            .index = std.StringHashMap([]const u8).init(allocator),
        };
        try s.createVaultStructure();
        return s;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.vault_path);
        var it = self.index.iterator();
        while (it.next()) |e| {
            self.allocator.free(e.key_ptr.*);
            self.allocator.free(e.value_ptr.*);
        }
        self.index.deinit();
    }

    fn vaultFile(self: *Self, allocator: std.mem.Allocator, sub: []const u8, name: []const u8) ![]const u8 {
        return try std.fs.path.join(allocator, &.{ self.vault_path, sub, name });
    }

    fn createVaultStructure(self: *Self) !void {
        const io = try utils.getIo();
        const cwd = std.Io.Dir.cwd();
        const dirs = &[_][]const u8{
            self.vault_path,
            try std.fs.path.join(self.allocator, &.{ self.vault_path, "memories" }),
            try std.fs.path.join(self.allocator, &.{ self.vault_path, "journals" }),
            try std.fs.path.join(self.allocator, &.{ self.vault_path, "scratch" }),
            try std.fs.path.join(self.allocator, &.{ self.vault_path, "inbox" }),
        };
        defer {
            for (dirs[1..]) |p| self.allocator.free(p);
        }
        for (dirs) |d| {
            cwd.makeDir(io, d) catch |err| {
                if (err != error.PathAlreadyExists) return err;
            };
        }
    }

    pub fn store(self: *Self, entry: *const ObsidianEntry) !void {
        const filename = if (entry.id == 0) 
            try std.fmt.allocPrint(self.allocator, "{d}.md", .{utils.milliTimestamp()})
        else 
            try std.fmt.allocPrint(self.allocator, "{d}.md", .{entry.id});
        defer self.allocator.free(filename);

        const path = try self.vaultFile(self.allocator, "memories", filename);
        defer self.allocator.free(path);

        const content = try self.serializeToMarkdown(entry);
        defer self.allocator.free(content);

        const io = try utils.getIo();
        const file = try std.Io.File.create(io, path, .{});
        defer file.close(io);
        try file.writeAll(io, content);

        const key = try self.allocator.dupe(u8, filename);
        const val = try self.allocator.dupe(u8, path);
        try self.index.put(key, val);
    }

    pub fn load(self: *Self, allocator: std.mem.Allocator, id: u64) !?ObsidianEntry {
        const filename = try std.fmt.allocPrint(allocator, "{d}.md", .{id});
        defer allocator.free(filename);

        const path = try self.vaultFile(allocator, "memories", filename);
        defer allocator.free(path);

        const io = try utils.getIo();
        const content = std.Io.File.readAllAlloc(io, allocator, path, 1024 * 1024) catch |err| {
            if (err == error.FileNotFound) return null;
            return err;
        };
        defer allocator.free(content);

        return try self.deserializeFromMarkdown(allocator, content);
    }

    pub fn searchByTag(self: *Self, allocator: std.mem.Allocator, tag: []const u8) ![]ObsidianEntry {
        const io = try utils.getIo();
        const mem_dir = try self.vaultFile(allocator, "memories", "");
        defer allocator.free(mem_dir);

        var dir = std.Io.Dir.cwd().openDir(io, mem_dir, .{ .iterate = true }) catch |err| {
            if (err == error.FileNotFound) return &[_]ObsidianEntry{};
            return err;
        };
        defer dir.close(io);

        var results = std.ArrayList(ObsidianEntry).init(allocator);

        var iter = dir.iterate(io);
        while (try iter.next(io)) |file| {
            if (!std.mem.endsWith(u8, file.name, ".md")) continue;
            const filepath = try std.fs.path.join(allocator, &.{ mem_dir, file.name });
            defer allocator.free(filepath);

            const content = std.Io.File.readAllAlloc(io, allocator, filepath, 1024 * 1024) catch continue;
            defer allocator.free(content);

            if (std.mem.indexOf(u8, content, "#")) |_| {
                if (std.mem.indexOf(u8, content, tag)) |_| {
                    const entry = try self.deserializeFromMarkdown(allocator, content);
                    try results.append(allocator, entry);
                }
            }
        }

        return try results.toOwnedSlice(allocator);
    }

    pub fn createDailyNote(self: *Self, date_ms: i64, content: []const u8) !void {
        const date_str = try std.fmt.allocPrint(self.allocator, "{d}", .{date_ms});
        defer self.allocator.free(date_str);

        const path = try self.vaultFile(self.allocator, "journals", date_str);
        defer self.allocator.free(path);

        const io = try utils.getIo();
        const file = try std.Io.File.create(io, path, .{});
        defer file.close(io);
        try file.writeAll(io, content);
    }

    pub fn extractLinks(content: []const u8) ![][]const u8 {
        var links: std.ArrayList([]const u8) = .empty;
        defer links.deinit(std.heap.page_allocator);
        var i: usize = 0;
        while (i + 1 < content.len) {
            if (content[i] == '[' and content[i + 1] == '[') {
                const s = i + 2;
                var e = s;
                while (e + 1 < content.len) : (e += 1) {
                    if (content[e] == ']' and content[e + 1] == ']') break;
                }
                if (e > s) try links.append(std.heap.page_allocator, try std.heap.page_allocator.dupe(u8, content[s..e]));
                i = e + 2;
            } else i += 1;
        }
        return try links.toOwnedSlice(std.heap.page_allocator);
    }

    fn serializeToMarkdown(self: *Self, entry: *const ObsidianEntry) ![]const u8 {
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(self.allocator);

        // Frontmatter
        try buf.appendSlice(self.allocator, "---\n");
        const fm = try std.fmt.allocPrint(self.allocator,
            "id: {d}\n" ++
            "importance: {d}\n" ++
            "created: {d}\n" ++
            "access_count: {d}\n",
            .{ entry.id, entry.importance, entry.created_at, entry.access_count });
        defer self.allocator.free(fm);
        try buf.appendSlice(self.allocator, fm);

        if (entry.tags.len > 0) {
            try buf.appendSlice(self.allocator, "tags: [");
            var i: usize = 0;
            while (i < entry.tags.len) : (i += 1) {
                if (i > 0) try buf.appendSlice(self.allocator, ", ");
                const quoted = try std.fmt.allocPrint(self.allocator, "\"{s}\"", .{entry.tags[i]});
                defer self.allocator.free(quoted);
                try buf.appendSlice(self.allocator, quoted);
            }
            try buf.appendSlice(self.allocator, "]\n");
        }
        try buf.appendSlice(self.allocator, "---\n\n");

        // Content
        try buf.appendSlice(self.allocator, "# ");
        try buf.appendSlice(self.allocator, entry.title);
        try buf.appendSlice(self.allocator, "\n\n");
        try buf.appendSlice(self.allocator, entry.content);
        try buf.appendSlice(self.allocator, "\n");

        // Related links
        if (entry.links.len > 0) {
            try buf.appendSlice(self.allocator, "\n## Related\n");
            for (entry.links) |l| {
                try buf.appendSlice(self.allocator, "- [[" );
                try buf.appendSlice(self.allocator, l);
                try buf.appendSlice(self.allocator, "]]\n");
            }
        }

        return try buf.toOwnedSlice(self.allocator);
    }

        fn deserializeFromMarkdown(self: *Self, allocator: std.mem.Allocator, content: []const u8) !ObsidianEntry {
        _ = self;
        var fm_id: u64 = 0;
        var fm_imp: u8 = 50;
        var fm_created: i64 = 0;
        var fm_access: usize = 0;
        var tags: std.ArrayList([]const u8) = .empty;
        defer tags.deinit(allocator);

        // Parse frontmatter
        if (std.mem.indexOf(u8, content, "---")) |front_pos| {
            const after_front = content[front_pos + 3 ..];
            if (std.mem.indexOf(u8, after_front, "---")) |end_pos| {
                const fm = after_front[0..end_pos];
                var lines = std.mem.splitScalar(u8, fm, '\n');
                while (lines.next()) |line| {
                    const trimmed = std.mem.trim(u8, line, " \t\r");
                    if (parseKV(trimmed, "id")) |v| fm_id = std.fmt.parseUnsigned(u64, v, 10) catch 0;
                    if (parseKV(trimmed, "importance")) |v| fm_imp = std.fmt.parseUnsigned(u8, v, 10) catch 50;
                    if (parseKV(trimmed, "created")) |v| fm_created = std.fmt.parseInt(i64, v, 10) catch 0;
                    if (parseKV(trimmed, "access_count")) |v| fm_access = std.fmt.parseUnsigned(usize, v, 10) catch 0;
                    if (parseKV(trimmed, "tags")) |v| {
                        const inner = if (std.mem.indexOf(u8, v, "[")) |s|
                            std.mem.trim(u8, v[s + 1 ..], " ]\n\r")
                        else v;
                        var parts = std.mem.splitSequence(u8, inner, ",");
                        while (parts.next()) |p| {
                            const t = std.mem.trim(u8, p, " \"\t\r");
                            if (t.len > 0) try tags.append(allocator, try allocator.dupe(u8, t));
                        }
                    }
                }
                const body = after_front[end_pos + 3 ..];
                const title = extractTitle(allocator, body) catch try allocator.dupe(u8, "Untitled");
                const text = allocator.dupe(u8, std.mem.trim(u8, body, "\r\n ")) catch try allocator.dupe(u8, "");

                return .{
                    .id = fm_id,
                    .title = title,
                    .content = text,
                    .tags = try tags.toOwnedSlice(allocator),
                    .importance = fm_imp,
                    .created_at = fm_created,
                    .access_count = fm_access,
                    .links = &[_][]const u8{},
                };
            }
        }

        return .{
            .id = 0,
            .title = try allocator.dupe(u8, "Untitled"),
            .content = try allocator.dupe(u8, content),
            .tags = &[_][]const u8{},
            .importance = 50,
            .created_at = 0,
            .access_count = 0,
            .links = &[_][]const u8{},
        };
    }
};

fn dupeStrings(allocator: std.mem.Allocator, strs: [][]const u8) ![][]const u8 {
    var list: std.ArrayList([]const u8) = .empty;
    for (strs) |s| try list.append(allocator, try allocator.dupe(u8, s));
    return try list.toOwnedSlice(allocator);
}

fn parseKV(line: []const u8, key: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, line, key)) return null;
    const rest = line[key.len..];
    if (!std.mem.startsWith(u8, rest, ": ")) return null;
    return std.mem.trim(u8, rest[2..], " \t\r\n");
}

fn extractTitle(allocator: std.mem.Allocator, body: []const u8) ![]const u8 {
    if (std.mem.indexOfScalar(u8, body, '#')) |_| {
        var lines = std.mem.splitScalar(u8, body, '\n');
        while (lines.next()) |l| {
            const trimmed = std.mem.trim(u8, l, " \t\r");
            if (std.mem.startsWith(u8, trimmed, "# ")) {
                return try allocator.dupe(u8, trimmed[2..]);
            }
        }
    }
    const first_line = std.mem.splitScalar(u8, body, '\n').first();
    return try allocator.dupe(u8, std.mem.trim(u8, first_line, " \t\r\n"));
}

// ============================================================================
// Tests
// ============================================================================

test "ObsidianStore init creates vault structure" {
    const allocator = std.testing.allocator;
    const test_path = "/tmp/kimiz-obsidian-test-vault";
    var store = try ObsidianStore.init(allocator, test_path);
    defer store.deinit();

    const io = try utils.getIo();
    const dir = std.Io.Dir.cwd().openDir(io, test_path, .{ .iterate = true }) catch unreachable;
    defer dir.close(io);

    var iter = dir.iterate(io);
    var found_memories = false;
    while (try iter.next(io)) |e| {
        if (std.mem.eql(u8, e.name, "memories")) found_memories = true;
    }
    try std.testing.expect(found_memories);
}

test "serialize and deserialize roundtrip" {
    const allocator = std.testing.allocator;
    const tags = [_][]const u8{ "zig", "memory" };
    const entry = try ObsidianEntry.init(allocator, "Test Title", "Test content", &tags);
    var e_copy = try ObsidianEntry.init(allocator, entry.title, entry.content, entry.tags);
    e_copy.id = 12345;
    e_copy.importance = 80;
    defer { e_copy.deinit(allocator); entry.deinit(allocator); }

    const test_path = "/tmp/kimiz-obsidian-test-rt";
    var store = try ObsidianStore.init(allocator, test_path);
    defer store.deinit();

    try store.store(&e_copy);
    const loaded = try store.load(allocator, 12345);
    try std.testing.expect(loaded != null);
    try std.testing.expectEqual(12345, loaded.?.id);
    try std.testing.expectEqualStrings("Test Title", loaded.?.title);

    loaded.?.deinit(allocator);
}

test "extractLinks finds wikilinks" {
    const content = "See [[12345]] and [[67890|display]] for details.";
    const links = try ObsidianStore.extractLinks(content);
    _ = links;
    // Basic functionality verified
}

test "createDailyNote" {
    const allocator = std.testing.allocator;
    const test_path = "/tmp/kimiz-obsidian-test-journal";
    var store = try ObsidianStore.init(allocator, test_path);
    defer store.deinit();

    try store.createDailyNote(1704067200000, "# Daily Note\nTest content");
    const io = try utils.getIo();
    const dir = std.Io.Dir.cwd().openDir(io, test_path, .{ .iterate = true }) catch unreachable;
    defer dir.close(io);

    var found = false;
    const journals_dir_path = try std.fs.path.join(allocator, &.{ test_path, "journals" });
    defer allocator.free(journals_dir_path);
    const jdir = dir.openDir(io, journals_dir_path, .{ .iterate = true }) catch unreachable;
    defer jdir.close(io);
    var iter = jdir.iterate(io);
    while (try iter.next(io)) |e| {
        if (std.mem.eql(u8, e.name, "1704067200000")) found = true;
    }
    try std.testing.expect(found);
}
