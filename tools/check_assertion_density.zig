//! Assertion Density Checker - TigerBeetle Standard Enforcement
//! 
//! Scans source files and calculates assertion density (asserts per function).
//! Target: 1.5 assertions per function (TigerBeetle standard)
//!
//! Usage:
//!   zig build-exe tools/check_assertion_density.zig
//!   ./check_assertion_density [--min-density 1.5] [--ci] [directory]

const std = @import("std");

const Config = struct {
    min_density: f64 = 1.5,
    ci_mode: bool = false,
    directory: []const u8 = "src",
};

const FileStats = struct {
    path: []const u8,
    functions: usize,
    asserts: usize,
    
    fn density(self: FileStats) f64 {
        if (self.functions == 0) return 0.0;
        return @as(f64, @floatFromInt(self.asserts)) / @as(f64, @floatFromInt(self.functions));
    }
};

const TotalStats = struct {
    total_files: usize = 0,
    total_functions: usize = 0,
    total_asserts: usize = 0,
    files_below_target: usize = 0,
    files_above_target: usize = 0,
    
    fn density(self: TotalStats) f64 {
        if (self.total_functions == 0) return 0.0;
        return @as(f64, @floatFromInt(self.total_asserts)) / @as(f64, @floatFromInt(self.total_functions));
    }
    
    fn percentOfTarget(self: TotalStats, target: f64) f64 {
        return (self.density() / target) * 100.0;
    }
};

pub fn main() !void {
    // Use testing allocator for simplicity
    const allocator = std.testing.allocator;

    // Parse arguments
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    
    _ = args.next(); // Skip program name
    
    var config = Config{};
    
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--ci")) {
            config.ci_mode = true;
        } else if (std.mem.eql(u8, arg, "--min-density")) {
            if (args.next()) |value| {
                config.min_density = try std.fmt.parseFloat(f64, value);
            }
        } else {
            config.directory = arg;
        }
    }

    // Scan directory
    var stats = TotalStats{};
    var files = std.ArrayList(FileStats).init(allocator);
    defer {
        for (files.items) |file| allocator.free(file.path);
        files.deinit();
    }
    
    try scanDirectory(allocator, config.directory, &stats, &files, config.min_density);
    
    // Report results
    if (config.ci_mode) {
        try reportCI(stats, config.min_density);
    } else {
        try reportHuman(allocator, stats, files.items, config.min_density);
    }
    
    // Exit code: 0 if meets target, 1 otherwise
    if (stats.density() < config.min_density) {
        std.process.exit(1);
    }
}

fn scanDirectory(
    allocator: std.mem.Allocator,
    dir_path: []const u8,
    stats: *TotalStats,
    files: *std.ArrayList(FileStats),
    min_density: f64,
) !void {
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();
    
    var walker = try dir.walk(allocator);
    defer walker.deinit();
    
    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".zig")) continue;
        
        // Skip test files
        if (std.mem.indexOf(u8, entry.basename, "test") != null) continue;
        
        const full_path = try std.fs.path.join(allocator, &.{ dir_path, entry.path });
        defer allocator.free(full_path);
        
        const content = try dir.readFileAlloc(allocator, entry.path, 10 * 1024 * 1024);
        defer allocator.free(content);
        
        const functions = countFunctions(content);
        const asserts = countAsserts(content);
        
        if (functions == 0) continue; // Skip files with no functions
        
        const file_stat = FileStats{
            .path = try allocator.dupe(u8, full_path),
            .functions = functions,
            .asserts = asserts,
        };
        
        try files.append(file_stat);
        
        stats.total_files += 1;
        stats.total_functions += functions;
        stats.total_asserts += asserts;
        
        if (file_stat.density() >= min_density) {
            stats.files_above_target += 1;
        } else {
            stats.files_below_target += 1;
        }
    }
}

fn countFunctions(content: []const u8) usize {
    var count: usize = 0;
    var lines = std.mem.splitScalar(u8, content, '\n');
    
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t");
        
        // Match function definitions: "pub fn " or "fn "
        if (std.mem.startsWith(u8, trimmed, "pub fn ") or 
            std.mem.startsWith(u8, trimmed, "fn ")) {
            // Exclude function types and pointers
            if (std.mem.indexOf(u8, trimmed, "fn(") == null and
                std.mem.indexOf(u8, trimmed, "*const fn") == null and
                std.mem.indexOf(u8, trimmed, "*fn") == null) {
                count += 1;
            }
        }
    }
    
    return count;
}

