### Task-FEAT-006: 实现 Extension 系统
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 16h
**参考**: [Simplified Architecture Proposal](../../docs/design/simplified-architecture-proposal.md)

**描述**:
实现强大的 Extension 系统，允许运行时加载自定义工具、命令和 UI 组件。Extensions 将替代原有的 Skills 系统，提供更灵活的定制能力。

**设计目标**:
1. **WASM 运行时**: 使用 WebAssembly 实现跨语言支持
2. **安全沙箱**: Extensions 在受限环境中运行
3. **完整 API**: 提供工具注册、UI 定制、事件监听等能力
4. **易于开发**: 清晰的 API 和开发工具

**架构**:

```
┌─────────────────────────────────────────┐
│           Kimiz Core                    │
├─────────────────────────────────────────┤
│  Extension Manager                      │
│  ├── Loader (WASM)                      │
│  ├── Runtime (Wasmtime)                 │
│  └── API Registry                       │
├─────────────────────────────────────────┤
│  Extension API                          │
│  ├── Tool Registration                  │
│  ├── Command Registration               │
│  ├── UI Widgets                         │
│  └── Event Hooks                        │
└─────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│  Extensions (WASM)                      │
│  ├── custom-tools.wasm                  │
│  ├── subagents.wasm                     │
│  ├── git-integration.wasm               │
│  └── ...                                │
└─────────────────────────────────────────┘
```

**核心 API 设计**:

```zig
// src/extension/api.zig
pub const ExtensionApi = struct {
    // 版本
    api_version: u32 = 1,
    
    // 工具注册
    registerTool: *const fn (
        def: ToolDefinition,
        handler: ToolHandler,
    ) void,
    
    // 命令注册
    registerCommand: *const fn (
        name: []const u8,
        description: []const u8,
        handler: CommandHandler,
    ) void,
    
    // UI 组件
    registerWidget: *const fn (
        position: WidgetPosition,
        render_fn: RenderFn,
    ) void,
    
    // 事件监听
    onEvent: *const fn (
        event_type: EventType,
        handler: EventHandler,
    ) Subscription,
    
    // 取消订阅
    unsubscribe: *const fn (subscription: Subscription) void,
    
    // 日志
    log: *const fn (level: LogLevel, message: []const u8) void,
    
    // 文件访问 (沙箱)
    readFile: *const fn (path: []const u8) ![]const u8,
    writeFile: *const fn (path: []const u8, content: []const u8) !void,
    
    // HTTP 请求 (受限)
    httpGet: *const fn (url: []const u8) ![]const u8,
};

pub const ToolDefinition = struct {
    name: []const u8,
    description: []const u8,
    parameters: []const Parameter,
};

pub const Parameter = struct {
    name: []const u8,
    param_type: ParamType,
    required: bool,
    description: []const u8,
};

pub const ParamType = enum {
    string,
    integer,
    boolean,
    filepath,
    directory,
};

pub const WidgetPosition = enum {
    header,      // 顶部
    footer,      // 底部
    sidebar,     // 侧边栏
    overlay,     // 浮层
};

pub const EventType = enum {
    message_start,
    message_delta,
    message_complete,
    tool_call_start,
    tool_call_complete,
    session_start,
    session_end,
    error,
};
```

**WASM 接口**:

```zig
// src/extension/runtime.zig
pub const ExtensionRuntime = struct {
    wasm_engine: wasmtime.Engine,
    wasm_store: wasmtime.Store,
    
    pub fn init(allocator: std.mem.Allocator) !ExtensionRuntime;
    
    /// 加载 Extension
    pub fn loadExtension(
        self: *ExtensionRuntime,
        path: []const u8,
    ) !Extension;
    
    /// 卸载 Extension
    pub fn unloadExtension(self: *ExtensionRuntime, ext: Extension) void;
    
    /// 调用 Extension 函数
    pub fn call(self: *ExtensionRuntime, func: []const u8, args: []const u8) ![]const u8;
    
    pub fn deinit(self: *ExtensionRuntime) void;
};

pub const Extension = struct {
    id: []const u8,
    name: []const u8,
    version: []const u8,
    instance: wasmtime.Instance,
    
    pub fn init(self: Extension, api: *ExtensionApi) !void;
    pub fn shutdown(self: Extension) !void;
};
```

