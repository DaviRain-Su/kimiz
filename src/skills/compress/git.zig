//! Git Command Filters - Native Zig implementation
//! Compresses git command outputs for reduced token consumption

const std = @import("std");
const filters = @import("filters.zig");
const FilterContext = filters.FilterContext;
const FilterResult = filters.FilterResult;

// ============================================================================
// Git Status Filter
// ============================================================================

fn gitStatusFilter(ctx: FilterContext) !FilterResult {
    const allocator = ctx.allocator;
    const lines = std.mem.splitScalar(u8, ctx.raw_output, '\n');

    var branch_line: ?[]const u8 = null;
    var modified: std.ArrayList([]const u8) = .empty;
    defer modified.deinit(allocator);
    var untracked: std.ArrayList([]const u8) = .empty;
    defer untracked.deinit(allocator);
    var staged: std.ArrayList([]const u8) = .empty;
    defer staged.deinit(allocator);
    var deleted: std.ArrayList([]const u8) = .empty;
    defer deleted.deinit(allocator);
    var renamed: std.ArrayList([]const u8) = .empty;
    defer renamed.deinit(allocator);

    var it = lines;
    while (it.next()) |line| {
        if (line.len == 0) continue;

        if (std.mem.startsWith(u8, line, "On branch ")) {
            branch_line = std.mem.trim(u8, line["On branch ".len..], " \t\r");
        } else if (std.mem.startsWith(u8, line, "Your branch is ")) {
            // Processed separately or ignored based on strategy
        } else if (line.len > 2 and (line[0] == '\\' or line[0] == 't') and std.mem.indexOf(u8, line, "modified:") != null) {
            const idx = std.mem.indexOf(u8, line, "modified: ").? + "modified: ".len;
            try modified.append(allocator, std.mem.trim(u8, line[idx..], " \t"));
        } else if (line.len > 2 and (line[0] == '\\' or line[0] == 't') and std.mem.indexOf(u8, line, "new file:") != null) {
            const idx = std.mem.indexOf(u8, line, "new file: ").? + "new file: ".len;
            try staged.append(allocator, std.mem.trim(u8, line[idx..], " \t"));
        } else if (line.len > 2 and (line[0] == '\\' or line[0] == 't') and std.mem.indexOf(u8, line, "deleted:") != null) {
            const idx = std.mem.indexOf(u8, line, "deleted: ").? + "deleted: ".len;
            try deleted.append(allocator, std.mem.trim(u8, line[idx..], " \t"));
        } else if (line.len > 2 and (line[0] == '\\' or line[0] == 't') and std.mem.indexOf(u8, line, "renamed:") != null) {
            const idx = std.mem.indexOf(u8, line, "renamed: ").? + "renamed: ".len;
            try renamed.append(allocator, std.mem.trim(u8, line[idx..], " \t"));
        } else if (std.mem.startsWith(u8, line, "Untracked files:")) {
            // Collect next few indented lines
            while (it.next()) |untracked_line| {
                if (untracked_line.len == 0) continue;
                if (untracked_line[0] == '\t' or untracked_line[0] == 't') {
                    const start = if (untracked_line[0] == 't') untracked_line["t".len..] else untracked_line[1..];
                    try untracked.append(allocator, start);
                } else if (std.mem.startsWith(u8, untracked_line, "  (use \"git add")) {
                    continue;
                } else {
                    break;
                }
            }
            // Continue processing rest of output (nothing to skip)
        }
    }

    // Build compact output
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    if (branch_line) |branch| {
        try result.appendSlice(allocator, branch);
        try result.appendSlice(allocator, "\n");
    }

    if (staged.items.len > 0) {
        const header = try std.fmt.allocPrint(allocator, "Staged: {d}\n", .{staged.items.len});
        defer allocator.free(header);
        try result.appendSlice(allocator, header);
        for (staged.items) |f| {
            const line = try std.fmt.allocPrint(allocator, "  {s}\n", .{f});
            defer allocator.free(line);
            try result.appendSlice(allocator, line);
        }
    }

    if (modified.items.len > 0) {
        const header = try std.fmt.allocPrint(allocator, "Modified: {d}\n", .{modified.items.len});
        defer allocator.free(header);
        try result.appendSlice(allocator, header);

        if (modified.items.len <= 5 or ctx.strategy != .aggressive) {
            for (modified.items) |f| {
                const line = try std.fmt.allocPrint(allocator, "  {s}\n", .{f});
                defer allocator.free(line);
                try result.appendSlice(allocator, line);
            }
        } else {
            for (modified.items[0..5]) |f| {
                const line = try std.fmt.allocPrint(allocator, "  {s}\n", .{f});
                defer allocator.free(line);
                try result.appendSlice(allocator, line);
            }
            const more = try std.fmt.allocPrint(allocator, "  ... +{d} more\n", .{modified.items.len - 5});
            defer allocator.free(more);
            try result.appendSlice(allocator, more);
        }
    }

    if (deleted.items.len > 0) {
        const header = try std.fmt.allocPrint(allocator, "Deleted: {d}\n", .{deleted.items.len});
        defer allocator.free(header);
        try result.appendSlice(allocator, header);
        for (deleted.items) |f| {
            const line = try std.fmt.allocPrint(allocator, "  {s}\n", .{f});
            defer allocator.free(line);
            try result.appendSlice(allocator, line);
        }
    }

    if (renamed.items.len > 0) {
        const header = try std.fmt.allocPrint(allocator, "Renamed: {d}\n", .{renamed.items.len});
        defer allocator.free(header);
        try result.appendSlice(allocator, header);
        for (renamed.items) |f| {
            const line = try std.fmt.allocPrint(allocator, "  {s}\n", .{f});
            defer allocator.free(line);
            try result.appendSlice(allocator, line);
        }
    }

    if (untracked.items.len > 0) {
        const header = try std.fmt.allocPrint(allocator, "Untracked: {d}\n", .{untracked.items.len});
        defer allocator.free(header);
        try result.appendSlice(allocator, header);
        if (untracked.items.len <= 5 or ctx.strategy != .aggressive) {
            for (untracked.items) |f| {
                const line = try std.fmt.allocPrint(allocator, "  {s}\n", .{f});
                defer allocator.free(line);
                try result.appendSlice(allocator, line);
            }
        } else {
            for (untracked.items[0..5]) |f| {
                const line = try std.fmt.allocPrint(allocator, "  {s}\n", .{f});
                defer allocator.free(line);
                try result.appendSlice(allocator, line);
            }
            const more = try std.fmt.allocPrint(allocator, "  ... +{d} more\n", .{untracked.items.len - 5});
            defer allocator.free(more);
            try result.appendSlice(allocator, more);
        }
    }

    if (result.items.len == 0) {
        try result.appendSlice(allocator, "nothing to commit, working tree clean\n");
    }

    const filtered = try result.toOwnedSlice(allocator);

    return FilterResult{
        .filtered = filtered,
        .tokens_saved = filters.estimateTokens(ctx.raw_output) - filters.estimateTokens(filtered),
        .compression_ratio = filters.calcCompressionRatio(ctx.raw_output, filtered),
    };
}

