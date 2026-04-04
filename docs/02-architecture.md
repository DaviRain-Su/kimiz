# Architecture — kimiz 架构设计

**版本**: 0.1.0  
**日期**: 2026-04-04  
**状态**: 草稿  
**依赖**: [01-prd.md](./01-prd.md)

---

## 1. 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                        kimiz CLI                            │
│                    (src/main.zig - REPL)                    │
└─────────────────────────┬───────────────────────────────────┘
                          │ uses
┌─────────────────────────▼───────────────────────────────────┐
│                    kimiz-agent                              │
│              (src/agent/ - Agent 状态机)                    │
│  Agent { state, messages, tools, event_emitter }            │
└─────────────────────────┬───────────────────────────────────┘
                          │ uses
┌─────────────────────────▼───────────────────────────────────┐
│                     kimiz-ai                                │
│             (src/ai/ - 统一 LLM API 层)                    │
│                                                             │
│  ┌──────────────┐  ┌───────────────┐  ┌──────────────────┐ │
│  │   types.zig  │  │  stream.zig   │  │   models.zig     │ │
│  │ (数据类型)   │  │ (流式 API)    │  │ (模型注册表)     │ │
│  └──────────────┘  └───────────────┘  └──────────────────┘ │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                  providers/                          │  │
│  │  ┌──────────┐  ┌───────────┐  ┌──────────────────┐  │  │
│  │  │ openai/  │  │anthropic/ │  │    google/       │  │  │
│  │  │(complete)│  │(complete) │  │   (complete)     │  │  │
│  │  └──────────┘  └───────────┘  └──────────────────┘  │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────┬───────────────────────────────────┘
                          │ uses
┌─────────────────────────▼───────────────────────────────────┐
│                      http.zig                               │
│              (std.http.Client 封装层)                       │
│         TLS + SSE parsing + retry logic                     │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. 模块划分

### 2.1 `src/ai/` — AI API 层

```
src/ai/
├── root.zig          # 模块入口，re-export 公共 API
├── types.zig         # 所有核心数据类型定义
├── models.zig        # 模型注册表 + getModel()
├── stream.zig        # stream()/complete() 顶层调度
├── sse.zig           # SSE 解析器（text/event-stream）
├── json_utils.zig    # JSON 序列化/反序列化工具函数
└── providers/
    ├── openai.zig    # OpenAI Completions API 实现
    ├── anthropic.zig # Anthropic Messages API 实现
    └── google.zig    # Google Generative AI REST API 实现
```

**关键职责**:
- 定义统一的 `Context`、`Message`、`AssistantMessage`、`Tool` 类型
- 每个 Provider 实现 `stream()` 和 `complete()` 函数
- SSE 解析器处理流式 HTTP 响应
- 模型注册表维护支持的 Provider/Model 列表及定价信息

### 2.2 `src/agent/` — Agent 运行时

```
src/agent/
├── root.zig          # 模块入口
├── agent.zig         # Agent 主结构体 + prompt()/continue()
├── events.zig        # AgentEvent 类型定义
└── tool.zig          # AgentTool 定义 + 执行逻辑
```

**关键职责**:
- 管理消息历史（动态 ArrayList）
- 实现 `prompt()` → LLM 调用 → tool 执行 → 再次调用 的循环
- 通过回调函数 emit 事件（不使用 async/await，使用同步回调）
- 提供 `beforeToolCall` hook 用于拦截

### 2.3 `src/http.zig` — HTTP 封装

```
src/http.zig          # std.http.Client 封装
                      # - TLS 连接管理
                      # - 请求/响应封装
                      # - 流式响应逐行读取
```

**关键职责**:
- 管理 `std.http.Client` 生命周期
- 提供 `post_json()` 用于非流式请求
- 提供 `post_stream()` 用于流式 SSE 请求
- 统一 HTTP 错误类型

### 2.4 `src/main.zig` — CLI REPL

