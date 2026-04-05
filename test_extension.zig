const std = @import("std");
const kimiz = @import("kimiz");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Kimiz Extension System Test ===\n\n");

    // Test 1: WASM Runtime
    std.debug.print("Test 1: WASM Runtime\n");
    {
        var runtime = kimiz.extension.wasm.WasmRuntime.init(allocator);
        defer runtime.deinit();

        // Load a minimal WASM module
        const wasm_bytes = &[_]u8{ 0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00 };
        try runtime.loadModule("test", wasm_bytes);

        const module = runtime.getModule("test");
        std.debug.print("  ✓ Loaded module: {s}\n", .{module.?.getName()});

        runtime.unloadModule("test");
        std.debug.print("  ✓ Unloaded module\n");
    }

    // Test 2: Extension Registry
    std.debug.print("\nTest 2: Extension Registry\n");
    {
        var registry = kimiz.extension.ExtensionRegistry.init(allocator);
        defer registry.deinit();

        const ext = kimiz.extension.Extension{
            .id = "test-ext",
            .name = "Test Extension",
            .version = "1.0.0",
            .description = "A test extension",
            .author = "Test",
            .wasm_path = "/path/to/ext.wasm",
            .provides_tools = &[_]kimiz.extension.ToolDefinition{},
            .provides_skills = &[_]kimiz.extension.SkillDefinition{},
        };

        try registry.register(ext);

        const retrieved = registry.get("test-ext");
        std.debug.print("  ✓ Registered extension: {s}\n", .{retrieved.?.name});

        const all = try registry.listAll();
        defer allocator.free(all);
        std.debug.print("  ✓ Listed {d} extensions\n", .{all.len});
    }

    // Test 3: Extension Manager
    std.debug.print("\nTest 3: Extension Manager\n");
    {
        var manager = try kimiz.extension.ExtensionManager.init(
            allocator,
            "examples/extension",
        );
        defer manager.deinit();

        std.debug.print("  ✓ Created manager for: {s}\n", .{manager.extension_dir});

        // Try to load all extensions (will skip if directory doesn't exist)
        manager.loadAll() catch |err| {
            std.debug.print("  ! Load all failed (expected if dir missing): {s}\n", .{@errorName(err)});
        };
    }

    std.debug.print("\n=== All Tests Passed! ===\n");
}
