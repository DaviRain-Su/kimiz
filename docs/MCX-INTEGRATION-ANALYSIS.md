# MCX MCP Protocol Implementation Analysis

**Repository**: https://github.com/schizoidcock/mcx  
**Commit SHA**: 24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4  
**Current Version**: 0.3.24 (CLI), 0.2.9 (Core)

---

## 1. ARCHITECTURE OVERVIEW

MCX is an **MCP (Model Context Protocol) server** that exposes code execution as a service instead of traditional tool definitions. The key innovation: agents write code that runs in a sandbox, filtering data before returning to context.

### Core Components

```
mcx/
├── packages/
│   ├── cli/          # MCP Server implementation + CLI
│   ├── core/         # Sandbox, adapters, skills, types
│   └── adapters/     # Base adapter classes
├── adapters/         # Pre-built adapters (supabase, chrome-devtools)
└── skills/           # Reusable skill definitions
```

### Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Runtime** | Bun 1.2.0+ | Code execution, package management |
| **MCP SDK** | @modelcontextprotocol/sdk ^1.26.0 | Protocol implementation |
| **Sandbox** | Bun Workers | Isolated code execution |
| **Code Analysis** | Acorn 8.16.0 | AST parsing for safety checks |
| **Validation** | Zod 3.23.0 | Input schema validation |
| **Transport** | Stdio + HTTP | MCP server transports |

---

## 2. MCP TOOLS EXPOSED

MCX registers **19 MCP tools** via `server.registerTool()`. All tools follow the MCP protocol with:
- **Input Schema**: Zod-validated parameters
- **Output**: Text content + optional structured data
- **Annotations**: readOnlyHint, destructiveHint, idempotentHint, openWorldHint

### Tool Definitions

#### **Core Execution Tools**

**1. `mcx_execute`** - Execute code in sandbox
```typescript
// Input Schema
{
  code: string                    // Required: JS/TS code
  truncate?: boolean              // Default: true
  maxItems?: number               // Default: 10, max: 1000
  maxStringLength?: number        // Default: 500, max: 10000
  intent?: string                 // Auto-index large outputs
  storeAs?: string                // Variable name for result
}

// Output
{
  content: [{ type: "text", text: string }]
  structuredContent?: {
    indexed?: boolean
    sourceId?: number
    chunks?: number
    metadata?: { type, count?, keys? }
    storedAs?: string[]
  }
  isError?: boolean
}
```

**Permalink**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/cli/src/commands/serve.ts#L1471-L1720

**2. `mcx_search`** - Three search modes
```typescript
// Mode 1: Spec exploration (code)
{ code: string }                    // JS code against $spec

// Mode 2: FTS5 content search (queries)
{
  queries: string[]                 // Search terms
  source?: string                   // Filter by source label
}

// Mode 3: Adapter/method search
{
  query?: string                    // Search term
  adapter?: string                  // Filter by adapter
  method?: string                   // Filter by method
  type?: "all" | "adapters" | "methods" | "skills"
  limit?: number                    // Default: 20, max: 100
  storeAs?: string                  // Store result as variable
}
```

**Permalink**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/cli/src/commands/serve.ts#L1851-L2333

**3. `mcx_run_skill`** - Execute registered skills
```typescript
{
  skill: string                     // Skill name
  inputs?: Record<string, unknown>  // Input parameters
  truncate?: boolean                // Default: true
  maxItems?: number                 // Default: 10
  maxStringLength?: number          // Default: 500
}
```

**Permalink**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/cli/src/commands/serve.ts#L1720-L1790

#### **File & Content Tools**

**4. `mcx_file`** - Process local files
```typescript
{
  path: string                      // File path
  storeAs?: string                  // Store in sandbox
  code?: string                     // Code to execute with $file
  intent?: string                   // Auto-index large files
}
```

**5. `mcx_edit`** - Edit files (string or line mode)
```typescript
{
  path: string
  mode: "string" | "line"
  search?: string                   // For string mode
  replace?: string                  // For string mode
  lineStart?: number                // For line mode
  lineEnd?: number
  content?: string
}
```

**6. `mcx_write`** - Create/overwrite files
```typescript
{
  path: string
  content: string
  append?: boolean
}
```

**7. `mcx_fetch`** - Fetch URLs with HTML-to-markdown
```typescript
{
  url: string
  intent?: string                   // Auto-index content
  storeAs?: string
}
```

