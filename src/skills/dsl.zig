//! comptime Skill DSL - T-103 SPIKE (Extended)
//! Compile-time skill definition with type-safe input/output validation

const std = @import("std");
const skills = @import("root.zig");

/// Define a skill at compile time with type-safe input/output contracts.
/// Returns a struct type that can generate a runtime `Skill` via `.toSkill()`.
pub fn defineSkill(comptime config: anytype) type {
    // Comptime validation
    comptime {
        validateConfig(config);
    }

    // Extract handler signature metadata at comptime
    const HandlerType = @TypeOf(config.handler);
    const fn_info = @typeInfo(HandlerType).@"fn";

    comptime var has_ctx = false;
    comptime var has_alloc = false;
    comptime var input_index: usize = 0;
    comptime var found_input = false;

    inline for (fn_info.params, 0..) |param, i| {
        const P = param.type orelse {
            @compileError("defineSkill: `handler` parameter types must be explicit");
        };
        if (P == config.input or isStructurallyEquivalent(P, config.input)) {
            if (found_input) @compileError("defineSkill: `handler` has multiple input-like parameters");
            found_input = true;
            input_index = i;
        } else if (P == skills.SkillContext) {
            if (has_ctx) @compileError("defineSkill: `handler` has multiple SkillContext parameters");
            has_ctx = true;
        } else if (P == std.mem.Allocator) {
            if (has_alloc) @compileError("defineSkill: `handler` has multiple Allocator parameters");
            has_alloc = true;
        } else {
            @compileError("defineSkill: `handler` has an unrecognized parameter type");
        }
    }
    if (!found_input) @compileError("defineSkill: `handler` must have a parameter matching `input`");

    return struct {
        pub const id = config.name;
        pub const name = config.name;
        pub const description = config.description;
        pub const version = "1.0.0";
        pub const category = skills.Skill.SkillCategory.misc;

        /// Auto-generated params from input struct fields
        pub const params = blk: {
            const input_info = @typeInfo(config.input);
            var params_array: [input_info.@"struct".fields.len]skills.SkillParam = undefined;
            for (input_info.@"struct".fields, 0..) |field, i| {
                const param_type = mapTypeToParamType(field.type, field.name);
                const has_default = field.default_value_ptr != null;
                const required = @typeInfo(field.type) != .optional and !has_default;
                params_array[i] = skills.SkillParam{
                    .name = field.name,
                    .description = field.name,
                    .param_type = param_type,
                    .required = required,
                    .default_value = getDefaultValue(field.type, field.default_value_ptr),
                };
            }
            const final = params_array;
            break :blk &final;
        };

        /// Execute function compatible with Skill.execute_fn
        pub fn execute_fn(
            ctx: skills.SkillContext,
            args: std.json.ObjectMap,
            arena: std.mem.Allocator,
        ) anyerror!skills.SkillResult {
            const InputType = fn_info.params[input_index].type.?;
            var input: InputType = undefined;
            inline for (comptime @typeInfo(InputType).@"struct".fields) |field| {
                const arg_val = args.get(field.name);
                if (arg_val) |val| {
                    @field(input, field.name) = try parseJsonValue(val, field.type, arena);
                } else if (@typeInfo(field.type) == .optional) {
                    @field(input, field.name) = null;
                } else if (field.default_value_ptr) |ptr| {
                    @field(input, field.name) = comptime defaultToValue(field.type, ptr);
                } else {
                    return skills.SkillResult{
                        .success = false,
                        .output = "",
                        .error_message = try std.fmt.allocPrint(arena, "Missing required parameter: {s}", .{field.name}),
                        .execution_time_ms = 0,
                    };
                }
            }

            const output = callHandler(input, ctx, arena);

            const output_str = try formatOutput(output, arena);
            var result = skills.SkillResult{
                .success = output.success,
                .output = output_str,
                .execution_time_ms = 0,
            };

            if (@hasField(@TypeOf(output), "error_message")) {
                if (@TypeOf(output.error_message) == ?[]const u8) {
                    if (output.error_message) |em| {
                        result.error_message = try arena.dupe(u8, em);
                    }
                } else if (@TypeOf(output.error_message) == []const u8) {
                    result.error_message = try arena.dupe(u8, output.error_message);
                }
            }

            return result;
        }

        fn callHandler(input: anytype, ctx: skills.SkillContext, arena: std.mem.Allocator) fn_info.return_type.? {
            if (has_ctx and has_alloc) return config.handler(ctx, input, arena);
            if (has_ctx) return config.handler(ctx, input);
            if (has_alloc) return config.handler(input, arena);
            return config.handler(input);
        }

        pub fn toSkill() skills.Skill {
            return skills.Skill{
                .id = id,
                .name = name,
                .description = description,
                .version = version,
                .category = category,
                .params = params,
                .execute_fn = execute_fn,
            };
        }
    };
}

