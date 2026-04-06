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

    // TASK-INFRA-007: Add yazap CLI parser dependency
    const yazap_dep = b.dependency("yazap", .{
        .target = target,
        .optimize = optimize,
    });

    // TASK-INFRA-001: Add LMDB dependency
    const lmdb_dep = b.dependency("lmdb", .{
        .target = target,
        .optimize = optimize,
    });

    const mod = b.addModule("kimiz", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "zwasm", .module = zwasm_dep.module("zwasm") },
            .{ .name = "yazap", .module = yazap_dep.module("yazap") },
            .{ .name = "lmdb", .module = lmdb_dep.module("lmdb") },
        },
    });
    mod.addIncludePath(b.path("ffi"));
    mod.addLibraryPath(b.path("ffi"));
    mod.linkSystemLibrary("fff_c", .{});

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

    // Engine module tests (T-128)
    const engine_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/engine/task.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_engine_tests = b.addRunArtifact(engine_tests);
    test_step.dependOn(&run_engine_tests.step);

    const project_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/engine/project.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_project_tests = b.addRunArtifact(project_tests);
    test_step.dependOn(&run_project_tests.step);

    // Review agent tests (T-128-05)
    const review_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/engine/review.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_review_tests = b.addRunArtifact(review_tests);
    test_step.dependOn(&run_review_tests.step);

    // Prompt loader tests (T-128-05)
    const prompts_loader_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/prompts/loader.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_prompts_loader_tests = b.addRunArtifact(prompts_loader_tests);
    test_step.dependOn(&run_prompts_loader_tests.step);

    // Orchestrator tests (T-128-07)
    const orchestrator_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/engine/orchestrator.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_orchestrator_tests = b.addRunArtifact(orchestrator_tests);
    test_step.dependOn(&run_orchestrator_tests.step);
    // Fuzz tests (disabled - needs fix for SkillContext API change)
    // test_step.dependOn(&run_fuzz_tests.step);
}