**Permalink**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/cli/src/commands/serve.ts#L2334-L2697

#### **Search & Discovery Tools**

**8. `mcx_find`** - Fast fuzzy file search
```typescript
{
  query: string                     // Fuzzy search pattern
  limit?: number                    // Default: 20
  cwd?: string                      // Search directory
}
```

**9. `mcx_grep`** - SIMD-accelerated content search
```typescript
{
  pattern: string                   // Regex pattern
  paths?: string[]                  // Files to search
  limit?: number                    // Default: 20
}
```

**10. `mcx_related`** - Find related files by imports/exports
```typescript
{
  path: string
  depth?: number                    // Default: 2
}
```

**11. `mcx_list`** - List adapters and skills
```typescript
{
  truncate?: boolean                // Default: true
  maxItems?: number                 // Default: 20, max: 500
}
```

**Permalink**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/cli/src/commands/serve.ts#L2698-L2801

#### **Batch & Background Tools**

**12. `mcx_batch`** - Batch executions/searches
```typescript
{
  executions?: Array<{
    code: string
    storeAs?: string
  }>
  queries?: string[]                // FTS5 queries
  source?: string
}
```

**13. `mcx_spawn`** - Run code in background
```typescript
{
  code: string
  storeAs?: string
}
```

**14. `mcx_tasks`** - List/check background tasks
```typescript
{
  taskId?: string                   // Specific task
  limit?: number                    // Default: 20
}
```

**Permalink**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/cli/src/commands/serve.ts#L2802-L3004

#### **Utility Tools**

**15. `mcx_tree`** - Navigate large JSON results
```typescript
{
  path: string                      // JSON path (e.g., "$result.data[0]")
  limit?: number                    // Default: 20
}
```

**16. `mcx_stats`** - Session statistics
```typescript
{
  // No parameters
}
```

**17. `mcx_doctor`** - Run diagnostics
```typescript
{
  // No parameters
}
```

**18. `mcx_upgrade`** - Get self-upgrade command
```typescript
{
  // No parameters
}
```

**Permalink**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/cli/src/commands/serve.ts#L3005-L3630

---

## 3. SANDBOX EXECUTION FLOW

### Execution Pipeline

```
User Code (mcx_execute)
    ↓
[1] Code Normalization (AST-based)
    - Auto-add return statements
    - Syntax validation
    ↓
[2] Pre-execution Analysis
    - Detect infinite loops
    - Detect dangerous patterns
    - Detect adapter calls in loops
    ↓
[3] Network Isolation
    - Block fetch/WebSocket by default
    - Configurable via networkPolicy
    ↓
[4] Bun Worker Execution
    - Isolated JavaScript context
    - Timeout enforcement (default 5s)
    - Adapter injection
    ↓
[5] Result Processing
    - Extract images
    - Summarize large outputs
    - Auto-index with intent
    - Store in variables ($result, $name)
```

### Code Normalization

**File**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/core/src/sandbox/normalizer.ts

```typescript
// Input
const x = 5;
x * 2

// Output (auto-return)
const x = 5;
return x * 2
```

### Pre-execution Analysis

**File**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/core/src/sandbox/analyzer/index.ts

Rules checked:
- `no-infinite-loop` - Detects while/for without break
- `no-dangerous-globals` - Blocks process, require, eval
- `no-adapter-in-loop` - Prevents adapter calls in loops
- `no-nested-loops` - Warns on nested loops
- `no-unhandled-async` - Detects unhandled promises

### Bun Worker Sandbox

**File**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/core/src/sandbox/bun-worker.ts#L40-L150

```typescript
class BunWorkerSandbox implements ISandbox {
  async execute<T>(code: string, context: ExecutionContext): Promise<SandboxResult<T>> {
    // 1. Normalize code
    const normalizedCode = normalizeCode(code);
    
    // 2. Analyze for safety
    const analysisResult = analyze(normalizedCode);
    
    // 3. Create isolated Worker
    const workerCode = this.buildWorkerCode();
    const blob = new Blob([workerCode], { type: "application/javascript" });
    const worker = new Worker(URL.createObjectURL(blob));
    
    // 4. Execute with timeout
    return new Promise((resolve) => {
      const timeoutId = setTimeout(() => {
        worker.terminate();
        resolve({ success: false, error: { name: "TimeoutError" } });
      }, this.config.timeout);
      
      worker.onmessage = (event) => {
        clearTimeout(timeoutId);
        worker.terminate();
        resolve(event.data);
      };
      
      // 5. Send code + context to worker
      worker.postMessage({ code: normalizedCode, context });
    });
  }
}
```

