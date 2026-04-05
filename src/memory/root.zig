//! kimiz-memory - Three-Tier Memory System
//! Short-term, Working, and Long-term memory
//! Reference: PRD Section 3.3 (inspired by mem0)

const std = @import("std");
const session = @import("../utils/session.zig");

// ============================================================================
// Memory Types
// ============================================================================

pub const MemoryTier = enum {
    short_term,  // Current session context
    working,     // Project-level knowledge
    long_term,   // User preferences and learned patterns
};

pub const MemoryType = enum {
    conversation,    // Conversation history
    code_pattern,   // Learned code patterns
    user_pref,      // User preferences
    project_knowledge, // Project-specific knowledge
    tool_usage,     // Tool usage patterns
    model_perf,     // Model performance data
};

/// Memory entry
pub const MemoryEntry = struct {
    id: u64,
    tier: MemoryTier,
    mem_type: MemoryType,
    content: []const u8,
    metadata: ?[]const u8, // JSON string
    importance: u8, // 0-100, for retention priority
    created_at: i64,
    last_accessed_at: i64,
    access_count: u32,

    /// Calculate relevance score for retrieval
    pub fn relevanceScore(self: MemoryEntry, query: []const u8, current_time: i64) f64 {
        // Base score from content match
        var score: f64 = 0.0;
        if (std.mem.indexOf(u8, self.content, query) != null) {
            score += 50.0;
        }

        // Recency bonus
        const age_ms = current_time - self.last_accessed_at;
        const recency_bonus = @max(0.0, 30.0 - @as(f64, @floatFromInt(age_ms)) / 1000.0 / 60.0); // Decay per minute
        score += recency_bonus;

        // Frequency bonus
        score += @min(20.0, @as(f64, @floatFromInt(self.access_count)) * 2.0);

        // Importance bonus
        score += @as(f64, @floatFromInt(self.importance)) * 0.3;

        return score;
    }
};

// ============================================================================
// Short-Term Memory (Session Context)
// ============================================================================

pub const ShortTermMemory = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(MemoryEntry),
    max_entries: usize,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, max_entries: usize) Self {
        return .{
            .allocator = allocator,
            .entries = .empty,
            .max_entries = max_entries,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.entries.items) |*entry| {
            self.allocator.free(entry.content);
            if (entry.metadata) |m| self.allocator.free(m);
        }
        self.entries.deinit(self.allocator);
    }

    pub fn add(self: *Self, mem_type: MemoryType, content: []const u8, importance: u8) !void {
        // Remove oldest if at capacity
        if (self.entries.items.len >= self.max_entries) {
            var oldest_idx: usize = 0;
            var oldest_time = self.entries.items[0].created_at;
            for (self.entries.items, 0..) |entry, i| {
                if (entry.created_at < oldest_time) {
                    oldest_time = entry.created_at;
                    oldest_idx = i;
                }
            }
            _ = self.entries.orderedRemove(oldest_idx);
        }

        const entry = MemoryEntry{
            .id = @intCast(self.entries.items.len),
            .tier = .short_term,
            .mem_type = mem_type,
            .content = try self.allocator.dupe(u8, content),
            .metadata = null,
            .importance = importance,
            .created_at = std.time.milliTimestamp(),
            .last_accessed_at = std.time.milliTimestamp(),
            .access_count = 0,
        };
        try self.entries.append(self.allocator, entry);
    }

    pub fn search(self: *Self, query: []const u8, limit: usize) ![]MemoryEntry {
        const current_time = std.time.milliTimestamp();

        // Score all entries
        var scored = try self.allocator.alloc(struct { entry: MemoryEntry, score: f64 }, self.entries.items.len);
        defer self.allocator.free(scored);

        for (self.entries.items, 0..) |entry, i| {
            scored[i] = .{
                .entry = entry,
                .score = entry.relevanceScore(query, current_time),
            };
        }

        // Sort by score descending
        std.mem.sort(struct { entry: MemoryEntry, score: f64 }, scored, {}, struct {
            fn lessThan(_: void, a: struct { entry: MemoryEntry, score: f64 }, b: struct { entry: MemoryEntry, score: f64 }) bool {
                return a.score > b.score; // Descending
            }
        }.lessThan);

        // Return top entries
        const result_count = @min(limit, scored.len);
        var result = try self.allocator.alloc(MemoryEntry, result_count);
        for (0..result_count) |i| {
            result[i] = scored[i].entry;
        }
        return result;
    }
};

