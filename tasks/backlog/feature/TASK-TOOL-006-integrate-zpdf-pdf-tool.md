# TASK-TOOL-006: 集成 zpdf PDF 处理工具

**状态**: pending  
**优先级**: P2  
**预计工时**: 6小时  
**指派给**: TBD  
**标签**: tools, pdf, document-processing

---

## 背景

kimiz 当前无法直接处理 PDF 文档，而技术规范、API 文档常以 PDF 格式存在：

```
用户: "分析这个 API 规范文档"
API-Spec-v2.pdf → ❌ 无法直接读取
```

需要 PDF 提取工具来扩展文档处理能力。

---

## 目标

集成 zpdf 作为 `pdf` 工具，支持文本提取和元数据读取。

---

## 技术方案

### 为什么选择 zpdf?

| 特性 | zpdf | 外部工具 (pdftotext) |
|------|------|---------------------|
| **语言** | ✅ Zig 原生 | 外部依赖 |
| **集成度** | ✅ 直接嵌入 | 需要 subprocess |
| **性能** | ✅ 高效 | 一般 |
| **单二进制** | ✅ 是 | 否 |

### 实现细节

```zig
// src/agent/tools/pdf.zig
const std = @import("std");
const tool = @import("../tool.zig");
// const zpdf = @import("zpdf");  // 待 zpdf 提供模块接口

pub const tool_definition = tool.Tool{
    .name = "pdf",
    .description = 
        "Extract text and metadata from PDF files. " ++
        "Useful for reading technical documentation, API specifications, and reports.",
    .parameters_json =
        \\{
        \\  "type": "object",
        \\  "properties": {
        \\    "action": {
        \\      "type": "string",
        \\      "enum": ["extract_text", "metadata", "to_markdown"],
        \\      "description": "Action to perform"
        \\    },
        \\    "file_path": {
        \\      "type": "string",
        \\      "description": "Path to the PDF file"
        \\    },
        \\    "pages": {
        \\      "type": "string",
        \\      "description": "Page range (e.g., \"1-10\", \"1,3,5\", default: all)",
        \\      "default": null
        \\    },
        \\    "max_chars": {
        \\      "type": "number",
        \\      "description": "Maximum characters to extract (default: 50000)",
        \\      "default": 50000
        \\    }
        \\  },
        \\  "required": ["action", "file_path"]
        \\}
    ,
};

pub const PDFContext = struct {
    allocator: std.mem.Allocator,
    
    pub fn execute(self: *PDFContext, arena: std.mem.Allocator, args: std.json.Value) !tool.ToolResult {
        const parsed = try tool.parseArguments(args, PDFArgs);
        
        // Validate file exists
        if (!try self.fileExists(parsed.file_path)) {
            return tool.errorResult(arena, "PDF file not found");
        }
        
        // Route to action
        return switch (parsed.action) {
            .extract_text => try self.extractText(arena, parsed),
            .metadata => try self.extractMetadata(arena, parsed),
            .to_markdown => try self.convertToMarkdown(arena, parsed),
        };
    }
    
    fn extractText(self: *PDFContext, arena: std.mem.Allocator, args: PDFArgs) !tool.ToolResult {
        // Load PDF
        const document = try zpdf.Document.open(self.allocator, args.file_path);
        defer document.close();
        
        // Extract text from pages
        var text_buffer = std.ArrayList(u8).init(arena);
        
        const page_range = try self.parsePageRange(args.pages, document.getPageCount());
        
        for (page_range.start..page_range.end) |page_num| {
            const page = try document.getPage(page_num);
            const page_text = try page.extractText();
            
            try text_buffer.writer().print("\n--- Page {d} ---\n{s}\n", .{ page_num, page_text });
            
            // Check max_chars limit
            if (text_buffer.items.len > args.max_chars) {
                try text_buffer.appendSlice("\n[Truncated: exceeded max_chars limit]");
                break;
            }
        }
        
        return tool.textContent(arena, text_buffer.items);
    }
    
    fn extractMetadata(self: *PDFContext, arena: std.mem.Allocator, args: PDFArgs) !tool.ToolResult {
        const document = try zpdf.Document.open(self.allocator, args.file_path);
        defer document.close();
        
        const metadata = document.getMetadata();
        
        const output = try std.fmt.allocPrint(arena,
            \\PDF Metadata:
            \\Title: {s}
            \\Author: {s}
            \\Subject: {s}
            \\Creator: {s}
            \\Producer: {s}
            \\Creation Date: {s}
            \\Modification Date: {s}
            \\Page Count: {d}
            \\File Size: {d} bytes
        , .{
            metadata.title,
            metadata.author,
            metadata.subject,
            metadata.creator,
            metadata.producer,
            metadata.creation_date,
            metadata.mod_date,
            metadata.page_count,
            metadata.file_size,
        });
        
        return tool.textContent(arena, output);
    }
    
    fn convertToMarkdown(self: *PDFContext, arena: std.mem.Allocator, args: PDFArgs) !tool.ToolResult {
        // Extract text and format as Markdown
        const text = try self.extractText(arena, args);
        
        // Basic Markdown formatting
        // - Headers from font size
        // - Lists from bullet points
        // - Tables (if detected)
        
        return text; // Simplified
    }
};

const PDFArgs = struct {
    action: PDFAction,
    file_path: []const u8,
    pages: ?[]const u8 = null,
    max_chars: usize = 50000,
};

const PDFAction = enum {
    extract_text,
    metadata,
    to_markdown,
};
```