fn countAsserts(content: []const u8) usize {
    var count: usize = 0;
    var index: usize = 0;
    
    const pattern = "assert(";
    while (std.mem.indexOf(u8, content[index..], pattern)) |pos| {
        count += 1;
        index += pos + pattern.len;
    }
    
    return count;
}

fn reportHuman(
    allocator: std.mem.Allocator,
    stats: TotalStats,
    file_stats: []const FileStats,
    min_density: f64,
) !void {
    const stdout = std.io.getStdOut().writer();
    
    try stdout.print("\n╔═══════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║  Assertion Density Report - TigerBeetle Standard ({d:.1}/fn)  ║\n", .{min_density});
    try stdout.print("╚═══════════════════════════════════════════════════════════════╝\n\n", .{});
    
    // Overall stats
    try stdout.print("📊 Overall Statistics:\n", .{});
    try stdout.print("  Total Files:      {d}\n", .{stats.total_files});
    try stdout.print("  Total Functions:  {d}\n", .{stats.total_functions});
    try stdout.print("  Total Asserts:    {d}\n", .{stats.total_asserts});
    try stdout.print("  Average Density:  {d:.2}/fn ({d:.1}% of target)\n\n", .{
        stats.density(),
        stats.percentOfTarget(min_density),
    });
    
    // Target achievement
    const meets_target = stats.density() >= min_density;
    if (meets_target) {
        try stdout.print("✅ TARGET MET! Average density exceeds {d:.1}/fn\n\n", .{min_density});
    } else {
        const gap = @as(isize, @intFromFloat(stats.total_functions * min_density)) - @as(isize, @intCast(stats.total_asserts));
        try stdout.print("❌ TARGET NOT MET! Need {d} more asserts to reach {d:.1}/fn\n\n", .{ gap, min_density });
    }
    
    // Files above target
    try stdout.print("🌟 Files Exceeding Target ({d}):\n", .{stats.files_above_target});
    const sorted_files = try allocator.dupe(FileStats, file_stats);
    defer allocator.free(sorted_files);
    
    std.mem.sort(FileStats, sorted_files, {}, struct {
        fn lessThan(_: void, a: FileStats, b: FileStats) bool {
            return a.density() > b.density();
        }
    }.lessThan);
    
    for (sorted_files) |file| {
        if (file.density() >= min_density) {
            try stdout.print("  ✅ {s}: {d} fns, {d} asserts ({d:.2}/fn)\n", .{
                file.path,
                file.functions,
                file.asserts,
                file.density(),
            });
        }
    }
    
    // Files below target
    try stdout.print("\n⚠️  Files Below Target ({d}):\n", .{stats.files_below_target});
    for (sorted_files) |file| {
        if (file.density() < min_density) {
            const needed = @as(isize, @intFromFloat(@as(f64, @floatFromInt(file.functions)) * min_density)) - @as(isize, @intCast(file.asserts));
            try stdout.print("  ❌ {s}: {d} fns, {d} asserts ({d:.2}/fn, need +{d})\n", .{
                file.path,
                file.functions,
                file.asserts,
                file.density(),
                needed,
            });
        }
    }
    
    try stdout.print("\n", .{});
}

fn reportCI(stats: TotalStats, min_density: f64) !void {
    const stdout = std.io.getStdOut().writer();
    
    // CI-friendly output (GitHub Actions compatible)
    if (stats.density() >= min_density) {
        try stdout.print("::notice::Assertion density check PASSED: {d:.2}/fn ({d:.1}% of {d:.1}/fn target)\n", .{
            stats.density(),
            stats.percentOfTarget(min_density),
            min_density,
        });
    } else {
        const gap = @as(isize, @intFromFloat(stats.total_functions * min_density)) - @as(isize, @intCast(stats.total_asserts));
        try stdout.print("::error::Assertion density check FAILED: {d:.2}/fn (need {d} more asserts for {d:.1}/fn target)\n", .{
            stats.density(),
            gap,
            min_density,
        });
    }
    
    // Summary for CI logs
    try stdout.print("Files: {d}, Functions: {d}, Asserts: {d}, Density: {d:.2}/fn\n", .{
        stats.total_files,
        stats.total_functions,
        stats.total_asserts,
        stats.density(),
    });
}