### Adapter Injection

Adapters are injected as globals in the sandbox:

```javascript
// In sandbox context
const result = await supabase.list_projects();
const data = await chromeDevtools.listPages();
const custom = await adapters['custom-name'].method();
```

**Permalink**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/core/src/executor.ts#L45-L150

---

## 4. ADAPTER SYSTEM

### Adapter Definition

**File**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/core/src/types.ts

```typescript
interface Adapter {
  name: string;                           // e.g., "supabase"
  description?: string;
  domain?: string;                        // e.g., "database", "payments"
  tools: Record<string, AdapterTool>;     // Methods
  __lazy?: boolean;                       // Lazy-loaded flag
  __path?: string;                        // Path to load from
}

interface AdapterTool {
  description: string;
  parameters?: Record<string, ParameterDefinition>;
  execute: (params: unknown) => Promise<unknown>;
}

interface ParameterDefinition {
  type: string;                           // "string", "number", "object", etc.
  description?: string;
  required?: boolean;
  default?: unknown;
}
```

### Built-in Adapters

1. **Supabase** (24 methods)
   - Project management
   - Table operations
   - Function invocation
   - Secret management

2. **Chrome DevTools** (25 methods)
   - Screenshots
   - Navigation
   - DOM manipulation
   - Network inspection

**Permalink**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/adapters/

### Lazy Loading

Adapters are metadata-scanned at startup but fully loaded on first use:

```typescript
// At startup: scan adapters/ directory
const adapters = loadAdaptersMetadata();  // Fast, ~100ms

// On first use: fully load adapter
const adapter = await loadAdapterFull(name);  // Slower, ~500ms
```

---

## 5. SKILL SYSTEM

### Skill Definition

**File**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/core/src/skill.ts

```typescript
interface Skill {
  name: string;
  description?: string;
  inputs?: Record<string, {
    type: string;
    description?: string;
    default?: unknown;
  }>;
  run: (ctx: { inputs: Record<string, unknown> }) => Promise<unknown>;
}

// Define a skill
const mySkill = defineSkill({
  name: "process-data",
  description: "Process invoice data",
  inputs: {
    limit: { type: "number", default: 100 }
  },
  run: async ({ inputs }) => {
    const invoices = await adapters.alegra.getInvoices({ limit: inputs.limit });
    return {
      count: invoices.length,
      total: sum(invoices, 'amount')
    };
  }
});
```

### Built-in Helpers

Available in sandbox:

```javascript
pick(data, ['id', 'name'])     // Extract fields
first(data, 5)                  // First N items
sum(data, 'amount')             // Sum numeric field
count(data, 'status')           // Count by field
table(data, 10)                 // Markdown table

// Async helpers
await poll(fn, { interval: 2000, maxIterations: 5 })
await waitFor(fn, { timeout: 30000 })
```

---

## 6. JSON-RPC PROTOCOL DETAILS

### MCP Server Implementation

**File**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/cli/src/commands/serve.ts#L3800-L3850

```typescript
// Create MCP server
const server = new McpServer({
  name: "mcx",
  version: "0.3.24",
});

// Register tools
server.registerTool("mcx_execute", {
  title: "Execute Code in MCX Sandbox",
  description: "...",
  inputSchema: ExecuteInputSchema,
  annotations: { ... }
}, async (params) => {
  // Tool implementation
  return { content: [...] };
});

// Connect transport
const transport = new StdioServerTransport();  // or StreamableHTTPServerTransport
await server.connect(transport);
```

### Transport Options

1. **Stdio** (default)
   ```bash
   mcx serve  # Listens on stdin/stdout
   ```

2. **HTTP**
   ```bash
   mcx serve --http 3000  # Listens on http://localhost:3000
   ```

### Tool Response Format

All tools return MCP-compliant responses:

```typescript
interface ToolResponse {
  content: Array<{
    type: "text" | "image" | "resource";
    text?: string;
    mimeType?: string;
    data?: string;
  }>;
  structuredContent?: Record<string, unknown>;
  isError?: boolean;
}
```

