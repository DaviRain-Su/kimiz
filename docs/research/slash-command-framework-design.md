# Slash Command Framework Design (T-089)

**Status**: Design Phase  
**Date**: 2026-04-05  
**Objective**: Add product-grade slash command support to kimiz CLI REPL, comparable to Claude Code and Codex CLI.

---

## 1. Requirements

### 1.1 Functional Requirements

- Detect and parse `/command [args...]` syntax from REPL input
- Route to registered handlers
- Support built-in system commands and extensible user-defined commands
- Provide `/help` with auto-generated documentation
- Maintain backward compatibility with plain-text prompts

### 1.2 Non-Functional Requirements

- **Latency**: <1ms overhead on REPL input processing
- **Extensibility**: New commands should be addable in <10 lines
- **Consistency**: Same command registry for both REPL and future TUI modes
- **Error Handling**: Invalid slash commands produce helpful error messages, not crashes

---

## 2. User Experience

### 2.1 Reference Implementations

**Claude Code**:
```
/help        Show help
/clear       Clear conversation
/cost        Show token usage
/compact     Compact conversation history
/exit        Exit
```

**Codex CLI**:
```
/model       Switch model
/mode        Switch mode (auto/ask/manual)
/approve     Approve all pending
/reject      Reject all pending
```

### 2.2 Proposed kimiz Slash Commands (MVP)

| Command | Description | Example |
|---------|-------------|---------|
| `/help` | Show available commands | `/help` |
| `/clear` | Clear screen or conversation | `/clear` |
| `/exit` | Exit REPL | `/exit` |
| `/model` | Switch or show current model | `/model k2p5` |
| `/models` | List available models | `/models` |
| `/yolo` | Toggle auto-approve mode | `/yolo on` |
| `/token` | Configure token optimization | `/token strategy aggressive` |
| `/skill` | Execute a skill inline | `/skill rtk-optimize command=git status` |
| `/settings` | Show current settings | `/settings` |
| `/history` | Show recent conversation turns | `/history` |

---

## 3. Architecture

### 3.1 High-Level Design

```
User Input
    |
    v
+-----------------------------------+
| REPL Input Loop (cli/root.zig)    |
|                                   |
|  if starts_with('/'):             |
|      slash.parse()                |
|      slash.dispatch()             |
|  else:                            |
|      agent.prompt()               |
+-----------------------------------+
```

### 3.2 Module Structure

```
src/cli/
├── root.zig          # REPL loop (light changes)
└── slash.zig         # Slash command framework (+ NEW)
```

### 3.3 Core Types

```zig
// src/cli/slash.zig

pub const SlashCommand = struct {
    name: []const u8,
    description: []const u8,
    usage: []const u8,
    handler: SlashHandler,
    hidden: bool = false,
};

pub const SlashContext = struct {
    allocator: std.mem.Allocator,
    agent: *agent.Agent,
    cfg: *config.Config,
    print_fn: *const fn ([]const u8) void,
    print_line_fn: *const fn ([]const u8) void,
    should_exit: bool = false,
};

pub const SlashHandler = *const fn (*SlashContext, args: []const u8) anyerror!void;
```

### 3.4 Registry

Static array of built-in commands (MVP). Future versions can use dynamic registry.

```zig
pub const registry = &[_]SlashCommand{
    .{ .name = "help", ... },
    .{ .name = "clear", ... },
    // ...
};
```

---

## 4. Integration Points

### 4.1 REPL Loop Changes

In `runInteractive()`, replace the current simple conditional:

```zig
// Current
if (std.mem.eql(u8, input, "help")) { ... }
if (std.mem.eql(u8, input, "clear")) { ... }
if (std.mem.eql(u8, input, "exit")) { ... }

// Proposed
if (slash.parse(input)) |cmd_info| {
    if (slash.find(cmd_info.name)) |cmd| {
        var ctx = makeSlashContext(...);
        try cmd.handler(&ctx, cmd_info.args);
        if (ctx.should_exit) break;
        continue;
    } else {
        print("Unknown slash command. Type /help for list.\n");
        continue;
    }
}

// Also keep legacy keywords for backward compat
if (std.mem.eql(u8, input, "help")) { ... }
if (std.mem.eql(u8, input, "clear")) { ... }
if (std.mem.eql(u8, input, "exit")) { ... }
```

### 4.2 Agent Context Access

Slash commands need mutable access to:
- `agent.Agent` - to inspect/change state, trigger skills
- `config.Config` - to toggle settings like yolo_mode
- Print functions - for CLI output

