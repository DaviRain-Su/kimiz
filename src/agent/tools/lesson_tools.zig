//! Lesson Tools (T-123)
//! Tools for reading and writing lessons-learned.md

const std = @import("std");
const tool = @import("../tool.zig");
const utils = @import("../../utils/root.zig");

// ============================================================================
// Tool: add_lesson
// ============================================================================

const ADD_LESSON_NAME = "add_lesson";
const ADD_LESSON_DESCRIPTION =
    \\Appends a new lesson entry to docs/lessons-learned.md (project long-term memory).
    \\The lesson is added at the top of the file (reverse chronological order).
    \\
    \\Categories: 架构决策, 踩坑记录, 性能优化, API 选择, 安全提醒
;

const ADD_LESSON_SCHEMA =
    \\{
    \\  "type": "object",
    \\  "required": ["category", "source", "lesson"],
    \\  "properties": {
    \\    "category": {
    \\      "type": "string",
    \\      "description": "Category: 架构决策, 踩坑记录, 性能优化, API 选择, 安全提醒"
    \\    },
    \\    "source": {
    \\      "type": "string",
    \\      "description": "Source of this lesson (e.g., task ID or event)"
    \\    },
    \\    "lesson": {
    \\      "type": "string",
    \\      "description": "The lesson text"
    \\    }
    \\  }
    \\}
;

pub const add_lesson_definition = tool.Tool{
    .name = ADD_LESSON_NAME,
    .description = ADD_LESSON_DESCRIPTION,
    .parameters_json = ADD_LESSON_SCHEMA,
};

pub const AddLessonContext = struct {};

pub fn createAddLessonTool(ctx: *AddLessonContext) tool.AgentTool {
    return .{
        .tool = add_lesson_definition,
        .execute_fn = struct {
            fn exec(ptr: *anyopaque, arena: std.mem.Allocator, args: std.json.Value) anyerror!tool.ToolResult {
                _ = ptr;
                return executeAddLesson(arena, args);
            }
        }.exec,
        .ctx = ctx,
    };
}

fn executeAddLesson(arena: std.mem.Allocator, args: std.json.Value) !tool.ToolResult {
    const category_val = args.object.get("category") orelse
        return tool.errorResult(arena, "Missing required parameter: category");
    const source_val = args.object.get("source") orelse
        return tool.errorResult(arena, "Missing required parameter: source");
    const lesson_val = args.object.get("lesson") orelse
        return tool.errorResult(arena, "Missing required parameter: lesson");

    const category = category_val.string;
    const source = source_val.string;
    const lesson = lesson_val.string;

    if (category.len == 0) return tool.errorResult(arena, "category cannot be empty");
    if (source.len == 0) return tool.errorResult(arena, "source cannot be empty");
    if (lesson.len == 0) return tool.errorResult(arena, "lesson cannot be empty");

    const lessons_path = "docs/lessons-learned.md";

    // Read existing content
    const existing = utils.readFileAlloc(arena, lessons_path, 256 * 1024) catch |err|
        return tool.errorResult(arena, try std.fmt.allocPrint(arena, "Failed to read lessons-learned.md: {s}", .{@errorName(err)}));

    // Build new lesson entry
    const ts = utils.milliTimestamp();
    const entry = try std.fmt.allocPrint(arena,
        \\---
        \\
        \\## {d} | {s}
        \\
        \\**分类**: {s}
        \\**来源**: {s}
        \\**教训**: {s}
        \\
    , .{ ts, lesson[0..@min(60, lesson.len)], category, source, lesson });

    // Find insertion point (after header, before first ---)
    const header_end = std.mem.indexOf(u8, existing, "---\n\n") orelse
        std.mem.indexOf(u8, existing, "---\n") orelse
        existing.len;

    var buf: std.ArrayList(u8) = .empty;
    try buf.appendSlice(arena, existing[0 .. header_end + 4]);
    try buf.append(arena, '\n');
    try buf.appendSlice(arena, entry);
    try buf.appendSlice(arena, existing[header_end + 4 ..]);

    // Atomic write
    const tmp_path = try std.fmt.allocPrint(arena, "{s}.tmp", .{lessons_path});
    try utils.writeFile(tmp_path, buf.items);
    try utils.rename(tmp_path, lessons_path);

    const response = try std.fmt.allocPrint(arena, "Lesson added successfully:\n\n{s}", .{entry});
    return tool.textContent(arena, response);
}

// ============================================================================
// Tests
// ============================================================================

test "add_lesson tool definition" {
    try std.testing.expectEqualStrings("add_lesson", add_lesson_definition.name);
}