```
src/main.zig          # 命令行入口
                      # - 解析命令行参数（一次性提问）
                      # - 创建 Agent，配置 Provider
                      # - 打印流式输出
```

---

## 3. 数据流

### 3.1 非流式调用流程

```
用户代码
  │
  ├─ ai.complete(model, context) 
  │     │
  │     ├─ providers/openai.complete()
  │     │     │
  │     │     ├─ 序列化 Context → JSON payload
  │     │     ├─ http.post_json(url, headers, body)
  │     │     │     └─ std.http.Client.fetch()
  │     │     ├─ 解析 JSON response → AssistantMessage
  │     │     └─ return AssistantMessage
  │     └─ return AssistantMessage
  │
  └─ 使用 AssistantMessage
```

### 3.2 流式调用流程

```
用户代码
  │
  ├─ ai.stream(model, context, callback)
  │     │
  │     ├─ providers/openai.stream()
  │     │     │
  │     │     ├─ 序列化 Context → JSON payload (stream: true)
  │     │     ├─ http.post_stream(url, headers, body)
  │     │     │     └─ 返回可迭代的 Reader
  │     │     ├─ sse.parse_line(line) → AssistantMessageEvent
  │     │     │     ├─ text_delta → callback(event)
  │     │     │     ├─ toolcall_delta → callback(event)
  │     │     │     └─ done → callback(event), return AssistantMessage
  │     │     └─ return AssistantMessage
  │     └─ return AssistantMessage
  │
  └─ 使用 AssistantMessage
```

### 3.3 Agent 循环流程

```
agent.prompt(user_text)
  │
  ├─ emit(agent_start)
  ├─ 添加 UserMessage 到 messages
  │
  └─ loop:
       ├─ emit(turn_start)
       ├─ ai.stream(model, context, handler)
       │     ├─ emit(message_start)
       │     ├─ emit(message_update) × N  ← 每个 delta
       │     └─ emit(message_end)
       ├─ 添加 AssistantMessage 到 messages
       │
       ├─ if stopReason == "toolUse":
       │     for each toolCall:
       │       ├─ emit(tool_execution_start)
       │       ├─ tool.execute(args) → result
       │       ├─ emit(tool_execution_end)
       │       └─ 添加 ToolResultMessage 到 messages
       │     continue loop
       │
       └─ else: break loop
  │
  └─ emit(agent_end)
```

---

## 4. 内存管理策略

### 原则
- **调用方提供 Allocator**：所有公共函数接受 `std.mem.Allocator`
- **Arena 模式用于请求**：每次 LLM 调用使用 `std.heap.ArenaAllocator`，完成后释放所有临时分配
- **消息历史归调用方**：`Agent.messages` 的内存由 Agent 自己管理，Agent.deinit() 释放
- **字符串切片原则**：返回的字符串为 `[]const u8`，生命周期与对应 Arena 绑定

### 生命周期示例

```zig
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
defer _ = gpa.deinit();
const allocator = gpa.allocator();

var agent = try Agent.init(allocator, .{
    .system_prompt = "You are helpful.",
    .model = models.getModel(.openai, "gpt-4o-mini"),
});
defer agent.deinit();

try agent.prompt("Hello", handler_fn);
```

---

## 5. 错误处理策略

```zig
pub const AiError = error{
    // HTTP 层
    HttpConnectionFailed,
    HttpRequestFailed,
    HttpResponseReadFailed,
    // API 层
    ApiAuthenticationFailed,    // 401
    ApiRateLimitExceeded,       // 429
    ApiServerError,             // 5xx
    ApiUnexpectedResponse,
    // 解析层
    JsonParseFailed,
    SseFormatInvalid,
    // 配置层
    ApiKeyNotFound,
    ProviderNotSupported,
    ModelNotFound,
};
```

所有 IO 操作返回 `!T`（error union），调用方自行处理或传播。

---

## 6. Provider 接口设计

每个 Provider 模块导出统一接口：