pub const git_status_filter = filters.OutputFilter{
    .name = "git_status",
    .description = "Compact git status output with emoji indicators",
    .filter_fn = gitStatusFilter,
};

// ============================================================================
// Git Log Filter
// ============================================================================

fn gitLogFilter(ctx: FilterContext) !FilterResult {
    const allocator = ctx.allocator;
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    // Determine max lines based on strategy
    const max_lines: usize = switch (ctx.strategy) {
        .conservative => 20,
        .balanced => 10,
        .aggressive => 5,
    };

    var lines = std.mem.splitScalar(u8, ctx.raw_output, '\n');
    var count: usize = 0;

    while (lines.next()) |line| {
        if (line.len == 0) continue;

        if (count >= max_lines) {
            const remaining = std.mem.count(u8, ctx.raw_output, "\n") - count;
            if (remaining > 0) {
                const msg = try std.fmt.allocPrint(allocator, "... +{d} more commits\n", .{remaining});
                defer allocator.free(msg);
                try result.appendSlice(allocator, msg);
            }
            break;
        }

        // Parse one-line format: <hash> <message>
        // Keep as-is since we're assuming --oneline
        try result.appendSlice(allocator, line);
        try result.append(allocator, '\n');
        count += 1;
    }

    const filtered = try result.toOwnedSlice(allocator);

    return FilterResult{
        .filtered = filtered,
        .tokens_saved = filters.estimateTokens(ctx.raw_output) - filters.estimateTokens(filtered),
        .compression_ratio = filters.calcCompressionRatio(ctx.raw_output, filtered),
    };
}

