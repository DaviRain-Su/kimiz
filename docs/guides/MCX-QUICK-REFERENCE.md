# MCX Quick Reference for Kimiz Integration

## What is MCX?

MCX is an **MCP server** that lets agents execute code in a sandboxed environment instead of calling individual tools. It exposes **19 MCP tools** for code execution, file operations, and content search.

**Key Innovation**: Agents write code that filters data in the sandbox, reducing context by 98%.

---

## MCP Tools at a Glance

### Execution (3 tools)
- `mcx_execute` - Run JS/TS code in sandbox
- `mcx_run_skill` - Execute registered skills
- `mcx_batch` - Run multiple executions/searches

### File Operations (4 tools)
- `mcx_file` - Process local files
- `mcx_edit` - Edit files (string or line mode)
- `mcx_write` - Create/overwrite files
- `mcx_fetch` - Fetch URLs with HTML-to-markdown

### Search & Discovery (4 tools)
- `mcx_search` - 3 modes: spec exploration, FTS5 search, adapter search
- `mcx_find` - Fast fuzzy file search
- `mcx_grep` - SIMD-accelerated content search
- `mcx_related` - Find related files by imports

### Background & Utilities (8 tools)
- `mcx_spawn` - Run code in background
- `mcx_tasks` - Check background tasks
- `mcx_list` - List adapters and skills
- `mcx_tree` - Navigate large JSON results
- `mcx_stats` - Session statistics
- `mcx_doctor` - Run diagnostics
- `mcx_upgrade` - Get upgrade command

---

## Sandbox Execution Flow

```
Code Input
    ↓
[1] Code Normalization (auto-return, syntax check)
[2] Pre-execution Analysis (infinite loops, dangerous patterns)
[3] Network Isolation (fetch/WebSocket blocked by default)
[4] Bun Worker Execution (isolated context, 5s timeout)
[5] Result Processing (summarize, index, store)
```

---

## Key Features

| Feature | Details |
|---------|---------|
| **Adapters** | Pluggable system, lazy-loaded, 2 built-in (Supabase, Chrome DevTools) |
| **Skills** | Reusable code snippets with inputs |
| **Variables** | Persist across executions ($result, $name, etc.) |
| **Indexing** | FTS5 full-text search on large outputs |
| **Security** | 5 layers: Worker isolation, network block, analysis, normalization, timeout |
| **Timeout** | 5 seconds default, configurable |
| **Network** | Blocked by default, configurable per execution |

---

## Integration Options for Kimiz

### Option 1: Direct Programmatic (Recommended)
```typescript
import { MCXExecutor } from '@papicandela/mcx-core';

const executor = new MCXExecutor({
  config: {
    sandbox: { timeout: 10000 },
    adapters: [/* custom adapters */]
  }
});

const result = await executor.execute('return 2 + 2');
```

### Option 2: MCP Client (Stdio)
```typescript
const mcxProcess = spawn('mcx', ['serve']);
const transport = new StdioClientTransport(mcxProcess);
const client = new MCPClient(transport);

const result = await client.callTool('mcx_execute', {
  code: 'return 2 + 2'
});
```

### Option 3: MCP Client (HTTP)
```bash
# Start MCX on HTTP
mcx serve --http 3000

# Connect from kimiz
const client = new MCPClient('http://localhost:3000');
```

### Option 4: CLI Wrapper
```bash
mcx run my-skill --input '{"param": "value"}'
```

---

## Creating Custom Adapters for Kimiz

```typescript
import { defineAdapter } from '@papicandela/mcx-core';

const kimizAdapter = defineAdapter({
  name: 'kimiz',
  description: 'Kimiz-specific operations',
  domain: 'task-execution',
  tools: {
    'execute-task': {
      description: 'Execute a kimiz task',
      parameters: {
        taskId: { type: 'string', required: true },
        params: { type: 'object' }
      },
      execute: async (params) => {
        // Call kimiz API
        return await kimizAPI.executeTask(params.taskId, params.params);
      }
    },
    'list-tasks': {
      description: 'List available tasks',
      execute: async () => {
        return await kimizAPI.listTasks();
      }
    }
  }
});

// Use in executor
const executor = new MCXExecutor({
  config: {
    adapters: [kimizAdapter]
  }
});

// Now available in sandbox
const result = await executor.execute(`
  const tasks = await kimiz.listTasks();
  return { count: tasks.length, tasks };
`);
```

---

## Built-in Helpers in Sandbox

```javascript
// Data transformation
pick(data, ['id', 'name'])     // Extract fields
first(data, 5)                  // First N items
sum(data, 'amount')             // Sum numeric field
count(data, 'status')           // Count by field
table(data, 10)                 // Markdown table

// Async helpers
await poll(fn, { interval: 2000, maxIterations: 5 })
await waitFor(fn, { timeout: 30000 })

// Variables
$result                         // Auto-stored result
$search                         // Auto-stored search results
delete $varname                 // Delete variable
$clear                          // Clear all variables
```

---

## Example: Using MCX with Kimiz

```typescript
// 1. Create executor with kimiz adapter
const executor = new MCXExecutor({
  config: {
    sandbox: { timeout: 10000 },
    adapters: [kimizAdapter]
  }
});

// 2. Execute code that uses kimiz
const result = await executor.execute(`
  // Get all active tasks
  const tasks = await kimiz.listTasks({ status: 'active' });
  
  // Filter and transform
  const summary = {
    total: tasks.length,
    byPriority: count(tasks, 'priority'),
    overdue: tasks.filter(t => new Date(t.dueDate) < new Date()).length
  };
  
  return summary;
`, {
  storeAs: 'taskSummary',
  intent: 'find overdue tasks'
});

// 3. Access result
console.log(result.value);  // { total: 42, byPriority: {...}, overdue: 5 }
```

---

## Dependencies

- **Bun 1.2.0+** (required for runtime)
- **@modelcontextprotocol/sdk ^1.26.0** (MCP protocol)
- **@papicandela/mcx-core** (sandbox, adapters, skills)
- **acorn ^8.16.0** (AST parsing)
- **zod ^3.23.0** (validation)

---

## Security Considerations

1. **Network Isolation**: Fetch/WebSocket blocked by default
2. **Code Analysis**: Detects infinite loops, dangerous patterns
3. **Timeout**: 5 seconds default, prevents runaway code
4. **Worker Isolation**: Code runs in separate JavaScript context
5. **Configurable**: All security layers can be customized

---

## Performance Tips

1. **Use `intent` for large outputs**: Auto-indexes and returns snippets
2. **Use `storeAs` to save variables**: Avoid re-computing
3. **Use `mcx_batch` for multiple operations**: Bypasses throttling
4. **Lazy-load adapters**: Only loaded on first use
5. **Auto-compress stale variables**: >5min old, >1KB auto-compressed

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Code timeout | Increase `timeout` in sandbox config |
| Network blocked | Set `networkPolicy.allowFetch: true` |
| Infinite loop detected | Rewrite with explicit break conditions |
| Large output truncated | Use `intent` parameter for auto-indexing |
| Adapter not found | Check adapter name (camelCase for hyphens) |

---

## Resources

- **Full Analysis**: See `MCX-INTEGRATION-ANALYSIS.md`
- **Repository**: https://github.com/schizoidcock/mcx
- **MCP Spec**: https://modelcontextprotocol.io/
- **Bun Docs**: https://bun.sh/docs

