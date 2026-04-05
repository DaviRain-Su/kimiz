# KimiZ Skills

This directory documents the KimiZ skill system, including built-in (hand-written) skills, the comptime `defineSkill` DSL, and the auto-generation pipeline.

## Directory Layout

```
src/skills/
  root.zig            # Core skill types, registry, and engine
  builtin.zig         # Registration for all built-in skills
  dsl.zig             # `defineSkill` comptime macro
  generator.zig       # LLM-based auto skill generation (T-100)
  auto/
    TEMPLATE.md       # Prompt template for LLM skill generation
    registry.zig      # Auto-generated import table for auto skills
    auto_*.zig        # Auto-generated skill files
  *_dsl.zig           # Built-in skills migrated to the DSL
```

## `defineSkill` DSL

`defineSkill` is a compile-time macro that validates skill contracts and generates the boilerplate needed for registration, parameter schema, JSON parsing, and execution.

### Supported Handler Signatures

- `fn(Input) Output`
- `fn(SkillContext, Input) Output`
- `fn(Input, std.mem.Allocator) Output`
- `fn(SkillContext, Input, std.mem.Allocator) Output`

If the handler produces dynamic string output (e.g., via `std.Io.Writer`), use the `Allocator` variant and copy the result onto the arena before returning.

### Example

```zig
const std = @import("std");
const skills = @import("../root.zig");

fn MyHandler(input: struct { msg: []const u8 }, arena: std.mem.Allocator) struct {
    success: bool,
    output: []const u8,
} {
    var buf: [256]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    w.print("Echo: {s}", .{input.msg}) catch {};
    const output = arena.dupe(u8, w.buffered()) catch return .{ .success = false, .output = "" };
    return .{ .success = true, .output = output };
}

pub const MySkill = skills.defineSkill(.{
    .name = "my-skill",
    .description = "Echoes a message",
    .input = struct { msg: []const u8 },
    .output = struct { success: bool, output: []const u8 },
    .handler = MyHandler,
});
```

## Auto Skill Generation (T-100)

The generator uses `src/skills/auto/TEMPLATE.md` as a prompt template and calls the configured LLM to produce a `auto_<name>.zig` file.

### CLI Usage

```bash
# Generate a new skill from a natural-language description
zig build run -- generate-skill <kebab-case-name> "<description>"
```

Example:

```bash
zig build run -- generate-skill line-counter "Count lines in a file and return the total"
```

### How it Works

1. `generator.zig` reads `TEMPLATE.md` and replaces placeholders (`{{NAME}}`, `{{DESCRIPTION}}`, etc.).
2. The prompt is sent to the configured LLM (e.g., Kimi/OpenAI/Anthropic).
3. The returned Zig code is extracted and written to `src/skills/auto/auto_<name>.zig`.
4. `registry.zig` is regenerated to include the new `@import("auto_<name>.zig")`.
5. `zig build test` is executed automatically.
6. If compilation fails, the error output is appended to the prompt and the LLM retries (up to 5 times).

### Adding a Hand-Crafted Auto Skill

You can also write an auto skill manually and have it picked up by the build system:

1. Create `src/skills/auto/auto_<name>.zig` following the DSL pattern.
2. Run the registry updater logic (or manually add the `registry.register(@import("auto_<name>.zig").getSkill());` line in `registry.zig`).
3. Run `zig build test` to verify.

## Compiler Error Feedback

Generated code is validated by the Zig compiler at comptime. Common pitfalls surfaced during T-103/T-100 include:

- Zig 0.16 uses quoted type tags: `.@"struct"`, `.@"fn"`, `.@"enum"`, `.optional`
- `std.io.fixedBufferStream` does not exist in 0.16; use `std.Io.Writer = .fixed(&buf)`
- Anonymous struct types are not identical; let `defineSkill` validate structural equivalence
- Returning a slice to a local stack buffer without copying to the arena causes UB

## Roadmap

- **T-100** (done): Auto skill generation pipeline, `auto/` directory, CLI `generate-skill`
- **T-101** (pending): AutoRegistry dynamic loading for runtime-discovered skills
