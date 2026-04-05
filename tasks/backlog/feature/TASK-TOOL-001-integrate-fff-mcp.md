### TASK-TOOL-001: 集成 fff MCP Server 作为搜索工具
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 3h

**描述**:
将 fff.nvim 的 MCP Server (`fff-mcp`) 集成为 kimiz 的高速模糊搜索工具，替代当前基于 std.regex 的简单 grep 实现。

**背景**:
fff.nvim 是目前最快的文件/代码搜索引擎：
- 500k 文件 < 100ms
- 模糊搜索 + typo 纠错
- Frecency 排名（记忆常用文件）
- Git 感知（优先显示 modified/staged）
- 支持 MCP 协议，已被 Claude Code/OpenCode 采用

**集成方案**:
```
kimiz Agent
    ↓ 调用工具
fff MCP Server (subprocess)
    ↓ stdio JSON-RPC
fff-core (Rust search engine)
    ↓
返回搜索结果
```

**实施步骤**:

1. **安装 fff-mcp**
```bash
# Linux/macOS
curl -L https://raw.githubusercontent.com/dmtrKovalenko/fff.nvim/main/install-mcp.sh | bash
# 安装到 ~/.local/bin/fff-mcp
```

2. **创建 FFFTool 封装**
```zig
// src/agent/tools/fff.zig
const std = @import("std");
const tool = @import("../tool.zig");

pub const TOOL_NAME = "fff";

pub const tool_definition = tool.Tool{
    .name = TOOL_NAME,
    .description = "Fast fuzzy file finder with AI memory. " ++
        "Use for finding files by name or searching content. " ++
        "Supports fuzzy matching, typo correction, and git-aware ranking.",
    .parameters_json = 
        \\{
        \\  "type": "object",
        \\  "properties": {
        \\    "action": { "type": "string", "enum": ["find_files", "grep"] },
        \\    "query": { "type": "string" },
        \\    "constraints": { "type": "string", "description": "git:modified, *.zig, !test/" }
        \\  }
        \\}
    ,
};

const FFFArgs = struct {
    action: []const u8,
    query: []const u8,
    constraints: ?[]const u8 = null,
};

pub fn createAgentTool(ctx: *anyopaque) tool.AgentTool {
    return tool.AgentTool{
        .tool = tool_definition,
        .execute_fn = execute,
        .ctx = ctx,
    };
}

fn execute(
    ctx: *anyopaque,
    arena: std.mem.Allocator,
    args: std.json.Value,
) anyerror!tool.ToolResult {
    const parsed_args = tool.parseArguments(args, FFFArgs) catch {
        return tool.errorResult(arena, "Invalid arguments");
    };

    // 构建 MCP 请求
    const request = try buildMCPRequest(arena, parsed_args);
    defer arena.free(request);

    // 调用 fff-mcp subprocess
    const result = try runFFFMCP(arena, request);
    defer arena.free(result);

    // 解析 MCP 响应
    return parseMCPResponse(arena, result);
}
```

3. **MCP Subprocess 管理**
```zig
fn runFFFMCP(arena: std.mem.Allocator, request: []const u8) ![]u8 {
    const fff_path = try findFFFPath();
    
    var child = std.process.Child.init(&.{ fff_path, "--no-update-check" }, arena);
    child.stdin_behavior = .pipe;
    child.stdout_behavior = .pipe;
    child.stderr_behavior = .ignore;

    try child.spawn();
    defer _ = child.wait() catch {};

    // 发送 JSON-RPC 请求
    try child.stdin.?.writeAll(request);
    child.stdin.?.close();
    child.stdin = null;

    // 读取响应
    const stdout = child.stdout.?.reader().readAllAlloc(arena, 1024 * 1024);
    return stdout;
}
```

4. **替换现有 grep 工具**
```zig
// src/agent/root.zig
pub fn getDefaultTools() []tool.AgentTool {
    return &.{
        fff.createAgentTool(&fff_ctx),  // 替换 grep
        read_file.createAgentTool(&read_ctx),
        write_file.createAgentTool(&write_ctx),
        edit.createAgentTool(&edit_ctx),
        bash.createAgentTool(&bash_ctx),
    };
}
```

5. **配置 MCP Server 路径**
```zig
// src/config.zig
pub const FFFConfig = struct {
    mcp_path: []const u8 = ".local/bin/fff-mcp",
    base_path: []const u8 = ".",
    frecency_db: ?[]const u8 = null,
    history_db: ?[]const u8 = null,
};
```

**MCP JSON-RPC 协议**:

```json
// find_files 请求
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "find_files",
    "arguments": {
      "query": "main.zig",
      "limit": 50
    }
  }
}

// grep 请求
{
  "jsonrpc": "2.0", 
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "grep",
    "arguments": {
      "query": "pub fn",
      "path": "src",
      "limit": 100
    }
  }
}
```

**验收标准**:
- [ ] `zig build` 编译通过
- [ ] fff-mcp 能正常启动
- [ ] find_files 搜索 < 100ms (10k 文件)
- [ ] grep 搜索 < 200ms (10k 文件)
- [ ] 模糊搜索 "mtxlk" 能匹配 "mutex_lock"
- [ ] git:modified 约束正常工作

**依赖**:
- fff-mcp 安装 (curl -L ... | bash)

**阻塞**:
- 无

**笔记**:
- MCP Server 通过 stdio 通信，延迟约 50-100ms
- 如需更低延迟，可考虑 C FFI 方案 (TASK-TOOL-002)
- fff 自动创建 ~/.cache/fff/ 存储 frecency 数据