pub const git_log_filter = filters.OutputFilter{
    .name = "git_log",
    .description = "Trucate git log to essential commits",
    .filter_fn = gitLogFilter,
};

// ============================================================================
// Git Diff Filter
// ============================================================================

fn gitDiffFilter(ctx: FilterContext) !FilterResult {
    const allocator = ctx.allocator;
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    var lines = std.mem.splitScalar(u8, ctx.raw_output, '\n');
    var current_file: ?[]const u8 = null;
    var added_lines: usize = 0;
    var removed_lines: usize = 0;
    var in_hunk = false;

    while (lines.next()) |line| {
        if (line.len == 0) continue;

        if (std.mem.startsWith(u8, line, "diff --git ")) {
            // Flush previous file stats
            if (current_file != null and (added_lines > 0 or removed_lines > 0)) {
                const stats = try std.fmt.allocPrint(allocator, "  +{d} -{d}\n", .{ added_lines, removed_lines });
                defer allocator.free(stats);
                try result.appendSlice(allocator, stats);
            }

            // Extract filename
            const a_start = std.mem.indexOf(u8, line, " a/") orelse continue;
            const b_start = std.mem.indexOf(u8, line, " b/") orelse continue;
            const filename = line[a_start + 3 .. b_start];

            current_file = filename;
            added_lines = 0;
            removed_lines = 0;
            in_hunk = false;

            const file_header = try std.fmt.allocPrint(allocator, "File: {s}\n", .{filename});
            defer allocator.free(file_header);
            try result.appendSlice(allocator, file_header);
        } else if (line[0] == '+') {
            if (!std.mem.startsWith(u8, line, "+++")) {
                added_lines += 1;
                if (ctx.strategy == .conservative or (ctx.strategy == .balanced and added_lines <= 3)) {
                    try result.appendSlice(allocator, line);
                    try result.append(allocator, '\n');
                }
            }
        } else if (line[0] == '-') {
            if (!std.mem.startsWith(u8, line, "---")) {
                removed_lines += 1;
                if (ctx.strategy == .conservative or (ctx.strategy == .balanced and removed_lines <= 3)) {
                    try result.appendSlice(allocator, line);
                    try result.append(allocator, '\n');
                }
            }
        } else if (std.mem.startsWith(u8, line, "@@ ")) {
            in_hunk = true;
            if (ctx.strategy != .aggressive) {
                try result.appendSlice(allocator, line);
                try result.append(allocator, '\n');
            }
        } else if (std.mem.startsWith(u8, line, "index ")) {
            // Skip
        }
    }

    // Flush last file
    if (current_file != null and (added_lines > 0 or removed_lines > 0)) {
        const stats = try std.fmt.allocPrint(allocator, "  +{d} -{d}\n", .{ added_lines, removed_lines });
        defer allocator.free(stats);
        try result.appendSlice(allocator, stats);
    }

    if (result.items.len == 0) {
        try result.appendSlice(allocator, "(no changes)\n");
    }

    const filtered = try result.toOwnedSlice(allocator);

    return FilterResult{
        .filtered = filtered,
        .tokens_saved = filters.estimateTokens(ctx.raw_output) - filters.estimateTokens(filtered),
        .compression_ratio = filters.calcCompressionRatio(ctx.raw_output, filtered),
    };
}