// ============================================================================
// Working Memory (Project Knowledge)
// ============================================================================

pub const ProjectKnowledge = struct {
    tech_stack: []const []const u8,
    code_patterns: []const []const u8,
    architecture_notes: []const u8,
    important_files: []const []const u8,
};

pub const WorkingMemory = struct {
    allocator: std.mem.Allocator,
    project_path: []const u8,
    knowledge: ?ProjectKnowledge,
    last_updated: i64,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, project_path: []const u8) !Self {
        return .{
            .allocator = allocator,
            .project_path = try allocator.dupe(u8, project_path),
            .knowledge = null,
            .last_updated = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.project_path);
        if (self.knowledge) |*k| {
            for (k.tech_stack) |s| self.allocator.free(s);
            for (k.code_patterns) |p| self.allocator.free(p);
            self.allocator.free(k.architecture_notes);
            for (k.important_files) |f| self.allocator.free(f);
        }
    }

    /// Analyze project and extract knowledge
    pub fn analyzeProject(self: *Self) !void {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const alloc = arena.allocator();
        
        var tech_stack: std.ArrayList([]const u8) = .empty;
        var code_patterns: std.ArrayList([]const u8) = .empty;
        var important_files: std.ArrayList([]const u8) = .empty;
        defer {
            for (tech_stack.items) |s| alloc.free(s);
            for (code_patterns.items) |p| alloc.free(p);
            for (important_files.items) |f| alloc.free(f);
        }
        
        // Detect tech stack by file patterns
        try self.detectTechStack(alloc, &tech_stack);
        
        // Identify code patterns from source files
        try self.identifyCodePatterns(alloc, &code_patterns);
        
        // Find important files
        try self.findImportantFiles(alloc, &important_files);
        
        // Build architecture notes
        var notes_buf: [4096]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&notes_buf);
        var writer = fbs.writer();
        const w: *std.Io.Writer = &writer.interface;
        
        try w.print("Project Analysis: {s}\n\n", .{self.project_path});
        try w.print("Tech Stack:\n", .{});
        for (tech_stack.items) |tech| {
            try w.print("  - {s}\n", .{tech});
        }
        try w.print("\nImportant Files:\n", .{});
        for (important_files.items) |file| {
            try w.print("  - {s}\n", .{file});
        }
        try w.flush();
        
        // Store results
        const notes = try self.allocator.dupe(u8, fbs.getWritten());
        errdefer self.allocator.free(notes);
        
        // Free old data if exists
        if (self.knowledge) |*k| {
            for (k.tech_stack) |s| self.allocator.free(s);
            for (k.code_patterns) |p| self.allocator.free(p);
            self.allocator.free(k.architecture_notes);
            for (k.important_files) |f| self.allocator.free(f);
        }
        
        // Copy tech stack to persistent memory
        var persistent_tech: std.ArrayList([]const u8) = .empty;
        for (tech_stack.items) |tech| {
            const copy = try self.allocator.dupe(u8, tech);
            try persistent_tech.append(self.allocator, copy);
        }
        
        // Copy patterns to persistent memory
        var persistent_patterns: std.ArrayList([]const u8) = .empty;
        for (code_patterns.items) |pattern| {
            const copy = try self.allocator.dupe(u8, pattern);
            try persistent_patterns.append(self.allocator, copy);
        }
        
        // Copy files to persistent memory
        var persistent_files: std.ArrayList([]const u8) = .empty;
        for (important_files.items) |file| {
            const copy = try self.allocator.dupe(u8, file);
            try persistent_files.append(self.allocator, copy);
        }
        
        self.knowledge = .{
            .tech_stack = try persistent_tech.toOwnedSlice(self.allocator),
            .code_patterns = try persistent_patterns.toOwnedSlice(self.allocator),
            .architecture_notes = notes,
            .important_files = try persistent_files.toOwnedSlice(self.allocator),
        };
        
        self.last_updated = std.time.milliTimestamp();
    }
    
    // Internal: Detect tech stack by file patterns
    fn detectTechStack(self: *Self, alloc: std.mem.Allocator, stack: *std.ArrayList([]const u8)) !void {
        // Check for common project files
        const markers = .{
            .{ "package.json", "Node.js/TypeScript" },
            .{ "Cargo.toml", "Rust" },
            .{ "go.mod", "Go" },
            .{ "pyproject.toml", "Python" },
            .{ "setup.py", "Python" },
            .{ "requirements.txt", "Python" },
            .{ "build.zig", "Zig" },
            .{ "CMakeLists.txt", "C++" },
            .{ "Makefile", "C/C++" },
            .{ "pom.xml", "Java/Maven" },
            .{ "build.gradle", "Java/Gradle" },
            .{ "Gemfile", "Ruby" },
            .{ "composer.json", "PHP" },
            .{ "pubspec.yaml", "Flutter/Dart" },
            .{ "mix.exs", "Elixir" },
        };
        
        for (markers) |marker| {
            const path = try std.fs.path.join(alloc, &.{ self.project_path, marker[0] });
            defer alloc.free(path);
            
            std.fs.cwd().access(path, .{}) catch continue;
            
            // Found it
            const tech = try alloc.dupe(u8, marker[1]);
            try stack.append(tech);
        }
    }
    
    // Internal: Identify common code patterns
    fn identifyCodePatterns(self: *Self, alloc: std.mem.Allocator, patterns: *std.ArrayList([]const u8)) !void {
        // Scan source files for patterns
        const pattern_markers = .{
            .{ "test", "Testing pattern detected" },
            .{ "async", "Async/await pattern" },
            .{ "error.", "Error handling pattern" },
            .{ "defer", "Resource cleanup pattern" },
            .{ "allocator", "Manual memory management" },
        };
        
        // Check a sample of source files
        var dir = std.fs.cwd().openDir(self.project_path, .{ .iterate = true }) catch return;
        defer dir.close();
        
        var found_patterns: [pattern_markers.len]bool = .{false} ** pattern_markers.len;
        var checked_files: usize = 0;
        const max_files = 20;
        
        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!isSourceFile(entry.name)) continue;
            
            if (checked_files >= max_files) break;
            checked_files += 1;
            
            const file_path = try std.fs.path.join(alloc, &.{ self.project_path, entry.name });
            defer alloc.free(file_path);
            
            const content = std.fs.cwd().readFileAlloc(alloc, file_path, 1024 * 1024) catch continue;
            defer alloc.free(content);
            
            // Check for patterns
            for (pattern_markers, 0..) |marker, i| {
                if (found_patterns[i]) continue;
                if (std.mem.indexOf(u8, content, marker[0]) != null) {
                    found_patterns[i] = true;
                }
            }
        }
        
        // Add found patterns
        for (pattern_markers, 0..) |marker, i| {
            if (found_patterns[i]) {
                const pattern = try alloc.dupe(u8, marker[1]);
                try patterns.append(pattern);
            }
        }
    }
    
    // Internal: Find important project files
    fn findImportantFiles(self: *Self, alloc: std.mem.Allocator, files: *std.ArrayList([]const u8)) !void {
        // Look for entry points and core modules
        const important_patterns = .{
            "main",
            "lib",
            "index",
            "root",
            "app",
            "core",
            "mod",
        };
        
        // Common extensions
        const extensions = .{
            ".zig", ".rs", ".go", ".py", ".js", ".ts", ".java", ".c", ".cpp", ".h", ".hpp"
        };
        
        var dir = std.fs.cwd().openDir(self.project_path, .{ .iterate = true }) catch return;
        defer dir.close();
        
        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind != .file) continue;
            
            const name = entry.name;
            
            inline for (important_patterns) |pattern| {
                inline for (extensions) |ext| {
                    const suffix = try std.mem.concat(alloc, u8, &.{ pattern, ext });
                    defer alloc.free(suffix);
                    
                    if (std.mem.eql(u8, name, suffix) or 
                        std.mem.endsWith(u8, name, try std.mem.concat(alloc, u8, &.{ "_", suffix }))) {
                        const file = try alloc.dupe(u8, name);
                        try files.append(file);
                    }
                }
            }
        }
    }
    
    // Helper: Check if file is source code
    fn isSourceFile(name: []const u8) bool {
        const extensions = .{
            ".zig", ".rs", ".go", ".py", ".js", ".ts", ".java", 
            ".c", ".cpp", ".h", ".hpp", ".cc", ".cxx"
        };
        inline for (extensions) |ext| {
            if (std.mem.endsWith(u8, name, ext)) return true;
        }
        return false;
    }
};

