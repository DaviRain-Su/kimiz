# MCX Quick Reference for Kimiz

## TL;DR

**MCX** = Production-ready code execution sandbox for AI agents  
**Status**: ✅ RECOMMENDED for kimiz integration  
**Key Feature**: `$var` persistence across executions  
**Security**: 5-layer defense (Worker isolation, network policy, analysis, normalization, timeout)

---

## 1. What is MCX?

MCX (Modular Code Execution) is an MCP server that executes JavaScript code in isolated Bun Workers with:
- Adapter injection (pluggable tools)
- Variable persistence (`$var` mechanism)
- 99% token savings for large files
- Built-in security & analysis

**Used by**: Claude Code (Anthropic's official integration)

---

## 2. Key Capabilities

### Code Execution
```javascript
// Execute code in sandbox
await mcx_execute({
  code: `
    const data = await adapters.api.fetch();
    return data.filter(x => x.active);
  `,
  storeAs: "activeData"  // Store for later use
});
```

### Variable Persistence
```javascript
// Execution 1: Store result
await mcx_execute({
  code: "return await adapters.api.getData();",
  storeAs: "apiData"
});

// Execution 2: Access stored variable
await mcx_execute({
  code: "return $apiData.filter(x => x.status === 'paid');"
});
```

### File Operations
```javascript
// Load large file without returning content (99% token savings)
await mcx_file({
  path: "large-file.json",
  storeAs: "data"
});

// Query with helpers
await mcx_execute({
  code: `
    const lines = lines($data, 100, 120);
    const matches = grep($data, "TODO", 3);
    return { lines, matches };
  `
});
```

### Adapter Calls
```javascript
// Call registered adapters
await mcx_execute({
  code: `
    const projects = await adapters.supabase.list_projects();
    const items = await adapters.myapi.getItems({ limit: 100 });
    return { projects, items };
  `
});
```

---

## 3. MCP Tools (15 total)

| Category | Tools |
|----------|-------|
| **Execution** | `mcx_execute`, `mcx_batch`, `mcx_spawn` |
| **Files** | `mcx_file`, `mcx_edit`, `mcx_write` |
| **Search** | `mcx_search`, `mcx_find`, `mcx_grep`, `mcx_related` |
| **Utilities** | `mcx_fetch`, `mcx_list`, `mcx_stats`, `mcx_doctor`, `mcx_run_skill` |

---

## 4. Security Layers

```
┌─────────────────────────────────────┐
│ Layer 1: Worker Isolation           │ ← Separate JS context
├─────────────────────────────────────┤
│ Layer 2: Network Isolation          │ ← fetch/WebSocket blocked
├─────────────────────────────────────┤
│ Layer 3: Pre-execution Analysis     │ ← Detect infinite loops
├─────────────────────────────────────┤
│ Layer 4: Code Normalization         │ ← AST validation
├─────────────────────────────────────┤
│ Layer 5: Timeout                    │ ← 5000ms default
└─────────────────────────────────────┘
```

---

## 5. Integration Options

### Option A: Subprocess (Recommended) ⭐

```typescript
import { spawn } from "child_process";

// Start MCX server
const mcxProcess = spawn("bun", [
  "run", "mcx", "serve",
  "--transport", "http",
  "--port", "3100"
]);

// Call via HTTP
const response = await fetch("http://127.0.0.1:3100/mcp", {
  method: "POST",
  body: JSON.stringify({
    jsonrpc: "2.0",
    id: 1,
    method: "tools/call",
    params: {
      name: "mcx_execute",
      arguments: { code: "return 42;" }
    }
  })
});
```

**Pros**: Isolated process, easy to manage  
**Cons**: Process overhead, requires Bun

### Option B: Programmatic (Advanced)

```typescript
import { MCXExecutor } from "@papicandela/mcx-core";

const executor = new MCXExecutor({
  config: {
    adapters: [customAdapter],
    sandbox: { timeout: 10000 }
  }
});

const result = await executor.execute(`
  return await adapters.custom.getData();
`);
```

**Pros**: No subprocess overhead  
**Cons**: Requires Bun in kimiz, more complex

---

## 6. Built-in Helpers

Available in sandbox code:

```javascript
// Data manipulation
pick(arr, ['id', 'name'])      // Extract fields
first(arr, 5)                   // First N items
sum(arr, 'amount')              // Sum numeric field
count(arr, 'status')            // Count by field
table(arr, 10)                  // Markdown table

// Async helpers
await poll(fn, { interval: 2000, maxIterations: 5 })
await waitFor(fn, { timeout: 30000 })

// File query helpers (when using mcx_file with storeAs)
around($file, 150, 10)          // 10 lines around line 150
lines($file, 100, 120)          // Get lines 100-120
block($file, 150)               // Extract code block
grep($file, "TODO", 3)          // Search with context
outline($file)                  // Function signatures
```

---

## 7. Performance

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

## 8. Configuration

### Global (~/.mcx/mcx.config.ts)

```typescript
export default {
  adapters: [
    // Auto-loaded from ~/.mcx/adapters/
  ],
  sandbox: {
    timeout: 10000,
    normalizeCode: true,
    analysis: {
      enabled: true,
      blockOnError: true,
    },
  },
};
```

### Custom Adapter

```typescript
// ~/.mcx/adapters/kimiz.ts
import { defineAdapter } from "@papicandela/mcx-adapters";

export default defineAdapter({
  name: "kimiz",
  domain: "development",
  tools: {
    executeCommand: {
      description: "Execute shell command",
      parameters: {
        cmd: { type: "string", required: true },
      },
      execute: async (params) => {
        // Implementation
      },
    },
  },
});
```

---

## 9. Strengths ✅

- ✅ Production-ready (used in Claude Code)
- ✅ Subprocess-invocable
- ✅ Variable persistence (`$var`)
- ✅ Strong security (5 layers)
- ✅ Excellent performance (99% token savings)
- ✅ Extensible adapters
- ✅ Active maintenance

---

## 10. Limitations ⚠️

- ⚠️ Bun-only (not Node.js compatible)
- ⚠️ Session-scoped state (lost on restart)
- ⚠️ No persistent storage
- ⚠️ Worker overhead (~5-10MB)
- ⚠️ Network isolation by default

---

## 11. CLI Commands

```bash
# Start server
mcx serve                    # stdio (default)
mcx serve --transport http   # HTTP on port 3100

# Initialize
mcx init                     # Create ~/.mcx/

# Generate adapter from OpenAPI
mcx gen ./api-docs.md -n myapi

# List adapters/skills
mcx list

# Run skill directly
mcx run skill-name

# View logs
mcx logs

# Update
mcx update
```

---

## 12. Variable Persistence Flow

```
Execution 1:
  code: "const data = await api.fetch(); return data;"
  storeAs: "apiData"
  ↓
  PersistentState.set("apiData", result)

Execution 2:
  code: "return $apiData.filter(x => x.active);"
  ↓
  PersistentState.getAllPrefixed() → { $apiData: {...} }
  ↓
  Injected into sandbox context
```

---

## 13. Recommended for Kimiz

1. **File Operations**
   - `mcx_file` - Load files (99% token savings)
   - `mcx_edit` - Edit files
   - `mcx_write` - Create files

2. **Code Search**
   - `mcx_grep` - SIMD-accelerated search
   - `mcx_find` - Fuzzy file search
   - `mcx_related` - Find related files

3. **Custom Adapter**
   - Register kimiz-specific tools
   - Example: `executeCommand`, `analyzeCode`

4. **Variable Persistence**
   - Use `$var` for multi-step workflows

---

## 14. Next Steps

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
   - Implement caching

---

## 15. References

- **Full Analysis**: `MCX_ARCHITECTURE.md`
- **Evaluation**: `MCX_EVALUATION_SUMMARY.md`
- **Repository**: https://github.com/schizoidcock/mcx
- **MCP Spec**: https://modelcontextprotocol.io/
- **Bun Docs**: https://bun.sh/docs

---

## Recommendation

**✅ PROCEED WITH INTEGRATION**

MCX is production-ready and meets all kimiz requirements. Use **Option A (Subprocess)** for clean separation and easy management.