fn validateConfig(comptime config: anytype) void {
    const input_info = @typeInfo(config.input);
    if (input_info != .@"struct") {
        @compileError("defineSkill: `input` must be a struct");
    }

    const output_info = @typeInfo(config.output);
    if (output_info != .@"struct") {
        @compileError("defineSkill: `output` must be a struct");
    }

    var has_success = false;
    for (output_info.@"struct".fields) |field| {
        if (std.mem.eql(u8, field.name, "success") and field.type == bool) {
            has_success = true;
        }
    }
    if (!has_success) {
        @compileError("defineSkill: `output` must contain a `success: bool` field");
    }

    const HandlerType = @TypeOf(config.handler);
    const handler_info = @typeInfo(HandlerType);
    if (handler_info != .@"fn") {
        @compileError("defineSkill: `handler` must be a function");
    }

    const expected_return_type = handler_info.@"fn".return_type orelse {
        @compileError("defineSkill: `handler` return type must be explicit");
    };
    if (expected_return_type != config.output and !isStructurallyEquivalent(expected_return_type, config.output)) {
        @compileError("defineSkill: `handler` return type must match `output`");
    }
}

fn isStructurallyEquivalent(comptime a: type, comptime b: type) bool {
    const a_info = @typeInfo(a);
    const b_info = @typeInfo(b);
    if (a_info != .@"struct" or b_info != .@"struct") return false;
    const a_fields = a_info.@"struct".fields;
    const b_fields = b_info.@"struct".fields;
    if (a_fields.len != b_fields.len) return false;
    for (a_fields, b_fields) |af, bf| {
        if (!std.mem.eql(u8, af.name, bf.name)) return false;
        if (af.type != bf.type) return false;
    }
    return true;
}

fn mapTypeToParamType(comptime T: type, comptime field_name: []const u8) skills.SkillParam.ParamType {
    if (@typeInfo(T) == .@"enum") return .selection;
    if (@typeInfo(T) == .optional and @typeInfo(@typeInfo(T).optional.child) == .@"enum") return .selection;

    return switch (T) {
        bool => .boolean,
        i32, i64, u32, u64 => .integer,
        []const u8 => classifyStringParam(field_name),
        ?[]const u8 => classifyStringParam(field_name),
        else => .string,
    };
}

fn classifyStringParam(comptime name: []const u8) skills.SkillParam.ParamType {
    if (endsWithAny(name, &.{ "filepath", "file_path", "path" })) return .filepath;
    if (endsWithAny(name, &.{ "directory", "dir", "folder" })) return .directory;
    if (endsWithAny(name, &.{ "code", "context", "content", "script", "patch" })) return .code;
    return .string;
}

fn endsWithAny(comptime haystack: []const u8, comptime needles: []const []const u8) bool {
    inline for (needles) |needle| {
        if (haystack.len >= needle.len and std.mem.eql(u8, haystack[haystack.len - needle.len ..], needle)) return true;
    }
    return false;
}

