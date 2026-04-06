### TASK-TOOL-001: 集成 fff MCP Server 作为搜索工具
|**状态**: pending
|**优先级**: P0
|**创建**: 2026-04-05
|**更新**: 2026-04-05 (添加 Dmitriy Kovalenko 发布详情)
|**预计耗时**: 3h

|**描述**:
将 fff (Fuzzy File Finder) 的 MCP Server 集成为 kimiz 的高速模糊搜索工具，**替代当前基于 std.regex 的简单 grep 实现**。

|**背景**:
fff 是 @neogoose_btw (Dmitriy Kovalenko) 开发的无索引、极致快的模糊文件/代码搜索引擎，专为超大规模代码库和 AI Coding Agent 设计：

**核心特性**:
- **500k 文件 (Chromium 级别)** 实时搜索 < 100ms
- **比 ripgrep (rg) 快 100 倍以上**
- **比 Cursor 官方搜索、Google indexed code search 还准还快**
- **完全无索引** (index-free)，全内存运行，零延迟启动
- **模糊搜索 + typo 纠错** ("mtxlk" → "mutex_lock")
- **Frecency 排名** (自动学习文件重要性，给 AI Agent 智能优先级)
- **Git 感知** (优先显示 modified/staged 文件)

**技术栈**: Rust + Zig + SIMD + 内存映射缓存 + 预过滤 + 内联汇编

**官方资源**:
- **开源地址**: https://github.com/dmtrKovalenko/fff.nvim
- **在线演示**: https://fff.dmtrkovalenko.dev (可直接试用)
- **SDK 支持**: Rust / C / Node.js / Bun (Python 即将推出)

**已有集成案例**:
- **Pi + fff 原生集成**: https://github.com/SamuelLHuber/pi-fff (参考实现)
- Claude Code / OpenCode 已采用

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

4. **替换现有 grep 工具 (确认方案)**

**现状**: kimiz 当前使用基于 `std.regex` 的简单 grep 实现，性能差、无模糊匹配。

**替换方案**:
```zig
// src/agent/root.zig
pub fn getDefaultTools() []tool.AgentTool {
    return &.{
        fff.createAgentTool(&fff_ctx),  // ✅ 替换 grep，提供模糊搜索 + 智能排名
        read_file.createAgentTool(&read_ctx),
        write_file.createAgentTool(&write_ctx),
        edit.createAgentTool(&edit_ctx),
        bash.createAgentTool(&bash_ctx),
    };
}
```

**fff 对比现有 grep 的优势**:

| 特性 | 现有 grep | fff | 提升 |
|------|----------|-----|------|
| 10k 文件搜索 | ~500ms | < 100ms | **5x+** |
| 50万文件搜索 | 不可用 | < 100ms | **∞** |
| 模糊匹配 | ❌ 无 | ✅ 支持 | - |
| Typo 纠错 | ❌ 无 | ✅ "mtxlk"→"mutex_lock" | - |
| 智能排名 | ❌ 无 | ✅ Frecency 学习 | - |
| Git 感知 | ❌ 无 | ✅ 优先 modified | - |
| 索引需求 | ❌ 无 | ❌ 无索引 | - |

**迁移策略**:
- [ ] Phase 1: 并行运行 (fff + grep 同时存在，对比测试)
- [ ] Phase 2: 默认启用 fff，grep 降级为备选
- [ ] Phase 3: 完全移除 grep，fff 成为唯一搜索工具

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
