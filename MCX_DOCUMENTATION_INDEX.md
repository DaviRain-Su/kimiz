# MCX Documentation Index

## Overview

This directory contains a comprehensive evaluation of **MCX** (Modular Code Execution) as a potential code execution sandbox for the kimiz agent.

**Status**: ✅ **RECOMMENDED** for integration

---

## Documents

### 1. **MCX_QUICK_REFERENCE.md** (Start Here!)
**Purpose**: Quick overview and practical examples  
**Length**: ~350 lines  
**Best for**: Getting started, quick lookups, code examples

**Contents**:
- What is MCX?
- Key capabilities with code examples
- MCP tools overview
- Security layers
- Integration options
- Built-in helpers
- Performance metrics
- Configuration examples
- CLI commands
- Next steps

**Read this first** if you want a quick understanding of MCX and how to use it.

---

### 2. **MCX_EVALUATION_SUMMARY.md** (Decision Document)
**Purpose**: Executive summary and integration recommendations  
**Length**: ~375 lines  
**Best for**: Decision-making, understanding trade-offs, planning integration

**Contents**:
- Quick assessment (strengths & limitations)
- Architecture highlights
- Core components breakdown
- Security layers explanation
- Variable persistence flow
- Integration recommendations (Option A vs B)
- Recommended adapters for kimiz
- Performance metrics
- Configuration examples
- Next steps for integration

**Read this** to understand why MCX is recommended and how to integrate it.

---

### 3. **MCX_ARCHITECTURE.md** (Deep Dive)
**Purpose**: Comprehensive technical architecture analysis  
**Length**: ~795 lines  
**Best for**: Understanding implementation details, security analysis, advanced integration

**Contents**:
- Executive summary
- Monorepo structure (packages/cli, packages/core, adapters)
- Runtime stack (Bun, MCP SDK, SQLite FTS5, etc.)
- MCP server implementation (serve.ts, 3,962 LOC)
- MCP tools (15 total with descriptions)
- Sandbox execution model (Bun Worker, 670 LOC)
- Security layers (5 layers with code examples)
- Variable persistence mechanism (PersistentState, 210 LOC)
- Adapter system (definition, loading, injection)
- CLI & subprocess invocation
- Performance characteristics
- Integration points for kimiz
- Key files & permalinks
- Strengths & limitations
- Recommendations
- References

**Read this** for deep technical understanding and implementation details.

---

## Quick Navigation

### I want to...

**...understand MCX in 5 minutes**
→ Read: **MCX_QUICK_REFERENCE.md** (sections 1-3)

**...decide if MCX is right for kimiz**
→ Read: **MCX_EVALUATION_SUMMARY.md** (sections 1-2)

**...understand how MCX works internally**
→ Read: **MCX_ARCHITECTURE.md** (sections 1-5)

**...integrate MCX into kimiz**
→ Read: **MCX_EVALUATION_SUMMARY.md** (section 8) + **MCX_QUICK_REFERENCE.md** (section 5)

**...understand the security model**
→ Read: **MCX_ARCHITECTURE.md** (section 3.2) + **MCX_QUICK_REFERENCE.md** (section 4)

**...see code examples**
→ Read: **MCX_QUICK_REFERENCE.md** (sections 2, 6, 8)

**...understand variable persistence**
→ Read: **MCX_ARCHITECTURE.md** (section 4) + **MCX_QUICK_REFERENCE.md** (section 12)

**...find specific implementation details**
→ Read: **MCX_ARCHITECTURE.md** (section 9 - Key Files & Permalinks)

---

## Key Findings Summary

### ✅ Strengths