fn getDefaultValue(comptime T: type, comptime default_ptr: ?*const anyopaque) ?[]const u8 {
    const ptr = default_ptr orelse return null;
    return switch (T) {
        ?[]const u8 => {
            const val: *const ?[]const u8 = @ptrCast(@alignCast(ptr));
            return val.*;
        },
        []const u8 => {
            const val: *const []const u8 = @ptrCast(@alignCast(ptr));
            return val.*;
        },
        bool => {
            const val: *const bool = @ptrCast(@alignCast(ptr));
            return if (val.*) "true" else "false";
        },
        i32, i64, u32, u64 => {
            const val: *const T = @ptrCast(@alignCast(ptr));
            return std.fmt.comptimePrint("{d}", .{val.*});
        },
        else => blk: {
            if (@typeInfo(T) == .@"enum") {
                const val: *const T = @ptrCast(@alignCast(ptr));
                break :blk @tagName(val.*);
            }
            break :blk null;
        },
    };
}

fn defaultToValue(comptime T: type, comptime default_ptr: *const anyopaque) T {
    return switch (T) {
        ?[]const u8, []const u8, bool, i32, i64, u32, u64 => {
            const val: *const T = @ptrCast(@alignCast(default_ptr));
            return val.*;
        },
        else => blk: {
            if (@typeInfo(T) == .@"enum") {
                const val: *const T = @ptrCast(@alignCast(default_ptr));
                break :blk val.*;
            }
            @compileError("unsupported default value type");
        },
    };
}

fn parseJsonValue(val: std.json.Value, comptime T: type, arena: std.mem.Allocator) !T {
    return switch (T) {
        []const u8 => switch (val) {
            .string => |s| try arena.dupe(u8, s),
            else => error.InvalidParamType,
        },
        ?[]const u8 => switch (val) {
            .string => |s| try arena.dupe(u8, s),
            .null => null,
            else => error.InvalidParamType,
        },
        bool => switch (val) {
            .bool => |b| b,
            else => error.InvalidParamType,
        },
        i32 => switch (val) {
            .integer => |n| @intCast(n),
            else => error.InvalidParamType,
        },
        i64 => switch (val) {
            .integer => |n| n,
            else => error.InvalidParamType,
        },
        u32 => switch (val) {
            .integer => |n| if (n >= 0) @intCast(n) else error.InvalidParamType,
            else => error.InvalidParamType,
        },
        u64 => switch (val) {
            .integer => |n| if (n >= 0) @intCast(n) else error.InvalidParamType,
            else => error.InvalidParamType,
        },
        else => blk: {
            if (@typeInfo(T) == .@"enum") {
                break :blk switch (val) {
                    .string => |s| std.meta.stringToEnum(T, s) orelse error.InvalidParamType,
                    else => error.InvalidParamType,
                };
            }
            if (@typeInfo(T) == .optional and @typeInfo(@typeInfo(T).optional.child) == .@"enum") {
                break :blk switch (val) {
                    .string => |s| std.meta.stringToEnum(@typeInfo(T).optional.child, s) orelse error.InvalidParamType,
                    .null => null,
                    else => error.InvalidParamType,
                };
            }
            @compileError("unsupported parameter type for defineSkill");
        },
    };
}

fn formatOutput(output: anytype, arena: std.mem.Allocator) ![]const u8 {
    if (@hasField(@TypeOf(output), "output")) {
        if (@TypeOf(output.output) == []const u8) {
            return try arena.dupe(u8, output.output);
        }
    }
    return try std.json.stringifyAlloc(arena, output, .{});
}

// ============================================================================
// Tests
// ============================================================================

const Tone = enum {
    junior_dev,
    peer_reviewer,
    senior_architect,
};

fn enumHandler(input: struct {
    code: []const u8,
    tone: Tone = .junior_dev,
    verbose: ?bool = null,
}) struct {
    success: bool,
    output: []const u8,
} {
    _ = input;
    return .{ .success = true, .output = "enum ok" };
}

