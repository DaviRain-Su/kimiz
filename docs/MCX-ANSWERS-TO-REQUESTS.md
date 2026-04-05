# MCX Integration - Answers to Your Requests

## REQUEST 1: Find MCP tool definitions in MCX

**ANSWER**: MCX exposes **19 MCP tools** via `server.registerTool()` in the MCP server.

### Tool Categories

**Execution (3 tools)**
- `mcx_execute` - Execute JS/TS code in sandbox
- `mcx_run_skill` - Execute registered skills  
- `mcx_batch` - Batch executions/searches

**File Operations (4 tools)**
- `mcx_file` - Process local files
- `mcx_edit` - Edit files (string or line mode)
- `mcx_write` - Create/overwrite files
- `mcx_fetch` - Fetch URLs with HTML-to-markdown

**Search & Discovery (4 tools)**
- `mcx_search` - 3 modes: spec exploration, FTS5 search, adapter search
- `mcx_find` - Fast fuzzy file search
- `mcx_grep` - SIMD-accelerated content search
- `mcx_related` - Find related files by imports/exports

**Background & Utilities (8 tools)**
- `mcx_spawn` - Run code in background
- `mcx_tasks` - Check background tasks
- `mcx_list` - List adapters and skills
- `mcx_tree` - Navigate large JSON results
- `mcx_stats` - Session statistics
- `mcx_doctor` - Run diagnostics
- `mcx_upgrade` - Get upgrade command

**Source Code**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/cli/src/commands/serve.ts#L1471-L3630

---

## REQUEST 2: Look at how sandbox execution is triggered

**ANSWER**: Sandbox execution follows a 5-stage pipeline with security checks at each stage.

### Execution Pipeline

```
User Code (mcx_execute)
    ↓
[1] Code Normalization (AST-based)
    - Auto-add return statements
    - Syntax validation
    - Acorn parser
    ↓
[2] Pre-execution Analysis
    - Detect infinite loops
    - Detect dangerous patterns
    - Detect adapter calls in loops
    - 5 analysis rules
    ↓
[3] Network Isolation
    - Block fetch/WebSocket by default
    - Configurable via networkPolicy
    ↓
[4] Bun Worker Execution
    - Create isolated Worker
    - Inject adapters as globals
    - Enforce timeout (default 5s)
    - Execute code
    ↓
[5] Result Processing
    - Extract images
    - Summarize large outputs
    - Auto-index with intent
    - Store in variables ($result, $name)
```

### Code Execution Example

```typescript
// Input
const result = await sandbox.execute(code, {
  adapters: adapterContext,
  variables: state.getAllPrefixed(),
  env: config?.env || {},
});

// Output
{
  success: boolean
  value?: unknown
  error?: { name: string, message: string, stack?: string }
  logs: string[]
  executionTime: number
}
```

**Source Code**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/core/src/sandbox/bun-worker.ts#L40-L150

---

## REQUEST 3: Check if MCX can run standalone or requires Neovim

**ANSWER**: MCX **runs completely standalone** and does NOT require Neovim.

### Standalone Operation

MCX is a standard MCP server that can be started independently:

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

### Optional: Claude Code Integration

MCX can optionally integrate with Claude Code via `.mcp.json`:

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

But this is **optional** - MCX works standalone without it.

### Neovim Requirement

**NO** - MCX does not require Neovim. It's a general MCP server that works with any MCP-compatible client.

**Source Code**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/cli/src/commands/serve.ts#L3800-L3850

---

## REQUEST 4: Find the JSON-RPC protocol details

**ANSWER**: MCX uses the Model Context Protocol (MCP) which is built on JSON-RPC 2.0.

### MCP Server Implementation

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
  inputSchema: ExecuteInputSchema,  // Zod schema
  annotations: {
    readOnlyHint: false,
    destructiveHint: false,
    idempotentHint: false,
    openWorldHint: true,
  }
}, async (params) => {
  // Tool implementation
  return { content: [...] };
});

// Connect transport
const transport = new StdioServerTransport();
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

### Input Validation

All tool inputs are validated with Zod schemas:

```typescript
const ExecuteInputSchema = z.object({
  code: z.string()
    .min(1, "Code cannot be empty")
    .describe("JavaScript/TypeScript code to execute"),
  truncate: z.boolean().optional().default(true),
  maxItems: z.number().int().min(1).max(1000).optional().default(10),
  maxStringLength: z.number().int().min(10).max(10000).optional().default(500),
  intent: z.string().optional(),
  storeAs: z.string().optional(),
}).strict();
```

**Source Code**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/cli/src/commands/serve.ts#L170-L280

---

## REQUEST 5: Look for any Python/CLI interface

**ANSWER**: MCX has a **CLI interface** but **NO native Python interface**.

### CLI Commands

```bash
mcx serve              # Start MCP server
mcx init               # Initialize ~/.mcx/
mcx gen ./api.md -n myapi  # Generate adapter from OpenAPI
mcx list               # List adapters and skills
mcx run <skill>        # Run skill directly
mcx logs               # View server logs
mcx update             # Update CLI
```

