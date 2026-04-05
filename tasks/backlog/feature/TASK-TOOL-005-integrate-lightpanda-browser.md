# TASK-TOOL-005: 集成 Lightpanda Browser 工具

**状态**: pending  
**优先级**: P2  
**预计工时**: 12小时  
**指派给**: TBD  
**标签**: tools, browser, web-rendering, zig-native

---

## 背景

kimiz 当前缺少能够渲染 JavaScript、处理动态网页的工具：

- `url_summary`: 只能提取静态 HTML
- `web_search`: 只返回搜索结果链接
- **缺失**: 获取 SPA (React/Vue) 页面内容的能力

**Lightpanda** (https://github.com/lightpanda-io/browser) 是一个 Zig 编写的轻量级 headless 浏览器，非常适合嵌入到 kimiz 中。

**研究文档**: `docs/research/lightpanda-browser-analysis.md`

---

## 目标

集成 Lightpanda 作为 `browser` 工具，提供网页渲染和 JavaScript 执行能力。

---

## 为什么选 Lightpanda?

| 特性 | Lightpanda | Puppeteer | Playwright | 说明 |
|------|-----------|-----------|------------|------|
| **语言** | ✅ Zig | Node.js | Node.js | 与 kimiz 同语言 |
| **启动时间** | ✅ < 100ms | 1-3s | 1-3s | 快 10-30 倍 |
| **内存占用** | ✅ ~10MB | ~100MB | ~100MB | 轻 10 倍 |
| **单二进制** | ✅ 是 | ❌ 否 | ❌ 否 | 易于分发 |
| **JS 执行** | ✅ 支持 | ✅ 支持 | ✅ 支持 | 必需 |
| **资源占用** | ✅ 极低 | 高 | 高 | 适合嵌入 |

---

## 技术方案

### 方案选择

| 方案 | 复杂度 | 性能 | 推荐 |
|------|--------|------|------|
| A. Zig 模块导入 | 中 | 最优 | ✅ 首选 |
| B. Subprocess | 低 | 好 | 备选 |
| C. MCP Server | 低 | 好 | 备选 |

### 方案 A: Zig 模块导入 (推荐)

```
kimiz (Zig)
    ↓ @import("lightpanda")
Lightpanda (Zig module)
    ↓
渲染结果
```

**build.zig 配置**:
```zig
// build.zig
const lightpanda = b.dependency("lightpanda", .{
    .target = target,
    .optimize = optimize,
});

exe.addModule("lightpanda", lightpanda.module("lightpanda"));
```

### 方案 B: Subprocess (备选)

如果 Lightpanda 不提供 Zig 模块，可作为 CLI 工具调用：

```bash
lightpanda --url "https://example.com" --format markdown
```

---

## 实现细节

### 1. Browser 工具结构

```zig
// src/agent/tools/browser.zig
const std = @import("std");
const tool = @import("../tool.zig");

// 导入 Lightpanda (如果作为模块提供)
const lightpanda = @import("lightpanda");

pub const tool_definition = tool.Tool{
    .name = "browser",
    .description = 
        "Fetch and render web pages using a headless browser. " ++
        "Supports JavaScript execution, useful for SPAs (React/Vue) and dynamic content. " ++
        "Converts rendered page to markdown for analysis.",
    .parameters_json =
        \\{
        \\  "type": "object",
        \\  "properties": {
        \\    "url": {
        \\      "type": "string",
        \\      "description": "URL to fetch and render"
        \\    },
        \\    "wait_for": {
        \\      "type": "string",
        \\      "description": "Optional: CSS selector to wait for (e.g., \".content-loaded\")",
        \\      "default": null
        \\    },
        \\    "timeout_ms": {
        \\      "type": "number",
        \\      "description": "Timeout in milliseconds (default: 5000)",
        \\      "default": 5000
        \\    },
        \\    "format": {
        \\      "type": "string",
        \\      "enum": ["markdown", "text", "html"],
        \\      "description": "Output format",
        \\      "default": "markdown"
        \\    }
        \\  },
        \\  "required": ["url"]
        \\}
    ,
};

pub const BrowserContext = struct {
    allocator: std.mem.Allocator,
    
    pub fn execute(self: *BrowserContext, arena: std.mem.Allocator, args: std.json.Value) !tool.ToolResult {
        const parsed = try tool.parseArguments(args, BrowserArgs);
        
        // Validate URL
        const url = try validateUrl(arena, parsed.url);
        
        // Fetch and render with Lightpanda
        const page = try self.fetchAndRender(url, parsed.wait_for, parsed.timeout_ms);
        defer page.deinit();
        
        // Convert to requested format
        const output = switch (parsed.format) {
            .markdown => try page.toMarkdown(arena),
            .text => try page.toText(arena),
            .html => try page.getHtml(arena),
        };
        
        return tool.textContent(arena, output);
    }
    
    fn fetchAndRender(self: *BrowserContext, url: []const u8, wait_for: ?[]const u8, timeout_ms: u32) !RenderedPage {
        // Initialize Lightpanda browser
        var browser = try lightpanda.Browser.init(self.allocator);
        defer browser.deinit();
        
        // Create new page
        var page = try browser.newPage();
        
        // Navigate to URL
        try page.navigate(url);
        
        // Wait for page load
        if (wait_for) |selector| {
            try page.waitForSelector(selector, timeout_ms);
        } else {
            try page.waitForLoad(timeout_ms);
        }
        
        // Execute any pending JavaScript
        try page.evaluate("window.scrollTo(0, document.body.scrollHeight)");  // Trigger lazy load
        
        return RenderedPage{
            .title = try page.getTitle(),
            .url = url,
            .html = try page.getContent(),
        };
    }
};

const BrowserArgs = struct {
    url: []const u8,
    wait_for: ?[]const u8 = null,
    timeout_ms: u32 = 5000,
    format: OutputFormat = .markdown,
};

const OutputFormat = enum {
    markdown,
    text,
    html,
};

const RenderedPage = struct {
    title: []const u8,
    url: []const u8,
    html: []const u8,
    
    pub fn toMarkdown(self: RenderedPage, allocator: std.mem.Allocator) ![]const u8 {
        // Convert HTML to Markdown
        // Use html2md or similar
    }
    
    pub fn toText(self: RenderedPage, allocator: std.mem.Allocator) ![]const u8 {
        // Strip HTML tags, return plain text
    }
    
    pub fn getHtml(self: RenderedPage, allocator: std.mem.Allocator) ![]const u8 {
        return allocator.dupe(u8, self.html);
    }
    
    pub fn deinit(self: *RenderedPage) void {
        // Cleanup
    }
};
```

### 2. 高级功能 (可选)

```zig
// 元素提取
pub fn extractElement(page: *Page, selector: []const u8) !Element;

// 截图
pub fn screenshot(page: *Page, path: []const u8) !void;

// 表单填写
pub fn fillForm(page: *Page, fields: []const FormField) !void;

// 点击操作
pub fn click(page: *Page, selector: []const u8) !void;

// Cookie 管理
pub fn setCookie(page: *Page, name: []const u8, value: []const u8) !void;
```

---

## 工具对比

| 场景 | url_summary (现有) | browser (Lightpanda) | 选择 |
|------|-------------------|---------------------|------|
| 静态文档网站 | ✅ 快速 | ✅ 也行 | url_summary |
| SPA (React/Vue) | ❌ 无法获取 | ✅ 完整渲染 | browser |
| 需要 JS 执行 | ❌ 不支持 | ✅ 支持 | browser |
| 简单快速获取 | ✅ < 100ms | ~500ms | url_summary |
| 完整页面内容 | ❌ 可能不完整 | ✅ 完整 | browser |

---

## 与 web_search 协作

```
用户: "搜索 Zig 最佳实践并总结"

kimiz Agent:
  1. web_search --query "Zig best practices"
     → 返回 5 个链接
     
  2. 对每个链接:
     browser --url <link> --format markdown
     → 获取完整渲染内容
     
  3. 总结所有内容
     → 生成最终答案
```

---

## 验收标准

- [ ] Lightpanda 成功集成到 kimiz build
- [ ] `browser` 工具能加载并渲染网页
- [ ] 支持 JavaScript 执行 (SPA 页面)
- [ ] 支持 timeout 配置
- [ ] 支持 wait_for selector (等待元素)
- [ ] 输出格式: markdown/text/html
- [ ] 内存占用 < 50MB (单页面)
- [ ] 渲染时间 < 5s (默认 timeout)
- [ ] 错误处理 (网络错误、timeout)
- [ ] 单元测试

---

## 依赖与阻塞

**依赖**:
- [ ] Lightpanda Zig 模块可用性 (需确认)
- [ ] HTML to Markdown 转换库

**阻塞**:
- Lightpanda 项目成熟度 (需评估)

---

## 使用示例

### 基础使用

```bash
# 获取并渲染网页
$ kimiz tool browser --url "https://docs.ziglang.org"

# 等待特定元素加载
$ kimiz tool browser --url "https://example.com/app" --wait_for "#content-loaded"

# 指定超时
$ kimiz tool browser --url "https://slow-site.com" --timeout_ms 10000

# 输出 HTML 格式
$ kimiz tool browser --url "https://example.com" --format html
```

### 与 web_search 结合

```bash
# 搜索并获取内容
$ kimiz run "搜索 Zig 异步编程最佳实践，并阅读前3个结果总结"

# Agent 内部执行:
# 1. web_search --query "Zig async best practices"
# 2. browser --url <result1>
# 3. browser --url <result2>
# 4. browser --url <result3>
# 5. 总结内容
```

---

## 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| Lightpanda 不成熟 | 高 | 先用 url_summary，逐步引入 |
| JS 执行安全问题 | 中 | 限制网络访问，沙箱执行 |
| 页面渲染慢 | 低 | 设置合理 timeout，fallback 到静态提取 |
| 内存泄漏 | 中 | 严格测试，及时 deinit |

---

## 参考

- Lightpanda: https://github.com/lightpanda-io/browser
- 研究文档: `docs/research/lightpanda-browser-analysis.md`
- 现有工具: `src/agent/tools/url_summary.zig`
- 相关任务: `TASK-TOOL-004-implement-web-search-duckduckgo.md`

---

**创建日期**: 2026-04-05  
**建议优先级**: P2 (在基础 web_search 完成后实现)
