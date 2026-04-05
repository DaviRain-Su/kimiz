# kimiz

> A fast, terminal-based AI coding assistant written in Zig.

[![Zig Version](https://img.shields.io/badge/zig-0.16-orange.svg)](https://ziglang.org/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**kimiz** is a command-line AI agent for coding tasks. It runs as an interactive REPL, can read and edit files, execute shell commands, and search your codebase — all in a single lightweight binary.

---

## Quick Start

**Time: ~5 minutes**

### 1. Install Zig 0.16

See [ziglang.org/download](https://ziglang.org/download/).

### 2. Get API Key

kimiz uses **Kimi** (`kimi-for-coding`) by default. Get a key from [platform.moonshot.cn](https://platform.moonshot.cn):

```bash
export KIMI_API_KEY="your-key-here"
```

(_Optional_) Other providers work too:
- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `GOOGLE_API_KEY`

### 3. Build

```bash
git clone https://github.com/DaviRain-Su/kimiz.git
cd kimiz
zig build
```

### 4. Run

```bash
./zig-out/bin/kimiz
```

You will enter the REPL. Example:

```
> read src/main.zig
> explain what this file does
> add a function that prints hello world
> exit
```

---

## What Can It Do?

### Core Tools

| Tool | Description | Example |
|------|-------------|---------|
| `read_file` | Read any file in your project | `read src/http.zig` |
| `write_file` | Create new files | `write a test.zig` |
| `edit` | Replace code blocks in existing files | `change error handler to string-based` |
| `grep` | Search file contents (powered by **fff** — fast fuzzy finder) | `find all TODOs` |
| `file_search` | Fuzzy-find files by name | `open file search agent.zig` |
| `bash` | Run shell commands with timeout protection | `run zig build test` |

### Modes

- **REPL** (`./zig-out/bin/kimiz`) — continuous, multi-turn conversation
- **Direct prompt** — pass a one-shot request (if your wrapper supports it)

---

## Troubleshooting

### "API Key not configured"

Make sure `KIMI_API_KEY` is exported in your shell:

```bash
export KIMI_API_KEY="sk-..."
```

### "Cannot connect to AI service"

Check your network and proxy settings. If behind a VPN or corporate firewall, ensure `https://api.kimi.com` is reachable.

### "Tool not found"

This usually means the model returned an unknown tool name. It is harmless — just tell the agent to re-read the file list or try again.

### Build fails on macOS / Linux

- Requires **Zig 0.16.0-dev** or newer.
- On macOS, the `libfff_c.dylib` is pre-built and linked automatically.
- On Linux, you may need to build the C FFI library first (see `ffi/` directory).

### Tests fail

```bash
zig build test
```

If a specific test fails, run it in isolation:

```bash
zig test src/ai/providers/openai.zig
```

---

## Project Status

**Current version: v0.4.0 (MVP)**

- ✅ REPL with stable agent loop
- ✅ 6 core tools (read, write, edit, grep, file_search, bash)
- ✅ Default Kimi for Coding (OpenAI/Anthropic compatible)
- ✅ Error handling with user-friendly messages
- ✅ Test coverage for core parsing and tools
- ✅ 26ms startup, 6MB binary

### Not in MVP

- ❌ No Web UI
- ❌ No MCP integration
- ❌ No complex TUI (basic REPL only)
- ❌ No cross-session memory (single-session context only)

---

## Development

```bash
zig build              # build
zig build test         # run all tests
zig build -Doptimize=ReleaseFast  # release build
```

### Project Layout

```
src/
├── cli/        REPL and CLI entry
├── ai/         AI providers (Kimi, OpenAI, Anthropic, Google)
├── agent/      Agent loop and tools
│   └── tools/
│       ├── read_file.zig
│       ├── write_file.zig
│       ├── edit.zig
│       ├── bash.zig
│       └── fff.zig       # grep + file_search
├── memory/     Session-level context
├── skills/     Built-in skills (token optimize, etc.)
└── utils/      Error handling, config, logging
```

---

## Roadmap

| Phase | Status | Focus |
|-------|--------|-------|
| **A** | ✅ Done | Core stability (REPL, tools, Kimi default) |
| **B** | ✅ Done | Quality (errors, tests, performance) |
| **C** | Pending | Selective enhancements based on real usage |

Phase C candidates:
- Better code-diff display
- Git integration
- More providers / models
- Simple TUI improvements

---

## License

MIT — see [LICENSE](LICENSE).
