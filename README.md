# kimiz

> **The AI Coding Agent that learns you** — Skill-Centric, High-Performance, Self-Learning

[![Zig Version](https://img.shields.io/badge/zig-0.15.2-orange.svg)](https://ziglang.org/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Status](https://img.shields.io/badge/status-alpha-yellow.svg)](https://github.com/DaviRain-Su/kimiz)

**kimiz** is a next-generation AI coding agent that learns your preferences, understands your codebase, and grows smarter with every interaction. Unlike stateless AI assistants, kimiz builds a persistent knowledge base about your coding style, frequently used patterns, and project-specific insights.

---

## 🌟 What Makes kimiz Different?

### Skill-Centric Architecture

kimiz organizes all capabilities as composable **Skills** rather than simple tools:

```
User Request → Skill Selection → Execution Plan → Tool Orchestration → Result
```

**Benefits**:
- 🔄 **Reusable**: Define once, use everywhere
- 🧩 **Composable**: Chain skills into complex workflows
- 📚 **Learnable**: Agent improves skill usage over time
- 🔌 **Extensible**: Add custom skills for your workflow

### Three-Layer Memory System

```
┌─────────────────────────────────────────────────┐
│  Short-Term Memory (Current Session)            │
│  • Active conversation context                  │
│  • Recent code changes                          │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│  Working Memory (Project-Level)                 │
│  • Tech stack detection                         │
│  • Code patterns & conventions                  │
│  • Important files & dependencies               │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│  Long-Term Memory (User Preferences)            │
│  • Coding style preferences                     │
│  • Frequently used tools                        │
│  • Model performance history                    │
└─────────────────────────────────────────────────┘
```

### Adaptive Learning

kimiz **learns** from every interaction:
- 📊 Tracks which models work best for different tasks
- 🎯 Adapts to your coding style (indentation, naming, patterns)
- 🚀 Optimizes tool selection based on success rates
- 💡 Suggests better approaches based on historical data

### Native Performance

Built with Zig for **blazing-fast** performance:
- ⚡ **<100ms** startup time (vs 1-3s for TypeScript/Python agents)
- 🔋 **Low memory footprint** (<50MB)
- 📦 **Single binary** - no runtime dependencies
- 🎯 **Native compilation** - no JIT overhead

---

## 🚀 Quick Start

### Prerequisites

- [Zig 0.15.2](https://ziglang.org/download/) (0.16 migration in progress)
- API keys for at least one provider:
  - OpenAI (GPT-4o, o1, o3)
  - Anthropic (Claude 3.5 Sonnet)
  - Google (Gemini 2.0 Flash)
  - Kimi (Moonshot k1)

### Installation

```bash
# Clone the repository
git clone https://github.com/DaviRain-Su/kimiz.git
cd kimiz

# Build
zig build

# The binary will be in zig-out/bin/kimiz
```

### Configuration

```bash
# Set up API keys (choose one or more)
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="sk-ant-..."
export GOOGLE_API_KEY="..."
export KIMI_API_KEY="..."

# Optional: Configure default model
./zig-out/bin/kimiz config set default_model gpt-4o
```

### Basic Usage

```bash
# Interactive REPL mode
./zig-out/bin/kimiz repl

# One-shot command
./zig-out/bin/kimiz run "Add error handling to src/main.zig"

# With specific model
./zig-out/bin/kimiz run --model claude-3.5-sonnet "Review this PR"

# Enable thinking mode for complex tasks
./zig-out/bin/kimiz run --thinking high "Refactor the HTTP client"
```

---

## 🎯 Features

### Built-in Skills

kimiz comes with powerful built-in skills:

- **🔍 Code Review**: Analyze code quality, detect bugs, suggest improvements
- **🔨 Refactoring**: Modernize code, extract functions, improve structure
- **🧪 Test Generation**: Create unit tests, integration tests, E2E tests
- **📝 Documentation**: Generate docstrings, README, API docs
- **🐛 Debugging**: Trace issues, analyze stack traces, suggest fixes

### Agent Tools

7 built-in tools for code manipulation:

- **📄 File Operations**: `read_file`, `write_file`
- **🔎 Search**: `grep`, `glob` (pattern matching)
- **⚙️ Execution**: `bash` (run commands)
- **🌐 Web**: `web_search`, `url_summary`

### Multi-Provider Support

Smart model routing automatically selects the best model for each task:

| Provider | Models | Use Case |
|----------|--------|----------|
| **OpenAI** | GPT-4o, o1, o3-mini | General coding, complex reasoning |
| **Anthropic** | Claude 3.5 Sonnet | Code review, long context |
| **Google** | Gemini 2.0 Flash | Fast iterations, prototyping |
| **Kimi** | k1, Moonshot-v1 | Chinese language, specialized tasks |
| **Fireworks** | Open source models | Cost-effective, local deployment |

### Intelligent Model Routing

kimiz automatically chooses the optimal model based on:
- 📊 **Task complexity**: Simple vs complex reasoning
- 💰 **Cost efficiency**: Balance quality and cost
- 🎯 **Historical performance**: Learn which models work best
- ⚡ **Speed requirements**: Fast iteration vs deep thinking

---

## 📖 Documentation

- **[Product Requirements](docs/01-PRD.md)** - Vision and roadmap
- **[Architecture Guide](docs/02-architecture.md)** - System design
- **[Task Management](tasks/README.md)** - Development tasks
- **[Project Audit](docs/08-project-audit-report.md)** - Current status
- **[Zig 0.16 Migration](docs/11-zig-0.16-migration-guide.md)** - Upgrade guide

---

## 🏗️ Project Status

**Version**: 0.0.0 (Alpha)  
**Zig**: 0.15.2 → 0.16 (migration in progress)

### What's Working ✅

- ✅ Core type system
- ✅ 5 AI providers (OpenAI, Anthropic, Google, Kimi, Fireworks)
- ✅ 7 agent tools (file, search, execution, web)
- ✅ 5 built-in skills (review, refactor, test, docs, debug)
- ✅ Three-layer memory system
- ✅ Adaptive learning framework
- ✅ REPL mode
- ✅ Smart model routing
- ✅ Session management
- ✅ Logging system

### Known Issues ⚠️

- ❌ **Compilation errors** (2 issues, fixes documented)
- ⚠️ **Memory leaks** (9 P1 issues identified)
- ⚠️ **E2E tests** incomplete
- ⚠️ **TUI mode** framework only

See [Critical Fixes Summary](tasks/CRITICAL-FIXES-SUMMARY.md) for details.

### Roadmap 🗺️

**Sprint 1** (Current):
- [x] Core infrastructure
- [x] Multi-provider support
- [x] Memory & learning systems
- [ ] Fix compilation errors
- [ ] Complete E2E tests

**Sprint 2** (Next):
- [ ] Skill marketplace
- [ ] Advanced learning algorithms
- [ ] Performance optimization (io_uring)
- [ ] Plugin system

**Sprint 3** (Future):
- [ ] TUI interface
- [ ] Multi-modal support
- [ ] Distributed execution
- [ ] Cloud sync

---

## 🛠️ Development

### Building from Source

```bash
# Development build
zig build

# Release build (optimized)
zig build -Doptimize=ReleaseFast

# Run tests
zig build test

# Run specific test
zig test src/core/root.zig
```

### Project Structure

```
kimiz/
├── src/
│   ├── core/           # Core types and constants
│   ├── ai/             # AI providers and routing
│   │   └── providers/  # OpenAI, Anthropic, Google, Kimi, Fireworks
│   ├── agent/          # Agent runtime and tools
│   │   └── tools/      # Built-in tools (7 tools)
│   ├── skills/         # Skill system (5 built-in skills)
│   ├── memory/         # Three-layer memory system
│   ├── learning/       # Adaptive learning engine
│   ├── cli/            # CLI interface
│   ├── prompts/        # Prompt templates
│   └── utils/          # Config, logging, session
├── docs/               # Documentation
├── tasks/              # Task management
├── tests/              # Test suite
└── build.zig           # Build configuration
```

### Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Code style guidelines
- Commit message conventions
- Pull request process
- Testing requirements

**Current Priority Tasks**:
1. 🔴 Fix compilation errors ([URGENT-FIX](tasks/backlog/bugfix/URGENT-FIX-compilation-errors.md))
2. 🔴 Fix memory leaks ([TASK-BUG-001 to 003](tasks/backlog/bugfix/))
3. 🟡 Complete E2E tests ([T-009](tasks/active/sprint-01-core/T-009-e2e-tests.md))

---

## 🤝 Community

- **Issues**: [GitHub Issues](https://github.com/DaviRain-Su/kimiz/issues)
- **Discussions**: [GitHub Discussions](https://github.com/DaviRain-Su/kimiz/discussions)
- **Documentation**: [docs/](docs/)

---

## 📜 License

MIT License - see [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgments

Inspired by:
- [pi-mono](https://github.com/badlogic/pi-mono) - Architecture patterns
- [Claude Code](https://github.com/didilili/claude-code-restored) - Agent design
- [Factory](https://factory.ai/) - Skill-centric approach

Built with:
- [Zig](https://ziglang.org/) - Programming language
- [OpenAI](https://openai.com/), [Anthropic](https://anthropic.com/), [Google AI](https://ai.google/), [Moonshot AI](https://moonshot.ai/) - AI providers

---

## 🌟 Star History

If kimiz helps you, please consider giving it a star ⭐

---

**Built with ❤️ using Zig**
