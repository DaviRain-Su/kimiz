# Kimiz 工具评估总览

**创建日期**: 2026-04-05  
**更新日期**: 2026-04-05  
**说明**: 本文档汇总所有外部工具评估结果，作为工具整合决策的参考

---

## 评估结果汇总

### ✅ 已确认整合的工具

| 工具 | 功能 | 优先级 | 状态 | 决策理由 |
|------|------|--------|------|---------|
| **fff** | 文件搜索 | P0 | 待实现 | 每天使用50+次，核心刚需，比 ripgrep 快100倍 |
| **web_search** | 网络搜索 (DuckDuckGo) | P1 | 待实现 | 基础功能，解决"有无"问题，发现信息必备 |
| **browser** | 网页渲染 (Lightpanda) | P2 | 待实现 | SPA/动态内容支持，与 web_search 协作 |
| **zpdf** | PDF 处理 | P2 | 待实现 | 技术文档常见格式，有用的补充功能 |

### ❌ 确认不整合的工具

| 工具 | 功能 | 决策 | 决策理由 | 替代方案 |
|------|------|------|---------|---------|
| **odiff** | 图像差异比较 | ❌ 不整合 | 图像处理非核心场景，使用频率极低 | `bash: odiff` |
| **zigimg** | 图像处理 | ❌ 不整合 | Coding Agent 很少处理图像，频率极低 | `bash: ImageMagick` |
| **ziggy-pydust** | Python 互操作 | ❌ 不整合 | kimiz 是 CLI 工具，不需要 Python 集成 | 不需要 |

### ⚠️ 保持关注的工具

| 工具 | 功能 | 状态 | 关注理由 | 未来可能 |
|------|------|------|---------|---------|
| **zmx** | Matrix 聊天客户端 | 保持关注 | 可选的通知功能，多用户协作有价值 | 通知工具 / Matrix Bot 模式 |
| **zlob** | 存储/缓存/序列化 | 🔍 评估中 | Dmitriy Kovalenko 新作，可能的高性能存储方案 | 缓存系统 / Session 存储 |

### 🏗️ 基础设施工具

| 工具 | 功能 | 状态 | 用途 |
|------|------|------|------|
| **mcp.zig** | MCP 客户端 | ✅✅ 强烈推荐 | 统一 MCP 工具集成，简化所有工具调用 |
| **yazap** | CLI 解析库 | ✅ 推荐 | 重构 kimiz CLI，提升可维护性 |
| **zBench** | 基准测试 | ✅ 开发依赖 | kimiz 自身性能测试 |
| **raze-tui** | TUI 库 | 🔍 评估中 | 可能加速 TUI 界面开发 |
| **Kiesel** | JS 引擎 | ⚠️ 保持关注 | 嵌入式 JS 执行，当前不需要 |
| **Kiesel Runtime** | JS 运行时 | ⚠️ 保持关注 | Kiesel 配套，相同结论 |
| **Celer** | 待确认 | 🔍 评估中 | 项目名称暗示性能相关功能 |
| **zg** | 待确认 | 🔍 评估中 | 需要确认核心功能 |

### 🖥️ 开发环境工具

| 工具 | 类型 | 状态 | 说明 |
|------|------|------|------|
| **Ghostty** | 终端模拟器 | ✅ 推荐 | 开发/运行环境，GPU 加速提升 TUI 体验 |
| **River** | Wayland 合成器 | ✅ 推荐 | Linux 窗口管理器，平铺式工作流 |
| **Ly** | TUI 登录管理器 | ✅ 推荐 | 极简 Linux 系统的 TUI 登录界面 |

---

## 详细评估文档

### 研究文档列表

```
docs/research/
├── fff-search-integration-analysis.md           ✅ 整合 [P0]
├── lightpanda-browser-analysis.md               ✅ 整合 [P2]
├── zpdf-pdf-processing-analysis.md              ✅ 整合 [P2]
├── autoagent-meta-harness-analysis.md           📚 参考
├── harness-four-pillars-nyk-analysis.md         📚 参考
├── odiff-image-diff-analysis.md                 ❌ 不整合
├── zigimg-image-processing-analysis.md          ❌ 不整合
├── zmx-zig-matrix-analysis.md                   ⚠️ 关注
└── ziggy-pydust-python-interop-analysis.md      ❌ 不整合
```

