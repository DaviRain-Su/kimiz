const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get zwasm dependency
    const zwasm_dep = b.dependency("zwasm", .{
        .target = target,
        .optimize = optimize,
        .tests = false,
    });

    const mod = b.addModule("kimiz", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "zwasm", .module = zwasm_dep.module("zwasm") },
        },
    });

    const exe = b.addExecutable(.{
        .name = "kimiz",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kimiz", .module = mod },
            },
        }),
    });

    exe.root_module.addIncludePath(b.path("ffi"));
    exe.root_module.addLibraryPath(b.path("ffi"));
    exe.root_module.linkSystemLibrary("fff_c", .{});

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // Integration tests
    const integration_tests_module = b.createModule(.{
        .root_source_file = b.path("tests/integration_tests.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "kimiz", .module = mod },
        },
    });

    const integration_tests = b.addTest(.{
        .root_module = integration_tests_module,
    });
    const run_integration_tests = b.addRunArtifact(integration_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
    test_step.dependOn(&run_integration_tests.step);
}