**Extension 示例 (Rust)**:

```rust
// example-extension/src/lib.rs
use kimiz_extension::*;

#[no_mangle]
pub extern "C" fn init(api: *const ExtensionApi) {
    let api = unsafe { &*api };
    
    // 注册自定义工具
    api.registerTool(
        ToolDefinition {
            name: "deploy",
            description: "Deploy the application",
            parameters: vec![
                Parameter {
                    name: "environment",
                    param_type: ParamType::String,
                    required: true,
                    description: "Target environment",
                },
            ],
        },
        deploy_handler,
    );
    
    // 注册命令
    api.registerCommand(
        "stats",
        "Show project statistics",
        stats_handler,
    );
    
    // 监听事件
    api.on_event(EventType::ToolCallComplete, |event| {
        api.log(LogLevel::Info, "Tool call completed");
    });
}

fn deploy_handler(args: &str) -> Result<String, String> {
    // 实现部署逻辑
    Ok("Deployed successfully".to_string())
}

fn stats_handler() -> Result<String, String> {
    // 实现统计逻辑
    Ok("Project stats: ...".to_string())
}
```

**Extension 管理**:

```bash
# 安装 Extension
kimiz install npm:@kimiz/git-tools
kimiz install git:github.com/user/kimiz-extension
kimiz install ./local-extension.wasm

# 列出已安装
kimiz list

# 启用/禁用
kimiz enable git-tools
kimiz disable git-tools

# 更新
kimiz update git-tools

# 移除
kimiz remove git-tools
```

```zig
// src/extension/manager.zig
pub const ExtensionManager = struct {
    allocator: std.mem.Allocator,
    runtime: ExtensionRuntime,
    extensions: std.StringHashMap(Extension),
    
    pub fn init(allocator: std.mem.Allocator) !ExtensionManager;
    
    /// 从 npm 安装
    pub fn installFromNpm(self: *ExtensionManager, package: []const u8) !void;
    
    /// 从 git 安装
    pub fn installFromGit(self: *ExtensionManager, url: []const u8) !void;
    
    /// 从本地文件安装
    pub fn installFromFile(self: *ExtensionManager, path: []const u8) !void;
    
    /// 加载所有已启用的 Extensions
    pub fn loadAll(self: *ExtensionManager) !void;
    
    /// 获取 Extension
    pub fn get(self: *ExtensionManager, id: []const u8) ?*Extension;
    
    pub fn deinit(self: *ExtensionManager) void;
};
```

**需要创建的文件**:
- [ ] `src/extension/api.zig` - Extension API 定义
- [ ] `src/extension/runtime.zig` - WASM 运行时
- [ ] `src/extension/manager.zig` - Extension 管理
- [ ] `src/extension/loader.zig` - 加载器
- [ ] `src/extension/sandbox.zig` - 沙箱

**需要修改的文件**:
- [ ] `src/agent/agent.zig` - 集成 Extension 工具
- [ ] `src/tui/root.zig` - 集成 Extension UI
- [ ] `src/cli/root.zig` - 添加 Extension 命令

**验收标准**:
- [ ] 可以加载 WASM Extension
- [ ] Extension 可以注册工具
- [ ] Extension 可以注册命令
- [ ] Extension 可以监听事件
- [ ] 沙箱限制文件访问
- [ ] 提供 Rust/TypeScript SDK 示例
- [ ] 文档完整
- [ ] 编译通过

**依赖**:
- Wasmtime 或其他 WASM 运行时
- TASK-REF-003-simplify-memory-system
- TASK-BUG-013-fix-page-allocator-abuse

**阻塞**:
- 高级功能扩展

**笔记**:
Extension 系统是简化架构后的核心差异化功能。参考 Pi-Mono 的 Extension 系统设计。
