//! comptime Skill DSL - T-103 SPIKE
//! Compile-time skill definition with type-safe input/output validation

const std = @import("std");
const skills = @import("root.zig");

/// Define a skill at compile time with type-safe input/output contracts.
/// Returns a struct type that can generate a runtime `Skill` via `.toSkill()`.
pub fn defineSkill(comptime config: anytype) type {
    comptime {
        // Validate input is struct
        const input_info = @typeInfo(config.input);
        if (input_info != .Struct) {
            @compileError("defineSkill: `input` must be a struct");
        }

        // Validate output is struct
        const output_info = @typeInfo(config.output);
        if (output_info != .Struct) {
            @compileError("defineSkill: `output` must be a struct");
        }

        // Validate output has success: bool
        var has_success = false;
        for (output_info.Struct.fields) |field| {
            if (std.mem.eql(u8, field.name, "success") and field.type == bool) {
                has_success = true;
            }
        }
        if (!has_success) {
            @compileError("defineSkill: `output` must contain a `success: bool` field");
        }

        // Validate handler is a function
        const HandlerType = @TypeOf(config.handler);
        const handler_info = @typeInfo(HandlerType);
        if (handler_info != .Fn) {
            @compileError("defineSkill: `handler` must be a function");
        }

        // Validate handler takes exactly 1 argument
        if (handler_info.Fn.params.len != 1) {
            @compileError("defineSkill: `handler` must take exactly 1 argument");
        }

        // Validate handler argument type matches input
        const expected_param_type = handler_info.Fn.params[0].type orelse {
            @compileError("defineSkill: `handler` parameter type must be explicit");
        };
        if (expected_param_type != config.input) {
            @compileError("defineSkill: `handler` parameter type must match `input`");
        }

        // Validate handler return type matches output
        const expected_return_type = handler_info.Fn.return_type orelse {
            @compileError("defineSkill: `handler` return type must be explicit");
        };
        if (expected_return_type != config.output) {
            @compileError("defineSkill: `handler` return type must match `output`");
        }
    }

    return struct {
        pub const id = config.name;
        pub const name = config.name;
        pub const description = config.description;
        pub const version = "1.0.0";
        pub const category = skills.Skill.SkillCategory.misc;

        /// Convert input struct fields to SkillParam array
        pub fn getParams() []const skills.SkillParam {
            comptime {
                const input_info = @typeInfo(config.input);
        var params_array: [input_info.Struct.fields.len]skills.SkillParam = undefined;
                for (input_info.Struct.fields, 0..) |field, i| {
                    params_array[i] = skills.SkillParam{
                        .name = field.name,
                        .description = field.name,
                        .param_type = mapTypeToParamType(field.type),
                        .required = @typeInfo(field.type) != .Optional,
                    };
                }
                return &params_array;
            }
        }

        /// Execute function compatible with Skill.execute_fn
        pub fn execute_fn(
            ctx: skills.SkillContext,
            args: std.json.ObjectMap,
            arena: std.mem.Allocator,
        ) anyerror!skills.SkillResult {
            _ = ctx;

            // Build input struct from JSON args
            var input: config.input = undefined;
            inline for (comptime @typeInfo(config.input).Struct.fields) |field| {
                const arg_val = args.get(field.name);
                if (arg_val) |val| {
                    @field(input, field.name) = try parseJsonValue(val, field.type, arena);
                } else if (@typeInfo(field.type) == .Optional) {
                    @field(input, field.name) = null;
                } else {
                    return skills.SkillResult{
                        .success = false,
                        .output = "",
                        .error_message = try std.fmt.allocPrint(arena, "Missing required parameter: {s}", .{field.name}),
                        .execution_time_ms = 0,
                    };
                }
            }

            // Call handler
            const output = config.handler(input);

            // Build SkillResult
            const output_str = try formatOutput(output, arena);

            return skills.SkillResult{
                .success = output.success,
                .output = output_str,
                .execution_time_ms = 0,
            };
        }

        /// Generate a runtime Skill struct
        pub fn toSkill() skills.Skill {
            return skills.Skill{
                .id = id,
                .name = name,
                .description = description,
                .version = version,
                .category = category,
                .params = getParams(),
                .execute_fn = execute_fn,
            };
        }
    };
}