// ============================================================================
// Long-Term Memory (Persistent Storage)
// ============================================================================

/// Memory record for serialization
const MemoryRecord = struct {
    id: u64,
    tier: MemoryTier,
    mem_type: MemoryType,
    content: []const u8,
    metadata: ?[]const u8,
    importance: u8,
    created_at: i64,
    last_accessed_at: i64,
    access_count: u32,
};

pub const LongTermMemory = struct {
    allocator: std.mem.Allocator,
    db_path: []const u8,
    entries: std.ArrayList(MemoryEntry),
    dirty: bool, // Track if needs save

    const Self = @This();
    const MAX_ENTRIES = 10000; // Limit long-term memory size

    pub fn init(allocator: std.mem.Allocator, db_path: []const u8) !Self {
        var self = Self{
            .allocator = allocator,
            .db_path = try allocator.dupe(u8, db_path),
            .entries = .empty,
            .dirty = false,
        };
        
        // Load existing data
        self.load() catch |err| switch (err) {
            error.FileNotFound => {}, // First run, empty is fine
            else => return err,
        };
        
        return self;
    }

    pub fn deinit(self: *Self) void {
        // Save if dirty
        if (self.dirty) {
            self.save() catch {};
        }
        
        for (self.entries.items) |*entry| {
            self.allocator.free(entry.content);
            if (entry.metadata) |m| self.allocator.free(m);
        }
        self.entries.deinit(self.allocator);
        self.allocator.free(self.db_path);
    }

    /// Store memory entry (in-memory + persist to disk)
    pub fn store(self: *Self, entry: MemoryEntry) !void {
        // Check for duplicate by content hash
        const entry_hash = hashContent(entry.content);
        for (self.entries.items) |*existing| {
            if (hashContent(existing.content) == entry_hash) {
                // Update existing entry
                existing.last_accessed_at = entry.last_accessed_at;
                existing.access_count += 1;
                if (entry.importance > existing.importance) {
                    existing.importance = entry.importance;
                }
                self.dirty = true;
                return;
            }
        }
        
        // Add new entry
        const entry_copy = try self.copyEntry(entry);
        try self.entries.append(self.allocator, entry_copy);
        self.dirty = true;
        
        // Enforce size limit (remove oldest low-importance entries)
        if (self.entries.items.len > MAX_ENTRIES) {
            try self.pruneOldEntries();
        }
        
        // Auto-save every 10 writes
        if (self.entries.items.len % 10 == 0) {
            try self.save();
        }
    }

    /// Retrieve memories by type
    pub fn retrieveByType(self: *Self, mem_type: MemoryType, limit: usize) ![]MemoryEntry {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const alloc = arena.allocator();
        
        var result: std.ArrayList(MemoryEntry) = .empty;
        defer result.deinit(alloc);
        
        // Collect matching entries
        for (self.entries.items) |entry| {
            if (entry.mem_type == mem_type) {
                try result.append(alloc, entry);
                if (result.items.len >= limit) break;
            }
        }
        
        // Sort by importance and recency
        std.mem.sort(MemoryEntry, result.items, {}, struct {
            fn lessThan(_: void, a: MemoryEntry, b: MemoryEntry) bool {
                const score_a = @as(f64, @floatFromInt(a.importance)) + @as(f64, @floatFromInt(a.access_count)) * 0.1;
                const score_b = @as(f64, @floatFromInt(b.importance)) + @as(f64, @floatFromInt(b.access_count)) * 0.1;
                return score_a > score_b;
            }
        }.lessThan);
        
        // Copy to persistent memory
        return try self.allocator.dupe(MemoryEntry, result.items);
    }

    /// Search memories by text match
    pub fn search(self: *Self, query: []const u8, limit: usize) ![]MemoryEntry {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const alloc = arena.allocator();
        
        var scored: std.ArrayList(struct { entry: MemoryEntry, score: f64 }) = .empty;
        defer scored.deinit(alloc);
        
        const current_time = std.time.milliTimestamp();
        const query_lower = try std.ascii.allocLowerString(alloc, query);
        
        for (self.entries.items) |entry| {
            const score = calculateSearchScore(entry, query_lower, current_time);
            if (score > 0) {
                try scored.append(alloc, .{ .entry = entry, .score = score });
            }
        }
        
        // Sort by score descending
        std.mem.sort(struct { entry: MemoryEntry, score: f64 }, scored.items, {}, struct {
            fn lessThan(_: void, a: struct { entry: MemoryEntry, score: f64 }, b: struct { entry: MemoryEntry, score: f64 }) bool {
                return a.score > b.score;
            }
        }.lessThan);
        
        // Return top results
        const result_count = @min(limit, scored.items.len);
        var result = try self.allocator.alloc(MemoryEntry, result_count);
        for (0..result_count) |i| {
            result[i] = scored.items[i].entry;
        }
        return result;
    }

    /// Consolidate short-term memories into long-term
    pub fn consolidate(self: *Self, short_term: *ShortTermMemory) !void {
        const current_time = std.time.milliTimestamp();
        
        var i: usize = short_term.entries.items.len;
        while (i > 0) {
            i -= 1;
            const entry = &short_term.entries.items[i];
            
            const should_consolidate = entry.importance > 70 or
                entry.access_count > 5 or
                (current_time - entry.created_at > 24 * 60 * 60 * 1000);
            
            if (should_consolidate) {
                var long_term_entry = entry.*;
                long_term_entry.tier = .long_term;
                try self.store(long_term_entry);
                
                // Remove from short-term
                short_term.allocator.free(entry.content);
                if (entry.metadata) |m| short_term.allocator.free(m);
                _ = short_term.entries.orderedRemove(i);
            }
        }
        
        // Save after consolidation
        try self.save();
    }

    // Internal: Save to JSON file
    fn save(self: *Self) !void {
        var buf: [1024 * 1024]u8 = undefined; // 1MB buffer
        var fbs = std.io.fixedBufferStream(&buf);
        var writer = fbs.writer();
        const w: *std.Io.Writer = &writer.interface;
        
        // Write JSON array
        try w.print("[\n", .{});
        
        for (self.entries.items, 0..) |entry, i| {
            try w.print("  {{\n", .{});
            try w.print("    \"id\": {d},\n", .{entry.id});
            try w.print("    \"tier\": \"{s}\",\n", .{@tagName(entry.tier)});
            try w.print("    \"mem_type\": \"{s}\",\n", .{@tagName(entry.mem_type)});
            try w.print("    \"content\": \"", .{});
            try writeEscapedString(w, entry.content);
            try w.print("\",\n", .{});
            try w.print("    \"importance\": {d},\n", .{entry.importance});
            try w.print("    \"created_at\": {d},\n", .{entry.created_at});
            try w.print("    \"last_accessed_at\": {d},\n", .{entry.last_accessed_at});
            try w.print("    \"access_count\": {d}\n", .{entry.access_count});
            
            if (i < self.entries.items.len - 1) {
                try w.print("  }},\n", .{});
            } else {
                try w.print("  }}\n", .{});
            }
        }
        
        try w.print("]\n", .{});
        try w.flush();
        
        // Create directory if needed
        const dir = std.fs.path.dirname(self.db_path) orelse ".";
        std.fs.cwd().makeDir(dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            error.FileNotFound => {}, // Dir might be "."
            else => return err,
        };
        
        // Write atomically (write to temp then rename)
        const temp_path = try std.fs.path.join(self.allocator, &.{ dir, ".memory.json.tmp" });
        defer self.allocator.free(temp_path);
        
        const file = try std.fs.cwd().createFile(temp_path, .{});
        defer file.close();
        try file.writeAll(fbs.getWritten());
        
        // Atomic rename
        try std.fs.cwd().rename(temp_path, self.db_path);
        self.dirty = false;
    }

    // Internal: Load from JSON file
    fn load(self: *Self) !void {
        const content = try std.fs.cwd().readFileAlloc(
            self.allocator,
            self.db_path,
            10 * 1024 * 1024, // Max 10MB
        );
        defer self.allocator.free(content);
        
        var parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            content,
            .{},
        );
        defer parsed.deinit();
        
        const array = parsed.value.array;
        for (array.items) |item| {
            const obj = item.object;
            
            const entry = MemoryEntry{
                .id = @intCast(obj.get("id").?.integer),
                .tier = std.meta.stringToEnum(MemoryTier, obj.get("tier").?.string) orelse .long_term,
                .mem_type = std.meta.stringToEnum(MemoryType, obj.get("mem_type").?.string) orelse .conversation,
                .content = try self.allocator.dupe(u8, obj.get("content").?.string),
                .metadata = null,
                .importance = @intCast(obj.get("importance").?.integer),
                .created_at = obj.get("created_at").?.integer,
                .last_accessed_at = obj.get("last_accessed_at").?.integer,
                .access_count = @intCast(obj.get("access_count").?.integer),
            };
            
            try self.entries.append(self.allocator, entry);
        }
    }

    // Internal: Copy entry with new allocation
    fn copyEntry(self: *Self, entry: MemoryEntry) !MemoryEntry {
        return .{
            .id = entry.id,
            .tier = entry.tier,
            .mem_type = entry.mem_type,
            .content = try self.allocator.dupe(u8, entry.content),
            .metadata = if (entry.metadata) |m| try self.allocator.dupe(u8, m) else null,
            .importance = entry.importance,
            .created_at = entry.created_at,
            .last_accessed_at = entry.last_accessed_at,
            .access_count = entry.access_count,
        };
    }

    // Internal: Prune old entries when over limit
    fn pruneOldEntries(self: *Self) !void {
        // Sort by importance * recency score
        std.mem.sort(MemoryEntry, self.entries.items, {}, struct {
            fn lessThan(_: void, a: MemoryEntry, b: MemoryEntry) bool {
                const score_a = @as(f64, @floatFromInt(a.importance)) * 0.5 +
                    @as(f64, @floatFromInt(a.access_count)) * 0.3;
                const score_b = @as(f64, @floatFromInt(b.importance)) * 0.5 +
                    @as(f64, @floatFromInt(b.access_count)) * 0.3;
                return score_a < score_b; // Ascending for removal
            }
        }.lessThan);
        
        // Remove bottom entries to get back to limit
        const to_remove = self.entries.items.len - MAX_ENTRIES;
        for (0..to_remove) |_| {
            const entry = self.entries.pop();
            self.allocator.free(entry.content);
            if (entry.metadata) |m| self.allocator.free(m);
        }
        
        self.dirty = true;
    }

    // Internal: Simple content hash for deduplication
    fn hashContent(content: []const u8) u64 {
        var hash: u64 = 0xcbf29ce484222325; // FNV offset basis
        for (content) |byte| {
            hash ^= byte;
            hash *%= 0x100000001b3; // FNV prime
        }
        return hash;
    }

    // Internal: Calculate search relevance score
    fn calculateSearchScore(entry: MemoryEntry, query: []const u8, current_time: i64) f64 {
        var score: f64 = 0.0;
        
        // Content match (case-insensitive)
        const content_lower = std.ascii.lowerString(@as([4096]u8, undefined), entry.content);
        if (std.mem.indexOf(u8, &content_lower, query) != null) {
            score += 50.0;
        }
        
        // Recency factor (decay over time)
        const age_hours = @as(f64, @floatFromInt(current_time - entry.last_accessed_at)) / 3600000.0;
        score += @max(0.0, 20.0 - age_hours);
        
        // Frequency factor
        score += @min(10.0, @as(f64, @floatFromInt(entry.access_count)));
        
        // Importance factor
        score += @as(f64, @floatFromInt(entry.importance)) * 0.2;
        
        return score;
    }
};