### Python Integration Options

**Option 1: Use MCP Client Library**
```python
import asyncio
from mcp.client import Client

async def main():
    client = Client("mcx")
    result = await client.call_tool("mcx_execute", {
        "code": "return 2 + 2"
    })
    print(result)
```

**Option 2: Shell Out to CLI**
```python
import subprocess
import json

result = subprocess.run(
    ["mcx", "run", "my-skill"],
    capture_output=True,
    text=True
)
print(json.loads(result.stdout))
```

**Option 3: Start MCX Server, Connect via HTTP**
```python
import requests

response = requests.post(
    "http://localhost:3000/tools/mcx_execute",
    json={"code": "return 2 + 2"}
)
print(response.json())
```

**Source Code**: https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/cli/src/index.ts

---

## REQUEST 6: Check dependencies (Bun? Node?)

**ANSWER**: MCX requires **Bun 1.2.0+** as the runtime.

### Core Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| **Bun** | 1.2.0+ | **REQUIRED** - Runtime for code execution |
| @modelcontextprotocol/sdk | ^1.26.0 | MCP protocol implementation |
| acorn | ^8.16.0 | AST parsing for code analysis |
| zod | ^3.23.0 | Input schema validation |
| @ff-labs/fff-bun | ^0.5.2 | Fast file finder |
| commander | ^14.0.3 | CLI framework |
| picocolors | ^1.1.1 | Terminal colors |
| yaml | ^2.6.0 | YAML parsing |

### Runtime Requirements

- **Bun 1.2.0+** (REQUIRED)
- **Node.js 18+** (for core package only)
- **SQLite 3** (for FTS5 search)

### Optional Dependencies

Platform-specific binaries for `fff` (Fast File Finder):
- `@ff-labs/fff-bin-darwin-arm64`
- `@ff-labs/fff-bin-darwin-x64`
- `@ff-labs/fff-bin-linux-x64-gnu`
- `@ff-labs/fff-bin-win32-x64`

### Why Bun?

MCX uses Bun for:
1. **Native Worker support** - Isolated code execution
2. **Performance** - Fast startup and execution
3. **Package management** - Integrated package manager
4. **TypeScript support** - Native TS compilation

**Source Code**: 
- https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/cli/package.json
- https://github.com/schizoidcock/mcx/blob/24670aa311ee83c1e7b7d6eb0f4ae62e3ec9f2d4/packages/core/package.json

---

## BONUS: MCP Protocol & Tool Definitions

### How Tools Are Defined

MCX tools are registered with the MCP server using `server.registerTool()`:

```typescript
server.registerTool(
  "tool_name",
  {
    title: "Human-readable title",
    description: "Detailed description with examples",
    inputSchema: ZodSchema,  // Validates input
    annotations: {
      readOnlyHint: boolean,
      destructiveHint: boolean,
      idempotentHint: boolean,
      openWorldHint: boolean,
    }
  },
  async (params) => {
    // Tool implementation
    return { content: [...] };
  }
);
```

### Tool Discovery

Agents can discover available tools via:

1. **mcx_list** - List all adapters and skills
2. **mcx_search** - Search adapters/methods by name
3. **mcx_search({ code: "..." })** - Query $spec directly

### Adapter System

Adapters are pluggable modules that provide methods to the sandbox:

```typescript
interface Adapter {
  name: string;
  description?: string;
  domain?: string;  // e.g., "database", "payments"
  tools: Record<string, AdapterTool>;
  __lazy?: boolean;  // Lazy-loaded flag
  __path?: string;   // Path to load from
}
```

Adapters are:
- **Lazy-loaded** - Metadata scanned at startup, fully loaded on first use
- **Injected as globals** - Available in sandbox as `adapterName.methodName()`
- **Customizable** - Can define domain-specific adapters for kimiz

---

## SUMMARY: Can MCX Be Used as Kimiz Code Execution Sandbox?

### YES - MCX is Perfect for Kimiz

✓ **Standalone MCP server** - No Neovim required  
✓ **19 MCP tools** - Comprehensive code execution and file operations  
✓ **Sandboxed execution** - 5 security layers  
✓ **Pluggable adapters** - Create kimiz-specific adapters  
✓ **External agent compatible** - Standard MCP protocol  
✓ **Variable persistence** - State across executions  
✓ **Content indexing** - FTS5 search on large outputs  

### Recommended Integration

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

## Documentation Files

1. **MCX-INTEGRATION-ANALYSIS.md** (895 lines)
   - Comprehensive technical analysis
   - All tool definitions with permalinks
   - Execution flow details
   - Security architecture

2. **MCX-QUICK-REFERENCE.md** (264 lines)
   - Quick lookup guide
   - Integration options
   - Code examples
   - Troubleshooting

3. **MCX-ANSWERS-TO-REQUESTS.md** (this file)
   - Direct answers to your 6 requests
   - Code examples
   - Integration recommendations

