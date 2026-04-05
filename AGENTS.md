# AGENTS.md — KimiZ Coding Agent Guide

> **If you are an AI coding agent (Claude Code, Codex, OpenCode, etc.), read this file first before doing anything else.**

---

## 1. Project Identity

- **Name**: KimiZ
- **Language**: Zig
- **Type**: AI Coding Agent CLI / Harness Engineering Platform
- **Repository**: `/Users/davirian/dev/active/kimiz`

---

## 2. Environment Constraints (Hard Rules)

### Zig Version
- **Target**: `Zig 0.16.0-dev`
- **All code must use Zig 0.16 APIs** (`std.process.Init`, `std.Io`, etc.)
- **Do NOT** use APIs removed in 0.16 (e.g., old `std.process.argsAlloc` signatures, pre-0.16 `std.http.Client` patterns)
- The `Makefile` uses `$(HOME)/zig-0.16.0-dev/zig` as the compiler

### Build Commands
```bash
make build              # Build the project
make test               # Run all tests
make run                # Run REPL mode
zig build               # Alternative (ensure your zig is 0.16)
zig build test          # Alternative test
```

### Pre-Commit Checklist
Every code change must pass:
- [ ] `zig build` compiles with **zero errors** on Zig 0.16
- [ ] `zig build test` passes
- [ ] No compiler warnings from deprecated APIs

---

## 3. Task System (The Only Source of Truth)

### Active Work
All current tasks live in:
```
tasks/active/sprint-2026-04/
```

Read `tasks/active/sprint-2026-04/README.md` to see what is currently in-progress.

### Execution Order
Tasks are strictly ordered. **Do not skip ahead.**

Current queue:
1. **T-092-VERIFY** — Verify delegate subagent tool registration
2. **T-119-VERIFY** — Verify git worktree isolation for subagents
3. **T-009-E2E** — Add end-to-end tests

### How to Pick Up a Task

Every task follows the **Document-Driven Workflow** defined in `docs/DOCUMENT-DRIVEN-WORKFLOW.md`. Read it before picking up any task.

1. Check the task's lifecycle state (`research` → `spec` → `implement` → `verify`)
2. Read the task file in `tasks/active/sprint-2026-04/` (pay special attention to `Research` and `Log`)
3. Read the corresponding spec in `docs/specs/`
4. Read `docs/DESIGN-REFERENCES.md` for relevant design docs
5. Implement
6. **Append a log entry to the task file's `Log` section after every meaningful step**
7. Run `make test`
8. Fill out `Lessons Learned` before marking the task `done`
9. Check if `docs/DESIGN-REFERENCES.md` or `docs/lessons-learned.md` needs updating
10. Update task status to `done` in both the task file and `AGENT-ENTRYPOINT.md`
11. Commit with format: `feat: description (TASK-ID)`

---

## 4. Documentation Map

| File | Purpose | When to Read |
|------|---------|--------------|
| `AGENTS.md` | This file | **First** |
| `AGENT-ENTRYPOINT.md` | Human-maintained execution status | Every session |
| `tasks/active/sprint-2026-04/README.md` | Current sprint board | Every session |
| `docs/DESIGN-REFERENCES.md` | Links analysis docs to implementation phases | Before writing code |
| `docs/ROADMAP-v2.md` | 0-10 phase roadmap | When you need context |
| `docs/FEATURES.md` | What is already built vs planned | When you need context |
| `docs/specs/*.md` | Executable technical specs | Per-task |

### Do NOT Read (Outdated / Misleading)
- `docs/reports/08-project-audit-report.md`
- `docs/reports/09-task-status-audit.md`
- `docs/reports/10-handoff-to-coding-agent.md`
- `docs/reports/review-report.md`
- `tasks/archive/` (historical garbage)
- `tasks/completed/` (read only if you need historical context)

---

## 5. Design Principles (Enforced)

### Code Quality
Read these **before** writing Zig code:
- [TigerBeetle Patterns](docs/research/TIGERBEETLE-PATTERNS-ANALYSIS.md) — State machines, explicit error handling, no hidden allocations
- [NullClaw Lessons](docs/guides/NULLCLAW-LESSONS-QUICKREF.md) — Tool sandboxing, graceful degradation, resource boundaries

### Zig API Version Rule
- **New code = Zig 0.16 only**
- If an API has both 0.15 and 0.16 forms, use the 0.16 form
- If an API is gone in 0.16, use its 0.16 replacement (check `docs/guides/ZIG-0.16-BREAKING-CHANGES-SUMMARY.md`)

### Memory Management
- No hidden allocations
- Every struct that holds an `allocator` must have a `deinit()`
- Use `std.testing.allocator` in tests to catch leaks

### Error Handling
- Map low-level errors to semantic `AiError` variants
- Never `catch unreachable` in production paths
- Provide human-readable error messages at CLI boundaries

---

## 6. Project Structure

```
src/
  main.zig              # Entry point (uses std.process.Init for 0.16)
  cli/root.zig          # CLI framework, REPL, argument parsing
  agent/
    agent.zig           # Main Agent loop
    subagent.zig        # Sub-agent delegation
    tool.zig            # Tool abstraction
    registry.zig        # Tool registry
    tools/*.zig         # Built-in tools (read_file, bash, grep, etc.)
  ai/
    providers/*.zig     # OpenAI, Anthropic, Google, Kimi, Fireworks
    models.zig          # Model registry
    routing.zig         # Smart routing stub
  skills/*.zig          # Built-in skills (code_review, refactor, etc.)
  utils/
    io_manager.zig      # std.Io management for 0.16
    worktree.zig        # Git worktree isolation
    fs_helper.zig       # File system helpers
    session.zig         # Session persistence
docs/
  specs/                # Current technical specs
  research/             # Analysis of external projects
  design/               # Architecture and design docs
tasks/
  active/sprint-2026-04/# Current sprint tasks
  backlog/phase-*/      # Future tasks by phase
  completed/            # Finished tasks
  archive/              # Do not touch
```

---

## 7. What NOT to Do

1. **Do not read `tasks/archive/` or `docs/08-*.md` / `docs/09-*.md` / `docs/10-*.md`**
2. **Do not implement backlog tasks** from `tasks/backlog/` unless explicitly asked
3. **Do not refactor unrelated code** while working on a task
4. **Do not write code without a spec** — if the spec is missing, write it first
5. **Do not commit broken code** — `zig build test` must pass
6. **Do not use Zig 0.15 APIs** in new code

---

## 8. Commit Message Format

```
<type>: <short description> (<TASK-ID>)

- Detailed change 1
- Detailed change 2
- Verification: make test passes
```

Types: `feat`, `fix`, `docs`, `test`, `refactor`, `revert`

---

## 9. Emergency Contacts

- **P0 Blocker**: Fix immediately, update task status, notify in commit message
- **Spec Ambiguity**: Update the spec file in `docs/specs/`, do not guess
- **API Confusion**: Check `docs/guides/ZIG-0.16-BREAKING-CHANGES-SUMMARY.md`

---

## 10. Quick Start Checklist

When you enter this project:

- [ ] Read `AGENTS.md` (this file)
- [ ] Read `AGENT-ENTRYPOINT.md`
- [ ] Read `tasks/active/sprint-2026-04/README.md`
- [ ] Pick the first `todo` task
- [ ] Read its spec in `docs/specs/`
- [ ] Read relevant references in `docs/DESIGN-REFERENCES.md`
- [ ] Implement
- [ ] Run `make test`
- [ ] Commit and update status