/// Map Zig types to SkillParam.ParamType at comptime
fn mapTypeToParamType(comptime T: type) skills.SkillParam.ParamType {
    return switch (T) {
        []const u8 => .string,
        ?[]const u8 => .string,
        bool => .boolean,
        i32, i64, u32, u64 => .integer,
        else => .string,
    };
}

/// Parse a std.json.Value into a Zig type
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
        else => @compileError("unsupported parameter type for defineSkill"),
    };
}

/// Format output struct into a string for SkillResult.output
fn formatOutput(output: anytype, arena: std.mem.Allocator) ![]const u8 {
    // If output has an `output` string field, use it directly
    if (@hasField(@TypeOf(output), "output")) {
        if (@TypeOf(output.output) == []const u8) {
            return try arena.dupe(u8, output.output);
        }
    }

    // Otherwise, JSON stringify the output struct
    return try std.json.stringifyAlloc(arena, output, .{});
}

// ============================================================================
// Tests
// ============================================================================

fn debugHandler(input: struct {
    code: []const u8,
    language: ?[]const u8 = null,
}) struct {
    success: bool,
    output: []const u8,
} {
    _ = input;
    return .{ .success = true, .output = "debug completed" };
}

test "defineSkill basic validation" {
    const DebugSkill = defineSkill(.{
        .name = "debug",
        .description = "Debug skill",
        .input = struct {
            code: []const u8,
            language: ?[]const u8 = null,
        },
        .output = struct {
            success: bool,
            output: []const u8,
        },
        .handler = debugHandler,
    });

    try std.testing.expectEqualStrings("debug", DebugSkill.id);
    try std.testing.expectEqualStrings("debug", DebugSkill.name);
    try std.testing.expect(DebugSkill.getParams().len == 2);
}

test "defineSkill execution" {
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

    const skill = EchoSkill.toSkill();
    try std.testing.expectEqualStrings("echo", skill.id);
    try std.testing.expectEqualStrings("echo", skill.name);

    var args = std.json.ObjectMap.init(allocator);
    defer args.deinit();
    try args.put("message", std.json.Value{ .string = "hello dsl" });

    const ctx = skills.SkillContext{
        .allocator = allocator,
        .working_dir = ".",
        .session_id = "test",
    };

    const result = try skill.execute_fn(ctx, args, allocator);
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("hello dsl", result.output);
}

test "defineSkill compile error on mismatch" {
    // This test validates that defineSkill produces a clear compile error
    // when handler signature doesn't match input. We can't test compile errors
    // at runtime, but we document the expected behavior here.
    //
    // Example of code that WOULD fail to compile:
    //
    // fn badHandler(input: struct { code: []const u8 }) struct { success: bool } { ... }
    //
    // const BadSkill = defineSkill(.{
    //     .name = "bad",
    //     .input = struct { code: []const u8, extra: []const u8 },
    //     .output = struct { success: bool },
    //     .handler = badHandler,
    // });
    //
    // Expected error: "defineSkill: `handler` parameter type must match `input`"

    // For now, verify that a correct definition compiles without issue.
    const GoodSkill = defineSkill(.{
        .name = "good",
        .description = "Good skill",
        .input = struct { code: []const u8 },
        .output = struct { success: bool, output: []const u8 },
        .handler = struct {
            fn exec(input: struct { code: []const u8 }) struct { success: bool, output: []const u8 } {
                return .{ .success = true, .output = input.code };
            }
        }.exec,
    });
    try std.testing.expectEqualStrings("good", GoodSkill.name);
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
