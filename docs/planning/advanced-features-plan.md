# kimiz 高级功能实现规划

## 1. 多模态支持（图片 + PDF）

### 1.1 图片输入

**支持 Provider**:
- ✅ OpenAI GPT-4o / GPT-4o-mini (Vision)
- ✅ Anthropic Claude 3/4 (Vision)
- ✅ Google Gemini (原生 Vision)
- ✅ Kimi K2.5 (Vision)

**实现方式**:
```zig
// 统一的图片内容类型
pub const ImageContent = struct {
    data: []const u8,           // base64 编码
    mime_type: []const u8,      // "image/png", "image/jpeg", "image/webp"
    url: ?[]const u8 = null,    // 可选 URL
    detail: ImageDetail = .auto,
};

pub const ImageDetail = enum { auto, low, high };
```

**各 Provider 格式**:

| Provider | 格式 | 说明 |
|----------|------|------|
| OpenAI | `{"type": "image_url", "image_url": {"url": "data:image/png;base64,..."}}` | base64 data URL |
| Anthropic | `{"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": "..."}}` | 原生 base64 |
| Gemini | `{"inlineData": {"mimeType": "image/png", "data": "..."}}` | inline_data |
| Kimi | 同 OpenAI | OpenAI 兼容 |

**图片处理流程**:
1. 用户输入图片路径或粘贴图片
2. 读取文件并检测 MIME 类型
3. base64 编码
4. 根据 Provider 格式序列化
5. 发送到 API

### 1.2 PDF 输入

**支持 Provider**:
- ✅ Google Gemini (原生，最多 3600 页)
- ✅ Anthropic Claude (原生，最多 100 页)
- ⚠️ OpenAI (需转换为图片)
- ✅ Kimi (原生支持)

**实现方式**:
```zig
pub const PdfContent = struct {
    data: []const u8,           // PDF 文件 base64
    mime_type: []const u8 = "application/pdf",
    page_count: ?u32 = null,    // 页数信息
};
```

**Gemini PDF 格式**:
```json
{
  "role": "user",
  "content": [
    {"text": "分析这个 PDF 文档"},
    {
      "inlineData": {
        "mimeType": "application/pdf",
        "data": "JVBERi0xLjQK..."
      }
    }
  ]
}
```

**Claude PDF 格式**:
```json
{
  "role": "user",
  "content": [
    {"type": "text", "text": "分析这个 PDF"},
    {
      "type": "document",
      "source": {
        "type": "base64",
        "media_type": "application/pdf",
        "data": "JVBERi0xLjQK..."
      }
    }
  ]
}
```

**PDF 处理策略**:
- Gemini/Claude/Kimi: 直接发送 PDF
- OpenAI: 将 PDF 转换为图片（每页一张）

---

## 2. 联网搜索

### 2.1 设计思路

**统一搜索接口**，支持多种后端：

```zig
pub const SearchProvider = enum {
    openai_builtin,     // OpenAI web_search 工具
    tavily,            // Tavily API
    serpapi,           // SerpAPI
    brave,             // Brave Search API
    duckduckgo,        // DuckDuckGo (免费)
};

pub const SearchTool = struct {
    provider: SearchProvider,
    api_key: ?[]const u8,
    
    pub fn search(
        self: *SearchTool,
        arena: std.mem.Allocator,
        query: []const u8,
    ) !SearchResult;
};

pub const SearchResult = struct {
    query: []const u8,
    results: []const SearchResultItem,
    total_results: u32,
};

pub const SearchResultItem = struct {
    title: []const u8,
    url: []const u8,
    snippet: []const u8,
    published_date: ?[]const u8,
};
```

### 2.2 OpenAI 内置搜索

OpenAI 提供 `web_search` 工具：

```json
{
  "model": "gpt-4o",
  "messages": [...],
  "tools": [
    {"type": "web_search"}
  ]
}
```

**特点**:
- 无需额外 API Key
- 按 token 计费
- 自动决定何时搜索

### 2.3 第三方搜索 API

**Tavily** (推荐):
- 专为 AI 设计
- 返回结构化结果
- 免费额度: 1000 次/月

**SerpAPI**:
- Google 搜索结果
- 付费服务

**Brave Search**:
- 隐私友好
- 有免费额度

### 2.4 搜索工具集成

```zig
// 作为 Agent 内置工具
pub const BUILT_IN_TOOLS = &[_]AgentTool{
    // ... 其他工具
    .{
        .tool = .{
            .name = "web_search",
            .description = "Search the web for current information",
            .parameters_json = "{\"type\":\"object\",\"properties\":{\"query\":{\"type\":\"string\",\"description\":\"Search query\"}},\"required\":[\"query\"]}",
        },
        .execute_fn = executeWebSearch,
    },
};
```

---

## 3. 代码执行（本地沙箱）

### 3.1 设计目标

- 本地执行 Python/Bash 代码
- 安全沙箱（限制资源、网络、文件系统）
- 与 Agent 工作流集成

### 3.2 架构