pub const git_diff_filter = filters.OutputFilter{
    .name = "git_diff",
    .description = "Condensed diff showing file stats and key changes",
    .filter_fn = gitDiffFilter,
};

// ============================================================================
// Tests
// ============================================================================

test "gitStatusFilter basic" {
    const allocator = std.testing.allocator;

    const input =
        \\On branch main
        \\Your branch is up to date with 'origin/main'.
        \\
        \\Changes not staged for commit:
        \\  (use "git add <file>..." to update what will be committed)
        \\  (use "git restore <file>..." to discard changes in working directory)
        \\\tmodified:   src/main.zig
        \\\tmodified:   README.md
        \\
        \\no changes added to commit (use "git add" and/or "git commit -a")
    ;

    const ctx = FilterContext{
        .allocator = allocator,
        .strategy = .balanced,
        .command = "git status",
        .raw_output = input,
        .max_tokens = 2000,
    };

    const result = try gitStatusFilter(ctx);
    defer result.deinit(allocator);

    try std.testing.expect(std.mem.indexOf(u8, result.filtered, "main") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.filtered, "Modified:") != null);
    try std.testing.expect(result.tokens_saved > 0);
    try std.testing.expect(result.compression_ratio > 0);
}

test "gitStatusFilter clean" {
    const allocator = std.testing.allocator;

    const input =
        \\On branch main
        \\Your branch is up to date with 'origin/main'.
        \\
        \\nothing to commit, working tree clean
    ;

    const ctx = FilterContext{
        .allocator = allocator,
        .strategy = .balanced,
        .command = "git status",
        .raw_output = input,
        .max_tokens = 2000,
    };

    const result = try gitStatusFilter(ctx);
    defer result.deinit(allocator);

    try std.testing.expect(result.compression_ratio > 0);
}

test "gitLogFilter" {
    const allocator = std.testing.allocator;

    const input =
        \\abc1234 Fix memory leak
        \\def5678 Add new feature
        \\ghi9012 Update docs
        \\jkl3456 Refactor code
        \\mno7890 Bump version
        \\pqr1234 Minor fix
    ;

    const ctx = FilterContext{
        .allocator = allocator,
        .strategy = .balanced,
        .command = "git log",
        .raw_output = input,
        .max_tokens = 2000,
    };

    const result = try gitLogFilter(ctx);
    defer result.deinit(allocator);

    try std.testing.expect(std.mem.indexOf(u8, result.filtered, "Fix memory leak") != null);
}

test "gitDiffFilter" {
    const allocator = std.testing.allocator;

    const input =
        \\diff --git a/src/main.zig b/src/main.zig
        \\index abc..def 100644
        \\--- a/src/main.zig
        \\+++ b/src/main.zig
        \\@@ -1,5 +1,6 @@
        \\ const std = @import("std");
        \\-const old = @import("old.zig");
        \\+const new = @import("new.zig");
        \\+const helper = @import("helper.zig");
        \\ 
        \\ pub fn main() void {
        \\     std.log.info("hello");
    ;

    const ctx = FilterContext{
        .allocator = allocator,
        .strategy = .balanced,
        .command = "git diff",
        .raw_output = input,
        .max_tokens = 2000,
    };

    const result = try gitDiffFilter(ctx);
    defer result.deinit(allocator);

    try std.testing.expect(std.mem.indexOf(u8, result.filtered, "File: src/main.zig") != null);
    try std.testing.expect(result.tokens_saved > 0);
}
