# TASK-TOOL-004: 实现基础 Web Search 工具 (DuckDuckGo API)

**状态**: pending  
**优先级**: P1  
**预计工时**: 4小时  
**指派给**: TBD  
**标签**: tools, web-search, integration

---

## 背景

kimiz 当前 `web_search` 工具只有 placeholder 实现，未提供实际搜索功能：

```zig
// src/agent/tools/web_search.zig (当前)
// TODO: Implement actual web search
// 返回: "[Web search not yet implemented]"
```

需要实现基础的 Web Search 功能，让 Agent 能够搜索互联网信息。

---

## 目标

实现基于 DuckDuckGo API 的 Web Search 工具，提供基础的搜索能力。

---

## 技术方案

### 选择 DuckDuckGo 的理由

- **免费**: 无需 API key
- **隐私**: 不追踪用户
- **简单**: HTML 接口易于解析
- **无需认证**: 降低使用门槛

### 替代方案对比

| 方案 | 优点 | 缺点 | 选择 |
|------|------|------|------|
| DuckDuckGo | 免费、无需 key | 有 rate limit | ✅ 首选 |
| Google Custom Search | 结果准确 | 需要 API key、付费 | 可选 |
| Bing API | 结果丰富 | 需要 API key | 可选 |
| Serper.dev | 结构化 JSON | 第三方服务 | 备选 |

---

## 实现细节

### 1. API 调用

```zig
// src/agent/tools/web_search.zig
const DUCKDUCKGO_URL = "https://html.duckduckgo.com/html/";

pub fn searchDuckDuckGo(allocator: std.mem.Allocator, query: []const u8, num_results: usize) !SearchResults {
    // URL encode query
    const encoded_query = try urlEncode(allocator, query);
    defer allocator.free(encoded_query);
    
    // Build URL
    const url = try std.fmt.allocPrint(allocator, "{s}?q={s}", .{ DUCKDUCKGO_URL, encoded_query });
    defer allocator.free(url);
    
    // HTTP GET request
    const response = try httpGet(allocator, url);
    defer allocator.free(response);
    
    // Parse HTML results
    return try parseDuckDuckGoResults(allocator, response, num_results);
}
```

### 2. HTML 解析

```zig
pub const SearchResult = struct {
    title: []const u8,
    url: []const u8,
    snippet: []const u8,
};

fn parseDuckDuckGoResults(allocator: std.mem.Allocator, html: []const u8, limit: usize) ![]SearchResult {
    // Parse DuckDuckGo HTML structure:
    // <div class="result">...</div>
    //   <a class="result__a">Title</a>
    //   <a class="result__url">URL</a>
    //   <div class="result__snippet">Snippet</div>
    
    var results = std.ArrayList(SearchResult).init(allocator);
    errdefer results.deinit();
    
    // Simple HTML parsing (or use lightweight parser)
    // Extract up to `limit` results
    
    return results.toOwnedSlice();
}
```

### 3. 工具接口

```zig
pub const tool_definition = tool.Tool{
    .name = "web_search",
    .description = 
        "Search the web for information using DuckDuckGo. " ++
        "Returns a list of search results with titles, URLs, and snippets. " ++
        "Use this to find documentation, tutorials, or general information.",
    .parameters_json =
        \\{
        \\  "type": "object",
        \\  "properties": {
        \\    "query": {
        \\      "type": "string",
        \\      "description": "Search query string"
        \\    },
        \\    "num_results": {
        \\      "type": "number",
        \\      "description": "Number of results to return (default: 5, max: 10)",
        \\      "default": 5
        \\    }
        \\  },
        \\  "required": ["query"]
        \\}
    ,
};

const WebSearchArgs = struct {
    query: []const u8,
    num_results: usize = 5,
};

fn execute(ctx: *anyopaque, arena: std.mem.Allocator, args: std.json.Value) !tool.ToolResult {
    const parsed = try tool.parseArguments(args, WebSearchArgs);
    
    // Validate
    if (parsed.query.len == 0) {
        return tool.errorResult(arena, "Query cannot be empty");
    }
    if (parsed.num_results > 10) {
        return tool.errorResult(arena, "num_results cannot exceed 10");
    }
    
    // Search
    const results = searchDuckDuckGo(arena, parsed.query, parsed.num_results) catch |err| {
        return tool.errorResult(arena, try std.fmt.allocPrint(arena, "Search failed: {s}", .{@errorName(err)}));
    };
    
    // Format output
    var output = std.ArrayList(u8).init(arena);
    errdefer output.deinit();
    
    try output.writer().print("Search results for: \"{s}\"\n\n", .{parsed.query});
    
    for (results, 0..) |result, i| {
        try output.writer().print("{d}. {s}\n   URL: {s}\n   {s}\n\n", .{
            i + 1,
            result.title,
            result.url,
            result.snippet,
        });
    }
    
    return tool.textContent(arena, output.items);
}
```

---

## Rate Limit 处理

```zig
pub const RateLimiter = struct {
    last_request_time: i64 = 0,
    min_interval_ms: i64 = 1000,  // 最少 1 秒间隔
    
    pub fn checkAndWait(self: *RateLimiter) !void {
        const now = std.time.milliTimestamp();
        const elapsed = now - self.last_request_time;
        
        if (elapsed < self.min_interval_ms) {
            const wait_ms = self.min_interval_ms - elapsed;
            std.time.sleep(@intCast(u64, wait_ms) * std.time.ns_per_ms);
        }
        
        self.last_request_time = std.time.milliTimestamp();
    }
};
```

---

## 错误处理

| 错误场景 | 处理策略 |
|----------|----------|
| Network timeout | 重试 3 次，然后报错 |
| Rate limited | 等待 5 秒后重试 |
| Parse error | 返回部分结果 + 警告 |
| Empty results | 返回 "No results found" |

---

## 验收标准

- [ ] `web_search` 工具能成功搜索并返回结果
- [ ] 支持 `num_results` 参数 (1-10)
- [ ] 返回格式: 标题 + URL + 摘要
- [ ] Rate limit 保护 (最小 1 秒间隔)
- [ ] 网络错误处理 (重试机制)
- [ ] 单元测试覆盖主要场景
- [ ] 文档更新

---

## 使用示例

```bash
# 基础搜索
$ kimiz tool web_search --query "Zig programming language"

# 指定结果数量
$ kimiz tool web_search --query "async await rust" --num_results 10
```

**预期输出**:
```
Search results for: "Zig programming language"

1. Zig Programming Language
   URL: https://ziglang.org/
   Zig is a general-purpose programming language and build system...

2. GitHub - ziglang/zig: General-purpose programming language...
   URL: https://github.com/ziglang/zig
   General-purpose programming language and build system...

3. Introduction | Zig Programming Language Documentation
   URL: https://ziglang.org/documentation/master/
   Zig is a general-purpose programming language and build system...
```

---

## 后续增强 (可选)

- [ ] 支持 Google Custom Search API (更精确结果)
- [ ] 支持搜索结果缓存
- [ ] 支持搜索结果相关性评分
- [ ] 与 Lightpanda browser 工具结合 (获取完整页面内容)

---

## 相关文档

- `docs/research/lightpanda-browser-analysis.md` (浏览器工具分析)
- `src/agent/tools/web_search.zig` (现有文件)
- DuckDuckGo HTML API: https://duckduckgo.com/html/

---

**阻塞**: 无  
**依赖**: HTTP client (已有)  
**创建日期**: 2026-04-05
