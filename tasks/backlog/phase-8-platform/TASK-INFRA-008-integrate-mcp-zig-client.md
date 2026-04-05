# TASK-INFRA-008: 集成 mcp.zig MCP 客户端

**状态**: pending  
**优先级**: P1  
**预计工时**: 8小时  
**指派给**: TBD  
**标签**: infrastructure, mcp, protocol, high-priority

---

## 背景

发现 **mcp.zig** (https://github.com/muhammad-fiaz/mcp.zig) - Zig 编写的 MCP (Model Context Protocol) 客户端实现。

**MCP 协议**: Anthropic 推出的标准化 Agent 工具协议，已被 Claude Code、OpenCode 等采用。

**当前问题**: TASK-TOOL-001/003/005 计划手动实现 MCP 调用，重复且维护成本高。

**解决方案**: 使用 mcp.zig 作为统一 MCP 客户端，简化所有工具集成。

---

## 目标

使用 mcp.zig 重构 kimiz 的 MCP 工具集成，实现统一、标准化的工具调用。

---

## 技术方案

### 架构设计

**之前 (手动实现)**:
```
src/agent/tools/
├── fff.zig          (手动 MCP JSON-RPC)
├── browser.zig      (手动 MCP 调用)
└── mcx.zig          (手动 MCP 管理)
```

**之后 (使用 mcp.zig)**:
```
src/mcp/
├── client.zig       (mcp.zig 封装)
├── manager.zig      (服务器管理)
└── config.zig       (配置加载)

src/agent/tools/     (简化，通过 MCP 调用)
└── (可能不需要单独文件)
```

### 核心实现

```zig
// src/mcp/manager.zig
const mcp = @import("mcp");
const std = @import("std");

pub const MCPManager = struct {
    allocator: std.mem.Allocator,
    clients: std.StringHashMap(mcp.Client),
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .clients = std.StringHashMap(mcp.Client).init(allocator),
        };
    }
    
    pub fn deinit(self: *MCPManager) void {
        var it = self.clients.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.clients.deinit();
    }
    
    /// 连接 MCP Server
    pub fn connectServer(self: *MCPManager, name: []const u8, command: []const u8) !void {
        const client = try mcp.Client.connectStdio(self.allocator, command);
        try self.clients.put(name, client);
    }
    
    /// 调用工具
    pub fn callTool(
        self: *MCPManager,
        server_name: []const u8,
        tool_name: []const u8,
        args: std.json.Value
    ) !ToolResult {
        const client = self.clients.get(server_name) orelse return error.ServerNotFound;
        return try client.callTool(tool_name, args);
    }
    
    /// 获取所有可用工具
    pub fn listAllTools(self: *MCPManager, allocator: std.mem.Allocator) ![]Tool {
        var all_tools = std.ArrayList(Tool).init(allocator);
        errdefer all_tools.deinit();
        
        var it = self.clients.iterator();
        while (it.next()) |entry| {
            const tools = try entry.value_ptr.listTools();
            for (tools) |tool| {
                const scoped_tool = Tool{
                    .name = try std.fmt.allocPrint(allocator, "{s}.{s}", .{
                        entry.key_ptr.*, tool.name
                    }),
                    .description = tool.description,
                    .parameters = tool.parameters,
                };
                try all_tools.append(scoped_tool);
            }
        }
        
        return all_tools.toOwnedSlice();
    }
    
    /// 从配置批量连接
    pub fn connectFromConfig(self: *MCPManager, config: MCPConfig) !void {
        for (config.servers) |server| {
            if (server.enabled) {
                try self.connectServer(server.name, server.command);
            }
        }
    }
};

const Tool = struct {
    name: []const u8,
    description: []const u8,
    parameters: std.json.Value,
};

const ToolResult = struct {
    content: []Content,
    is_error: bool,
};

const Content = union(enum) {
    text: []const u8,
    image: ImageData,
    resource: ResourceData,
};
```

### 配置设计

```toml
# kimiz.toml
[mcp]
# MCP Servers 配置

[mcp.servers.fff]
command = "fff-mcp"
enabled = true

[mcp.servers.browser]
command = "lightpanda-mcp"
enabled = true

[mcp.servers.github]
command = "github-mcp"
enabled = false  # 默认禁用

[mcp.servers.postgres]
command = "postgres-mcp"
enabled = false
```

---

## 与现有任务的整合

### 需要更新的任务

| 任务 | 当前方案 | 新方案 | 行动 |
|------|---------|--------|------|
| **TASK-TOOL-001** | 手动 MCP | mcp.zig | 更新为使用 MCPManager |
| **TASK-TOOL-003** | 手动 MCP | mcp.zig | 更新为使用 MCPManager |
| **TASK-TOOL-005** | 手动 MCP | mcp.zig | 更新为使用 MCPManager |

### Agent 工具注册

```zig
// src/agent/root.zig (简化)
pub fn registerMCPTools(agent: *Agent, mcp_manager: *MCPManager) !void {
    // 动态获取所有 MCP 工具
    const tools = try mcp_manager.listAllTools(agent.allocator);
    
    // 注册到 Agent
    for (tools) |tool| {
        try agent.registerTool(.{
            .name = tool.name,
            .description = tool.description,
            .execute_fn = struct {
                fn execute(ctx: *anyopaque, arena: Allocator, args: std.json.Value) !ToolResult {
                    const manager: *MCPManager = @ptrCast(@alignCast(ctx));
                    // 解析 server_name.tool_name
                    // 调用 mcp_manager.callTool
                }
            }.execute,
            .ctx = mcp_manager,
        });
    }
}
```

---

## 验收标准

- [ ] mcp.zig 成功添加为依赖
- [ ] MCPManager 实现完整功能
- [ ] 能连接 fff-mcp 并调用工具
- [ ] 能连接 lightpanda-mcp 并调用工具
- [ ] 配置加载正常工作
- [ ] 错误处理完善
- [ ] 更新 TASK-TOOL-001/003/005
- [ ] 文档更新

---

## 依赖与阻塞

**依赖**:
- mcp.zig 项目成熟度评估 (https://github.com/muhammad-fiaz/mcp.zig)
- MCP Servers 可用性 (fff-mcp, lightpanda-mcp)

**阻塞**:
- 无

---

## 影响范围

### 正面影响

1. **简化开发**: 不需要手动实现 MCP
2. **标准兼容**: 确保 MCP 协议兼容性
3. **生态接入**: 自动支持所有 MCP Servers
4. **维护成本**: 由社区维护 mcp.zig

### 需要更新的文件

```
src/
├── mcp/
│   ├── root.zig        (新增)
│   ├── manager.zig     (新增)
│   └── config.zig      (新增)
├── agent/
│   └── root.zig        (更新工具注册)
└── config.zig          (更新 MCP 配置)

tasks/backlog/feature/
├── TASK-TOOL-001       (更新)
├── TASK-TOOL-003       (更新)
└── TASK-TOOL-005       (更新)
```

---

## 参考

- **mcp.zig**: https://github.com/muhammad-fiaz/mcp.zig
- **MCP 协议**: https://modelcontextprotocol.io/
- **MCP Servers**: https://github.com/modelcontextprotocol/servers
- **研究文档**: `docs/research/mcp-zig-client-analysis.md`

---

**创建日期**: 2026-04-05  
**建议实施时机**: 立即开始 (高优先级)  
**相关任务**: TASK-TOOL-001, TASK-TOOL-003, TASK-TOOL-005
