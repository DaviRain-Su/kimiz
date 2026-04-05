//! Glob tool - Find files matching patterns

const std = @import("std");
const tool = @import("../tool.zig");
const utils = @import("../../utils/root.zig");

pub const tool_definition = tool.Tool{
    .name = "glob",
    .description = "Find files matching a glob pattern",
    .parameters_json =
        \\{"type":"object","properties":{"pattern":{"type":"string","description":"Glob pattern to match"},"path":{"type":"string","description":"Base directory to search"}},"required":["pattern"]}
    ,
};

pub const GlobContext = struct {
    pub fn execute(self: *GlobContext, arena: std.mem.Allocator, args: std.json.Value) !tool.ToolResult {
        _ = self;
        std.debug.assert(args == .object); // Args must be object
        
        const pattern = args.object.get("pattern") orelse return error.MissingArgument;
        const pattern_str = pattern.string;
        std.debug.assert(pattern_str.len > 0); // Pattern must be non-empty

        const base_path = if (args.object.get("path")) |p| p.string else ".";
        std.debug.assert(base_path.len > 0); // Path must be non-empty

        // Simple glob implementation - collect matching files
        var results = std.ArrayList(u8){ .items = &.{}, .capacity = 0 };
        defer results.deinit();

        // Use utils to open directory (Zig 0.16 compatible)
        const io = utils.getIo() catch |err| {
            return tool.textContent(arena, try std.fmt.allocPrint(arena, "Failed to get I/O: {s}", .{@errorName(err)}));
        };
        
        var dir = utils.openDir(base_path, .{ .iterate = true }) catch |err| {
            return tool.textContent(arena, try std.fmt.allocPrint(arena, "Error opening directory: {s}", .{@errorName(err)}));
        };
        defer dir.close(io);

        var walker = try dir.walk(arena);
        defer walker.deinit();

        var count: usize = 0;
        const max_results: usize = 100;
        while (try walker.next()) |entry| {
            if (entry.kind != .file) continue;

            // Simple pattern matching (exact match or contains)
            if (std.mem.indexOf(u8, entry.path, pattern_str) != null or
                std.mem.eql(u8, entry.path, pattern_str))
            {
                if (count > 0) try results.appendSlice("\n");
                try results.appendSlice(entry.path);
                const prev_count = count;
                count += 1;
                std.debug.assert(count == prev_count + 1); // Count incremented correctly
                std.debug.assert(count <= max_results); // Within limit

                // Limit results
                if (count >= max_results) {
                    try results.appendSlice("\n... (truncated to 100 results)");
                    break;
                }
            }
        }
        
        std.debug.assert(count <= max_results); // Final count within limit

        if (results.items.len == 0) {
            return tool.textContent(arena, "No files found matching pattern");
        }

        return tool.textContent(arena, try results.toOwnedSlice());
    }
};

pub fn createAgentTool(ctx: *GlobContext) tool.AgentTool {
    return .{
        .tool = tool_definition,
        .execute_fn = struct {
            fn exec(ptr: *anyopaque, arena: std.mem.Allocator, args: std.json.Value) anyerror!tool.ToolResult {
                const c: *GlobContext = @ptrCast(@alignCast(ptr));
                return c.execute(arena, args);
            }
        }.exec,
        .ctx = ctx,
    };
}
