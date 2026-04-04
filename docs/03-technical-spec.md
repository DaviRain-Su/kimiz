# Technical Spec — kimiz 技术规格

**版本**: 0.1.0  
**日期**: 2026-04-04  
**状态**: 草稿  
**依赖**: [02-architecture.md](./02-architecture.md)

> ⚠️ 本文档是代码的契约。实现必须与规格 100% 一致。不一致时先修改规格。

---

## 目录

1. [常量定义](#1-常量定义)
2. [错误类型](#2-错误类型)
3. [核心数据类型 (ai/types.zig)](#3-核心数据类型)
4. [模型注册表 (ai/models.zig)](#4-模型注册表)
5. [HTTP 封装 (http.zig)](#5-http-封装)
6. [SSE 解析器 (ai/sse.zig)](#6-sse-解析器)
7. [JSON 工具 (ai/json_utils.zig)](#7-json-工具)
8. [OpenAI Provider (ai/providers/openai.zig)](#8-openai-provider)
9. [Anthropic Provider (ai/providers/anthropic.zig)](#9-anthropic-provider)
10. [Google Provider (ai/providers/google.zig)](#10-google-provider)
11. [顶层 AI API (ai/stream.zig)](#11-顶层-ai-api)
12. [Kimi Provider (ai/providers/kimi.zig)](#12-kimi-provider)
13. [Fireworks AI Provider (ai/providers/fireworks.zig)](#13-fireworks-ai-provider)
14. [Agent 运行时 (agent/agent.zig)](#14-agent-运行时)
15. [Agent 事件系统 (agent/events.zig)](#15-agent-事件系统)
16. [Agent 工具定义 (agent/tool.zig)](#16-agent-工具定义)
17. [CLI 入口 (main.zig)](#17-cli-入口)
18. [TUI (tui/*.zig)](#18-tui-terminal-user-interface)
19. [Build 配置 (build.zig)](#19-build-配置)
20. [边界条件](#20-边界条件)

---

## 1. 常量定义

```zig
// src/ai/types.zig 或 src/constants.zig
pub const MAX_CONTENT_BLOCKS = 64;       // 单条 AssistantMessage 最多内容块数
pub const MAX_TOOL_ARGS_BYTES = 65536;   // 工具参数 JSON 最大字节数 (64KB)
pub const MAX_MESSAGE_TEXT_BYTES = 1 << 20; // 单条消息文本最大字节数 (1MB)
pub const MAX_MESSAGES = 4096;           // 上下文最多消息数
pub const MAX_TOOLS = 64;               // 最多工具数
pub const SSE_LINE_BUF_SIZE = 65536;    // SSE 单行最大字节数
pub const HTTP_BUF_SIZE = 65536;        // HTTP 读缓冲区大小
pub const DEFAULT_MAX_TOKENS = 8192;    // 默认最大输出 token 数
pub const DEFAULT_TEMPERATURE: f32 = 1.0;

// API 相关
pub const OPENAI_BASE_URL = "https://api.openai.com";
pub const ANTHROPIC_BASE_URL = "https://api.anthropic.com";
pub const GOOGLE_BASE_URL = "https://generativelanguage.googleapis.com";
pub const KIMI_BASE_URL = "https://api.moonshot.cn";
pub const KIMI_CODE_BASE_URL = "https://api.kimi.com/coding";
pub const FIREWORKS_BASE_URL = "https://api.fireworks.ai/inference/v1";
pub const ANTHROPIC_API_VERSION = "2023-06-01";

// 重复检测配置（针对 Fireworks Kimi 2.5 Turbo）
pub const REPETITION_DETECTION_ENABLED = true;
pub const REPETITION_WINDOW_SIZE = 5;      // 检查最近 5 个 delta
pub const REPETITION_THRESHOLD = 0.8;       // 80% 相似度阈值
pub const REPETITION_MAX_CONSECUTIVE = 3;   // 最多允许 3 次连续重复
```

---

## 2. 错误类型

```zig
// src/ai/types.zig
pub const AiError = error{
    // HTTP 层
    HttpConnectionFailed,
    HttpTlsFailed,
    HttpRequestFailed,
    HttpResponseReadFailed,
    HttpRedirectFailed,
    // API 层
    ApiAuthenticationFailed,    // HTTP 401
    ApiPermissionDenied,        // HTTP 403
    ApiNotFound,                // HTTP 404
    ApiRateLimitExceeded,       // HTTP 429
    ApiServerError,             // HTTP 5xx
    ApiUnexpectedResponse,      // 2xx 但响应格式不符预期
    // 解析层
    JsonParseFailed,
    JsonFieldMissing,
    JsonFieldTypeError,
    SseFormatInvalid,           // SSE 行格式非法
    SseDoneReceived,            // [DONE] 信号（内部用，非用户可见）
    // 配置层
    ApiKeyNotFound,             // 环境变量未设置
    ProviderNotSupported,       // 未知 provider
    ModelNotFound,              // 模型 ID 不在注册表
    // 运行时
    OutOfMemory,
    Aborted,
    ToolExecutionFailed,
    ToolNotFound,
};
```

---

## 3. 核心数据类型

### 3.1 Provider & API 标识符

```zig
// src/ai/types.zig
pub const KnownProvider = enum {
    openai,
    anthropic,
    google,
    kimi,           // Moonshot AI Kimi
    fireworks,      // Fireworks AI
    openrouter,     // MVP 后期支持
    // ... 其他 provider 后续扩展
};

pub const KnownApi = enum {
    @"openai-completions",
    @"anthropic-messages",
    @"google-generative-ai",
    @"kimi-code",           // Kimi Code 专用 API
};

pub const Provider = union(enum) {
    known: KnownProvider,
    custom: []const u8,  // 自定义 provider 名称（借用字符串，调用方管理生命周期）
};

pub const Api = union(enum) {
    known: KnownApi,
    custom: []const u8,
};
```

### 3.2 ThinkingLevel

```zig
pub const ThinkingLevel = enum {
    off,
    minimal,
    low,
    medium,
    high,
    xhigh,
};
```

### 3.3 StopReason

```zig
pub const StopReason = enum {
    stop,
    length,
    tool_use,
    @"error",
    aborted,
};
```

### 3.4 内容块类型

```zig
pub const TextContent = struct {
    type: enum { text } = .text,
    text: []const u8,               // 归 Arena 所有
};

pub const ThinkingContent = struct {
    type: enum { thinking } = .thinking,
    thinking: []const u8,           // 归 Arena 所有
    thinking_signature: ?[]const u8 = null,
    redacted: bool = false,
};

/// 图片内容 - 多模态支持
pub const ImageContent = struct {
    type: enum { image } = .image,
    data: []const u8,               // base64 编码的图片数据，归 Arena 所有
    mime_type: []const u8,          // 如 "image/png", "image/jpeg", "image/webp"
    /// 可选：图片 URL（如果通过 URL 提供）
    url: ?[]const u8 = null,
    /// 可选：图片尺寸信息
    width: ?u32 = null,
    height: ?u32 = null,
};

/// 图片 URL 内容 - 某些 Provider 支持直接传 URL
pub const ImageUrlContent = struct {
    type: enum { image_url } = .image_url,
    url: []const u8,                // 图片 URL
    detail: ImageDetail = .auto,    // 图片 detail 级别
};

pub const ImageDetail = enum {
    auto,       // 自动选择
    low,        // 低分辨率（快速、省 token）
    high,       // 高分辨率（详细分析）
};

// 工具调用
pub const ToolCall = struct {
    type: enum { tool_call } = .tool_call,
    id: []const u8,                 // provider 分配的 ID，归 Arena 所有
    name: []const u8,               // 工具名，归 Arena 所有
    arguments: std.json.Value,      // 已解析的 JSON 对象，归 Arena 所有
    // 流式过程中的原始参数字符串（非公开字段，仅流式解析时使用）
    _partial_args: ?[]u8 = null,    // 可变切片，流式累积用
};

pub const AssistantContentBlock = union(enum) {
    text: TextContent,
    thinking: ThinkingContent,
    tool_call: ToolCall,
    // 注意：Assistant 通常不直接返回图片，但某些模型可能返回
    image: ImageContent,
};

pub const UserContentBlock = union(enum) {
    text: TextContent,
    image: ImageContent,
    image_url: ImageUrlContent,
};
```

### 3.5 Usage（token 用量 & 成本）

```zig
pub const Usage = struct {
    input: u64 = 0,
    output: u64 = 0,
    cache_read: u64 = 0,
    cache_write: u64 = 0,
    total_tokens: u64 = 0,
    cost: struct {
        input: f64 = 0.0,       // USD
        output: f64 = 0.0,
        cache_read: f64 = 0.0,
        cache_write: f64 = 0.0,
        total: f64 = 0.0,
    } = .{},
};
```

### 3.6 Message 类型

```zig
pub const UserMessage = struct {
    role: enum { user } = .user,
    /// 简单文本场景：content_text 非 null，content_blocks 为 null
    /// 多媒体场景：content_blocks 非 null，content_text 为 null
    content_text: ?[]const u8 = null,
    content_blocks: ?[]const UserContentBlock = null,
    timestamp: i64,                 // Unix 毫秒时间戳
};

pub const AssistantMessage = struct {
    role: enum { assistant } = .assistant,
    content: []AssistantContentBlock,   // 长度 0..MAX_CONTENT_BLOCKS，归 Arena 所有
    api: KnownApi,
    provider: []const u8,               // 归 Arena 所有
    model: []const u8,                  // 归 Arena 所有
    response_id: ?[]const u8 = null,
    usage: Usage = .{},
    stop_reason: StopReason = .stop,
    error_message: ?[]const u8 = null,
    timestamp: i64,
};

pub const ToolResultMessage = struct {
    role: enum { tool_result } = .tool_result,
    tool_call_id: []const u8,           // 归 Arena 所有
    tool_name: []const u8,              // 归 Arena 所有
    content: []const UserContentBlock,  // 归 Arena 所有
    is_error: bool,
    timestamp: i64,
};

pub const Message = union(enum) {
    user: UserMessage,
    assistant: AssistantMessage,
    tool_result: ToolResultMessage,
};
```

### 3.7 Tool（工具定义）

```zig
pub const Tool = struct {
    name: []const u8,           // 归调用方所有（生命周期 ≥ Tool 本身）
    description: []const u8,    // 同上
    /// JSON Schema 字符串，用于传给 LLM API
    /// 格式：{"type":"object","properties":{...},"required":[...]}
    parameters_json: []const u8,
};
```

### 3.8 Context

```zig
pub const Context = struct {
    system_prompt: ?[]const u8 = null,  // 归调用方所有
    messages: []const Message,           // 归调用方所有
    tools: []const Tool = &.{},          // 归调用方所有
};
```

### 3.9 Model（模型定义）

```zig
pub const ModelCost = struct {
    input: f64,      // USD / 百万 token
    output: f64,
    cache_read: f64,
    cache_write: f64,
};

pub const Model = struct {
    id: []const u8,             // 归全局注册表所有（静态字符串）
    name: []const u8,           // 同上
    api: KnownApi,
    provider: KnownProvider,
    base_url: []const u8,       // 静态字符串
    reasoning: bool,
    supports_vision: bool,
    cost: ModelCost,
    context_window: u32,
    max_tokens: u32,
};
```

### 3.10 StreamOptions

```zig
pub const StreamOptions = struct {
    temperature: ?f32 = null,
    max_tokens: ?u32 = null,
    api_key: ?[]const u8 = null,    // 归调用方所有；null 时从环境变量读取
    thinking_level: ThinkingLevel = .off,
};
```

---

## 4. 模型注册表

### 4.1 接口

```zig
// src/ai/models.zig
const model_table: []const Model = &.{
    // OpenAI
    .{
        .id = "gpt-4o",
        .name = "GPT-4o",
        .api = .@"openai-completions",
        .provider = .openai,
        .base_url = OPENAI_BASE_URL,
        .reasoning = false,
        .supports_vision = true,
        .cost = .{ .input = 2.5, .output = 10.0, .cache_read = 1.25, .cache_write = 0 },
        .context_window = 128000,
        .max_tokens = 16384,
    },
    .{
        .id = "gpt-4o-mini",
        .name = "GPT-4o Mini",
        .api = .@"openai-completions",
        .provider = .openai,
        .base_url = OPENAI_BASE_URL,
        .reasoning = false,
        .supports_vision = true,
        .cost = .{ .input = 0.15, .output = 0.6, .cache_read = 0.075, .cache_write = 0 },
        .context_window = 128000,
        .max_tokens = 16384,
    },
    .{
        .id = "o4-mini",
        .name = "o4-mini",
        .api = .@"openai-completions",
        .provider = .openai,
        .base_url = OPENAI_BASE_URL,
        .reasoning = true,
        .supports_vision = true,
        .cost = .{ .input = 1.1, .output = 4.4, .cache_read = 0.275, .cache_write = 0 },
        .context_window = 200000,
        .max_tokens = 100000,
    },
    // Anthropic
    .{
        .id = "claude-haiku-4-20250514",
        .name = "Claude Haiku 4",
        .api = .@"anthropic-messages",
        .provider = .anthropic,
        .base_url = ANTHROPIC_BASE_URL,
        .reasoning = false,
        .supports_vision = true,
        .cost = .{ .input = 0.8, .output = 4.0, .cache_read = 0.08, .cache_write = 1.0 },
        .context_window = 200000,
        .max_tokens = 16000,
    },
    .{
        .id = "claude-sonnet-4-20250514",
        .name = "Claude Sonnet 4",
        .api = .@"anthropic-messages",
        .provider = .anthropic,
        .base_url = ANTHROPIC_BASE_URL,
        .reasoning = false,
        .supports_vision = true,
        .cost = .{ .input = 3.0, .output = 15.0, .cache_read = 0.3, .cache_write = 3.75 },
        .context_window = 200000,
        .max_tokens = 64000,
    },
    // Google
    .{
        .id = "gemini-2.0-flash",
        .name = "Gemini 2.0 Flash",
        .api = .@"google-generative-ai",
        .provider = .google,
        .base_url = GOOGLE_BASE_URL,
        .reasoning = false,
        .supports_vision = true,
        .cost = .{ .input = 0.1, .output = 0.4, .cache_read = 0.025, .cache_write = 0 },
        .context_window = 1048576,
        .max_tokens = 8192,
    },
    .{
        .id = "gemini-2.5-pro",
        .name = "Gemini 2.5 Pro",
        .api = .@"google-generative-ai",
        .provider = .google,
        .base_url = GOOGLE_BASE_URL,
        .reasoning = true,
        .supports_vision = true,
        .cost = .{ .input = 1.25, .output = 10.0, .cache_read = 0.31, .cache_write = 0 },
        .context_window = 1048576,
        .max_tokens = 65536,
    },
    // Kimi (Moonshot AI) - 标准 API
    .{
        .id = "kimi-k2-5",
        .name = "Kimi K2.5",
        .api = .@"openai-completions",  // 使用 OpenAI 兼容 API
        .provider = .kimi,
        .base_url = "https://api.moonshot.cn",
        .reasoning = true,
        .supports_vision = true,
        .cost = .{ .input = 0.5, .output = 2.0, .cache_read = 0.1, .cache_write = 0 },
        .context_window = 256000,
        .max_tokens = 8192,
    },
    .{
        .id = "kimi-k2",
        .name = "Kimi K2",
        .api = .@"openai-completions",
        .provider = .kimi,
        .base_url = "https://api.moonshot.cn",
        .reasoning = true,
        .supports_vision = true,
        .cost = .{ .input = 0.3, .output = 1.2, .cache_read = 0.06, .cache_write = 0 },
        .context_window = 256000,
        .max_tokens = 8192,
    },
    // Kimi Code - Coding Agent 专用 API
    .{
        .id = "kimi-for-coding",
        .name = "Kimi for Coding",
        .api = .@"kimi-code",           // 使用 Kimi Code 专用 API
        .provider = .kimi,
        .base_url = "https://api.kimi.com/coding",
        .reasoning = true,
        .supports_vision = true,
        .cost = .{ .input = 0.5, .output = 2.0, .cache_read = 0.1, .cache_write = 0 },
        .context_window = 262144,       // 256K
        .max_tokens = 32768,
    },
    // Fireworks AI - 提供加速版 Kimi 2.5 Turbo
    .{
        .id = "accounts/fireworks/routers/kimi-k2p5-turbo",
        .name = "Kimi K2.5 Turbo (Fireworks)",
        .api = .@"openai-completions",  // Fireworks 使用 OpenAI 兼容 API
        .provider = .fireworks,
        .base_url = "https://api.fireworks.ai/inference/v1",
        .reasoning = true,
        .supports_vision = true,
        .cost = .{ .input = 0.4, .output = 1.6, .cache_read = 0.08, .cache_write = 0 },
        .context_window = 256000,
        .max_tokens = 8192,
    },
};

/// 按 provider + model_id 查找模型
/// 返回指向静态表格的指针，永远有效
pub fn getModel(provider: KnownProvider, id: []const u8) ?*const Model

/// 获取某 provider 下的所有模型（只读切片）
pub fn getModelsByProvider(provider: KnownProvider) []const Model

/// 计算成本（直接修改 Usage.cost 字段）
/// 公式：cost_input = (model.cost.input / 1_000_000.0) * usage.input
pub fn calculateCost(model: *const Model, usage: *Usage) void
```

---

## 5. HTTP 封装

### 5.1 数据结构

```zig
// src/http.zig
pub const HttpClient = struct {
    allocator: std.mem.Allocator,
    client: std.http.Client,
    
    pub fn init(allocator: std.mem.Allocator) HttpClient
    pub fn deinit(self: *HttpClient) void
    
    /// 发送 POST 请求，返回完整响应体（调用方负责 free）
    pub fn postJson(
        self: *HttpClient,
        arena: std.mem.Allocator,
        url: []const u8,
        headers: []const HttpHeader,
        body: []const u8,
    ) HttpError![]const u8
    
    /// 发送 POST 请求，逐行回调处理响应体（用于 SSE）
    /// callback 返回 error.SseDoneReceived 表示正常终止
    pub fn postStream(
        self: *HttpClient,
        arena: std.mem.Allocator,
        url: []const u8,
        headers: []const HttpHeader,
        body: []const u8,
        ctx: *anyopaque,
        callback: *const fn (ctx: *anyopaque, line: []const u8) anyerror!void,
    ) HttpError!void
};

pub const HttpHeader = struct {
    name: []const u8,
    value: []const u8,
};

pub const HttpError = error{
    ConnectionFailed,
    TlsFailed,
    RequestFailed,
    ResponseReadFailed,
    AuthFailed,          // 401
    PermissionDenied,    // 403
    NotFound,            // 404
    RateLimitExceeded,   // 429
    ServerError,         // 5xx
    UnexpectedStatus,    // 其他非 2xx
};
```

### 5.2 HTTP 状态码映射规则

| HTTP 状态码 | 映射到 HttpError |
|-------------|-----------------|
| 200-299 | 成功（无错误） |
| 401 | `AuthFailed` |
| 403 | `PermissionDenied` |
| 404 | `NotFound` |
| 429 | `RateLimitExceeded` |
| 500-599 | `ServerError` |
| 其他 4xx | `UnexpectedStatus` |

### 5.3 postJson 实现规范

1. 使用 `std.http.Client.fetch()` 发送请求
2. 读取完整响应体到 Arena 分配的缓冲区
3. 检查状态码，非 2xx 时映射为对应 HttpError
4. 返回响应体字节切片（生命周期 = arena）

### 5.4 postStream 实现规范

1. 使用 `std.http.Client.open()` + `send()` 发起流式请求
2. 设置 `Accept: text/event-stream`
3. 使用 `std.io.BufferedReader` 逐行读取
4. 每行调用 callback（不含末尾换行符）
5. 空行直接跳过
6. callback 返回 `error.SseDoneReceived` 时正常结束
7. 非 2xx 状态码在发起请求后立即检测并返回对应错误

---

## 6. SSE 解析器

### 6.1 SSE 格式规范

```
data: {"key":"value"}\n\n    → 数据行
data: [DONE]\n\n              → 结束信号
: keep-alive\n                → 注释行（忽略）
event: message\n              → 事件类型行（忽略，pi-mono 不使用）
\n                            → 空行（事件分隔符）
```

### 6.2 接口

```zig
// src/ai/sse.zig
/// 解析单行 SSE 数据（只处理 "data: ..." 格式）
/// 返回 data 字段的内容（不含 "data: " 前缀）
/// 如果是 [DONE] 行，返回 error.SseDoneReceived
/// 如果不是 data: 行，返回 null（表示跳过）
pub fn parseSseLine(line: []const u8) SseError!?[]const u8

pub const SseError = error{
    SseDoneReceived,
    InvalidFormat,
};
```

### 6.3 parseSseLine 逻辑

```
输入: line = "data: {\"text\":\"hello\"}"
1. if line 以 "data: " 开头：
   a. 取子串 line[6..]
   b. if 子串 == "[DONE]": return error.SseDoneReceived
   c. return 子串
2. else if line 以 ":" 开头：return null（注释）
3. else if line.len == 0：return null（空行）
4. else：return null（忽略其他字段）
```

---

## 7. JSON 工具

### 7.1 接口

```zig
// src/ai/json_utils.zig

/// 将 Context 序列化为 OpenAI /v1/chat/completions 请求体 JSON
pub fn serializeOpenAIRequest(
    arena: std.mem.Allocator,
    model: *const Model,
    context: Context,
    options: StreamOptions,
    stream: bool,
) ![]const u8

/// 将 Context 序列化为 Anthropic /v1/messages 请求体 JSON
pub fn serializeAnthropicRequest(
    arena: std.mem.Allocator,
    model: *const Model,
    context: Context,
    options: StreamOptions,
    stream: bool,
) ![]const u8

/// 将 Context 序列化为 Google Generative AI 请求体 JSON
pub fn serializeGoogleRequest(
    arena: std.mem.Allocator,
    model: *const Model,
    context: Context,
    options: StreamOptions,
    stream: bool,
) ![]const u8

/// 解析流式 JSON（处理 SSE 中的不完整 JSON）
/// 返回已解析的 Value，用于工具参数累积场景
/// 注意：不完整的 JSON 返回已解析部分（尽力而为）
pub fn parsePartialJson(
    arena: std.mem.Allocator,
    json_str: []const u8,
) !std.json.Value
```

---

## 8. OpenAI Provider

### 8.1 API 端点

```
POST {base_url}/v1/chat/completions
Content-Type: application/json
Authorization: Bearer {api_key}
```

### 8.2 请求体格式（非流式）

```json
{
  "model": "gpt-4o-mini",
  "messages": [
    {"role": "system", "content": "You are helpful."},
    {"role": "user", "content": "Hello"},
    {"role": "assistant", "content": "Hi there!"},
    {"role": "tool", "tool_call_id": "call_abc", "content": "result"},
    {"role": "assistant", "tool_calls": [
      {"id": "call_abc", "type": "function",
       "function": {"name": "get_time", "arguments": "{}"}}
    ]}
  ],
  "tools": [
    {"type": "function", "function": {
      "name": "get_time",
      "description": "Get current time",
      "parameters": {"type": "object", "properties": {}, "required": []}
    }}
  ],
  "max_tokens": 8192,
  "temperature": 1.0,
  "stream": false,
  "stream_options": null
}
```

### 8.3 请求体格式（流式）

与非流式相同，但：
```json
{
  ...
  "stream": true,
  "stream_options": {"include_usage": true}
}
```

### 8.4 响应体格式（非流式）

```json
{
  "id": "chatcmpl-abc123",
  "model": "gpt-4o-mini",
  "choices": [{
    "finish_reason": "stop",
    "message": {
      "role": "assistant",
      "content": "Hello!",
      "tool_calls": null
    }
  }],
  "usage": {
    "prompt_tokens": 10,
    "completion_tokens": 5,
    "total_tokens": 15,
    "prompt_tokens_details": {"cached_tokens": 0},
    "completion_tokens_details": {}
  }
}
```

### 8.5 流式 SSE chunk 格式

```json
{"id":"chatcmpl-abc","choices":[{"delta":{"content":"Hello"},"index":0}],"usage":null}
{"id":"chatcmpl-abc","choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_xyz","type":"function","function":{"name":"get_time","arguments":""}}]},"index":0}]}
{"id":"chatcmpl-abc","choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\"tz\":\"UTC\"}"}}]},"index":0}]}
{"id":"chatcmpl-abc","choices":[{"delta":{},"finish_reason":"tool_calls","index":0}],"usage":{"prompt_tokens":20,"completion_tokens":10,"total_tokens":30}}
```

### 8.6 finish_reason → StopReason 映射

| finish_reason | StopReason |
|---------------|------------|
| "stop" | `.stop` |
| "length" | `.length` |
| "tool_calls" | `.tool_use` |
| "content_filter" | `.@"error"` |
| null | `.stop`（流式中间 chunk） |

### 8.7 函数接口

```zig
// src/ai/providers/openai.zig

/// 非流式完整请求
/// arena 用于分配响应相关内存，AssistantMessage 生命周期 = arena
pub fn complete(
    allocator: std.mem.Allocator,  // 长期分配（HTTP client）
    arena: std.mem.Allocator,      // 请求级分配（响应数据）
    http_client: *HttpClient,
    model: *const Model,
    context: Context,
    options: StreamOptions,
) AiError!AssistantMessage

/// 流式请求
/// callback 在每个 AssistantMessageEvent 时被同步调用
/// AssistantMessage 生命周期 = arena
pub fn stream(
    allocator: std.mem.Allocator,
    arena: std.mem.Allocator,
    http_client: *HttpClient,
    model: *const Model,
    context: Context,
    options: StreamOptions,
    ctx: *anyopaque,
    callback: EventCallback,
) AiError!AssistantMessage

pub const EventCallback = *const fn (
    ctx: *anyopaque,
    event: AssistantMessageEvent,
) void;
```

### 8.8 Message → OpenAI messages 转换规则

| kimiz Message | OpenAI role | OpenAI content 格式 |
|---------------|-------------|---------------------|
| `UserMessage`（文本） | "user" | string |
| `UserMessage`（块） | "user" | array of content parts |
| `UserMessage`（含图片） | "user" | array with image_url |
| `AssistantMessage`（纯文本） | "assistant" | string |
| `AssistantMessage`（含 ToolCall） | "assistant" | null，tool_calls array |
| `AssistantMessage`（混合） | "assistant" | string + tool_calls |
| `ToolResultMessage` | "tool" | string（content 字段） |

系统提示以 `{"role": "system", "content": "..."}` 作为第一条消息。

#### 8.8.1 图片输入格式（OpenAI Vision）

```json
{
  "role": "user",
  "content": [
    {"type": "text", "text": "描述这张图片"},
    {
      "type": "image_url",
      "image_url": {
        "url": "data:image/png;base64,iVBORw0KGgo...",
        "detail": "auto"
      }
    }
  ]
}
```

**图片 detail 级别映射:**
| ImageDetail | OpenAI detail |
|-------------|---------------|
| `.auto` | "auto" |
| `.low` | "low" |
| `.high` | "high" |

**支持的图片格式:**
- PNG (image/png)
- JPEG (image/jpeg)
- WebP (image/webp)
- GIF (image/gif) - 非动画

**图片限制:**
- 最大 20MB
- 最大 8192x8192 像素
- 建议小于 512x512 以节省 token

---

## 9. Anthropic Provider

### 9.1 API 端点

```
POST {base_url}/v1/messages
Content-Type: application/json
x-api-key: {api_key}
anthropic-version: 2023-06-01
```

### 9.2 请求体格式

```json
{
  "model": "claude-haiku-4-20250514",
  "max_tokens": 8192,
  "system": "You are helpful.",
  "messages": [
    {"role": "user", "content": "Hello"},
    {"role": "assistant", "content": [
      {"type": "text", "text": "Hi!"},
      {"type": "tool_use", "id": "toolu_abc", "name": "get_time", "input": {}}
    ]},
    {"role": "user", "content": [
      {"type": "tool_result", "tool_use_id": "toolu_abc", "content": "12:00"}
    ]}
  ],
  "tools": [
    {"name": "get_time", "description": "Get time",
     "input_schema": {"type": "object", "properties": {}, "required": []}}
  ],
  "stream": true
}
```

### 9.3 流式 SSE 事件格式

```
data: {"type":"message_start","message":{"id":"msg_abc","model":"claude-haiku-4-20250514","usage":{"input_tokens":10}}}
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}
data: {"type":"content_block_stop","index":0}
data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":5}}
data: {"type":"message_stop"}
```

### 9.4 Anthropic 事件 → AssistantMessageEvent 映射

| Anthropic 事件 type | 触发的 AssistantMessageEvent |
|---------------------|------------------------------|
| `message_start` | `start` |
| `content_block_start` (text) | `text_start` |
| `content_block_delta` (text_delta) | `text_delta` |
| `content_block_stop` (text block) | `text_end` |
| `content_block_start` (tool_use) | `toolcall_start` |
| `content_block_delta` (input_json_delta) | `toolcall_delta` |
| `content_block_stop` (tool_use block) | `toolcall_end` |
| `content_block_start` (thinking) | `thinking_start` |
| `content_block_delta` (thinking_delta) | `thinking_delta` |
| `content_block_stop` (thinking) | `thinking_end` |
| `message_delta` (stop_reason) | 更新 stop_reason |
| `message_stop` | `done` |

### 9.5 Anthropic stop_reason → StopReason 映射

| stop_reason | StopReason |
|-------------|------------|
| "end_turn" | `.stop` |
| "max_tokens" | `.length` |
| "tool_use" | `.tool_use` |
| "stop_sequence" | `.stop` |
| null | `.stop` |

### 9.6 Message → Anthropic messages 转换规则

| kimiz Message | Anthropic role | content 格式 |
|---------------|----------------|--------------|
| `UserMessage`（文本） | "user" | string |
| `UserMessage`（块） | "user" | array content blocks |
| `AssistantMessage`（纯文本） | "assistant" | array `[{type:"text",text:"..."}]` |
| `AssistantMessage`（含 ToolCall） | "assistant" | array with tool_use blocks |
| `ToolResultMessage` | "user" | array `[{type:"tool_result",tool_use_id:"...",content:"..."}]` |

**注意**: Anthropic 使用 `"user"` role 传递工具结果，不同于 OpenAI 的 `"tool"` role。

系统提示放在 `"system"` 字段中，不放在 messages 中。

---

## 10. Google Provider

### 10.1 API 端点（非流式）

```
POST {base_url}/v1beta/models/{model_id}:generateContent?key={api_key}
Content-Type: application/json
```

### 10.2 API 端点（流式）

```
POST {base_url}/v1beta/models/{model_id}:streamGenerateContent?key={api_key}&alt=sse
Content-Type: application/json
```

### 10.3 请求体格式

```json
{
  "systemInstruction": {
    "role": "user",
    "parts": [{"text": "You are helpful."}]
  },
  "contents": [
    {"role": "user", "parts": [{"text": "Hello"}]},
    {"role": "model", "parts": [{"text": "Hi!"}]},
    {"role": "user", "parts": [
      {"functionResponse": {"name": "get_time", "response": {"result": "12:00"}}}
    ]}
  ],
  "tools": [{"functionDeclarations": [
    {"name": "get_time", "description": "Get time",
     "parameters": {"type": "OBJECT", "properties": {}, "required": []}}
  ]}],
  "generationConfig": {
    "maxOutputTokens": 8192,
    "temperature": 1.0
  }
}
```

### 10.4 流式响应格式

```json
{"candidates":[{"content":{"role":"model","parts":[{"text":"Hello"}]}}],"usageMetadata":{}}
{"candidates":[{"content":{"role":"model","parts":[{"functionCall":{"name":"get_time","args":{}}}]}}],"usageMetadata":{"promptTokenCount":10,"candidatesTokenCount":5}}
```

### 10.5 Google stop_reason → StopReason 映射

| finishReason | StopReason |
|--------------|------------|
| "STOP" | `.stop` |
| "MAX_TOKENS" | `.length` |
| "SAFETY" | `.@"error"` |
| 未设置 | `.stop` |

### 10.6 AssistantMessage → Google messages 转换规则

| kimiz Message | Google role | parts 格式 |
|---------------|-------------|-----------|
| `UserMessage`（文本） | "user" | `[{text:"..."}]` |
| `AssistantMessage`（文本） | "model" | `[{text:"..."}]` |
| `AssistantMessage`（ToolCall） | "model" | `[{functionCall:{name,args}}]` |
| `ToolResultMessage` | "user" | `[{functionResponse:{name,response}}]` |

---

## 11. 顶层 AI API

### 11.1 接口

```zig
// src/ai/stream.zig
pub const Ai = struct {
    allocator: std.mem.Allocator,
    http_client: HttpClient,

    pub fn init(allocator: std.mem.Allocator) !Ai
    pub fn deinit(self: *Ai) void

    /// 非流式请求，调用方负责 deinit arena 以释放内存
    pub fn complete(
        self: *Ai,
        arena: std.mem.Allocator,
        model: *const Model,
        context: Context,
        options: StreamOptions,
    ) AiError!AssistantMessage

    /// 流式请求，每个事件同步回调
    pub fn stream(
        self: *Ai,
        arena: std.mem.Allocator,
        model: *const Model,
        context: Context,
        options: StreamOptions,
        ctx: *anyopaque,
        callback: EventCallback,
    ) AiError!AssistantMessage
};
```

### 11.2 `complete()` 路由逻辑

```
switch model.api:
  .@"openai-completions"   → openai.complete(...)
  .@"anthropic-messages"   → anthropic.complete(...)
  .@"google-generative-ai" → google.complete(...)
  .@"kimi-code"            → kimi.completeCode(...)
  else                     → return error.ProviderNotSupported
```

### 11.3 API Key 解析顺序

```
1. options.api_key（非 null 时直接使用）
2. 环境变量（按 provider 查询）：
   openai    → OPENAI_API_KEY
   anthropic → ANTHROPIC_API_KEY
   google    → GOOGLE_API_KEY 或 GEMINI_API_KEY
   kimi      → KIMI_API_KEY 或 MOONSHOT_API_KEY
   kimi-code → KIMI_CODE_API_KEY 或 KIMI_API_KEY
   fireworks → FIREWORKS_API_KEY
3. 上述均无 → return error.ApiKeyNotFound
```

---

## 12. Kimi Provider

### 12.1 设计说明

Kimi 提供**两套 API**：

| API 类型 | 端点 | 用途 | 特性 |
|----------|------|------|------|
| **标准 Kimi API** | `https://api.moonshot.cn/v1` | 通用对话 | OpenAI 兼容 |
| **Kimi Code API** | `https://api.kimi.com/coding/v1` | **Coding Agent 专用** | 增强工具、Thinking、Plan Mode |

Kimi Code API 特有功能：
- **Thinking Mode** - 深度推理（`enable_thinking`）
- **Plan Mode** - 先规划再执行
- **YOLO Mode** - 自动批准所有工具调用
- **内置工具** - SearchWeb, FetchURL, Shell, ReadFile, WriteFile 等
- **Session 管理** - fork/undo/export/import

### 12.2 API 端点

**标准 Kimi API:**
```
POST https://api.moonshot.cn/v1/chat/completions
Authorization: Bearer {api_key}
```

**Kimi Code API:**
```
POST https://api.kimi.com/coding/v1/chat/completions
Authorization: Bearer {api_key}
```

### 12.3 模型定义

```zig
// Kimi 标准模型
.{
    .id = "kimi-k2-5",
    .name = "Kimi K2.5",
    .api = .@"openai-completions",
    .provider = .kimi,
    .base_url = "https://api.moonshot.cn",
    .reasoning = true,
    .supports_vision = true,
    .cost = .{ .input = 0.5, .output = 2.0, .cache_read = 0.1, .cache_write = 0 },
    .context_window = 256000,
    .max_tokens = 8192,
},

// Kimi Code 专用模型
.{
    .id = "kimi-for-coding",
    .name = "Kimi for Coding",
    .api = .@"kimi-code",  // 专用 API 类型
    .provider = .kimi,
    .base_url = "https://api.kimi.com/coding",
    .reasoning = true,
    .supports_vision = true,
    .cost = .{ .input = 0.5, .output = 2.0, .cache_read = 0.1, .cache_write = 0 },
    .context_window = 262144,  // 256K
    .max_tokens = 32768,
},
```

### 12.4 Kimi Code 特有参数

```zig
// src/ai/types.zig
pub const KimiCodeOptions = struct {
    // Thinking 模式
    enable_thinking: bool = false,
    thinking_budget: ?u32 = null,  // 1024, 2048, 4096, 8192, 16384
    
    // Plan Mode - 先规划再执行
    plan_mode: bool = false,
    
    // YOLO Mode - 自动批准工具调用
    yolo_mode: bool = false,
    
    // 工具配置
    enable_search: bool = true,     // SearchWeb 工具
    enable_fetch: bool = true,      // FetchURL 工具
    enable_shell: bool = true,      // Shell 工具
};

// 扩展 StreamOptions
pub const StreamOptions = struct {
    temperature: ?f32 = null,
    max_tokens: ?u32 = null,
    api_key: ?[]const u8 = null,
    thinking_level: ThinkingLevel = .off,
    kimi_code: ?KimiCodeOptions = null,  // Kimi Code 专用选项
};
```

### 12.5 Thinking Mode

Kimi Code 支持深度推理模式：

```json
{
  "model": "kimi-for-coding",
  "messages": [...],
  "enable_thinking": true,
  "thinking_budget": 4096
}
```

**ThinkingLevel 映射:**
| ThinkingLevel | enable_thinking | thinking_budget |
|---------------|-----------------|-----------------|
| `.off` | false | - |
| `.minimal` | true | 1024 |
| `.low` | true | 2048 |
| `.medium` | true | 4096 |
| `.high` | true | 8192 |
| `.xhigh` | true | 16384 |

### 12.6 Plan Mode（规划模式）

Plan Mode 下，Agent 只能使用**只读工具**来探索代码库并生成实施计划：

```zig
// src/agent/agent.zig
pub const AgentMode = enum {
    normal,     // 正常模式 - 可以执行所有工具
    plan,       // 规划模式 - 只读工具（ReadFile, Glob, Grep 等）
};

pub const AgentOptions = struct {
    system_prompt: ?[]const u8 = null,
    model: *const Model,
    mode: AgentMode = .normal,  // 新增：Agent 运行模式
    thinking_level: ThinkingLevel = .off,
    tools: []const AgentTool = &.{},
    messages: []const Message = &.{},
    before_tool_call: ?*const fn (ctx: *anyopaque, tool_call: *const ToolCall) bool = null,
    before_tool_call_ctx: *anyopaque = undefined,
};
```

**Plan Mode 工具白名单:**
- `ReadFile` - 读取文件
- `Glob` - 文件搜索
- `Grep` - 文本搜索
- `SearchWeb` - 网络搜索
- `FetchURL` - 获取网页

**非 Plan Mode 工具（需要批准）:**
- `WriteFile` - 写入文件
- `StrReplaceFile` - 替换文件内容
- `Shell` - 执行命令
- `Agent` - 子 Agent

### 12.7 YOLO Mode（自动批准模式）

YOLO Mode 下，所有工具调用自动批准，无需用户确认：

```zig
pub const AgentOptions = struct {
    // ...
    yolo_mode: bool = false,  // 自动批准所有工具调用
};
```

### 12.8 Kimi Code 内置工具

Kimi Code API 提供以下**服务器端内置工具**：

| 工具名 | 描述 | 参数 |
|--------|------|------|
| `SearchWeb` | 网络搜索 | `{"query": "搜索关键词"}` |
| `FetchURL` | 获取网页内容 | `{"url": "https://..."}` |
| `ReadFile` | 读取文件 | `{"path": "/path/to/file"}` |
| `WriteFile` | 写入文件 | `{"path": "...", "content": "..."}` |
| `StrReplaceFile` | 替换文件内容 | `{"path": "...", "old_str": "...", "new_str": "..."}` |
| `Glob` | 文件模式匹配 | `{"pattern": "**/*.zig"}` |
| `Grep` | 文本搜索 | `{"pattern": "regex", "path": "..."}` |
| `Shell` | 执行 shell 命令 | `{"command": "ls -la", "timeout": 60}` |
| `Agent` | 子 Agent 委托 | `{"prompt": "...", "tools": [...]}` |

**工具配置:**
```zig
pub const KimiCodeOptions = struct {
    enable_search: bool = true,     // 启用 SearchWeb
    enable_fetch: bool = true,      // 启用 FetchURL
    enable_shell: bool = true,      // 启用 Shell
    // ReadFile/WriteFile 等文件工具始终启用
};
```

### 12.9 Session 管理

Kimi Code 支持高级 Session 管理：

```zig
// src/agent/session.zig
pub const Session = struct {
    id: []const u8,
    messages: std.ArrayList(Message),
    created_at: i64,
    updated_at: i64,
    
    // Session 操作
    pub fn fork(self: *const Session, allocator: std.mem.Allocator) !Session;
    pub fn undo(self: *Session) !void;  // 撤销最后一次操作
    pub fn export(self: *const Session, path: []const u8) !void;
    pub fn import(allocator: std.mem.Allocator, path: []const u8) !Session;
};

// Session 管理器
pub const SessionManager = struct {
    sessions: std.StringHashMap(Session),
    current: ?*Session,
    
    pub fn new(self: *SessionManager) !*Session;
    pub fn fork(self: *SessionManager, session_id: []const u8) !*Session;
    pub fn switch(self: *SessionManager, session_id: []const u8) ?*Session;
    pub fn list(self: *const SessionManager) []const Session;
};
```

### 12.10 实现方式

```zig
// src/ai/providers/kimi.zig

/// Kimi 标准 API（OpenAI 兼容）
pub const complete = openai.complete;
pub const stream = openai.stream;

/// Kimi Code API（增强版）
pub fn completeCode(
    allocator: std.mem.Allocator,
    arena: std.mem.Allocator,
    http_client: *HttpClient,
    model: *const Model,
    context: Context,
    options: StreamOptions,
) AiError!AssistantMessage {
    // 使用 Kimi Code 端点
    // 处理 KimiCodeOptions 特有参数
    // 复用 OpenAI 解析逻辑处理响应
}

pub fn streamCode(
    allocator: std.mem.Allocator,
    arena: std.mem.Allocator,
    http_client: *HttpClient,
    model: *const Model,
    context: Context,
    options: StreamOptions,
    ctx: *anyopaque,
    callback: EventCallback,
) AiError!AssistantMessage;

/// 序列化 Kimi Code 请求
pub fn serializeKimiCodeRequest(
    arena: std.mem.Allocator,
    model: *const Model,
    context: Context,
    options: StreamOptions,
    stream: bool,
) ![]const u8 {
    // 基础 OpenAI 格式
    var json_obj = try serializeOpenAIRequestJson(arena, model, context, options, stream);
    
    // 添加 Kimi Code 特有字段
    if (options.kimi_code) |kimi_opts| {
        // enable_thinking
        // thinking_budget
        // plan_mode (通过 tools 列表控制)
        // yolo_mode (客户端处理)
    }
    
    return try std.json.stringifyAlloc(arena, json_obj, .{});
}
```

### 12.11 路由逻辑

```zig
// src/ai/stream.zig
switch (model.api) {
    .@"openai-completions" => {
        if (model.provider == .kimi and std.mem.eql(u8, model.base_url, KIMI_CODE_BASE_URL)) {
            return kimi.completeCode(...);
        }
        return openai.complete(...);
    },
    .@"kimi-code" => return kimi.completeCode(...),
    // ...
}
```

---

## 13. Fireworks AI Provider

### 13.1 设计说明

Fireworks AI 提供**加速版 Kimi 2.5 Turbo**，但存在已知的**重复生成循环**问题：

| 问题 | 描述 |
|------|------|
| **Repetition Loop** | 模型陷入无限重复，如 "Let me verify..." |
| **触发条件** | Tool use 场景、长上下文 |
| **影响** | 消耗大量 token，不执行任何操作 |

### 13.2 API 端点

```
POST https://api.fireworks.ai/inference/v1/chat/completions
Content-Type: application/json
Authorization: Bearer {api_key}
```

### 13.3 模型定义

```zig
.{
    .id = "accounts/fireworks/routers/kimi-k2p5-turbo",
    .name = "Kimi K2.5 Turbo (Fireworks)",
    .api = .@"openai-completions",
    .provider = .fireworks,
    .base_url = "https://api.fireworks.ai/inference/v1",
    .reasoning = true,
    .supports_vision = true,
    .cost = .{ .input = 0.4, .output = 1.6, .cache_read = 0.08, .cache_write = 0 },
    .context_window = 256000,
    .max_tokens = 8192,
},
```

### 13.4 重复检测机制

为了缓解 Fireworks Kimi 2.5 Turbo 的重复问题，实现客户端重复检测：

```zig
// src/ai/stream_guard.zig

pub const StreamGuard = struct {
    /// 最近生成的文本片段（滑动窗口）
    recent_deltas: std.ArrayList([]const u8),
    
    /// 重复计数
    repetition_count: u32 = 0,
    
    /// 是否启用重复检测
    enabled: bool,
    
    /// 配置参数
    config: RepetitionConfig,
    
    pub fn init(allocator: std.mem.Allocator, enabled: bool) StreamGuard {
        return .{
            .recent_deltas = std.ArrayList([]const u8).init(allocator),
            .repetition_count = 0,
            .enabled = enabled,
            .config = .{},
        };
    }
    
    pub fn deinit(self: *StreamGuard) void {
        self.recent_deltas.deinit();
    }
    
    /// 检查新的 delta 是否构成重复
    /// 返回 true 表示检测到重复
    pub fn check(self: *StreamGuard, delta: []const u8) bool {
        if (!self.enabled or delta.len < self.config.min_delta_len) {
            return false;
        }
        
        // 检查与最近 deltas 的相似度
        for (self.recent_deltas.items) |recent| {
            const similarity = calculateSimilarity(delta, recent);
            if (similarity >= self.config.threshold) {
                self.repetition_count += 1;
                if (self.repetition_count >= self.config.max_consecutive) {
                    return true;  // 检测到重复循环
                }
            }
        }
        
        // 添加到滑动窗口
        self.recent_deltas.append(delta) catch {};
        if (self.recent_deltas.items.len > self.config.window_size) {
            _ = self.recent_deltas.orderedRemove(0);
        }
        
        return false;
    }
    
    pub fn reset(self: *StreamGuard) void {
        self.recent_deltas.clearRetainingCapacity();
        self.repetition_count = 0;
    }
};

pub const RepetitionConfig = struct {
    /// 滑动窗口大小
    window_size: usize = 5,
    
    /// 相似度阈值（0.0-1.0）
    threshold: f32 = 0.8,
    
    /// 最大允许连续重复次数
    max_consecutive: u32 = 3,
    
    /// 最小检查长度（忽略过短的 delta）
    min_delta_len: usize = 10,
};

/// 计算两段文本的相似度（使用简单的 n-gram 哈希）
pub fn calculateSimilarity(a: []const u8, b: []const u8) f32 {
    if (a.len == 0 or b.len == 0) return 0.0;
    if (std.mem.eql(u8, a, b)) return 1.0;
    
    // 使用 3-gram 计算 Jaccard 相似度
    var a_grams = std.AutoHashMap(u64, void).init(std.heap.page_allocator);
    defer a_grams.deinit();
    
    var i: usize = 0;
    while (i + 3 <= a.len) : (i += 1) {
        const hash = std.hash.Crc32.hash(a[i..i+3]);
        a_grams.put(hash, {}) catch {};
    }
    
    var intersection: usize = 0;
    i = 0;
    while (i + 3 <= b.len) : (i += 1) {
        const hash = std.hash.Crc32.hash(b[i..i+3]);
        if (a_grams.contains(hash)) {
            intersection += 1;
        }
    }
    
    const union_size = a_grams.count() + (b.len - 2) - intersection;
    if (union_size == 0) return 0.0;
    
    return @as(f32, @floatFromInt(intersection)) / @as(f32, @floatFromInt(union_size));
}
```

### 13.5 重复检测错误

```zig
// src/ai/types.zig
pub const AiError = error{
    // ... 其他错误
    RepetitionDetected,     // 检测到重复生成循环
};
```

当检测到重复时：
1. 立即终止流式输出
2. 返回部分生成的 AssistantMessage
3. 在 stop_reason 中标记为 `.@"error"`
4. 在 error_message 中说明 "Repetition loop detected"

---

## 14. Agent 运行时

### 12.1 AssistantMessageEvent 类型

```zig
// src/agent/events.zig（同时也在 src/ai/types.zig 中定义）
pub const AssistantMessageEventType = enum {
    start,
    text_start,
    text_delta,
    text_end,
    thinking_start,
    thinking_delta,
    thinking_end,
    toolcall_start,
    toolcall_delta,
    toolcall_end,
    done,
    @"error",
};

pub const AssistantMessageEvent = union(AssistantMessageEventType) {
    start:          struct { partial: *const AssistantMessage },
    text_start:     struct { content_index: usize, partial: *const AssistantMessage },
    text_delta:     struct { content_index: usize, delta: []const u8, partial: *const AssistantMessage },
    text_end:       struct { content_index: usize, content: []const u8, partial: *const AssistantMessage },
    thinking_start: struct { content_index: usize, partial: *const AssistantMessage },
    thinking_delta: struct { content_index: usize, delta: []const u8, partial: *const AssistantMessage },
    thinking_end:   struct { content_index: usize, content: []const u8, partial: *const AssistantMessage },
    toolcall_start: struct { content_index: usize, partial: *const AssistantMessage },
    toolcall_delta: struct { content_index: usize, delta: []const u8, partial: *const AssistantMessage },
    toolcall_end:   struct { content_index: usize, tool_call: *const ToolCall, partial: *const AssistantMessage },
    done:           struct { reason: StopReason, message: *const AssistantMessage },
    @"error":       struct { reason: StopReason, message: *const AssistantMessage },
};
```

### 12.2 AgentEvent 类型

```zig
// src/agent/events.zig
pub const AgentEventType = enum {
    agent_start,
    agent_end,
    turn_start,
    turn_end,
    message_start,
    message_update,
    message_end,
    tool_execution_start,
    tool_execution_update,
    tool_execution_end,
};

pub const AgentEvent = union(AgentEventType) {
    agent_start:          struct {},
    agent_end:            struct { messages: []const Message },
    turn_start:           struct { turn_index: u32 },
    turn_end:             struct { message: *const AssistantMessage, tool_results: []const ToolResultMessage },
    message_start:        struct { message: *const Message },
    message_update:       struct { message: *const AssistantMessage, assistant_event: AssistantMessageEvent },
    message_end:          struct { message: *const Message },
    tool_execution_start: struct { tool_call_id: []const u8, tool_name: []const u8, args: std.json.Value },
    tool_execution_update: struct { tool_call_id: []const u8, partial_result: []const u8 },
    tool_execution_end:   struct { tool_call_id: []const u8, result: []const UserContentBlock, is_error: bool },
};
```

### 12.3 AgentState（Agent 内部状态）

```zig
// src/agent/agent.zig
pub const AgentState = struct {
    system_prompt: ?[]const u8,
    model: *const Model,
    thinking_level: ThinkingLevel,
    tools: []const AgentTool,
    messages: std.ArrayList(Message),   // 动态消息历史
};
```

### 12.4 Agent 结构体

```zig
pub const AgentOptions = struct {
    system_prompt: ?[]const u8 = null,
    model: *const Model,
    thinking_level: ThinkingLevel = .off,
    tools: []const AgentTool = &.{},
    messages: []const Message = &.{},  // 初始消息历史（复制）
    /// 工具调用前拦截钩子（null 表示不拦截）
    before_tool_call: ?*const fn (
        ctx: *anyopaque,
        tool_call: *const ToolCall,
    ) bool = null,
    before_tool_call_ctx: *anyopaque = undefined,
};

pub const Agent = struct {
    allocator: std.mem.Allocator,
    ai: *Ai,
    state: AgentState,
    /// 事件订阅者回调
    subscriber: ?*const fn (ctx: *anyopaque, event: AgentEvent) void,
    subscriber_ctx: *anyopaque,

    pub fn init(allocator: std.mem.Allocator, ai: *Ai, options: AgentOptions) !Agent
    pub fn deinit(self: *Agent) void

    /// 发送用户消息并运行 Agent 循环直到 LLM 不再调用工具
    /// arena 用于所有 LLM 响应内存，调用方在 prompt() 返回后可按需释放
    pub fn prompt(self: *Agent, arena: std.mem.Allocator, user_text: []const u8) !void

    /// 从当前状态继续（不添加用户消息，用于错误重试）
    pub fn @"continue"(self: *Agent, arena: std.mem.Allocator) !void

    /// 订阅 Agent 事件（同一时刻只支持单一订阅者）
    pub fn subscribe(
        self: *Agent,
        ctx: *anyopaque,
        callback: *const fn (ctx: *anyopaque, event: AgentEvent) void,
    ) void
};
```

### 12.5 Agent Loop 状态机

```
State: { messages: ArrayList(Message), turn_index: u32 }

prompt(user_text):
  → 创建 UserMessage { role=user, content_text=user_text, timestamp=now }
  → 追加到 state.messages
  → emit(agent_start)
  → run_loop()
  → emit(agent_end { messages: state.messages.items })

run_loop():
  while true:
    emit(turn_start { turn_index })
    turn_index++

    context = build_context(state)   // 从 messages 构造 Context
    result = ai.stream(arena, model, context, ..., stream_callback)

    if result == error:
      emit(message_end { assistant_message })
      emit(turn_end { ... })
      return error

    追加 result(AssistantMessage) 到 state.messages
    emit(message_end { assistant_message })

    tool_calls = 收集 result.content 中的 ToolCall

    if tool_calls.len == 0 or result.stop_reason != .tool_use:
      emit(turn_end { result, tool_results=[] })
      break

    tool_results = []
    for each tool_call in tool_calls:
      if before_tool_call != null:
        if !before_tool_call(tool_call): continue（跳过该工具调用）
      emit(tool_execution_start { id, name, args })
      tool_result = execute_tool(tool_call)
      emit(tool_execution_end { id, result, is_error })
      追加 ToolResultMessage 到 state.messages
      tool_results.append(tool_result)

    emit(turn_end { result, tool_results })

stream_callback(event):
  match event:
    start → emit(message_start { assistant_message })
    text_delta / toolcall_delta / ... → emit(message_update { assistant_message, event })
    done / error → (不在此处 emit message_end，在 run_loop 外层处理)
```

### 12.6 `build_context` 函数规范

```
输入: AgentState
输出: Context

1. system_prompt = state.system_prompt
2. messages = state.messages.items（直接传递切片，不复制）
3. tools = 将 AgentTool[] 转换为 Tool[]（提取 Tool 字段）
```

---

## 15. Agent 事件系统

（已在 12.1-12.2 中定义，此处补充约束）

- 事件回调在 Agent loop 线程上同步调用
- 回调内不得调用 `agent.prompt()` 或 `agent.continue()`（防止重入）
- 所有事件中的指针只在回调返回前有效（不要存储 `event.message` 指针超过回调范围）

---

## 16. Agent 工具定义

```zig
// src/agent/tool.zig
pub const ToolResult = struct {
    content: []const UserContentBlock,
    is_error: bool,
};

pub const AgentTool = struct {
    tool: Tool,  // 嵌入的 Tool 定义（含 name, description, parameters_json）
    
    /// 工具执行函数
    /// args: 已解析的 JSON arguments
    /// arena: 用于分配返回值
    /// 返回 ToolResult（生命周期 = arena）
    execute_fn: *const fn (
        ctx: *anyopaque,
        arena: std.mem.Allocator,
        args: std.json.Value,
    ) anyerror!ToolResult,
    
    ctx: *anyopaque,  // 传递给 execute_fn 的上下文
};

/// 工具执行入口（Agent 内部调用）
pub fn executeTool(
    arena: std.mem.Allocator,
    agent_tool: *const AgentTool,
    args: std.json.Value,
) !ToolResult
```

---

## 17. Auto-Parallel Agent（自动并行 Agent）

### 17.1 设计说明

Auto-Parallel Agent 能够**自动识别可拆分的任务**，分配给多个 sub-agent **并行执行**，最后汇总结果。这比简单的顺序执行或手动定义的并行更高效。

**核心能力：**
1. **任务分解识别** - 自动判断哪些子任务可以并行
2. **Sub-Agent 委派** - 为每个子任务创建专门的 sub-agent
3. **并行执行** - 同时运行多个 sub-agent
4. **结果汇总** - 收集所有 sub-agent 结果并整合

**适用场景：**
| 场景 | 示例 |
|------|------|
| 多文件修改 | "给所有 .zig 文件添加 license header" |
| 批量处理 | "分析 src/ 下所有文件的复杂度" |
| 多维度分析 | "检查代码风格、安全漏洞、性能问题" |
| 独立子任务 | "同时生成测试代码和文档" |

### 17.2 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                    Orchestrator Agent                       │
│  (主 Agent，负责分解任务、创建 Sub-Agent、汇总结果)          │
└───────────────────────┬─────────────────────────────────────┘
                        │ analyzes task
                        ▼
        ┌───────────────────────────────┐
        │  Task Decomposition Analysis  │
        │  - 可并行？                   │
        │  - 子任务边界？               │
        │  - 依赖关系？                 │
        └───────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  Sub-Agent 1 │ │  Sub-Agent 2 │ │  Sub-Agent N │
│  (并行执行)   │ │  (并行执行)   │ │  (并行执行)   │
└──────┬───────┘ └──────┬───────┘ └──────┬───────┘
       │                │                │
       └────────────────┼────────────────┘
                        ▼
        ┌───────────────────────────────┐
        │      Result Aggregation       │
        │  - 收集所有结果               │
        │  - 解决冲突                   │
        │  - 生成最终响应               │
        └───────────────────────────────┘
```

### 17.3 核心类型

```zig
// src/agent/parallel.zig

/// 子任务定义
pub const SubTask = struct {
    id: []const u8,              // 唯一标识
    description: []const u8,     // 任务描述
    context: []const u8,         // 相关上下文（文件路径等）
    dependencies: []const []const u8,  // 依赖的其他子任务 ID
    estimated_complexity: u32,   // 预估复杂度（用于资源分配）
};

/// 子任务结果
pub const SubTaskResult = struct {
    task_id: []const u8,
    status: enum { pending, running, success, error, timeout },
    output: ?[]const u8,         // 文本输出
    artifacts: []const Artifact, // 生成的文件等
    error_message: ?[]const u8,
    execution_time_ms: u64,
};

/// 生成的产物
pub const Artifact = struct {
    type: enum { file, text, json },
    path: ?[]const u8,           // 文件路径（如果是文件）
    content: []const u8,         // 内容
};

/// 并行执行配置
pub const ParallelConfig = struct {
    /// 最大并行 sub-agent 数
    max_concurrency: usize = 4,
    
    /// 单个 sub-agent 超时时间（毫秒）
    sub_agent_timeout_ms: u64 = 300_000,  // 5分钟
    
    /// 是否允许 sub-agent 再创建 sub-agent
    allow_recursive: bool = false,
    
    /// 结果冲突解决策略
    conflict_resolution: ConflictResolution = .manual,
};

pub const ConflictResolution = enum {
    manual,      // 手动解决（默认，返回给父 Agent 决定）
    last_write,  // 后写入优先
    merge,       // 尝试自动合并
};

/// 任务分解提示模板
pub const DECOMPOSITION_PROMPT =
    \\You are a task decomposition expert. Analyze the following task and determine:
    \\1. Can this task be broken down into parallel sub-tasks?
    \\2. If yes, list each sub-task with:
    \\   - A clear description
    \\   - The context/files it needs
    \\   - Dependencies on other sub-tasks
    \\3. If no, explain why sequential execution is better.
    \\4. Return your analysis in JSON format:
    \\   {
    \\     "can_parallelize": true/false,
    \\     "reasoning": "explanation",
    \\     "sub_tasks": [
    \\       {
    \\         "id": "unique-id",
    \\         "description": "what to do",
    \\         "context": "relevant files/context",
    \\         "dependencies": ["other-task-id"]
    \\       }
    \\     ]
    \\   }
    \\Task: {s}
;
```

### 17.4 ParallelAgent 结构体

```zig
// src/agent/parallel.zig

pub const ParallelAgent = struct {
    allocator: std.mem.Allocator,
    
    /// 父 Agent（用于创建 sub-agents）
    parent_agent: *Agent,
    
    /// 配置
    config: ParallelConfig,
    
    /// 子任务队列
    pending_tasks: std.ArrayList(SubTask),
    running_tasks: std.ArrayList(RunningTask),
    completed_tasks: std.ArrayList(SubTaskResult),
    
    /// 执行统计
    stats: ExecutionStats,
    
    pub fn init(allocator: std.mem.Allocator, parent: *Agent, config: ParallelConfig) !ParallelAgent;
    pub fn deinit(self: *ParallelAgent) void;
    
    /// 分析任务并决定是否并行化
    pub fn analyzeTask(
        self: *ParallelAgent,
        arena: std.mem.Allocator,
        user_request: []const u8,
    ) !TaskAnalysis;
    
    /// 执行并行任务
    pub fn executeParallel(
        self: *ParallelAgent,
        arena: std.mem.Allocator,
        sub_tasks: []const SubTask,
    ) ![]const SubTaskResult;
    
    /// 汇总结果
    pub fn aggregateResults(
        self: *ParallelAgent,
        arena: std.mem.Allocator,
        results: []const SubTaskResult,
    ) !AggregationResult;
};

pub const TaskAnalysis = struct {
    can_parallelize: bool,
    reasoning: []const u8,
    sub_tasks: []const SubTask,
};

pub const RunningTask = struct {
    task: SubTask,
    agent: Agent,
    thread: std.Thread,
    start_time: i64,
};

pub const ExecutionStats = struct {
    total_tasks: usize,
    completed_tasks: usize,
    failed_tasks: usize,
    total_execution_time_ms: u64,
    max_concurrency_reached: usize,
};

pub const AggregationResult = struct {
    summary: []const u8,
    artifacts: []const Artifact,
    conflicts: []const Conflict,
};

pub const Conflict = struct {
    type: enum { file_modify, logic_inconsistent },
    description: []const u8,
    involved_tasks: []const []const u8,
    suggested_resolution: []const u8,
};
```

### 17.5 执行流程

```zig
/// 完整的并行执行流程
pub fn runParallelWorkflow(
    self: *ParallelAgent,
    arena: std.mem.Allocator,
    user_request: []const u8,
) !AggregationResult {
    
    // Step 1: 分析任务是否可并行化
    const analysis = try self.analyzeTask(arena, user_request);
    
    if (!analysis.can_parallelize) {
        // 不可并行，使用父 Agent 顺序执行
        return .{
            .summary = "Task is not suitable for parallel execution",
            .artifacts = &.{},
            .conflicts = &.{},
        };
    }
    
    // Step 2: 按依赖关系排序任务
    const sorted_tasks = try topologicalSort(arena, analysis.sub_tasks);
    
    // Step 3: 分批执行（考虑依赖和并发限制）
    var all_results = std.ArrayList(SubTaskResult).init(arena);
    
    var i: usize = 0;
    while (i < sorted_tasks.len) {
        // 找出当前可执行的任务（依赖已完成）
        const ready_tasks = try self.getReadyTasks(sorted_tasks[i..], all_results.items);
        
        if (ready_tasks.len == 0) {
            return error.CircularDependency;
        }
        
        // 限制并发数
        const batch_size = @min(ready_tasks.len, self.config.max_concurrency);
        const batch = ready_tasks[0..batch_size];
        
        // 并行执行当前批次
        const batch_results = try self.executeBatch(arena, batch);
        try all_results.appendSlice(batch_results);
        
        i += batch_size;
    }
    
    // Step 4: 汇总结果
    return try self.aggregateResults(arena, all_results.items);
}

/// 执行一批并行任务
fn executeBatch(
    self: *ParallelAgent,
    arena: std.mem.Allocator,
    tasks: []const SubTask,
) ![]const SubTaskResult {
    var results = std.ArrayList(SubTaskResult).init(arena);
    var mutex = std.Thread.Mutex{};
    
    // 使用线程池并行执行
    const ThreadContext = struct {
        task: SubTask,
        parent: *Agent,
        arena: std.mem.Allocator,
        results: *std.ArrayList(SubTaskResult),
        mutex: *std.Thread.Mutex,
    };
    
    var threads = std.ArrayList(std.Thread).init(self.allocator);
    defer threads.deinit();
    
    for (tasks) |task| {
        const ctx = try arena.create(ThreadContext);
        ctx.* = .{
            .task = task,
            .parent = self.parent_agent,
            .arena = arena,
            .results = &results,
            .mutex = &mutex,
        };
        
        const thread = try std.Thread.spawn(.{}, runSubAgent, .{ctx});
        try threads.append(thread);
    }
    
    // 等待所有线程完成
    for (threads.items) |thread| {
        thread.join();
    }
    
    return results.toOwnedSlice();
}

/// 单个 sub-agent 执行函数
fn runSubAgent(ctx: *ThreadContext) void {
    var sub_agent = Agent.init(ctx.arena, ctx.parent.ai, .{
        .model = ctx.parent.state.model,
        .system_prompt = ctx.task.description,
    }) catch |err| {
        // 记录错误
        return;
    };
    defer sub_agent.deinit();
    
    // 执行子任务
    sub_agent.prompt(ctx.arena, ctx.task.context) catch |err| {
        // 记录错误
        return;
    };
    
    // 收集结果
    const result = SubTaskResult{
        .task_id = ctx.task.id,
        .status = .success,
        .output = "Task completed successfully",
        .artifacts = &.{},
        .execution_time_ms = 0, // 实际计算
    };
    
    ctx.mutex.lock();
    defer ctx.mutex.unlock();
    ctx.results.append(result) catch {};
}
```

### 17.6 使用示例

```zig
// 创建并行 Agent
var parallel = ParallelAgent.init(allocator, &parent_agent, .{
    .max_concurrency = 4,
    .sub_agent_timeout_ms = 300_000,
});
defer parallel.deinit();

// 执行并行任务
const result = try parallel.runParallelWorkflow(arena, 
    \\Please analyze all .zig files in src/ for:
    \\1. Code style issues
    \\2. Potential bugs
    \\3. Performance bottlenecks
    \\Generate a comprehensive report.
);

// 处理结果
for (result.artifacts) |artifact| {
    std.debug.print("Generated: {s}\n", .{artifact.path.?});
}

if (result.conflicts.len > 0) {
    std.debug.print("Warning: {d} conflicts need resolution\n", .{result.conflicts.len});
}
```

### 17.7 与现有 Agent 集成

```zig
// 在 Agent 中添加并行执行能力
pub const Agent = struct {
    // ... 现有字段
    
    /// 并行执行配置（null 表示不使用并行）
    parallel_config: ?ParallelConfig = null,
    
    /// 执行用户请求（自动决定是否并行）
    pub fn execute(
        self: *Agent,
        arena: std.mem.Allocator,
        user_request: []const u8,
    ) !void {
        // 检查是否应该并行化
        if (self.parallel_config) |config| {
            var parallel = ParallelAgent.init(self.allocator, self, config);
            defer parallel.deinit();
            
            const analysis = try parallel.analyzeTask(arena, user_request);
            if (analysis.can_parallelize and analysis.sub_tasks.len > 1) {
                // 使用并行执行
                const result = try parallel.runParallelWorkflow(arena, user_request);
                try self.handleParallelResult(result);
                return;
            }
        }
        
        // 顺序执行
        try self.prompt(arena, user_request);
    }
};
```

### 17.8 边界条件

17. **循环依赖**：Sub-task 之间存在循环依赖 → 返回错误，要求用户明确指定顺序
18. **资源耗尽**：并发数达到上限仍有任务等待 → 排队等待，或动态增加并发
19. **部分失败**：部分 sub-agent 失败 → 根据策略决定：继续/重试/中止
20. **结果冲突**：多个 sub-agent 修改同一文件 → 根据 conflict_resolution 策略处理

---

## 18. CLI 入口

### 15.1 命令行接口

```
kimiz [OPTIONS] [PROMPT]

OPTIONS:
  --model <provider/model-id>  使用的模型（默认：openai/gpt-4o-mini）
  --system <text>              系统提示
  --no-stream                  禁用流式输出（等待完整响应）
  -h, --help                   显示帮助

PROMPT:
  如果提供，执行单次对话后退出
  如果不提供，进入交互式 REPL 模式

ENVIRONMENT:
  OPENAI_API_KEY       OpenAI API Key
  ANTHROPIC_API_KEY    Anthropic API Key
  GOOGLE_API_KEY       Google API Key
  KIMI_API_KEY         Kimi (Moonshot) API Key
  KIMI_CODE_API_KEY    Kimi Code API Key
  FIREWORKS_API_KEY    Fireworks AI API Key
```

### 15.2 main() 流程

```
1. 解析命令行参数
2. 确定模型（--model 或默认值）
3. 初始化 Ai 实例
4. 初始化 Agent（含系统提示、模型）
5. if PROMPT 提供:
     单次 agent.prompt(prompt_text)
     流式打印 text_delta 事件
     退出
   else:
     REPL 循环:
       print "> "
       readline 用户输入
       if 空行: continue
       if "exit" 或 "quit": break
       agent.prompt(user_text)
       等待 agent_end
6. 输出最终换行
7. 退出 0
```

### 15.3 流式打印回调

```
callback(event):
  match event:
    message_update { assistant_event }:
      match assistant_event:
        text_delta { delta }: stdout.write(delta)
        toolcall_end { tool_call }: 
          stderr.print("[Tool: {s}({s})]\n", .{tool_call.name, json_str(tool_call.arguments)})
    tool_execution_end { result, is_error }:
      if is_error: stderr.print("[Tool Error]\n")
      else: stderr.print("[Tool OK]\n")
    agent_end:
      stdout.write("\n")
```

---

## 19. Build 配置

### 16.1 build.zig 模块结构

```zig
// 模块定义
const ai_mod = b.addModule("kimiz-ai", .{
    .root_source_file = b.path("src/ai/root.zig"),
    .target = target,
});

const agent_mod = b.addModule("kimiz-agent", .{
    .root_source_file = b.path("src/agent/root.zig"),
    .target = target,
    .imports = &.{ .{ .name = "kimiz-ai", .module = ai_mod } },
});

const lib_mod = b.addModule("kimiz", .{
    .root_source_file = b.path("src/root.zig"),
    .target = target,
    .imports = &.{
        .{ .name = "kimiz-ai", .module = ai_mod },
        .{ .name = "kimiz-agent", .module = agent_mod },
    },
});

// 可执行文件
const exe = b.addExecutable(.{
    .name = "kimiz",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "kimiz-ai", .module = ai_mod },
            .{ .name = "kimiz-agent", .module = agent_mod },
        },
    }),
});
```

---

## 19. TUI (Terminal User Interface)

### 19.1 设计说明

TUI 提供比 REPL 更丰富的交互体验，参考 pi-tui 的设计：

| 特性 | REPL | TUI |
|------|------|-----|
| 消息展示 | 纯文本 | 气泡式对话框 |
| 代码高亮 | 无 | 语法高亮 |
| 流式输出 | 逐字打印 | 平滑滚动 |
| 会话管理 | 命令行 | 侧边栏列表 |
| 工具状态 | 文字描述 | 图标动画 |
| 历史查看 | 滚动终端 | 独立滚动区域 |

### 19.2 布局设计

```
┌─────────────────────────────────────────────────────────────┐
│  kimiz TUI                              [? Help] [Q Quit]   │
├──────────┬──────────────────────────────────────────────────┤
│          │                                                   │
│ Sessions │  Conversation Area                                │
│          │  ┌──────────────────────────────────────────┐    │
│ [S1] ✓   │  │ User: 你好                                 │    │
│ [S2]     │  │                                            │    │
│ [S3] ✓   │  │ Assistant: 你好！有什么可以帮助你的？      │    │
│          │  │                                            │    │
│ [+ New]  │  │ User: 写一个快速排序                       │    │
│          │  │                                            │    │
│          │  │ Assistant: 我来为你写一个快速排序算法：    │    │
│          │  │ ┌────────────────────────────────────┐    │    │
│          │  │ │ ```zig                             │    │    │
│          │  │ │ fn quickSort(...) void {           │    │    │
│          │  │ │     // ...                         │    │    │
│          │  │ │ }                                  │    │    │
│          │  │ │ ```                                │    │    │
│          │  │ └────────────────────────────────────┘    │    │
│          │  │ [Thinking...] 或 [Tool: ReadFile]         │    │
│          │  └──────────────────────────────────────────┘    │
│          │                                                   │
├──────────┴──────────────────────────────────────────────────┤
│  > _                                                        │
│  [Send] [Plan Mode: Off] [YOLO: Off] [Model: kimi-k2-5]     │
└─────────────────────────────────────────────────────────────┘
```

### 19.3 组件架构

```
src/tui/
├── root.zig           # TUI 入口
├── app.zig            # 主应用状态
├── ui.zig             # UI 渲染
├── components/        # 可复用组件
│   ├── message.zig    # 消息气泡
│   ├── code_block.zig # 代码块
│   ├── sidebar.zig    # 会话侧边栏
│   ├── input.zig      # 输入框
│   └── status_bar.zig # 状态栏
├── events.zig         # 事件处理
└── theme.zig          # 主题配置
```

### 19.4 核心类型

```zig
// src/tui/app.zig
pub const TuiApp = struct {
    allocator: std.mem.Allocator,
    
    // 核心组件
    agent: Agent,
    session_manager: SessionManager,
    
    // UI 状态
    current_view: View,
    sidebar_open: bool,
    scroll_offset: usize,
    
    // 输入状态
    input_buffer: std.ArrayList(u8),
    cursor_position: usize,
    
    // 渲染状态
    messages: std.ArrayList(UIMessage),
    needs_redraw: bool,
    
    pub fn init(allocator: std.mem.Allocator, options: TuiOptions) !TuiApp;
    pub fn deinit(self: *TuiApp) void;
    pub fn run(self: *TuiApp) !void;
};

pub const TuiOptions = struct {
    model: *const Model,
    system_prompt: ?[]const u8 = null,
    theme: Theme = .default,
};

pub const View = enum {
    chat,       // 主聊天界面
    sessions,   // 会话管理
    settings,   // 设置界面
    help,       // 帮助界面
};

// 消息显示类型
pub const UIMessage = struct {
    id: u64,
    role: enum { user, assistant, system },
    content: []const u8,
    blocks: []const ContentBlock,  // 解析后的内容块
    timestamp: i64,
    status: MessageStatus,
};

pub const ContentBlock = union(enum) {
    text: []const u8,
    code: CodeBlock,
    tool_call: ToolCallInfo,
    tool_result: ToolResultInfo,
};

pub const CodeBlock = struct {
    language: ?[]const u8,
    code: []const u8,
    collapsed: bool = false,
};

pub const ToolCallInfo = struct {
    name: []const u8,
    status: enum { pending, running, success, error },
    args: ?std.json.Value,
};

pub const MessageStatus = enum {
    sending,      // 发送中
    streaming,    // 流式接收中
    complete,     // 完成
    error,        // 错误
};
```

### 19.5 渲染流程

```zig
// src/tui/ui.zig

/// 主渲染循环
pub fn renderLoop(app: *TuiApp) !void {
    while (app.running) {
        // 1. 处理输入事件
        if (try pollInput()) |event| {
            try handleEvent(app, event);
        }
        
        // 2. 更新 Agent 事件
        while (app.agent.pollEvent()) |event| {
            try updateUI(app, event);
        }
        
        // 3. 重绘（如果需要）
        if (app.needs_redraw) {
            try draw(app);
            app.needs_redraw = false;
        }
        
        // 4. 控制帧率
        std.time.sleep(16 * std.time.ns_per_ms); // ~60fps
    }
}

/// 绘制主界面
fn draw(app: *TuiApp) !void {
    // 清屏
    try clearScreen();
    
    // 绘制标题栏
    try drawHeader(app);
    
    // 绘制侧边栏（如果打开）
    if (app.sidebar_open) {
        try drawSidebar(app);
    }
    
    // 绘制消息区域
    try drawMessages(app);
    
    // 绘制输入框
    try drawInputBox(app);
    
    // 绘制状态栏
    try drawStatusBar(app);
    
    // 刷新显示
    try flush();
}
```

### 19.6 事件处理

```zig
// src/tui/events.zig

pub const Event = union(enum) {
    key: KeyEvent,
    mouse: MouseEvent,
    resize: ResizeEvent,
    agent: AgentEvent,
};

pub const KeyEvent = struct {
    key: Key,
    modifiers: Modifiers,
};

pub const Key = enum {
    char,        // 普通字符
    enter,
    escape,
    backspace,
    delete,
    tab,
    up,
    down,
    left,
    right,
    home,
    end,
    page_up,
    page_down,
    f1, f2, ..., f12,
};

/// 处理键盘事件
pub fn handleKeyEvent(app: *TuiApp, event: KeyEvent) !void {
    switch (event.key) {
        .char => |c| try handleChar(app, c),
        .enter => try submitInput(app),
        .escape => try handleEscape(app),
        .backspace => try handleBackspace(app),
        .up => try scrollUp(app),
        .down => try scrollDown(app),
        .tab => try toggleFocus(app),
        .f1 => try showHelp(app),
        .f2 => try toggleSidebar(app),
        else => {},
    }
}

/// 快捷键映射
const SHORTCUTS = .{
    .{ .key = .{ .char = 'c', .ctrl = true }, .action = "Cancel" },
    .{ .key = .{ .char = 'd', .ctrl = true }, .action = "Quit" },
    .{ .key = .{ .char = 'n', .ctrl = true }, .action = "New Session" },
    .{ .key = .{ .char = 'p', .ctrl = true }, .action = "Toggle Plan Mode" },
    .{ .key = .{ .char = 'y', .ctrl = true }, .action = "Toggle YOLO Mode" },
    .{ .key = .{ .char = 'l', .ctrl = true }, .action = "Clear Screen" },
};
```

### 19.7 主题系统

```zig
// src/tui/theme.zig

pub const Theme = struct {
    name: []const u8,
    
    // 颜色定义
    colors: Colors,
    
    // 样式定义
    styles: Styles,
};

pub const Colors = struct {
    background: Color,
    foreground: Color,
    accent: Color,
    success: Color,
    warning: Color,
    error: Color,
    
    // 消息气泡颜色
    user_bubble: Color,
    assistant_bubble: Color,
    system_bubble: Color,
    
    // 语法高亮颜色
    keyword: Color,
    string: Color,
    comment: Color,
    number: Color,
    function: Color,
};

pub const Color = union(enum) {
    default,
    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,
    bright_black,
    bright_red,
    // ...
    rgb: struct { r: u8, g: u8, b: u8 },
};

// 预设主题
pub const THEMES = .{
    .default = Theme{
        .name = "Default",
        .colors = .{
            .background = .black,
            .foreground = .white,
            .accent = .cyan,
            .success = .green,
            .warning = .yellow,
            .error = .red,
            .user_bubble = .blue,
            .assistant_bubble = .bright_black,
            .system_bubble = .magenta,
            .keyword = .magenta,
            .string = .green,
            .comment = .bright_black,
            .number = .yellow,
            .function = .cyan,
        },
    },
    .light = Theme{ /* ... */ },
    .dracula = Theme{ /* ... */ },
    .monokai = Theme{ /* ... */ },
};
```

### 19.8 实现依赖

TUI 实现需要以下 Zig 库（纯 Zig，无外部依赖）：

```zig
// build.zig
const tui_mod = b.addModule("kimiz-tui", .{
    .root_source_file = b.path("src/tui/root.zig"),
    .target = target,
    .imports = &.{
        .{ .name = "kimiz-ai", .module = ai_mod },
        .{ .name = "kimiz-agent", .module = agent_mod },
    },
});

// 依赖的 Zig 标准库功能：
// - std.io: 终端 I/O
// - std.os: 终端控制（termios）
// - std.unicode: 宽字符处理
```

**注意**: 使用纯 Zig 标准库实现 TUI，不依赖 ncurses 等外部库。

### 19.9 启动方式

```bash
# 默认启动 TUI
kimiz

# 显式启动 TUI
kimiz --tui

# 启动 REPL 模式（无 TUI）
kimiz --repl

# 单次提问模式
kimiz "prompt"
```

---

## 20. 边界条件

1. **空 Context**：messages 为空 + 无 system_prompt → 发送只含空 messages 数组的请求（不报错）
2. **API Key 含空格**：trim 后使用（环境变量常见问题）
3. **SSE 行末 `\r\n`**：Windows 换行，需要 strip `\r`
4. **工具参数为 null JSON**：`"arguments": null` 时，视为空对象 `{}`
5. **AssistantMessage 无 content**：stop_reason=stop 但 content 为空数组 → 正常，返回空文本
6. **Anthropic 工具结果顺序**：Anthropic 要求 assistant 消息中的 tool_use 块和 user 消息中的 tool_result 块 ID 必须一一对应，保持相同顺序
7. **Google JSON schema 类型**：Google API 使用大写类型名（"OBJECT", "STRING" 等），转换时需从 JSON Schema 的小写转大写
8. **流式连接中断**：SSE 流中途 TCP 断开 → 返回 `error.HttpResponseReadFailed`，不返回部分 AssistantMessage
9. **max_tokens 超出模型限制**：options.max_tokens > model.max_tokens → 使用 model.max_tokens（静默截断，不报错）
10. **重复工具 ID**：同一响应中出现相同 tool_call_id → 以第一个为准，后续忽略
11. **usage 为 null**：部分 provider 在流式响应中不返回 usage → 保持 usage 全零
12. **UTF-8 截断**：SSE delta 中可能出现跨 chunk 的 UTF-8 多字节序列 → 不处理（provider 应保证 UTF-8 完整）
13. **空工具名**：tool_call.name == "" → 跳过该工具调用，emit tool_execution_end { is_error=true }
14. **context_window 超出**：消息历史超出模型 context_window → 由 API 返回错误，不在客户端截断（MVP 不实现自动截断）
15. **Fireworks 重复循环**：Fireworks Kimi 2.5 Turbo 可能出现重复生成 → 使用 StreamGuard 检测并终止
16. **重复检测误报**：正常文本被误判为重复 → 调整相似度阈值或窗口大小

---

## 验收标准（进入 Phase 4 的门槛）

- [ ] 所有数据类型均有精确字段名、类型、约束
- [ ] 所有函数均有参数、返回值、前置条件
- [ ] 三大 Provider 的 JSON 格式均有示例
- [ ] 所有状态机有完整转换表
- [ ] 至少 14 个边界条件已列出
- [ ] API Key 解析顺序已定义
- [ ] Memory 生命周期规则已明确
