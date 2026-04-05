# kimiz Skills

## Overview

kimiz uses a **Skill-Centric Architecture** where capabilities are organized as composable Skills rather than simple tools.

## Built-in Skills

| Skill ID | Name | Description | Status |
|----------|------|-------------|--------|
| `code-review` | Code Review | Analyze code quality, detect bugs, suggest improvements | ✅ Active |
| `debug` | Debug Assistant | Trace issues, analyze stack traces, suggest fixes | ✅ Active |
| `doc-gen` | Documentation | Generate docstrings, README, API docs | ✅ Active |
| `refactor` | Refactoring | Modernize code, extract functions, improve structure | ✅ Active |
| `test-gen` | Test Generation | Create unit tests, integration tests, E2E tests | ✅ Active |
| `rtk-optimize` | Token Optimizer | Compress command outputs to save 60-90% tokens | ✅ Active |

## Using Skills

### Via CLI

```bash
# Execute a skill directly
kimiz skill <skill_id> [param=value...]

# Examples
kimiz skill rtk-optimize command="git status"
kimiz skill code-review filepath=src/main.zig focus=bugs
kimiz skill debug filepath=src/http.zig error_message="connection refused"
```

### Via Agent

The Agent can automatically select and execute skills based on user intent:

```bash
kimiz "Review src/main.zig for bugs"
# Agent selects: code-review skill

kimiz "Compress git status output"
# Agent selects: rtk-optimize skill
```

## Skill Architecture

```
User Request
    ↓
Agent / CLI
    ↓
SkillEngine
    ↓
Skill.execute_fn(ctx, args, arena)
    ↓
Result (output, tokens_used, execution_time_ms)
```

## Creating Custom Skills

See the [Architecture Guide](../02-architecture.md) for details on extending the skill system.

## Documentation

- [rtk-optimize.md](rtk-optimize.md) - Token optimization (RTK + native filters)
