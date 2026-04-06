const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get zwasm dependency
    const zwasm_dep = b.dependency("zwasm", .{
        .target = target,
        .optimize = optimize,
    });

    // TASK-INFRA-007: Add yazap CLI parser dependency
    // NOTE: yazap 暂时禁用，等待 Zig 0.16 兼容更新
    // const yazap_dep = b.dependency("yazap", .{
    //     .target = target,
    //     .optimize = optimize,
    // });

    // TASK-INFRA-001: Add LMDB dependency
    const lmdb_dep = b.dependency("lmdb", .{
        .target = target,
        .optimize = optimize,
    });

    // TUI support via remote libvaxis fork
    const vaxis_dep = b.dependency("vaxis", .{ .target = target, .optimize = optimize });

    const mod = b.addModule("kimiz", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "zwasm", .module = zwasm_dep.module("zwasm") },
            // .{ .name = "yazap", .module = yazap_dep.module("yazap") },
            .{ .name = "lmdb", .module = lmdb_dep.module("lmdb") },
            .{ .name = "vaxis", .module = vaxis_dep.module("vaxis") },
        },
    });
    mod.addIncludePath(b.path("ffi"));
    mod.addLibraryPath(b.path("ffi"));
    mod.linkSystemLibrary("fff_c", .{});

    // Single module — all src/ files come in via relative imports from main.zig
    const exe = b.addExecutable(.{
        .name = "kimiz",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "kimiz", .module = mod },
                .{ .name = "zwasm", .module = zwasm_dep.module("zwasm") },
            },
        }),
    });

    // FFF-C
    const build_fff = b.option(bool, "build-fff", "Build fff-c (requires cargo)") orelse true;
    if (build_fff) {
        const cargo = b.addSystemCommand(&.{ "cargo", "build", "--release", "-p", "fff-c" });
        cargo.setCwd(b.path("vendor/fff.nvim"));
        cargo.has_side_effects = true;
        exe.step.dependOn(&cargo.step);
        exe.root_module.addIncludePath(b.path("ffi"));
        exe.root_module.addLibraryPath(b.path("vendor/fff.nvim/target/release"));
        const inst = b.addInstallBinFile(b.path("vendor/fff.nvim/target/release/libfff_c.so"), "libfff_c.so");
        inst.step.dependOn(&cargo.step);
        b.getInstallStep().dependOn(&inst.step);
    } else {
        exe.root_module.addIncludePath(b.path("ffi"));
        exe.root_module.addLibraryPath(b.path("ffi"));
    }
    exe.root_module.linkSystemLibrary("fff_c", .{ .preferred_link_mode = .dynamic });
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

    // Fuzz tests (disabled - needs fix for SkillContext API change)
    // test_step.dependOn(&run_fuzz_tests.step);
}