---

## 使用示例

### 基础使用

```bash
# 提取 PDF 文本
$ kimiz tool pdf --action extract_text --file_path "docs/spec.pdf"

# 提取指定页面
$ kimiz tool pdf --action extract_text --file_path "report.pdf" --pages "1-10"

# 提取元数据
$ kimiz tool pdf --action metadata --file_path "document.pdf"

# 转换为 Markdown
$ kimiz tool pdf --action to_markdown --file_path "article.pdf"
```

### 与 Agent 结合

```
用户: "分析这个 API 规范文档的核心设计"

Agent 执行:
1. pdf --action extract_text --file_path "API-Spec-v2.pdf"
2. LLM 分析提取的文本
3. 生成设计总结报告
```

### 与 url_summary 结合 (未来)

```bash
# 下载并分析 PDF
$ kimiz tool url_summary --url "https://example.com/api-spec.pdf"
→ 下载 PDF → zpdf 提取 → 返回 Markdown 摘要
```

---

## 验收标准

- [ ] `pdf` 工具能成功加载 PDF 文件
- [ ] `extract_text` 提取文本内容
- [ ] `metadata` 读取文档元数据
- [ ] `to_markdown` 基本 Markdown 转换
- [ ] 支持页码范围选择
- [ ] 支持 max_chars 限制 (防止超大 PDF)
- [ ] 错误处理 (文件不存在、损坏 PDF)
- [ ] 单元测试覆盖

---

## 依赖与阻塞

**依赖**:
- zpdf 提供 Zig 模块接口 (待确认)
- 或作为 external dependency 编译

**阻塞**:
- zpdf 项目成熟度评估
- 复杂 PDF 支持程度

---

## 限制说明

| 限制 | 说明 |
|------|------|
| 扫描 PDF | 不支持 (需要 OCR) |
| 复杂排版 | 可能丢失格式 |
| 图片提取 | 超出范围 |
| 加密 PDF | 需要密码 |

---

## 优先级理由

**为什么是 P2 不是 P1?**

| 工具 | 频率 | 优先级 |
|------|------|--------|
| fff (文件搜索) | 每天 50+ 次 | P0 |
| web_search (搜索) | 每天 10+ 次 | P1 |
| browser (网页) | 每天 5+ 次 | P2 |
| **pdf (文档)** | 每周 2-3 次 | **P2** |

PDF 处理是**有用的补充**，但不是**核心刚需**。

---

## 参考

- zpdf: https://github.com/Lulzx/zpdf
- 研究文档: `docs/research/zpdf-pdf-processing-analysis.md`

---

**创建日期**: 2026-04-05  
**建议实施时机**: Phase 2 (核心工具完成后)