---

## 7. STANDALONE vs NEOVIM INTEGRATION

### Standalone Operation

MCX **runs standalone** as an MCP server:

```bash
# 1. Install globally
bun add -g @papicandela/mcx-cli

# 2. Initialize
mcx init  # Creates ~/.mcx/

# 3. Start server
mcx serve  # Listens on stdio

# 4. Connect via MCP client
# Any MCP-compatible client can connect
```

**Does NOT require Neovim** - it's a general MCP server.

### Claude Code Integration

MCX integrates with Claude Code via `.mcp.json`:

```json
{
  "mcpServers": {
    "mcx": {
      "command": "mcx",
      "args": ["serve"]
    }
  }
}
```

### Optional: Hooks Integration

MCX can redirect native Claude Code tools to MCX alternatives:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Grep",
        "hooks": [{ "type": "command", "command": "bun ~/.claude/hooks/mcx-redirect.js" }]
      }
    ]
  }
}
```

---

## 8. PYTHON/CLI INTERFACE

### CLI Commands

**File**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/cli/src/index.ts

```bash
mcx serve              # Start MCP server
mcx init               # Initialize ~/.mcx/
mcx gen ./api.md -n myapi  # Generate adapter from OpenAPI
mcx list               # List adapters and skills
mcx run <skill>        # Run skill directly
mcx logs               # View server logs
mcx update             # Update CLI
```

### No Native Python Interface

MCX is **TypeScript/Bun only**. To use from Python:

1. **Option A**: Start MCX server, connect via MCP client library
   ```python
   import asyncio
   from mcp.client import Client
   
   async def main():
       client = Client("mcx")
       result = await client.call_tool("mcx_execute", {
           "code": "return 2 + 2"
       })
   ```

2. **Option B**: Shell out to `mcx` CLI
   ```python
   import subprocess
   result = subprocess.run(["mcx", "run", "my-skill"], capture_output=True)
   ```

---

## 9. DEPENDENCIES

### Core Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| @modelcontextprotocol/sdk | ^1.26.0 | MCP protocol |
| acorn | ^8.16.0 | AST parsing |
| zod | ^3.23.0 | Schema validation |
| @ff-labs/fff-bun | ^0.5.2 | Fast file finder |
| commander | ^14.0.3 | CLI framework |
| picocolors | ^1.1.1 | Terminal colors |
| yaml | ^2.6.0 | YAML parsing |

### Runtime Requirements

- **Bun 1.2.0+** (required)
- **Node.js 18+** (for core package)
- **SQLite 3** (for FTS5 search)

### Optional Dependencies

Platform-specific binaries for `fff` (Fast File Finder):
- `@ff-labs/fff-bin-darwin-arm64`
- `@ff-labs/fff-bin-darwin-x64`
- `@ff-labs/fff-bin-linux-x64-gnu`
- `@ff-labs/fff-bin-win32-x64`

---

## 10. EXTERNAL AGENT INTEGRATION

### Can MCX Be Called from External Agents?

**YES** - MCX is a standard MCP server that any MCP-compatible client can call:

1. **Direct MCP Connection**
   ```typescript
   // Any MCP client can connect
   const client = new MCPClient("mcx");
   const result = await client.callTool("mcx_execute", {
     code: "return 2 + 2"
   });
   ```

2. **Stdio Transport**
   ```bash
   # Start MCX
   mcx serve
   
   # Connect from external process
   # Reads from stdin, writes to stdout
   ```

3. **HTTP Transport**
   ```bash
   # Start MCX on HTTP
   mcx serve --http 3000
   
   # Connect from anywhere
   curl -X POST http://localhost:3000/tools/mcx_execute \
     -d '{"code": "return 2 + 2"}'
   ```

### Kimiz Integration Approach

For kimiz to use MCX as a code execution sandbox:

```typescript
// Option 1: Spawn MCX process
const mcxProcess = spawn('mcx', ['serve']);
const transport = new StdioClientTransport(mcxProcess);
const client = new MCPClient(transport);

// Option 2: Connect to HTTP endpoint
const client = new MCPClient('http://localhost:3000');

