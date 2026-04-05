# mcp.zig MCP 客户端分析与 Kimiz 整合评估

**研究日期**: 2026-04-05  
**项目链接**: https://github.com/muhammad-fiaz/mcp.zig  
**评估目标**: 是否可作为 kimiz 的 MCP 协议实现方案

---

## 1. 项目概述

**mcp.zig** 是一个 **Zig 编写的 MCP (Model Context Protocol) 客户端实现**：

- **核心功能**: MCP 协议客户端，连接 MCP Servers
- **MCP 协议**: Anthropic 推出的标准化 Agent 工具协议
- **用途**: 让 Agent 能够调用外部工具 (fff, browser, 等)
- **语言**: Zig (与 kimiz 同语言)

**什么是 MCP?**
```
MCP (Model Context Protocol):
├── 标准化工具调用协议
├── 支持 stdio 和 HTTP 传输
├── 已被 Claude Code, OpenCode 等采用
└── 生态: fff-mcp, playwright-mcp, 等
```

---

## 2. 与 Kimiz 使用场景匹配度分析

### 2.1 MCP 在 kimiz 中的角色

**当前计划**: 通过 MCP 集成外部工具

```
kimiz Agent
    ↓ MCP 协议
MCP Servers
    ├── fff-mcp        (文件搜索)
    ├── browser-mcp    (网页渲染)
    └── 更多工具...
```

### 2.2 潜在使用场景

#### 场景 1: 统一工具接口

```zig
// 通过 MCP 调用所有外部工具
const mcp = @import("mcp");

// 连接 fff-mcp
const fff_server = try mcp.Client.connect("fff-mcp");

// 调用工具
const result = try fff_server.callTool("find_files", .{
    .query = "main.zig"
});
```

**价值**: ⭐⭐⭐⭐⭐ 极高 - 统一工具调用方式

#### 场景 2: 工具生态扩展

```zig
// 通过 MCP 使用各种工具，无需单独集成
const tools = &.{
    "fff-mcp",           // 文件搜索
    "playwright-mcp",    // 浏览器自动化
    "github-mcp",        // GitHub API
    "postgres-mcp",      // 数据库
    // 更多...
};
```

**价值**: ⭐⭐⭐⭐⭐ 极高 - 自动获得整个 MCP 生态

#### 场景 3: 动态工具发现

```zig
// MCP Server 提供工具列表
const tools = try server.listTools();
// 动态调用，无需预定义
```

**价值**: ⭐⭐⭐⭐ 高 - 灵活的工具使用

---

## 3. 整合方案评估

### 方案 A: 使用 mcp.zig 作为 MCP 客户端 (强烈推荐)

**替换/增强现有 MCP 集成计划**:

```zig
// src/mcp/client.zig
const mcp = @import("mcp");

pub const MCPClientManager = struct {
    allocator: Allocator,
    clients: std.StringHashMap(mcp.Client),
    
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .clients = std.StringHashMap(mcp.Client).init(allocator),
        };
    }
    
    pub fn connectServer(self: *MCPClientManager, name: []const u8, command: []const u8) !void {
        const client = try mcp.Client.connectStdio(self.allocator, command);
        try self.clients.put(name, client);
    }
    
    pub fn callTool(self: *MCPClientManager, server_name: []const u8, tool_name: []const u8, args: anytype) !ToolResult {
        const client = self.clients.get(server_name) orelse return error.ServerNotFound;
        return try client.callTool(tool_name, args);
    }
    
    pub fn listAllTools(self: *MCPClientManager) ![]Tool {
        var all_tools = std.ArrayList(Tool).init(self.allocator);
        
        var it = self.clients.iterator();
        while (it.next()) |entry| {
            const tools = try entry.value_ptr.listTools();
            try all_tools.appendSlice(tools);
        }
        
        return all_tools.toOwnedSlice();
    }
};
```

**使用**:
```zig
// kimiz 启动时连接 MCP Servers
var mcp_manager = MCPClientManager.init(allocator);

// 连接 fff
try mcp_manager.connectServer("fff", "fff-mcp");

// 连接 browser
try mcp_manager.connectServer("browser", "lightpanda-mcp");

// Agent 调用工具
const result = try mcp_manager.callTool("fff", "find_files", .{
    .query = "main.zig"
});
```

### 方案 B: 自行实现 MCP 客户端

