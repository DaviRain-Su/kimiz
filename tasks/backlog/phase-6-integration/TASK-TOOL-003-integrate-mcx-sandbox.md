### TASK-TOOL-003: 集成 MCX MCP Server 作为代码执行沙箱
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 2h

**描述**:
将 MCX (Model Context Protocol 服务器) 集成为 kimiz 的代码执行沙箱，提供高效的安全执行能力和变量持久化。

**背景**:
MCX 让 AI Agent 直接在沙箱里写代码执行，而不是一个个调用工具：
- 98% token 节省 (过滤在沙箱内完成)
- 变量持久化 ($var) - 工作记忆
- 大文件自动沙箱存储
- 内置 FFF 文件搜索 (SIMD 加速)
- 后台任务支持

**注意**: MCX 需要 Bun 运行时。如果kimiz需要完全自包含，可能需要用其他方案替代。

**集成方案**:
```
kimiz Agent
    ↓ MCP JSON-RPC
mcx serve (subprocess)
    ↓
Bun 沙箱执行
    ↓
返回 ~50 tokens 结果
```

**MCP 服务器配置**:
```json
// ~/.config/kimiz/mcp.json 或项目 .mcp.json
{
  "mcpServers": {
    "mcx": {
      "command": "mcx",
      "args": ["serve"]
    }
  }
}
```

**实施步骤**:

1. **检查 Bun 运行时**
```zig
// src/mcp/discovery.zig
pub fn hasBunRuntime() bool {
    const result = std.process.Child.run(.{
        .argv = &.{"bun", "--version"},
        .allocator = undefined,
    });
    return result != null;
}
```

2. **创建 MCX MCP 客户端封装**
```zig
// src/mcp/mcx.zig
const std = @import("std");

pub const MCXClient = struct {
    allocator: std.mem.Allocator,
    process: std.process.Child,
    
    pub fn init(allocator: std.mem.Allocator) !Self {
        var process = try std.process.Child.init(&.{"mcx", "serve"}, allocator);
        process.stdin_behavior = .pipe;
        process.stdout_behavior = .pipe;
        process.stderr_behavior = .pipe;
        
        try process.spawn();
        
        return Self{
            .allocator = allocator,
            .process = process,
        };
    }
    
    // 调用 MCP 工具
    pub fn callTool(self: *Self, tool: []const u8, args: anytype) ![]u8 {
        const request = try std.json.stringifyAlloc(self.allocator, .{
            .jsonrpc = "2.0",
            .id = 1,
            .method = "tools/call",
            .params = .{
                .name = tool,
                .arguments = args,
            },
        });
        defer self.allocator.free(request);
        
        try self.process.stdin.?.writeAll(request);
        try self.process.stdin.?.writeAll("\n");
        
        const reader = self.process.stdout.?.reader();
        const response = try reader.readUntilDelimiterAlloc(self.allocator, '\n');
        return response;
    }
    
    pub fn deinit(self: *Self) void {
        _ = self.process.wait() catch {};
    }
};
```

3. **定义 MCX 工具代理**
```zig
// src/agent/tools/mcx_execute.zig
pub const MCXExecuteTool = struct {
    client: *MCXClient,
    
    pub fn execute(self: *Self, arena: std.mem.Allocator, code: []const u8) !ToolResult {
        const result = try self.client.callTool("mcx_execute", .{
            .code = code,
            .truncate = true,
            .maxItems = 10,
        });
        defer self.allocator.free(result);
        
        // 解析结果
        const parsed = try std.json.parseFromSlice(MCPResponse, arena, result, .{});
        return ToolResult{
            .content = &.{
                .{ .text = parsed.result.content },
            },
        };
    }
};
```

4. **添加其他 MCX 工具**
```zig
// MCX 提供的 16 个工具可以按需代理:
const MCX_TOOLS = .{
    "mcx_execute",   // 代码执行
    "mcx_search",    // 3 模式搜索
    "mcx_file",      // 文件处理
    "mcx_edit",      // 编辑文件
    "mcx_write",     // 写文件
    "mcx_fetch",     // URL 获取
    "mcx_find",      // FFF 文件搜索
    "mcx_grep",      // SIMD 内容搜索
    "mcx_related",   // 相关文件
    "mcx_tree",      // JSON 导航
    "mcx_spawn",     // 后台任务
    "mcx_tasks",     // 任务管理
    "mcx_list",      // 列出适配器
    "mcx_stats",     // 统计
    "mcx_doctor",    // 诊断
    "mcx_run_skill", // 运行 skill
};
```

5. **处理变量持久化**
```zig
// MCX 变量系统
pub const MCXVariables = struct {
    allocator: std.mem.Allocator,
    vars: std.StringHashMap(MCXVar),
    
    pub fn get(self: *Self, name: []const u8) ?[]const u8 { ... }
    pub fn set(self: *Self, name: []const u8, value: []const u8) !void { ... }
    pub fn clear(self: *Self) void { ... }
    pub fn autoCompress(self: *Self) void { ... }  // >5min 或 >1KB
};
```

**工具定义示例**:
```zig
pub const tool_definition = tool.Tool{
    .name = "mcx_execute",
    .description = "Execute JavaScript/TypeScript code in sandbox. " ++
        "Use for data processing, API calls, file operations. " ++
        "Results auto-stored as $result. Token efficient - only returns summary.",
    .parameters_json = 
        \\{
        \\  "type": "object",
        \\  "properties": {
        \\    "code": { "type": "string" },
        \\    "storeAs": { "type": "string" },
        \\    "intent": { "type": "string" }
        \\  }
        \\}
    ,
};
```

**Bun 运行时检查**:
```zig
// 在 kimiz 启动时检查
pub fn checkMCPDependencies() !void {
    // 检查 bun
    const bun_version = try runCommand(&.{"bun", "--version"});
    if (bun_version.len == 0) {
        std.log.warn("MCX requires Bun runtime but not found. Install: bun.sh", .{});
    }
    
    // 检查 mcx
    const mcx_version = try runCommand(&.{"mcx", "--version"});
    if (mcx_version.len == 0) {
        std.log.warn("MCX not found. Install: bun add -g @papicandela/mcx-cli", .{});
    }
}
```

**验收标准**:
- [ ] `mcx serve` 能正常启动
- [ ] `mcx_execute` 能执行 JS 代码
- [ ] 变量持久化 ($var) 正常工作
- [ ] `mcx_find` 和 `mcx_grep` 正常工作 (FFF 集成)
- [ ] 大文件 `storeAs` 正常工作

**依赖**:
- Bun 运行时
- MCX: `bun add -g @papicandela/mcx-cli`

**阻塞**:
- 无

**笔记**:
- MCX 是外部依赖，需要 Bun 运行时
- 如果 kimiz 需要完全自包含 (无外部依赖)，需要用其他方案替代
- MCX 内置 FFF，集成 MCX 后自动获得快速文件搜索
- 考虑添加 `use_mcx` 配置选项，默认关闭 (需要用户主动安装)

**替代方案 (完全自包含)**:
如果需要完全自包含，可以用 Zig 重写沙箱执行：
- 使用 Zig 的 `std.process.Child` 执行用户代码
- 添加安全检查 (syscall 过滤、内存限制)
- 但功能不如 MCX 完善