// Option 3: Use MCXExecutor directly (programmatic)
import { MCXExecutor } from '@papicandela/mcx-core';
const executor = new MCXExecutor();
const result = await executor.execute('return 2 + 2');
```

---

## 11. SECURITY ARCHITECTURE

### Sandbox Security Layers

1. **Worker Isolation**
   - Code runs in separate JavaScript context
   - No access to main thread

2. **Network Isolation**
   - fetch/WebSocket blocked by default
   - Configurable via networkPolicy

3. **Pre-execution Analysis**
   - Detects infinite loops
   - Detects dangerous patterns
   - Detects adapter calls in loops

4. **Code Normalization**
   - AST-based validation
   - Syntax checking

5. **Timeout Enforcement**
   - Default 5 seconds
   - Configurable per execution

### Network Policy

**File**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/core/src/sandbox/network-policy.ts

```typescript
interface NetworkPolicy {
  allowedDomains?: string[];
  blockedDomains?: string[];
  allowFetch?: boolean;
  allowWebSocket?: boolean;
}

// Default: all network blocked
const DEFAULT_NETWORK_POLICY = {
  allowFetch: false,
  allowWebSocket: false,
};
```

---

## 12. VARIABLE PERSISTENCE

### Session State Management

**File**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/cli/src/sandbox/state.ts

```typescript
// Variables persist across executions
mcx_execute({ code: "const x = 5; return x;" })
// → Stored as $result

mcx_execute({ code: "return $result * 2;" })
// → Can access $result from previous execution

// Custom variable names
mcx_execute({
  code: "return [1, 2, 3];",
  storeAs: "numbers"
})
// → Stored as $numbers

// Auto-compression
// Stale variables (>5min, >1KB) auto-compressed to save context
```

### Variable Helpers

```javascript
$clear                    // Clear all variables
delete $varname           // Delete specific variable
$result                   // Auto-stored result
$search                   // Auto-stored search results
```

---

## 13. CONTENT INDEXING & SEARCH

### FTS5 Full-Text Search

**File**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/cli/src/search/store.ts

```typescript
// Auto-index large outputs (>5KB)
mcx_execute({
  code: "return await api.getInvoices();",
  intent: "find overdue invoices"
})

// Returns search results instead of full data
// Indexed content searchable via mcx_search
```

### Intent-based Indexing

When `intent` parameter is provided:
1. Output is indexed into FTS5 database
2. Search performed against intent
3. Relevant snippets returned
4. Full data stored in $result for later access

---

## SUMMARY FOR KIMIZ INTEGRATION

### Key Findings

| Aspect | Details |
|--------|---------|
| **MCP Tools** | 19 tools exposed via standard MCP protocol |
| **Sandbox** | Bun Workers with 5 security layers |
| **Adapters** | Pluggable system, lazy-loaded, 2 built-in |
| **Skills** | Reusable code snippets with inputs |
| **Standalone** | YES - runs as independent MCP server |
| **Neovim Required** | NO - general MCP server |
| **Python Support** | NO native interface, use MCP client or shell |
| **External Agents** | YES - standard MCP protocol |
| **Dependencies** | Bun 1.2.0+, @modelcontextprotocol/sdk ^1.26.0 |
| **Network** | Blocked by default, configurable |
| **Timeout** | 5 seconds default, configurable |
| **State** | Variables persist across executions |

### Integration Points for Kimiz

1. **Direct Programmatic**: Import `MCXExecutor` from `@papicandela/mcx-core`
2. **MCP Client**: Connect via stdio or HTTP transport
3. **CLI Wrapper**: Shell out to `mcx` commands
4. **Custom Adapters**: Define domain-specific adapters for kimiz

### Recommended Approach

```typescript
// kimiz/src/integrations/mcx.ts
import { MCXExecutor } from '@papicandela/mcx-core';
import { defineAdapter } from '@papicandela/mcx-core';

// Create executor
const executor = new MCXExecutor({
  config: {
    sandbox: { timeout: 10000 },
    adapters: [
      defineAdapter({
        name: 'kimiz',
        description: 'Kimiz-specific operations',
        tools: {
          'execute-task': {
            description: 'Execute kimiz task',
            execute: async (params) => { ... }
          }
        }
      })
    ]
  }
});

// Use in kimiz
const result = await executor.execute(`
  const tasks = await kimiz.executeTasks({ filter: 'active' });
  return { count: tasks.length, tasks };
`);
```

