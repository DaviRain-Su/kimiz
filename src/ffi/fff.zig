//! fff C FFI Bindings
//! High-performance fuzzy file finder via libfff_c
//! API reference: ffi/fff.h

const std = @import("std");

const c = @cImport({
    @cInclude("fff.h");
});

pub const FffResult = c.FffResult;
pub const FffSearchResult = c.FffSearchResult;
pub const FffGrepResult = c.FffGrepResult;
pub const FffGrepMatch = c.FffGrepMatch;
pub const FffFileItem = c.FffFileItem;
pub const FffScore = c.FffScore;
pub const FffScanProgress = c.FffScanProgress;

pub const FFFError = error{
    InstanceCreationFailed,
    SearchFailed,
    GrepFailed,
    ScanFailed,
    InvalidHandle,
    OutOfMemory,
};

// ============================================================================
// FFF Instance
// ============================================================================

pub const FFFInstance = struct {
    handle: ?*anyopaque,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        base_path: []const u8,
    ) !Self {
        const path_z = try allocator.dupeZ(u8, base_path);
        defer allocator.free(path_z);

        const result = c.fff_create_instance(
            path_z.ptr,
            null, // frecency_db_path
            null, // history_db_path
            false, // use_unsafe_no_lock
            false, // warmup_mmap_cache
            true, // ai_mode
        );
        if (result == null) return FFFError.InstanceCreationFailed;
        defer c.fff_free_result(result);

        if (!result.*.success) {
            if (result.*.@"error" != null) {
                std.log.err("fff init failed: {s}", .{std.mem.span(result.*.@"error")});
            }
            return FFFError.InstanceCreationFailed;
        }

        return .{
            .handle = result.*.handle,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.handle) |h| {
            c.fff_destroy(h);
            self.handle = null;
        }
    }

    /// Wait for the initial file scan to complete.
    pub fn waitForScan(self: *Self, timeout_ms: u64) !bool {
        const result = c.fff_wait_for_scan(self.handle, timeout_ms);
        if (result == null) return FFFError.ScanFailed;
        defer c.fff_free_result(result);
        if (!result.*.success) return FFFError.ScanFailed;
        return result.*.int_value == 1;
    }

    /// Fuzzy file search.
    pub fn search(
        self: *Self,
        allocator: std.mem.Allocator,
        query: []const u8,
        max_results: u32,
    ) !SearchResult {
        const query_z = try allocator.dupeZ(u8, query);
        defer allocator.free(query_z);

        const result = c.fff_search(
            self.handle,
            query_z.ptr,
            null, // current_file
            0, // max_threads (auto)
            0, // page_index
            max_results, // page_size
            0, // combo_boost_multiplier (default)
            0, // min_combo_count (default)
        );
        if (result == null) return FFFError.SearchFailed;
        defer c.fff_free_result(result);

        if (!result.*.success) {
            if (result.*.@"error" != null) {
                std.log.err("fff search failed: {s}", .{std.mem.span(result.*.@"error")});
            }
            return FFFError.SearchFailed;
        }

        const sr: *FffSearchResult = @ptrCast(@alignCast(result.*.handle orelse return FFFError.SearchFailed));
        defer c.fff_free_search_result(sr);

        var items = try allocator.alloc(FileMatch, sr.count);
        errdefer allocator.free(items);

        for (0..sr.count) |i| {
            const fi = c.fff_search_result_get_item(sr, @intCast(i));
            const sc = c.fff_search_result_get_score(sr, @intCast(i));
            items[i] = .{
                .path = if (fi != null and fi.*.path != null) try allocator.dupe(u8, std.mem.span(fi.*.path)) else "",
                .relative_path = if (fi != null and fi.*.relative_path != null) try allocator.dupe(u8, std.mem.span(fi.*.relative_path)) else "",
                .score = if (sc != null) sc.*.total else 0,
            };
        }

        return .{
            .items = items,
            .total_matched = sr.total_matched,
            .total_files = sr.total_files,
        };
    }

    /// Content grep (live_grep).
    pub fn grep(
        self: *Self,
        allocator: std.mem.Allocator,
        query: []const u8,
        opts: GrepOptions,
    ) !GrepResult {
        const query_z = try allocator.dupeZ(u8, query);
        defer allocator.free(query_z);

        const result = c.fff_live_grep(
            self.handle,
            query_z.ptr,
            opts.mode, // 0=plain, 1=regex, 2=fuzzy
            0, // max_file_size (default 10MB)
            0, // max_matches_per_file (unlimited)
            true, // smart_case
            0, // file_offset
            opts.max_results, // page_limit
            opts.time_budget_ms, // time_budget_ms
            opts.context_before, // before_context
            opts.context_after, // after_context
            false, // classify_definitions
        );
        if (result == null) return FFFError.GrepFailed;
        defer c.fff_free_result(result);

        if (!result.*.success) {
            if (result.*.@"error" != null) {
                std.log.err("fff grep failed: {s}", .{std.mem.span(result.*.@"error")});
            }
            return FFFError.GrepFailed;
        }

        const gr: *FffGrepResult = @ptrCast(@alignCast(result.*.handle orelse return FFFError.GrepFailed));
        defer c.fff_free_grep_result(gr);

        var matches = try allocator.alloc(GrepMatch, gr.count);
        errdefer allocator.free(matches);

        for (0..gr.count) |i| {
            const m = c.fff_grep_result_get_match(gr, @intCast(i));
            if (m == null) {
                matches[i] = .{};
                continue;
            }
            matches[i] = .{
                .path = if (m.*.relative_path != null) try allocator.dupe(u8, std.mem.span(m.*.relative_path)) else "",
                .line_number = m.*.line_number,
                .col = m.*.col,
                .line_content = if (m.*.line_content != null) try allocator.dupe(u8, std.mem.span(m.*.line_content)) else "",
            };
        }

        return .{
            .matches = matches,
            .total_matched = gr.total_matched,
            .total_files = gr.total_files,
            .total_files_searched = gr.total_files_searched,
            .next_file_offset = gr.next_file_offset,
        };
    }
};

// ============================================================================
// Result types
// ============================================================================

pub const FileMatch = struct {
    path: []const u8 = "",
    relative_path: []const u8 = "",
    score: i32 = 0,
};

pub const SearchResult = struct {
    items: []FileMatch,
    total_matched: u32,
    total_files: u32,
};

pub const GrepOptions = struct {
    mode: u8 = 0, // 0=plain, 1=regex, 2=fuzzy
    max_results: u32 = 50,
    time_budget_ms: u64 = 0, // 0=unlimited
    context_before: u32 = 0,
    context_after: u32 = 0,
};

pub const GrepMatch = struct {
    path: []const u8 = "",
    line_number: u64 = 0,
    col: u32 = 0,
    line_content: []const u8 = "",
};

pub const GrepResult = struct {
    matches: []GrepMatch,
    total_matched: u32,
    total_files: u32,
    total_files_searched: u32,
    next_file_offset: u32,
};