test "defineSkill with enum fields" {
    const EnumSkill = defineSkill(.{
        .name = "enum_test",
        .description = "Test enum support",
        .input = struct {
            code: []const u8,
            tone: Tone = .junior_dev,
            verbose: ?bool = null,
        },
        .output = struct {
            success: bool,
            output: []const u8,
        },
        .handler = enumHandler,
    });

    try std.testing.expectEqualStrings("enum_test", EnumSkill.id);
    try std.testing.expect(EnumSkill.params.len == 3);

    // tone should be selection type
    try std.testing.expect(EnumSkill.params[1].param_type == .selection);
    try std.testing.expectEqualStrings("junior_dev", EnumSkill.params[1].default_value.?);

    // filepath should be filepath type
    try std.testing.expect(EnumSkill.params[0].param_type == .filepath);

    // verbose should be boolean and not required
    try std.testing.expect(EnumSkill.params[2].param_type == .boolean);
    try std.testing.expect(EnumSkill.params[2].required == false);
}

test "defineSkill with SkillContext handler" {
    const allocator = std.testing.allocator;

    const CtxSkill = defineSkill(.{
        .name = "ctx_test",
        .description = "Test context handler",
        .input = struct {
            message: []const u8,
        },
        .output = struct {
            success: bool,
            output: []const u8,
        },
        .handler = struct {
            fn exec(ctx: skills.SkillContext, input: struct { message: []const u8 }) struct {
                success: bool,
                output: []const u8,
            } {
                _ = ctx;
                return .{ .success = true, .output = input.message };
            }
        }.exec,
    });

    var args = std.json.ObjectMap.init(allocator);
    defer args.deinit();
    try args.put("message", std.json.Value{ .string = "hello ctx" });

    const ctx = skills.SkillContext{
        .allocator = allocator,
        .working_dir = ".",
        .session_id = "test",
    };

    const result = try CtxSkill.execute_fn(ctx, args, allocator);
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("hello ctx", result.output);
}

test "defineSkill with allocator handler" {
    const allocator = std.testing.allocator;

    const AllocSkill = defineSkill(.{
        .name = "alloc_test",
        .description = "Test allocator handler",
        .input = struct {
            count: u32 = 10,
        },
        .output = struct {
            success: bool,
            output: []const u8,
        },
        .handler = struct {
            fn exec(input: struct { count: u32 }, arena: std.mem.Allocator) struct {
                success: bool,
                output: []const u8,
            } {
                const s = std.fmt.allocPrint(arena, "count={d}", .{input.count}) catch return .{ .success = false, .output = "" };
                return .{ .success = true, .output = s };
            }
        }.exec,
    });

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var args = std.json.ObjectMap.init(allocator);
    defer args.deinit();
    try args.put("count", std.json.Value{ .integer = 42 });

    const ctx = skills.SkillContext{
        .allocator = allocator,
        .working_dir = ".",
        .session_id = "test",
    };

    const result = try AllocSkill.execute_fn(ctx, args, arena.allocator());
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("count=42", result.output);
}

test "defineSkill registry integration" {
    const allocator = std.testing.allocator;

    const EchoSkill = defineSkill(.{
        .name = "echo",
        .description = "Echo skill",
        .input = struct {
            message: []const u8,
        },
        .output = struct {
            success: bool,
            output: []const u8,
        },
        .handler = struct {
            fn exec(input: struct { message: []const u8 }) struct {
                success: bool,
                output: []const u8,
            } {
                return .{ .success = true, .output = input.message };
            }
        }.exec,
    });

    var registry = skills.SkillRegistry.init(allocator);
    defer registry.deinit();

    try registry.register(EchoSkill.toSkill());

    const retrieved = registry.get("echo");
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualStrings("Echo skill", retrieved.?.description);
}
