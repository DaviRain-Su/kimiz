# Lightpanda 浏览器分析与 Kimiz Web Search 整合评估

**研究日期**: 2026-04-05  
**项目链接**: https://github.com/lightpanda-io/browser  
**评估目标**: 是否可作为 kimiz 的 web_search 工具服务

---

## 1. 项目概述

Lightpanda 是一个**轻量级、高性能的 headless 浏览器**，专为 AI 和自动化场景设计：

- **核心定位**: AI/自动化场景的浏览器
- **技术栈**: Zig (与 kimiz 同语言！)
- **架构**: 无头浏览器 (headless)，支持 JavaScript 执行
- **资源占用**: 极低 (对比 Chrome/Puppeteer)

---

## 2. 与 Kimiz Web Search 需求对比

### 2.1 Kimiz 当前 Web Search 状态

```zig
// src/agent/tools/web_search.zig (当前)
// ⚠️ TODO: 只有 placeholder，未实现
// 需要:
// 1. 搜索 API 集成 (DuckDuckGo, Google, etc.)
// 2. 结果解析格式化
// 3. 速率限制和错误处理
```

**当前问题**:
- ❌ 未实现实际搜索功能
- ❌ 需要依赖外部搜索 API
- ❌ API 可能有 rate limit / 成本

### 2.2 Lightpanda 能做什么？

| 能力 | Lightpanda | 传统 Web Search API | 说明 |
|------|-----------|---------------------|------|
| **网页渲染** | ✅ 完整 DOM | ❌ 仅文本 | 可执行 JS，获取动态内容 |
| **搜索功能** | ❌ 无内置 | ✅ 有 | Lightpanda 是浏览器，不是搜索引擎 |
| **资源占用** | ✅ 极低 | - | 适合嵌入 |
| **JavaScript** | ✅ 支持 | ❌ 不支持 | 可获取 React/Vue 渲染内容 |
| **同语言** | ✅ Zig | - | 与 kimiz 完美兼容 |

### 2.3 关键结论

> **Lightpanda 不是搜索引擎，它是浏览器**

**不能直接替代 web_search**，但可以作为**网页获取和渲染工具**。

---

## 3. 适用场景分析

### 场景 1: Web Search (搜索) ❌ 不合适

```
用户需求: "搜索 Zig 最佳实践"

Lightpanda:
  - 无法直接搜索
  - 需要配合搜索引擎 API (Google/DuckDuckGo)
  
传统方案:
  - DuckDuckGo API
  - Google Custom Search
  - Bing API
```

### 场景 2: 网页获取和渲染 ✅ 合适

```
用户需求: "获取 https://example.com 的内容"

Lightpanda:
  - 加载页面
  - 执行 JavaScript
  - 提取渲染后的 DOM
  - 转换为 Markdown
  
优势:
  - 支持 SPA (单页应用)
  - 获取动态内容
  - 比 curl/wget 更强大
```

### 场景 3: 网页操作 (点击、表单) ✅ 合适

```
用户需求: "在页面上执行操作"

Lightpanda:
  - 点击按钮
  - 填写表单
  - 截图
  - 提取特定元素
```

---

## 4. 整合方案建议

### 方案 A: Lightpanda 作为 Browser 工具 (推荐)

不是替代 `web_search`，而是增强 `url_summary` 或新增 `browser` 工具：

```zig
// src/agent/tools/browser.zig (新工具)
pub const BrowserTool = struct {
    // 使用 Lightpanda 加载和渲染网页
    
    pub fn fetchAndRender(url: []const u8) !RenderedPage {
        // 调用 Lightpanda 浏览器
        const page = try lightpanda.fetch(url);
        
        // 执行 JavaScript (等待页面加载)
        try page.waitForLoad();
        
        // 转换为 Markdown
        const markdown = try page.toMarkdown();
        
        return RenderedPage{
            .url = url,
            .title = page.getTitle(),
            .content = markdown,
            .links = page.getLinks(),
        };
    }
};
```

**使用场景**:
```bash
# 获取网页内容 (支持 JS 渲染)
$ kimiz tool browser --url "https://docs.ziglang.org" --render

# 对比 url_summary (当前只有文本提取)
$ kimiz tool url_summary --url "https://example.com"  # 静态提取
```

### 方案 B: Web Search + Lightpanda 组合