```
┌─────────────────────────────────────┐
│           Agent                     │
│  (调用代码执行工具)                  │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│      Code Execution Service         │
│  ┌─────────────────────────────┐   │
│  │    Process Sandbox          │   │
│  │  - Python/Bash interpreter  │   │
│  │  - Resource limits          │   │
│  │  - Timeout control          │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

### 3.3 实现方式

**方案 A: 直接执行（简单场景）**
```zig
pub fn executePython(
    arena: std.mem.Allocator,
    code: []const u8,
    timeout_ms: u32,
) !ExecutionResult {
    // 使用系统 Python
    // 限制: ulimit + timeout
    // 禁止网络: 防火墙规则
}
```

**方案 B: Docker 沙箱（推荐，更安全）**
```zig
pub fn executeInDocker(
    arena: std.mem.Allocator,
    code: []const u8,
    language: enum { python, bash },
    timeout_ms: u32,
) !ExecutionResult {
    // 启动临时容器
    // 挂载只读文件系统
    // 网络隔离
    // 资源限制
}
```

### 3.4 工具定义

```zig
pub const CODE_EXECUTION_TOOL = AgentTool{
    .tool = .{
        .name = "execute_code",
        .description = "Execute Python or Bash code in a sandboxed environment",
        .parameters_json = 
            \\{"type":"object","properties":{
            \\  "language":{"type":"string","enum":["python","bash"]},
            \\  "code":{"type":"string","description":"Code to execute"},
            \\  "timeout":{"type":"integer","default":30}
            \\},"required":["language","code"]}
        ,
    },
    .execute_fn = executeCodeSandbox,
};
```

### 3.5 安全限制

| 限制项 | 配置 |
|--------|------|
| **超时** | 默认 30 秒，最大 5 分钟 |
| **内存** | 最大 512MB |
| **CPU** | 单核限制 |
| **网络** | 禁止外网访问 |
| **文件系统** | 只读，或指定目录 |
| **进程数** | 最多 10 个子进程 |

---

## 4. Agent 集群（Auto-Parallel）

### 4.1 跨 Provider 并行

kimiz 的独特优势：**可以同时使用多个 Provider 的模型**

```zig
// 并行执行配置
pub const ParallelExecutionConfig = struct {
    // 为不同子任务选择不同 Provider
    tasks: []const ParallelTask,
};

pub const ParallelTask = struct {
    id: []const u8,
    description: []const u8,
    provider: KnownProvider,    // 指定 Provider
    model_id: []const u8,       // 指定模型
    // ...
};
```

**使用场景**:
- 子任务 1: 用 GPT-4o 生成代码（快速）
- 子任务 2: 用 Claude 分析安全性（深度）
- 子任务 3: 用 Gemini 处理 PDF 文档（多模态）

### 4.2 实现架构

```zig
// 使用 libxev 实现并行
pub fn executeParallelCrossProvider(
    self: *ParallelAgent,
    arena: std.mem.Allocator,
    tasks: []const ParallelTask,
) ![]const TaskResult {
    var completions: usize = 0;
    var mutex = std.Thread.Mutex{};
    var results = std.ArrayList(TaskResult).init(arena);
    
    // 为每个任务创建异步操作
    for (tasks) |task| {
        const op = try self.xev_loop.addOperation(.{
            .task = task,
            .callback = struct {
                fn callback(result: TaskResult) void {
                    mutex.lock();
                    results.append(result) catch {};
                    completions += 1;
                    mutex.unlock();
                }
            }.callback,
        });
    }
    
    // 等待所有完成
    while (completions < tasks.len) {
        self.xev_loop.run(.once) catch {};
    }
    
    return results.toOwnedSlice();
}
```

---

## 5. 实现优先级

### Phase 1 (MVP)
- [x] 基础多 Provider 支持
- [x] Tool Calling
- [ ] 图片输入（Vision）

### Phase 2 (高级功能)
- [ ] PDF 文档输入
- [ ] 联网搜索（统一接口）
- [ ] 代码执行沙箱
- [ ] Agent 集群完善

### Phase 3 (优化)
- [ ] 视频输入（Gemini/Kimi）
- [ ] 更完善的沙箱安全
- [ ] 搜索缓存
- [ ] 并行执行优化

---

## 6. 与 Kimi 官方的对比优势

| 特性 | kimiz | Kimi 官方 |
|------|-------|-----------|
| **多 Provider** | ✅ 自由选择 | ❌ 仅限 Kimi |
| **跨 Provider 并行** | ✅ 独特优势 | ❌ 不支持 |
| **模型组合** | ✅ GPT-4o + Claude + Gemini | ❌ 单一模型 |
| **成本优化** | ✅ 按需选择便宜模型 | ❌ 固定价格 |
| **离线运行** | ✅ 完全离线 | ❌ 需要联网 |
| **功能完整度** | ⚠️ 逐步完善 | ✅ 开箱即用 |

**kimiz 的独特价值**:
1. **灵活性**: 不被单一供应商锁定
2. **成本**: 可以选择更便宜的模型处理简单任务
3. **组合**: 不同任务用最适合的模型
4. **隐私**: 本地执行，数据不离开本机
5. **定制**: 完全开源，可深度定制