**当前 TASK-TOOL-001 的方案**:
```zig
// 手动实现 MCP JSON-RPC
fn runFFFMCP(arena: Allocator, request: []const u8) ![]u8 {
    // 手动管理 subprocess
    // 手动构造 JSON-RPC
}
```

**缺点**:
- 重复造轮子
- 维护成本高
- 可能不兼容标准

### 方案 C: 对比评估

| 方案 | 实现成本 | 维护成本 | 标准兼容 | 推荐 |
|------|---------|---------|---------|------|
| **mcp.zig** (方案A) | 低 | 低 | ✅ 标准 | ⭐⭐⭐⭐⭐ |
| **自行实现** (方案B) | 高 | 高 | ⚠️ 风险 | ⭐⭐ |

---

## 4. 与现有任务的关联

### 影响的任务

| 任务 | 当前方案 | 新方案 (mcp.zig) | 建议 |
|------|---------|-----------------|------|
| **TASK-TOOL-001** (fff) | 手动 MCP | 使用 mcp.zig | ✅ 更新 |
| **TASK-TOOL-005** (browser) | 手动 MCP | 使用 mcp.zig | ✅ 更新 |
| **TASK-TOOL-003** (MCX) | 手动 MCP | 使用 mcp.zig | ✅ 更新 |

### 架构简化

**之前**:
```
每个工具单独实现 MCP 调用
├── fff.zig     (手动 MCP)
├── browser.zig (手动 MCP)
└── mcx.zig     (手动 MCP)
```

**使用 mcp.zig 后**:
```
统一 MCP 客户端
├── mcp/client.zig (使用 mcp.zig)
└── config: 服务器配置列表
```

---

## 5. 决策建议

### 强烈推荐: 使用 mcp.zig

> **"mcp.zig 是 kimiz MCP 集成的理想方案"**

**理由**:
1. **同语言**: Zig 原生，无缝集成
2. **标准化**: 兼容 MCP 协议标准
3. **简化开发**: 不需要自行实现 MCP
4. **生态接入**: 自动支持所有 MCP Servers
5. **维护成本**: 由社区维护，kimiz 专注业务

### 优先级

| 评估项 | 优先级 | 说明 |
|--------|--------|------|
| 整合 mcp.zig | P1 | 高优先级，简化工具集成 |
| 更新现有任务 | P1 | 同步更新 TASK-TOOL-001/003/005 |
| 测试兼容性 | P2 | 验证与 fff-mcp 等兼容 |

---

## 6. 实施建议

### Phase 1: 添加依赖

```zig
// build.zig
const mcp = b.dependency("mcp", .{
    .target = target,
    .optimize = optimize,
});

exe.addModule("mcp", mcp.module("mcp"));
```

### Phase 2: 重构工具集成

```zig
// src/tools/mcp_manager.zig
pub const ToolManager = struct {
    mcp_manager: MCPClientManager,
    
    pub fn initDefaultServers(self: *ToolManager) !void {
        // 自动连接配置的 MCP Servers
        try self.mcp_manager.connectServer("fff", "fff-mcp");
        try self.mcp_manager.connectServer("browser", "lightpanda-mcp");
        // ...
    }
};
```

### Phase 3: 更新配置

```toml
# kimiz.toml
[mcp.servers]
fff = { command = "fff-mcp" }
browser = { command = "lightpanda-mcp" }
github = { command = "github-mcp", enabled = false }
```

---

## 7. 结论

### 一句话总结

> **"mcp.zig 是 kimiz 工具集成的最佳方案，强烈建议采用"**

### 决策

| 评估项 | 结论 |
|--------|------|
| 整合建议 | ✅✅ 强烈推荐 |
| 优先级 | P1 (高优先级) |
| 影响 | 简化所有 MCP 工具集成 |

### 立即行动

- [ ] 评估 mcp.zig 成熟度和 API 稳定性
- [ ] 创建分支测试 mcp.zig 集成
- [ ] 更新 TASK-TOOL-001/003/005 使用 mcp.zig
- [ ] 设计统一的 MCP 服务器管理

---

## 参考

- mcp.zig: https://github.com/muhammad-fiaz/mcp.zig
- MCP 协议: https://modelcontextprotocol.io/
- MCP Servers: https://github.com/modelcontextprotocol/servers
- 相关任务:
  - TASK-TOOL-001 (fff MCP)
  - TASK-TOOL-003 (MCX MCP)
  - TASK-TOOL-005 (browser MCP)

---

*文档版本: 1.0*  
*最后更新: 2026-04-05*  
*维护者: kimiz-core-team*