```
web_search (DuckDuckGo API)
    ↓ 返回搜索结果
Lightpanda (Browser)
    ↓ 获取和渲染具体页面
Markdown 内容
```

**流程**:
1. `web_search` 获取搜索结果 (链接列表)
2. `browser` 工具用 Lightpanda 加载具体页面
3. 提取内容并总结

### 方案 C: 不整合 Lightpanda

如果需求只是简单搜索，直接用 DuckDuckGo API 更简单：

```zig
// web_search.zig 实现 (DuckDuckGo)
pub fn searchDuckDuckGo(query: []const u8) !SearchResults {
    const url = try std.fmt.allocPrint(arena, 
        "https://html.duckduckgo.com/html/?q={s}", 
        .{query}
    );
    // 解析 HTML 结果
}
```

---

## 5. 技术评估

### 5.1 集成复杂度

| 方案 | 复杂度 | 工作量 | 依赖 |
|------|--------|--------|------|
| Lightpanda Browser 工具 | 中 | 8-12h | Lightpanda 库 |
| DuckDuckGo API | 低 | 2-4h | HTTP client |
| 两者都有 | 高 | 16-20h | - |

### 5.2 语言兼容性 ✅ 优秀

```
kimiz: Zig
Lightpanda: Zig

→ 可以直接 import 为 Zig 模块
→ 无需 FFI/C 绑定
→ 编译为单一二进制
```

### 5.3 性能对比

| 指标 | Lightpanda | Puppeteer/Playwright | curl |
|------|-----------|---------------------|------|
| 启动时间 | < 100ms | 1-3s | < 50ms |
| 内存占用 | ~10MB | ~100MB+ | ~1MB |
| JS 执行 | ✅ | ✅ | ❌ |
| 资源占用 | 极低 | 高 | 极低 |

---

## 6. 决策建议

### 推荐方案: **方案 A + 简单 Web Search**

```
kimiz 工具集
├── web_search (DuckDuckGo API)     [简单搜索]
│   └── 返回: 链接列表 + 摘要
│
├── browser (Lightpanda)            [网页渲染]
│   └── 返回: 渲染后的 Markdown
│   └── 支持: JS 执行、元素提取
│
└── url_summary (curl + 解析)       [简单获取]
    └── 返回: 静态 HTML 转 Markdown
```

### 优先级

| 工具 | 优先级 | 理由 |
|------|--------|------|
| web_search (DuckDuckGo) | P1 | 先解决"有无"问题 |
| browser (Lightpanda) | P2 | 增强功能，处理复杂页面 |
| url_summary | P3 | 可合并到 browser |

---

## 7. 实施路线图

### Phase 1: 基础 Web Search (本周)

```
实现 web_search.zig:
├── DuckDuckGo API 集成
├── 结果解析 (HTML → 结构化)
└── Rate limit 处理
```

### Phase 2: Lightpanda Browser (下周)

```
集成 Lightpanda:
├── 添加为 Zig 依赖
├── 创建 browser.zig 工具
├── 支持 fetch + render
└── Markdown 转换
```

### Phase 3: 工具协同 (可选)

```
web_search 返回链接
    ↓
browser 获取具体内容
    ↓
summary 生成最终答案
```

---

## 8. 风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| Lightpanda 不成熟 | 中 | 先用 DuckDuckGo，逐步引入 |
| 页面渲染慢 | 低 | 设置 timeout，fallback 到静态提取 |
| JS 执行安全问题 | 中 | 沙箱环境，限制网络访问 |

---

## 9. 关键结论

> **"Lightpanda 不适合直接作为 web_search，但作为 browser 工具很有价值"**

| 问题 | 答案 |
|------|------|
| 能替代 web_search? | ❌ 不能，它不是搜索引擎 |
| 能作为 browser 工具? | ✅ 可以，渲染网页能力强 |
| 值得整合吗? | ✅ 值得，特别是处理 SPA/Dynamic 内容 |
| 优先级? | P2 (先解决基础 web_search) |

### 一句话建议

> **先用 DuckDuckGo API 实现 web_search，再用 Lightpanda 实现 browser 工具作为增强。**

---

## 参考

- Lightpanda: https://github.com/lightpanda-io/browser
- Kimiz web_search: `src/agent/tools/web_search.zig` (TODO)
- DuckDuckGo API: https://duckduckgo.com/api (需要确认可用性)

---

*文档版本: 1.0*  
*最后更新: 2026-04-05*  
*维护者: kimiz-core-team*
