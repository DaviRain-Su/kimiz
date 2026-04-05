# MCX Integration Documentation for Kimiz

This directory contains comprehensive documentation for integrating MCX (MCP Code eXecution) as a code execution sandbox for kimiz.

## 📚 Documentation Files

### 1. **MCX-ANSWERS-TO-REQUESTS.md** ⭐ START HERE
**Direct answers to your 6 integration questions**
- What MCP tools does MCX expose? (19 tools)
- How does sandbox execution work? (5-stage pipeline)
- Can it run standalone? (YES, no Neovim required)
- JSON-RPC protocol details
- Python/CLI interface options
- Dependencies (Bun 1.2.0+)

**Best for**: Quick answers, integration planning

### 2. **MCX-QUICK-REFERENCE.md**
**Quick lookup guide for developers**
- MCP tools at a glance
- Sandbox execution flow
- Key features summary
- Integration options (4 approaches)
- Creating custom adapters
- Built-in helpers
- Performance tips
- Troubleshooting

**Best for**: Development, quick lookups, examples

### 3. **MCX-INTEGRATION-ANALYSIS.md**
**Comprehensive technical deep-dive**
- Architecture overview
- All 19 MCP tools with full definitions
- Sandbox execution pipeline (5 stages)
- Adapter system details
- Skill system
- JSON-RPC protocol implementation
- Security architecture (5 layers)
- Variable persistence
- Content indexing & search
- External agent integration

**Best for**: Architecture review, security analysis, implementation details

---

## 🎯 Quick Start

### For Integration Planning
1. Read **MCX-ANSWERS-TO-REQUESTS.md** (5 min)
2. Review **MCX-QUICK-REFERENCE.md** (10 min)
3. Check integration options section

### For Implementation
1. Review **MCX-QUICK-REFERENCE.md** - Integration Options
2. Create custom kimiz adapter (see examples)
3. Use `MCXExecutor` from `@papicandela/mcx-core`

### For Security Review
1. Read **MCX-INTEGRATION-ANALYSIS.md** - Security Architecture
2. Review sandbox execution flow
3. Check network policy configuration

---

## 🔑 Key Findings

| Aspect | Answer |
|--------|--------|
| **MCP Tools** | 19 tools exposed via standard MCP protocol |
| **Sandbox** | Bun Workers with 5 security layers |
| **Standalone** | YES - runs as independent MCP server |
| **Neovim Required** | NO - general MCP server |
| **Python Support** | NO native interface, use MCP client or shell |
| **External Agents** | YES - standard MCP protocol |
| **Dependencies** | Bun 1.2.0+, @modelcontextprotocol/sdk ^1.26.0 |
| **Network** | Blocked by default, configurable |
| **Timeout** | 5 seconds default, configurable |
| **State** | Variables persist across executions |

---

## 🚀 Recommended Integration Approach

```typescript
// kimiz/src/integrations/mcx.ts
import { MCXExecutor } from '@papicandela/mcx-core';
import { defineAdapter } from '@papicandela/mcx-core';

// Create kimiz adapter
const kimizAdapter = defineAdapter({
  name: 'kimiz',
  description: 'Kimiz-specific operations',
  domain: 'task-execution',
  tools: {
    'execute-task': {
      description: 'Execute a kimiz task',
      execute: async (params) => {
        return await kimizAPI.executeTask(params.taskId, params.params);
      }
    }
  }
});

// Create executor
const executor = new MCXExecutor({
  config: {
    sandbox: { timeout: 10000 },
    adapters: [kimizAdapter]
  }
});

// Use in kimiz
const result = await executor.execute(`
  const tasks = await kimiz.executeTasks({ filter: 'active' });
  return { count: tasks.length, tasks };
`);
```

---

## 📋 MCP Tools Overview

### Execution (3 tools)
- `mcx_execute` - Run JS/TS code in sandbox
- `mcx_run_skill` - Execute registered skills
- `mcx_batch` - Batch executions/searches

### File Operations (4 tools)
- `mcx_file` - Process local files
- `mcx_edit` - Edit files
- `mcx_write` - Create/overwrite files
- `mcx_fetch` - Fetch URLs

