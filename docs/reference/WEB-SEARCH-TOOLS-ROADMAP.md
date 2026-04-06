# Kimiz Web 搜索工具路线图

**创建日期**: 2026-04-05  
**目标**: 为 kimiz 提供完整的 Web 信息获取能力

---

## 工具概览

```
┌─────────────────────────────────────────────────────────────────┐
│                    Kimiz Web 工具矩阵                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  web_search (DuckDuckGo)                                       │
│  ├── 输入: 查询关键词                                           │
│  ├── 输出: 搜索结果列表 (标题+URL+摘要)                         │
│  ├── 适用: 发现信息、找链接                                     │
│  └── 优先级: P1                                                │
│                                                                 │
│  browser (Lightpanda)                                          │
│  ├── 输入: URL                                                  │
│  ├── 输出: 渲染后的页面 (Markdown)                              │
│  ├── 适用: SPA 页面、动态内容、JS 渲染                          │
│  └── 优先级: P2                                                │
│                                                                 │
│  url_summary (现有)                                            │
│  ├── 输入: URL                                                  │
│  ├── 输出: 静态 HTML 摘要                                       │
│  ├── 适用: 静态文档、快速获取                                   │
│  └── 状态: 已存在                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 任务清单

### P1: 基础 Web Search (本周)

```
TASK-TOOL-004: 实现 web_search (DuckDuckGo)
├── 状态: pending
├── 工时: 4h
├── 依赖: 无
├── 阻塞: 无
└── 文件: tasks/backlog/feature/TASK-TOOL-004-implement-web-search-duckduckgo.md
```

**关键功能**:
- DuckDuckGo HTML API 集成
- 结果解析 (HTML → 结构化)
- Rate limit 保护
- 错误处理和重试

### P2: Lightpanda Browser (下周)

```
TASK-TOOL-005: 集成 Lightpanda Browser
├── 状态: pending
├── 工时: 12h
├── 依赖: Lightpanda Zig 模块
├── 阻塞: Lightpanda 成熟度评估
└── 文件: tasks/backlog/feature/TASK-TOOL-005-integrate-lightpanda-browser.md
```

**关键功能**:
- Zig 模块导入
- 页面加载和渲染
- JavaScript 执行
- Markdown 转换

---

## 使用场景对比

| 场景 | web_search | browser | url_summary | 推荐 |
|------|-----------|---------|-------------|------|
| "搜索 Zig 文档" | ✅ | ❌ | ❌ | web_search |
| "获取 React 官网内容" | ❌ | ✅ | ❌ | browser |
| "快速获取静态页面" | ❌ | ⚠️ 慢 | ✅ | url_summary |
| "搜索并阅读结果" | ✅ + browser | - | - | 组合使用 |
| "SPA 应用内容" | ❌ | ✅ | ❌ | browser |

---

## 协作流程

### 场景: 搜索并总结

```
用户: "搜索 Zig 异步编程最佳实践并总结"

Agent 执行:
  1. web_search --query "Zig async best practices"
     → 返回 5 个搜索结果
     
  2. 对每个结果链接:
     browser --url <link> --format markdown
     → 获取完整渲染内容
     
  3. 分析所有内容
     → 生成最终总结
```

### 场景: 快速回答

```
用户: "Zig 的 async/await 怎么使用？"

Agent 执行:
  1. web_search --query "Zig async await tutorial"
     → 返回教程链接
     
  2. browser --url <best_result>
     → 获取教程内容
     
  3. 提取关键信息
     → 回答用户
```

---

## 实施路线图

### Phase 1: 基础 Web Search (本周)

```
Day 1-2:
├── 实现 DuckDuckGo API 调用
├── HTML 结果解析
└── 工具集成

Day 3:
├── Rate limit 保护
├── 错误处理
└── 测试和文档
```

### Phase 2: Lightpanda Browser (下周)

```
Week 1:
├── 评估 Lightpanda Zig 模块可用性
├── 集成到 build.zig
├── 实现 browser.zig 工具
└── 基础渲染功能

Week 2:
├── JavaScript 执行支持
├── Markdown 转换
├── 高级功能 (wait_for, timeout)
└── 测试和优化
```

### Phase 3: 工具协同 (可选)

```
├── web_search + browser 自动协作
├── 智能选择工具 (静态 vs 动态页面)
└── 结果缓存和优化
```

---

## 技术对比

### web_search vs browser

| 维度 | web_search (DuckDuckGo) | browser (Lightpanda) |
|------|------------------------|---------------------|
| **输入** | 查询关键词 | URL |
| **输出** | 搜索结果列表 | 渲染后的页面 |
| **JS 执行** | ❌ | ✅ |
| **适用页面** | 所有 (搜索结果) | SPA, 动态内容 |
| **速度** | ~500ms | ~1-3s (含渲染) |
| **资源** | 低 | 中 (~10MB) |
| **依赖** | 网络 | Lightpanda 模块 |

---

## 风险与决策

| 决策点 | 选择 | 理由 |
|--------|------|------|
| 搜索引擎 | DuckDuckGo | 免费、无需 API key |
| 浏览器引擎 | Lightpanda | Zig 原生、轻量级 |
| 优先级 | web_search P1 | 先解决"有无"问题 |
| 备选浏览器 | Puppeteer/Playwright | 如果 Lightpanda 不成熟 |

---

## 相关文档

- **研究分析**:
  - `docs/research/lightpanda-browser-analysis.md`
  
- **任务文件**:
  - `tasks/backlog/feature/TASK-TOOL-004-implement-web-search-duckduckgo.md`
  - `tasks/backlog/feature/TASK-TOOL-005-integrate-lightpanda-browser.md`
  
- **现有工具**:
  - `src/agent/tools/web_search.zig` (placeholder)
  - `src/agent/tools/url_summary.zig` (现有)

---

## 验收标准

### web_search (TASK-TOOL-004)

- [ ] 能成功搜索并返回结果
- [ ] 支持 1-10 个结果
- [ ] 返回标题 + URL + 摘要
- [ ] Rate limit 保护
- [ ] 错误处理

### browser (TASK-TOOL-005)

- [ ] 能加载和渲染网页
- [ ] 支持 JavaScript 执行
- [ ] 支持 timeout 配置
- [ ] 输出 Markdown 格式
- [ ] 内存占用 < 50MB

---

## 下一步行动

1. **本周**: 实现 TASK-TOOL-004 (web_search)
2. **评估**: Lightpanda 模块可用性
3. **下周**: 实现 TASK-TOOL-005 (browser)
4. **测试**: 工具协作流程

---

*文档版本: 1.0*  
*最后更新: 2026-04-05*
