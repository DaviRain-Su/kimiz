//! File Command Filters - Native Zig implementation
//! Compresses ls, find, and tree outputs for reduced token consumption

const std = @import("std");
const filters = @import("filters.zig");
const FilterContext = filters.FilterContext;
const FilterResult = filters.FilterResult;

// ============================================================================
// LS Filter
// ============================================================================

fn lsFilter(ctx: FilterContext) !FilterResult {
    const allocator = ctx.allocator;
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    var lines = std.mem.splitScalar(u8, ctx.raw_output, '\n');
    var total_files: usize = 0;
    var total_dirs: usize = 0;
    var file_list: std.ArrayList([]const u8) = .empty;
    defer file_list.deinit(allocator);

    while (lines.next()) |line| {
        if (line.len == 0) continue;
        if (std.mem.startsWith(u8, line, "total ")) continue;

        if (line[0] == 'd') {
            total_dirs += 1;
            if (ctx.strategy == .conservative or total_dirs <= 10) {
                const name = getLastFieldFromLine(line);
                const line_text = try std.fmt.allocPrint(allocator, "Dir: {s}\n", .{name});
                defer allocator.free(line_text);
                try result.appendSlice(allocator, line_text);
            }
        } else if (line[0] == '-' or line[0] == 'l') {
            total_files += 1;
            if (ctx.strategy == .conservative or total_files <= 15) {
                const name = getLastFieldFromLine(line);
                const size = getFileSize(line);
                if (ctx.strategy == .aggressive) {
                    const line_text = try std.fmt.allocPrint(allocator, "  {s}\n", .{name});
                    defer allocator.free(line_text);
                    try result.appendSlice(allocator, line_text);
                } else {
                    const line_text = try std.fmt.allocPrint(allocator, "  {s} ({s})\n", .{ name, size });
                    defer allocator.free(line_text);
                    try result.appendSlice(allocator, line_text);
                }
            }
        } else {
            // Non-standard ls output, keep verbatim
            try result.appendSlice(allocator, line);
            try result.append(allocator, '\n');
        }
    }

    if (result.items.len == 0 and (total_files > 0 or total_dirs > 0)) {
        try result.appendSlice(allocator, try std.fmt.allocPrint(
            allocator,
            "📁 {d} dirs, 📄 {d} files\n",
            .{ total_dirs, total_files },
        ));
    }

    if (total_dirs > 10 or total_files > 15) {
        try result.appendSlice(allocator, try std.fmt.allocPrint(
            allocator,
            "... +{d} more items\n",
            .{ total_dirs +| total_files - @min(total_dirs, 10) - @min(total_files, 15) },
        ));
    }

    const filtered = try result.toOwnedSlice(allocator);

    return FilterResult{
        .filtered = filtered,
        .tokens_saved = filters.estimateTokens(ctx.raw_output) - filters.estimateTokens(filtered),
        .compression_ratio = filters.calcCompressionRatio(ctx.raw_output, filtered),
    };
}

fn getLastFieldFromLine(line: []const u8) []const u8 {
    var parts = std.mem.splitScalar(u8, line, ' ');
    var last: ?[]const u8 = null;
    while (parts.next()) |part| {
        if (part.len > 0) last = part;
    }
    return last orelse line;
}

fn getFileSize(line: []const u8) []const u8 {
    var parts = std.mem.splitScalar(u8, line, ' ');
    var count: usize = 0;
    while (parts.next()) |part| {
        if (part.len == 0) continue;
        count += 1;
        if (count == 5) return part;
    }
    return "-";
}

pub const ls_filter = filters.OutputFilter{
    .name = "ls",
    .description = "Compact directory listing with counts",
    .filter_fn = lsFilter,
};

// ============================================================================
// Find Filter
// ============================================================================

fn findFilter(ctx: FilterContext) !FilterResult {
    const allocator = ctx.allocator;
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    var paths = std.StringHashMap(usize).init(allocator);
    defer paths.deinit();

    var lines = std.mem.splitScalar(u8, ctx.raw_output, '\n');
    var total: usize = 0;

    while (lines.next()) |line| {
        if (line.len == 0) continue;
        total += 1;

        const dir = std.fs.path.dirname(line) orelse ".";
        const entry = try paths.getOrPut(dir);
        if (!entry.found_existing) {
            entry.value_ptr.* = 0;
        }
        entry.value_ptr.* += 1;
    }

    var iter = paths.iterator();
    var shown: usize = 0;
    while (iter.next()) |entry| {
        if (shown >= 10 and ctx.strategy == .aggressive) {
            const remaining = paths.count() - shown;
            if (remaining > 0) {
                const more = try std.fmt.allocPrint(allocator, "... +{d} more directories\n", .{remaining});
                defer allocator.free(more);
                try result.appendSlice(allocator, more);
            }
            break;
        }
        const line_text = try std.fmt.allocPrint(allocator, "{s} ({d} files)\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        defer allocator.free(line_text);
        try result.appendSlice(allocator, line_text);
        shown += 1;
    }

    const total_line = try std.fmt.allocPrint(allocator, "Total: {d} files\n", .{total});
    defer allocator.free(total_line);
    try result.appendSlice(allocator, total_line);

    const filtered = try result.toOwnedSlice(allocator);

    return FilterResult{
        .filtered = filtered,
        .tokens_saved = filters.estimateTokens(ctx.raw_output) - filters.estimateTokens(filtered),
        .compression_ratio = filters.calcCompressionRatio(ctx.raw_output, filtered),
    };
}

pub const find_filter = filters.OutputFilter{
    .name = "find",
    .description = "Group find results by directory",
    .filter_fn = findFilter,
};

// ============================================================================
// Tests
// ============================================================================

test "lsFilter" {
    const allocator = std.testing.allocator;

    const input =
        \\total 120
        \\drwxr-xr-x  15 user  staff   480 Apr  5 17:00 .
        \\drwxr-xr-x   5 user  staff   160 Apr  5 16:00 ..
        \\-rw-r--r--   1 user  staff   172 Apr  1 10:00 .gitignore
        \\drwxr-xr-x   8 user  staff   256 Apr  5 16:30 .git
        \\-rw-r--r--   1 user  staff  8800 Apr  5 16:00 build.zig
    ;

    const ctx = FilterContext{
        .allocator = allocator,
        .strategy = .balanced,
        .command = "ls -la",
        .raw_output = input,
        .max_tokens = 2000,
    };

    const result = try lsFilter(ctx);
    defer result.deinit(allocator);

    try std.testing.expect(std.mem.indexOf(u8, result.filtered, ".git")
 != null);
    try std.testing.expect(result.compression_ratio >= 0);
}

test "findFilter" {
    const allocator = std.testing.allocator;

    const input =
        \\./src/main.zig
        \\./src/config.zig
        \\./src/agent.zig
        \\./tests/test1.zig
        \\./tests/test2.zig
    ;

    const ctx = FilterContext{
        .allocator = allocator,
        .strategy = .balanced,
        .command = "find . -name '*.zig'",
        .raw_output = input,
        .max_tokens = 2000,
    };

    const result = try findFilter(ctx);
    defer result.deinit(allocator);

    try std.testing.expect(std.mem.indexOf(u8, result.filtered, "./src") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.filtered, "Total:") != null);
    try std.testing.expect(result.tokens_saved > 0);
}