```zig
// providers/openai.zig
pub fn complete(
    allocator: std.mem.Allocator,
    model: *const Model,
    context: Context,
    options: StreamOptions,
) !AssistantMessage

pub fn stream(
    allocator: std.mem.Allocator,
    model: *const Model,
    context: Context,
    options: StreamOptions,
    callback: *const fn (event: AssistantMessageEvent) void,
) !AssistantMessage
```

通过函数指针组成 Provider 虚表（vtable）：

```zig
pub const Provider = struct {
    complete_fn: *const fn(...) !AssistantMessage,
    stream_fn:   *const fn(...) !AssistantMessage,
};
```

---

## 7. 文件结构（最终）

```
kimiz/
├── build.zig
├── build.zig.zon
├── docs/
│   ├── 01-prd.md
│   ├── 02-architecture.md
│   ├── 03-technical-spec.md
│   ├── 04-task-breakdown.md
│   ├── 05-test-spec.md
│   ├── 06-implementation-log.md
│   └── 07-review-report.md
└── src/
    ├── main.zig              # CLI 入口
    ├── root.zig              # 库入口（re-export）
    ├── http.zig              # HTTP 客户端封装
    ├── ai/
    │   ├── root.zig
    │   ├── types.zig
    │   ├── models.zig
    │   ├── stream.zig
    │   ├── sse.zig
    │   ├── json_utils.zig
    │   └── providers/
    │       ├── openai.zig
    │       ├── anthropic.zig
    │       └── google.zig
    └── agent/
        ├── root.zig
        ├── agent.zig
        ├── events.zig
        └── tool.zig
```

---

## 4. 技术栈

### 4.1 核心依赖

| 类别 | 技术/库 | 版本 | 说明 |
|------|---------|------|------|
| **语言** | Zig | 0.15.2 | 主开发语言 |
| **标准库** | std | 内置 | HTTP, JSON, 线程, 文件 I/O |

### 4.2 第三方库