// Helper: Write escaped JSON string
fn writeEscapedString(w: *std.Io.Writer, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '"' => try w.print("\\\"", .{}),
            '\\' => try w.print("\\\\", .{}),
            '\n' => try w.print("\\n", .{}),
            '\r' => try w.print("\\r", .{}),
            '\t' => try w.print("\\t", .{}),
            else => {
                if (c >= 0x20 and c <= 0x7e) {
                    try w.print("{c}", .{c});
                } else {
                    try w.print("\\u{x:0>4}", .{c});
                }
            },
        }
    }
}

// ============================================================================
// Memory Manager
// ============================================================================

pub const MemoryManager = struct {
    allocator: std.mem.Allocator,
    short_term: ShortTermMemory,
    working: ?WorkingMemory,
    long_term: LongTermMemory,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        project_path: ?[]const u8,
        db_path: []const u8,
    ) !Self {
        var working: ?WorkingMemory = null;
        if (project_path) |path| {
            working = try WorkingMemory.init(allocator, path);
        }

        return .{
            .allocator = allocator,
            .short_term = ShortTermMemory.init(allocator, 100), // Keep last 100 entries
            .working = working,
            .long_term = try LongTermMemory.init(allocator, db_path),
        };
    }

    pub fn deinit(self: *Self) void {
        self.short_term.deinit();
        if (self.working) |*w| w.deinit();
        self.long_term.deinit();
    }

    /// Add to short-term memory
    pub fn remember(self: *Self, mem_type: MemoryType, content: []const u8, importance: u8) !void {
        try self.short_term.add(mem_type, content, importance);
    }

    /// Recall relevant memories
    pub fn recall(self: *Self, query: []const u8, limit: usize) ![]MemoryEntry {
        // Search short-term first
        const short_term_results = try self.short_term.search(query, limit);
        defer self.allocator.free(short_term_results);

        // TODO: Also search long-term and merge results

        return short_term_results;
    }

    /// Consolidate memories
    pub fn consolidate(self: *Self) !void {
        try self.long_term.consolidate(&self.short_term);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "ShortTermMemory operations" {
    const allocator = std.testing.allocator;
    var stm = ShortTermMemory.init(allocator, 10);
    defer stm.deinit();

    try stm.add(.conversation, "Test conversation", 50);
    try stm.add(.code_pattern, "fn foo() {{}}", 80);

    try std.testing.expectEqual(@as(usize, 2), stm.entries.items.len);

    const results = try stm.search("Test", 5);
    defer allocator.free(results);

    try std.testing.expect(results.len > 0);
}