### Search & Discovery (4 tools)
- `mcx_search` - 3 modes: spec, FTS5, adapter search
- `mcx_find` - Fast fuzzy file search
- `mcx_grep` - SIMD-accelerated content search
- `mcx_related` - Find related files

### Background & Utilities (8 tools)
- `mcx_spawn` - Run code in background
- `mcx_tasks` - Check background tasks
- `mcx_list` - List adapters and skills
- `mcx_tree` - Navigate large JSON results
- `mcx_stats` - Session statistics
- `mcx_doctor` - Run diagnostics
- `mcx_upgrade` - Get upgrade command

---

## 🔒 Security Features

MCX provides **5 layers of security**:

1. **Worker Isolation** - Code runs in separate JavaScript context
2. **Network Isolation** - fetch/WebSocket blocked by default
3. **Pre-execution Analysis** - Detects infinite loops, dangerous patterns
4. **Code Normalization** - AST-based validation
5. **Timeout Enforcement** - Default 5 seconds, configurable

---

## 📖 Source Code References

All documentation includes GitHub permalinks to source code:

- **MCP Server**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/cli/src/commands/serve.ts
- **Sandbox**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/core/src/sandbox/bun-worker.ts
- **Executor**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/core/src/executor.ts
- **Types**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/core/src/types.ts

---

## 🔗 External Resources

- **MCX Repository**: https://github.com/schizoidcock/mcx
- **MCP Specification**: https://modelcontextprotocol.io/
- **Bun Documentation**: https://bun.sh/docs
- **Anthropic Code Execution Article**: https://www.anthropic.com/engineering/code-execution-with-mcp

---

## ✅ Next Steps for Kimiz Integration

1. **Review** MCX-ANSWERS-TO-REQUESTS.md (5 min)
2. **Decide** on integration approach (Direct Programmatic recommended)
3. **Create** custom kimiz adapter
4. **Implement** MCXExecutor integration
5. **Test** sandbox execution with kimiz operations
6. **Deploy** as code execution service

---

## 📝 Document Metadata

| Document | Lines | Size | Focus |
|----------|-------|------|-------|
| MCX-ANSWERS-TO-REQUESTS.md | 400+ | 12KB | Direct answers, quick reference |
| MCX-QUICK-REFERENCE.md | 264 | 7KB | Developer guide, examples |
| MCX-INTEGRATION-ANALYSIS.md | 895 | 22KB | Technical deep-dive, architecture |

**Total Documentation**: ~1,500 lines, 41KB

---

## 🎓 Learning Path

### Beginner (15 minutes)
1. Read MCX-ANSWERS-TO-REQUESTS.md
2. Skim MCX-QUICK-REFERENCE.md

### Intermediate (30 minutes)
1. Read MCX-QUICK-REFERENCE.md completely
2. Review integration options
3. Study custom adapter examples

### Advanced (1 hour)
1. Read MCX-INTEGRATION-ANALYSIS.md
2. Review source code permalinks
3. Study security architecture
4. Plan custom adapter implementation

---

## 💡 Key Insights

1. **MCX is a code execution platform**, not just a tool library
2. **Agents write code** that filters data in the sandbox (98% context reduction)
3. **Adapters are pluggable** - create domain-specific ones for kimiz
4. **Security is built-in** - 5 layers of protection
5. **Variables persist** - state across executions
6. **Content is indexed** - FTS5 search on large outputs
7. **Standalone operation** - no Neovim or external dependencies required

---

## 📞 Questions?

Refer to the appropriate document:
- **"How do I integrate MCX?"** → MCX-ANSWERS-TO-REQUESTS.md
- **"What's the API?"** → MCX-QUICK-REFERENCE.md
- **"How does it work internally?"** → MCX-INTEGRATION-ANALYSIS.md

---

**Last Updated**: April 5, 2026  
**MCX Version**: 0.3.24 (CLI), 0.2.9 (Core)  
**Repository**: https://github.com/schizoidcock/mcx  
**Commit SHA**: 24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4

