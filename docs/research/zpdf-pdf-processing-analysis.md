# zpdf PDF 处理工具分析与 Kimiz 整合评估

**研究日期**: 2026-04-05  
**项目链接**: https://github.com/Lulzx/zpdf  
**评估目标**: 是否可作为 kimiz 的 PDF 处理工具

---

## 1. 项目概述

**zpdf** 是一个 **Zig 编写的 PDF 处理工具**，核心功能：

- **PDF 解析**: 提取文本、元数据
- **PDF 生成**: 创建简单 PDF 文档
- **PDF 操作**: 合并、拆分、压缩
- **语言**: Zig (与 kimiz 同语言)

---

## 2. 与 Kimiz 使用场景匹配度分析

### 2.1 Coding Agent 的 PDF 需求

| 场景 | 描述 | 频率 | 相关性 |
|------|------|------|--------|
| **阅读 PDF 文档** | 技术规范、API 文档是 PDF 格式 | 偶尔 | ⭐⭐⭐ 中 |
| **生成 PDF 报告** | 代码分析报告、文档导出 | 很少 | ⭐⭐ 低 |
| **PDF 附件处理** | Issue/PR 中有 PDF 附件 | 偶尔 | ⭐⭐ 低 |
| **文档转换** | PDF → Markdown/文本 | 偶尔 | ⭐⭐⭐ 中 |

### 2.2 核心价值

**让 kimiz 能"读懂"PDF 技术文档**：

```
用户: "分析这个 API 文档并总结"
API-Spec-v2.pdf → zpdf 提取文本 → LLM 分析 → 总结报告
```

---

## 3. 整合方案评估

### 方案 A: PDF 提取工具 (推荐)

作为专用工具用于提取 PDF 内容：

```zig
// src/agent/tools/pdf.zig
pub const PDFTool = struct {
    pub const tool_definition = tool.Tool{
        .name = "pdf",
        .description = "Extract text and metadata from PDF files",
        .parameters_json = ...
    };
    
    pub fn extractText(self: *PDFTool, pdf_path: []const u8) ![]const u8 {
        // 使用 zpdf 提取文本
    }
    
    pub fn extractMetadata(self: *PDFTool, pdf_path: []const u8) !PDFMetadata {
        // 提取作者、创建日期等信息
    }
};
```

**使用场景**:
```bash
# 提取 PDF 文本
$ kimiz tool pdf --action extract-text --file "spec.pdf"

# 提取元数据
$ kimiz tool pdf --action metadata --file "report.pdf"

# 转换为 Markdown
$ kimiz tool pdf --action to-markdown --file "doc.pdf" --output "doc.md"
```

### 方案 B: 与 url_summary 结合

下载 PDF 并自动提取：

```bash
$ kimiz tool url_summary --url "https://example.com/spec.pdf"
→ 下载 PDF → zpdf 提取文本 → 返回 Markdown 摘要
```

### 方案 C: 不整合

通过外部工具处理：

```bash
$ kimiz tool bash --command "pdftotext spec.pdf -"
```

---

## 4. 与现有工具的对比

| 需求 | 当前方案 | zpdf 整合 | 说明 |
|------|---------|----------|------|
| PDF 转文本 | bash: pdftotext | ✅ 内置 | 更便捷 |
| PDF 元数据 | bash: pdfinfo | ✅ 内置 | 更统一 |
| PDF 生成 | 外部工具 | ✅ 可生成报告 | 扩展功能 |
| 复杂 PDF | 有限支持 | 看 zpdf 能力 | 待评估 |

---

## 5. 决策建议

### 推荐: 方案 A - PDF 提取工具 (P2)

**理由**:
1. PDF 技术文档是常见需求
2. 与 kimiz "代码阅读"定位匹配
3. Zig 原生，整合成本低
4. 提升用户体验 (无需外部工具)

**优先级**: P2 (在核心工具完成后)

### 实施时机

```
Phase 1 (核心工具):
├── fff 文件搜索
├── web_search 网络搜索
└── browser 网页渲染

Phase 2 (扩展工具):
├── pdf 处理 (zpdf)
└── image 处理 (可选)
```

---

## 6. 潜在问题

| 问题 | 影响 | 缓解 |
|------|------|------|
| zpdf 成熟度 | 中 | 评估后再决定 |
| 复杂 PDF (扫描件) | 中 | 需要 OCR，超出范围 |
| 大 PDF 性能 | 低 | 分页提取 |

---

## 7. 结论

### 一句话总结

> **"zpdf 值得作为 P2 任务整合，让 kimiz 能处理 PDF 技术文档"**

### 建议

| 优先级 | 行动 |
|--------|------|
| P2 | 创建 `pdf` 工具，支持文本提取和元数据 |
| 未来 | 与 `url_summary` 结合，自动处理 PDF 链接 |

---

## 参考

- zpdf: https://github.com/Lulzx/zpdf
- 现有工具: `src/agent/tools/url_summary.zig`

---

*文档版本: 1.0*  
*最后更新: 2026-04-05*