基于 [awesome-zig](https://github.com/zigcc/awesome-zig) 的评估，选择以下库：

#### 必选项（核心功能）

| 库名 | 用途 | 来源 | 选择理由 |
|------|------|------|----------|
| **libvaxis** | TUI 界面 | rockorager/libvaxis | 现代 TUI 库，支持图像、鼠标、动画 |
| **libxev** | 异步运行时 | mitchellh/libxev | 跨平台事件循环，社区标准 |
| **zig-clap** | CLI 参数解析 | Hejsil/zig-clap | 社区最流行，简单易用 |
| **nexlog** | 日志 | chrischtel/nexlog | 生产级，支持文件轮转、彩色输出 |

#### 可选项（根据需求）

| 库名 | 用途 | 来源 | 使用场景 |
|------|------|------|----------|
| **zimdjson** | 高性能 JSON | ezequielramis/zimdjson | 需要解析大量 JSON 时 |
| **zig-yaml** | YAML 解析 | kubkon/zig-yaml | 配置文件使用 YAML 时 |
| **tomlz** | TOML 解析 | mattyhall/tomlz | 配置文件使用 TOML 时 |
| **csv-zero** | CSV 处理 | peymanmortazavi/csv-zero | 需要处理 CSV 数据时 |
| **zeit** | 时间处理 | rockorager/zeit | 需要时区支持时 |
| **zg** | Unicode 文本 | atman/zg | 需要完整 Unicode 支持时 |
| **zig-regex** | 正则表达式 | tiehuis/zig-regex | 需要复杂模式匹配时 |
| **glob.zig** | Glob 匹配 | xcaeser/glob.zig | 需要文件路径模式匹配时 |

### 4.3 技术选择理由

#### 为什么使用 Zig 标准库？

| 功能 | 标准库支持 | 说明 |
|------|-----------|------|
| HTTP Client | ✅ `std.http.Client` | 0.15+ 已很完善，支持 HTTPS/TLS |
| JSON | ✅ `std.json` | 基础解析和序列化已足够 |
| 线程 | ✅ `std.Thread` | 原生线程支持 |
| 文件 I/O | ✅ `std.fs` | 跨平台文件操作 |
| 时间 | ✅ `std.time` | 基础时间处理 |

**原则**: 优先使用标准库，仅在标准库不满足需求时引入第三方库

#### 为什么使用这些第三方库？

**libvaxis vs 纯 std 实现**
| 特性 | libvaxis | 纯 std 实现 |
|------|----------|-------------|
| 现代终端支持 | ✅ Kitty, WezTerm, iTerm2 | ⚠️ 需自行实现 |
| 图像显示 | ✅ Kitty graphics protocol | ❌ 不支持 |
| 鼠标事件 | ✅ 完整支持 | ⚠️ 部分支持 |
| 动画/刷新 | ✅ 优化过的渲染循环 | ⚠️ 需自行优化 |
| 开发成本 | 低（直接使用） | 高（数周工作量） |

**libxev vs 标准库线程**
| 特性 | libxev | std.Thread |
|------|--------|-----------|
| 异步 IO | ✅ io_uring/epoll/kqueue | ❌ 阻塞 IO |
| 事件循环 | ✅ 内置 | ❌ 需自行实现 |
| 性能 | ✅ 高（零拷贝） | 一般 |
| 复杂度 | 中等 | 低 |

**zig-clap vs 其他 CLI 库**
| 库 | 优点 | 缺点 |
|----|------|------|
| zig-clap | 社区最流行，文档完善 | 功能较基础 |
| zig-args | 基于结构体，声明式 | 功能较少 |
| yazap | 功能丰富，支持子命令 | 学习曲线陡峭 |

### 4.4 构建配置

```zig
// build.zig.zon
.{
    .name = "kimiz",
    .version = "0.1.0",
    .dependencies = .{
        // 核心依赖
        .vaxis = .{
            .url = "https://github.com/rockorager/libvaxis/archive/refs/tags/v0.1.0.tar.gz",
            .hash = "...",
        },
        .libxev = .{
            .url = "https://github.com/mitchellh/libxev/archive/refs/tags/v0.1.0.tar.gz",
            .hash = "...",
        },
        .clap = .{
            .url = "https://github.com/Hejsil/zig-clap/archive/refs/tags/v0.10.0.tar.gz",
            .hash = "...",
        },
        .nexlog = .{
            .url = "https://github.com/chrischtel/nexlog/archive/refs/tags/v0.1.0.tar.gz",
            .hash = "...",
        },
        
        // 可选依赖（根据需求启用）
        // .zimdjson = .{ ... },
        // .yaml = .{ ... },
        // .tomlz = .{ ... },
        // .csv = .{ ... },
        // .zeit = .{ ... },
        // .zg = .{ ... },
        // .regex = .{ ... },
        // .glob = .{ ... },
    },
}
```

### 4.5 依赖管理策略

**MVP 阶段（最小依赖）**:
```
必选:
├── libvaxis (TUI)
├── libxev (异步运行时)
├── zig-clap (CLI)
└── nexlog (日志)
```

**完整功能阶段（按需添加）**:
```
可选:
├── zimdjson (高性能 JSON)
├── zig-yaml (YAML 配置)
├── tomlz (TOML 配置)
├── csv-zero (CSV 处理)
├── zeit (时间处理)
├── zg (Unicode)
├── zig-regex (正则)
└── glob.zig (Glob 匹配)
```

**原则**:
1. 优先使用 Zig 标准库
2. 仅在标准库不满足需求时引入第三方库
3. 每个引入的库都需要明确的使用场景
4. 保持依赖数量最小化

---

## 验收标准（进入 Phase 3 的门槛）

- [ ] 模块划分清晰，每个模块职责单一
- [ ] 数据流图覆盖所有主要场景（非流式/流式/Agent 循环）
- [ ] 内存管理策略明确
- [ ] 错误类型完整
- [ ] Provider 接口统一可扩展
- [ ] 文件结构已确定