The current `g_agent` global pointer can be extended or replaced with a `SlashContext` struct constructed in the REPL loop.

---

## 5. Command Specifications

### 5.1 `/help`

**Behavior**:
- Lists all non-hidden commands with descriptions
- Optional `/help --all` to show hidden/debug commands

**Output Example**:
```
╔═══════════════════════════════════════════════════╗
║           Available Slash Commands                ║
╚═══════════════════════════════════════════════════╝

  /help        Show available slash commands
  /clear       Clear the screen
  /model       Switch the active AI model
  /models      List all available models
  /yolo        Toggle YOLO mode
  /token       Configure token optimization
  /skill       Execute a skill directly
  /settings    Show current configuration

You can also type regular messages to chat with the agent.
```

### 5.2 `/model <id>`

**Behavior**:
- If `<id>` omitted, show current model
- If `<id>` provided, validate against `ai.models_registry`
- Update `cfg.default_model`
- Print warning that restart may be needed (since Agent owns the model instance)

**Future enhancement**: Hot-swap model without re-init.

### 5.3 `/yolo [on|off]`

**Behavior**:
- Toggle `cfg.yolo_mode`
- Also ideally update `agent.options.yolo_mode` if possible

### 5.4 `/token [on|off|strategy <name>]`

**Behavior**:
- Enable/disable token optimization
- Change strategy (conservative/balanced/aggressive)
- Print current state when no args given

### 5.5 `/skill <id> [k=v...]`

**Behavior**:
- Inline alias for `kimiz skill <id>` CLI command
- Parse simple `key=value` pairs into JSON ObjectMap
- Call `agent.executeSkill()`
- Print result

### 5.6 `/settings`

**Behavior**:
- Pretty-print current configuration table:
  - Model
  - Temperature
  - YOLO mode
  - Token optimization status + strategy
  - API key presence (not the keys themselves)

---

## 6. Error Handling

| Scenario | Behavior |
|----------|----------|
| Unknown `/foo` | `"Unknown slash command '/foo'. Type /help for list."` |
| `/model invalid` | `"❌ Unknown model: invalid. See /models for list."` |
| `/token strategy foo` | `"❌ Invalid strategy. Use: conservative, balanced, or aggressive"` |
| `/skill` (no args) | `"Usage: /skill <skill_id> [param=value...]"` |
| Handler throws error | Print `"❌ Command failed: {error_name}"` |

---

## 7. Testing Plan

### Unit Tests
- `slash.parse("/help")` → `{name="help", args=""}`
- `slash.parse("/model gpt-4o")` → `{name="model", args="gpt-4o"}`
- `slash.parse("hello")` → `null`
- `slash.find("clear")` → returns command
- `slash.find("nonexistent")` → `null`

### Integration Tests
- `/clear` clears screen
- `/model k2p5` changes default model
- `/yolo on` toggles YOLO mode
- `/token strategy aggressive` updates strategy
- `/skill rtk-optimize command=git status` executes skill

---

## 8. Implementation Plan

| Step | Task | Est. Time |
|------|------|-----------|
| 1 | Create `src/cli/slash.zig` with parser, registry, and core types | 30 min |
| 2 | Implement 10 built-in command handlers | 1.5 hr |
| 3 | Integrate into `src/cli/root.zig` REPL loop | 30 min |
| 4 | Add unit tests | 30 min |
| 5 | Integration testing and refinement | 30 min |
| **Total** | | **~3.5 hr** |

---

## 9. Open Questions

1. **Should slash commands work in non-interactive mode?**  
   _Recommendation_: No. Slash commands are REPL/TUI only. CLI one-shots continue using `kimiz skill <id>`.

2. **Should we keep legacy text commands (`help`, `clear`, `exit`)?**  
   _Recommendation_: Yes, for backward compatibility, but `/help` becomes the canonical way.

3. **Should `/history` be included in MVP?**  
   _Recommendation_: Optional. If `agent.Agent` already exposes conversation history, include it; otherwise defer.

4. **Dynamic command registration (plugins/extensions)?**  
   _Recommendation_: Defer to Phase 3. Use static registry for now.

---

## 10. Conclusion

This design provides a lightweight, extensible slash command framework that matches the UX of modern AI CLI tools. It requires minimal changes to the existing REPL loop and leverages existing kimiz primitives (`agent.executeSkill`, `config.Config`, `models_registry`).

**Next Step**: Await review/approval, then proceed to implementation.