### 任务文件列表

```
tasks/backlog/feature/
├── TASK-TOOL-001-integrate-fff-mcp.md           [P0] fff MCP Server
├── TASK-TOOL-002-integrate-fff-cffi.md          [P2] fff C FFI (可选)
├── TASK-TOOL-004-implement-web-search-duckduckgo.md [P1] Web Search
├── TASK-TOOL-005-integrate-lightpanda-browser.md    [P2] Browser
└── TASK-TOOL-006-integrate-zpdf-pdf-tool.md     [P2] PDF 处理
```

---

## 决策标准

### 整合标准 (必须满足 2+ 条)

- [ ] **高频使用**: 每天使用 5+ 次
- [ ] **核心场景**: 代码开发的核心需求
- [ ] **性能优势**: 比现有方案显著更好
- [ ] **生态契合**: 与 kimiz 定位一致

### 不整合标准 (满足 1 条即可)

- [ ] **低频使用**: 每周使用 < 3 次
- [ ] **场景偏离**: 非代码开发场景
- [ ] **替代方案**: bash 工具可直接调用
- [ ] **架构冲突**: 与 CLI 工具定位冲突

---

## 工具分类矩阵

### 按功能分类

```
核心开发工具 (P0-P1):
├── fff              文件搜索
├── web_search       网络搜索
└── grep (将被替换)   文本搜索

增强工具 (P2):
├── browser          网页渲染
├── zpdf             PDF 处理
└── glob             文件匹配

不整合工具:
├── odiff            图像差异
├── zigimg           图像处理
└── ziggy-pydust     Python 互操作

未来可能:
└── zmx              Matrix 聊天
```

### 按优先级分类

```
P0 (本周):
└── fff MCP Server 集成

P1 (下周):
├── web_search DuckDuckGo 实现
└── (与核心功能并行)

P2 (未来):
├── Lightpanda browser 集成
├── zpdf PDF 处理
└── fff C FFI 高性能版本
```

---

## 使用场景对照

| 用户场景 | 推荐工具 | 不推荐的替代 |
|---------|---------|-------------|
| "找 main.zig 文件" | fff | grep (慢，即将被替换) |
| "搜索 Zig 最佳实践" | web_search | - |
| "获取 React 文档" | browser | url_summary (不支持 JS) |
| "分析 PDF 规范文档" | zpdf | - |
| "比较两个截图" | bash: odiff | 不整合 odiff |
| "查看图片信息" | bash: identify | 不整合 zigimg |
| "Python 数据处理" | bash: python | 不整合 ziggy-pydust |
| "任务完成通知" | (未来) zmx | - |

---

## 下一步行动

### 立即开始 (本周)

1. **TASK-TOOL-001**: fff MCP Server 集成 [P0]
2. **TASK-TOOL-004**: web_search 实现 [P1]

### 并行进行

3. **代码修复**: CRITICAL-FIXES-SUMMARY.md 中的 Bug 修复
4. **基础设施**: LMDB 依赖评估

### 下周计划

5. **TASK-TOOL-005**: Lightpanda browser 集成 [P2]
6. **TASK-TOOL-006**: zpdf PDF 处理 [P2]

---

## 附录: 工具评估时间线

```
2026-04-05 评估工具:
├── ✅ fff          - 整合 [P0]
├── ✅ web_search   - 整合 [P1]
├── ✅ browser      - 整合 [P2]
├── ✅ zpdf         - 整合 [P2]
├── ❌ odiff        - 不整合
├── ❌ zigimg       - 不整合
├── ⚠️ zmx          - 保持关注
└── ❌ ziggy-pydust - 不整合
```

---

## 参考

- **总览文档**: `tasks/CRITICAL-FIXES-SUMMARY.md`
- **四大支柱**: `tasks/FOUR-PILLARS-TASKS.md`
- **Web 搜索路线**: `tasks/WEB-SEARCH-TOOLS-ROADMAP.md`
- **研究目录**: `docs/research/`

---

*文档版本: 1.0*  
*最后更新: 2026-04-05*