1. **Production-Ready**: Used in Claude Code (Anthropic's official integration)
2. **Subprocess-Invocable**: CLI-based, works as standalone MCP server
3. **Variable Persistence**: `$var` mechanism for cross-execution state
4. **Security**: 5-layer defense (Worker isolation, network policy, analysis, normalization, timeout)
5. **Performance**: 99% token savings for large files, 10-500ms execution time
6. **Extensible**: Pluggable adapters with lazy-loading
7. **Well-Documented**: README, docs/, examples

### ⚠️ Limitations

1. **Bun-Only**: Requires Bun 1.2.0+ (not Node.js compatible)
2. **Session-Scoped State**: Variables lost on server restart
3. **No Persistent Storage**: No database for cross-session state
4. **Worker Overhead**: ~5-10MB per execution
5. **Network Isolation**: Fetch/WebSocket blocked by default

---

## Architecture at a Glance

```
MCX = MCP Server + Sandbox + Adapters + Variable Persistence

┌─────────────────────────────────────────────────────────┐
│ MCP Server (serve.ts, 3,962 LOC)                        │
│ - 15 MCP tools (execute, search, file, etc.)            │
│ - Stdio + HTTP transport                                │
│ - Adapter loading & management                          │
│ - Variable persistence (PersistentState)                │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Sandbox (bun-worker.ts, 670 LOC)                        │
│ - Bun Worker isolation                                  │
│ - Code normalization (AST-based)                        │
│ - Pre-execution analysis (5 rules)                      │
│ - Network isolation                                     │
│ - Timeout enforcement                                   │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Adapters (pluggable tools)                              │
│ - Supabase (24 methods)                                 │
│ - Chrome DevTools (25 methods)                          │
│ - Custom adapters (user-defined)                        │
└─────────────────────────────────────────────────────────┘
```

---

## Integration Recommendation

**Option A: Subprocess (Recommended)** ⭐
- Spawn `mcx serve --transport http` as subprocess
- Connect via HTTP to `http://127.0.0.1:3100/mcp`
- Pros: Isolated process, easy to manage
- Cons: Process overhead, requires Bun

**Option B: Programmatic (Advanced)**
- Use `@papicandela/mcx-core` directly
- Create `MCXExecutor` instance
- Pros: No subprocess overhead
- Cons: Requires Bun in kimiz, more complex

---

## Performance Metrics

### Execution Time
- Simple code: 10-50ms
- Adapter call: 50-200ms
- Large data: 100-500ms
- Timeout: 5000ms (configurable)

### Token Efficiency
- Large file processing: **99% savings**
- Data filtering in sandbox: **98% savings**
- Compressed variables: **70-90% savings**

**Example**: 50KB JSON file
- Native Read: ~12,500 tokens
- `mcx_file({ storeAs })`: ~125 tokens

---

## Next Steps

1. **Proof of Concept**
   - Spawn MCX as subprocess
   - Test `mcx_execute` with simple code
   - Verify variable persistence

2. **Integration**
   - Create custom kimiz adapter
   - Register with MCX
   - Test with real workflows

3. **Optimization**
   - Profile execution time
   - Tune sandbox config
   - Implement caching if needed

4. **Documentation**
   - Document adapter API
   - Create usage examples
   - Add to kimiz docs

---

## References

- **Repository**: https://github.com/schizoidcock/mcx
- **Commit**: 24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4
- **MCP Spec**: https://modelcontextprotocol.io/
- **Bun Docs**: https://bun.sh/docs
- **Anthropic Article**: https://www.anthropic.com/engineering/code-execution-with-mcp

---

## Document Statistics

| Document | Lines | Size | Focus |
|----------|-------|------|-------|
| MCX_QUICK_REFERENCE.md | ~350 | 8.6K | Quick overview & examples |
| MCX_EVALUATION_SUMMARY.md | ~375 | 8.6K | Decision & integration |
| MCX_ARCHITECTURE.md | ~795 | 24K | Deep technical analysis |
| **Total** | **~1,520** | **~41K** | Comprehensive evaluation |

---

## Conclusion

MCX is a **production-ready, well-architected code execution sandbox** that meets all of kimiz's requirements:

✅ Subprocess-invocable  
✅ Variable persistence  
✅ Extensible adapters  
✅ Strong security  
✅ Excellent performance  
✅ Active maintenance  

**Recommendation**: Proceed with integration using **Option A (Subprocess)** for clean separation and easy management.

---

**Last Updated**: April 5, 2026  
**Evaluated Version**: MCX 0.3.24 (CLI), 0.2.9 (Core)  
**Status**: ✅ RECOMMENDED

