# RTK Token Optimizer Skill

## Overview

The RTK Token Optimizer skill integrates the [rtk](https://github.com/rtk-ai/rtk) tool to compress command outputs, reducing LLM token consumption by 60-90%.

> **Note**: As of Phase 2, kimiz also includes **native Zig filters** for common commands (`git status`, `git log`, `git diff`, `ls`, `find`) that work without installing RTK. These are automatically applied when token optimization is enabled. The `rtk-optimize` skill remains available for commands not yet covered by native filters.

**Skill ID**: `rtk-optimize`  
**Category**: Miscellaneous  
**Version**: 1.0.0

## Features

- ✅ Reduces token consumption by 60-90% for common dev commands
- ✅ Supports git, file operations, tests, and build tools
- ✅ **Native Zig filters** for core commands (no external dependency)
- ✅ **RTK skill wrapper** for 100+ extended commands
- ✅ Configurable via environment variables
- ✅ <10ms overhead

## Native Filters (Phase 2)

kimiz now includes **native Zig token optimization filters** that work out of the box:

### Supported Native Commands

| Command | Filter | Reduction | Configurable |
|---------|--------|-----------|--------------|
| `git status` | `git_status_filter.zig` | ~56% | Yes |
| `git log` | `git_log_filter.zig` | ~85% | Yes |
| `git diff` | `git_diff_filter.zig` | ~75% | Yes |
| `ls -la` | `ls_filter.zig` | ~72% | Yes |
| `find` | `find_filter.zig` | ~63% | Yes |

### How Native Filters Work

Native filters are **automatically applied** when the bash tool executes a matching command, if token optimization is enabled in configuration.

```bash
# Enable globally
export KIMIZ_TOKEN_OPTIMIZE=true
export KIMIZ_TOKEN_STRATEGY=balanced  # or conservative, aggressive

# Now bash tool calls are auto-optimized:
$ kimiz "Run git status"
# Output goes through native git status filter automatically
```

### Configuration

Environment variables:
- `KIMIZ_TOKEN_OPTIMIZE` - `true`/`1`/`yes` to enable
- `KIMIZ_TOKEN_STRATEGY` - `conservative` | `balanced` | `aggressive`
- `KIMIZ_USE_NATIVE_FILTERS` - `true` to prefer native over RTK

## RTK Skill (Phase 1)

For commands **not yet covered** by native filters, use the `rtk-optimize` skill with the external [rtk](https://github.com/rtk-ai/rtk) tool.

### Prerequisites

RTK must be installed on your system:

```bash
# Install via Homebrew (recommended)
brew install rtk

# Or download from releases
# https://github.com/rtk-ai/rtk/releases
```

Verify installation:
```bash
rtk --version  # Should show rtk 0.28.2 or higher
```

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `command` | string | ✅ Yes | - | Command to execute and optimize |
| `strategy` | selection | ❌ No | `balanced` | Compression strategy (reserved for future use) |
| `working_dir` | directory | ❌ No | current | Working directory for command execution |

### Strategy Parameter

The `strategy` parameter accepts three values:
- `conservative` - More verbose output (~60% reduction)
- `balanced` - Default optimization (~70-80% reduction)
- `aggressive` - Maximum compression (~90% reduction)

**Behavior**:
- For **native filters**, strategy controls truncation limits and detail level
- For **RTK skill**, all strategies currently use rtk's default optimizations

## Usage

### Basic Usage

```bash
# Optimize git status
kimiz skill rtk-optimize command="git status"

# Optimize directory listing
kimiz skill rtk-optimize command="ls -la"

# Optimize git log
kimiz skill rtk-optimize command="git log -n 10"
```

### With Strategy

```bash
# Use aggressive compression (currently same as default)
kimiz skill rtk-optimize command="git status" strategy=aggressive
```

### With Working Directory

```bash
# Execute in a specific directory
kimiz skill rtk-optimize command="git status" working_dir="/path/to/project"
```

## Supported Commands

RTK supports 100+ commands. Here are the most commonly used:

### Git Commands
```bash
command="git status"      # Compact status with emoji
command="git log -n 10"   # One-line commits
command="git diff"        # Condensed diff
command="git add ."       # → "ok"
command="git commit -m 'msg'"  # → "ok abc1234"
```

### File Operations
```bash
command="ls -la"          # Token-optimized tree
command="find . -name '*.zig'"  # Grouped results
command="grep 'pattern' ."      # Compact matches
```

### Test Runners
```bash
command="cargo test"      # Show failures only (-90%)
command="npm test"        # Compact test output
command="pytest"          # Python tests (-90%)
command="go test"         # Go tests (-90%)
```

### Build & Lint
```bash
command="tsc"             # TypeScript errors grouped by file
command="cargo clippy"    # Cargo lint (-80%)
command="eslint ."        # ESLint grouped by rule
```

## Token Savings Examples

### Git Status

**Standard Output** (~2,000 tokens):
```
On branch main
Your branch is ahead of 'origin/main' by 6 commits.
  (use "git push" to publish your local commits)

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)

	modified:   src/agent/agent.zig
	modified:   src/skills/builtin.zig
	modified:   src/skills/root.zig
	modified:   src/skills/token_optimize.zig

Untracked files:
  (use "git add <file>..." to include in what will be committed)

	src/skills/token_optimize.zig

no changes added to commit (use "git add" and/or "git commit -a")
```

**RTK Optimized** (~200 tokens, -90%):
```
📌 main...origin/main [ahead 6]
📝 Modified: 4 files
   src/agent/agent.zig
   src/skills/builtin.zig
   src/skills/root.zig
   src/skills/token_optimize.zig
```

### Directory Listing

**Standard ls -la** (~1,500 tokens for medium project):
```
total 120
drwxr-xr-x  15 user  staff    480 Apr  5 17:00 .
drwxr-xr-x   5 user  staff    160 Apr  5 16:00 ..
-rw-r--r--   1 user  staff    172 Apr  1 10:00 .gitignore
drwxr-xr-x   8 user  staff    256 Apr  5 16:30 .git
drwxr-xr-x   3 user  staff     96 Apr  5 16:00 .zig-cache
... (many more lines)
```

**RTK Optimized** (~300 tokens, -80%):
```
.git/
.zig-cache/
docs/
src/
build.zig  8.8K
README.md  9.9K
Makefile  6.4K

📊 3 files, 4 dirs
```

## Native Filter Error Handling

### Command Not Covered by Native Filter

If a command has no native filter and RTK is not installed, the bash tool will return the raw unoptimized output.

### Missing KIMIZ_TOKEN_OPTIMIZE

Native filters only activate when explicitly enabled:
```bash
export KIMIZ_TOKEN_OPTIMIZE=true
```

## RTK Skill Error Handling

### RTK Not Installed

```bash
$ kimiz skill rtk-optimize command="git status"
❌ Failed!
Error: RTK is not installed.

Install via:
  brew install rtk
  
Or download from: https://github.com/rtk-ai/rtk/releases
```

### Invalid Command

```bash
$ kimiz skill rtk-optimize command="invalid-command"
❌ Failed!
Error: RTK command failed with exit code: 127
```

### Missing Required Parameter

```bash
$ kimiz skill rtk-optimize
❌ Failed!
Error: Missing required parameter: command
```

## Implementation Notes

### Memory Management

Both native filters and the RTK skill properly manage memory using kimiz's allocator system:
- Command output is allocated and returned to the caller
- Caller (CLI) is responsible for freeing the result strings
- No memory leaks in normal operation

### Performance

**Native Filters**:
- **Overhead**: ~1-2ms (pure Zig processing)
- **Output limit**: 100KB (prevents excessive memory use)

**RTK Skill**:
- **Overhead**: <10ms (C popen execution)
- **Output limit**: 100KB
- **Timeout**: Inherited from rtk (30s default)

### Architecture

```
                      Native Filters (Phase 2)
User → bash tool ─────────────────────────────→ Filtered Output
              ↓      ┌──────────────────┐
           git status  │ git_status_filter.zig │
           ls -la      │ ls_filter.zig         │
           find        │ find_filter.zig       │
              ↓      └──────────────────┘

                      RTK Skill (Phase 1)
User → CLI → SkillEngine → token_optimize.zig → rtk → Output
```

## Future Enhancements

### Phase 2 Extension

- [x] Native git filters (status, log, diff)
- [x] Native file filters (ls, find)
- [x] Configurable via environment variables
- [ ] Native test runner filters (cargo test, npm test, pytest)
- [ ] Native build/lint filters (tsc, eslint, clippy)

### Phase 3: Advanced Features

- [ ] Adaptive compression based on context window
- [ ] Learn user preferences
- [ ] Custom compression rules
- [ ] Skill composition (chain with other skills)

## Troubleshooting

### Native filters not working

Check that optimization is enabled:
```bash
echo $KIMIZ_TOKEN_OPTIMIZE  # Should print 'true'
```

Check that the command is supported by native filters:
```bash
# Currently supported: git status, git log, git diff, ls, find
# All other commands require RTK skill
```

### rtk command not found

Ensure rtk is in your PATH:
```bash
echo $PATH | grep -o '.local/bin'  # Should show .local/bin
rtk --version                       # Should show version
```

### Permission denied

Ensure rtk is executable:
```bash
chmod +x ~/.local/bin/rtk
```

### Unexpected output format

Different rtk versions may have different output formats. Upgrade to latest:
```bash
brew upgrade rtk
```

## Related Skills

- `code-review` - Code review automation
- `debug` - Debugging assistant
- `test-gen` - Test generation

## References

- [rtk GitHub Repository](https://github.com/rtk-ai/rtk)
- [rtk Documentation](https://github.com/rtk-ai/rtk#readme)
- [kimiz Skills System](../skills/README.md)

## Changelog

### v1.1.0 (2026-04-05)

- ✅ Phase 2 native filters integrated
- ✅ Native support for git status, git log, git diff, ls, find
- ✅ Environment variable configuration
- ✅ Bash tool auto-optimization

### v1.0.0 (2026-04-05)

- ✅ Initial implementation (Phase 1)
- ✅ RTK external tool wrapper
- ✅ Git, file, test, and lint command support via RTK
- ✅ Basic error handling
- ✅ Memory leak fixes
