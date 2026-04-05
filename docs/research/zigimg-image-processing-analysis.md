# zigimg 图像处理库分析与 Kimiz 整合评估

**研究日期**: 2026-04-05  
**项目链接**: https://github.com/zigimg/zigimg  
**评估目标**: 是否可作为 kimiz 的图像处理工具

---

## 1. 项目概述

**zigimg** 是一个 **Zig 编写的图像处理库**，核心功能：

- **图像格式支持**: PNG, JPEG, BMP, TGA, PPM, QOI 等
- **图像操作**: 读取、写入、基本处理
- **颜色空间**: RGB, RGBA, Grayscale 等
- **语言**: Zig (与 kimiz 同语言)
- **成熟度**: ⭐⭐⭐⭐ 较成熟，社区活跃

---

## 2. 与 Kimiz 使用场景匹配度分析

### 2.1 Coding Agent 的图像需求

| 场景 | 描述 | 频率 | 相关性 |
|------|------|------|--------|
| **读取图像元数据** | 获取图片尺寸、格式 | 偶尔 | ⭐⭐⭐ 中 |
| **生成图像报告** | 代码覆盖率报告中的图表 | 很少 | ⭐⭐ 低 |
| **处理项目中的图像** | 压缩、转换格式 | 偶尔 | ⭐⭐ 低 |
| **视觉测试截图** | 测试生成图像的正确性 | 很少 | ⭐⭐ 低 |
| **文档中的图像** | README 中的示例图 | 偶尔 | ⭐⭐ 低 |

### 2.2 与 odiff 的对比

| 工具 | 功能 | 使用场景 |
|------|------|---------|
| **zigimg** | 图像读取/写入/基本处理 | 格式转换、元数据 |
| **odiff** | 图像差异比较 | 视觉回归测试 |

---

## 3. 整合方案评估

### 方案 A: 不整合 (推荐)

**理由**:
1. kimiz 是 Coding Agent，图像处理是边缘需求
2. 与 odiff 场景重叠，但 odiff 更专注差异检测
3. 可用外部工具替代 (ImageMagick, ffmpeg)

**替代方案**:
```bash
# 通过 bash 工具调用外部命令
$ kimiz tool bash --command "identify image.png"  # ImageMagick
$ kimiz tool bash --command "file image.png"      # 基本格式检测
```

### 方案 B: 专用 image 工具 (可选)

如果有图像处理需求：

```zig
// src/agent/tools/image.zig
pub const ImageTool = struct {
    pub fn getInfo(path: []const u8) !ImageInfo;      // 尺寸、格式
    pub fn convert(input: []const u8, output: []const u8, format: Format) !void;
    pub fn resize(input: []const u8, output: []const u8, width: u32, height: u32) !void;
};
```

### 方案 C: 与 odiff 结合 (未来)

如果整合 odiff，可以同时引入 zigimg 用于图像加载：

```
odiff 差异检测
    ↓
zigimg 加载图像
    ↓
差异分析
```

---

## 4. 与现有工具的对比

| 需求 | 当前方案 | zigimg 整合 | 说明 |
|------|---------|------------|------|
| **图像信息** | bash: file/identify | ✅ 内置 | 更便捷 |
| **格式转换** | bash: convert | ✅ 可集成 | 更统一 |
| **图像处理** | 外部工具 | ✅ 可编程 | 更灵活 |
| **使用频率** | - | 很低 | 边缘需求 |

---

## 5. 决策建议

### 推荐: 不整合，保持关注

> **zigimg 是优秀的库，但不是 kimiz 的优先需求**

**理由**:
1. **场景不匹配**: Coding Agent 很少处理图像
2. **替代方案**: bash 工具可调用外部命令
3. **维护成本**: 增加依赖，但收益有限

### 优先级评估

| 工具 | 功能 | 频率 | 优先级 | 决策 |
|------|------|------|--------|------|
| **fff** | 文件搜索 | 每天 50+ | P0 | ✅ 整合 |
| **web_search** | 网络搜索 | 每天 10+ | P1 | ✅ 整合 |
| **browser** | 网页渲染 | 每天 5+ | P2 | ✅ 整合 |
| **zpdf** | PDF 处理 | 每周 2-3 | P2 | ✅ 整合 |
| **zigimg** | 图像处理 | 每月几次 | - | ❌ 不整合 |
| **odiff** | 图像差异 | 很少 | - | ❌ 不整合 |
| **zmx** | Matrix 聊天 | 未知 | - | ❌ 保持关注 |

---

## 6. 结论

### 一句话总结

> **"zigimg 是成熟的图像库，但 kimiz 不需要内置图像处理功能"**

### 建议

| 情况 | 行动 |
|------|------|
| **当前** | 不整合，通过 bash 调用外部工具 |
| **有图像需求时** | 使用 ImageMagick / ffmpeg |
| **未来扩展** | 如需图像功能，再评估 zigimg |

---

## 7. 如果将来需要...

### 可能的实现

```zig
// src/agent/tools/image.zig (未来可能)
const zigimg = @import("zigimg");

pub const ImageTool = struct {
    pub fn getInfo(path: []const u8) !ImageInfo {
        const img = try zigimg.Image.fromFilePath(allocator, path);
        return ImageInfo{
            .width = img.width,
            .height = img.height,
            .format = img.format,
        };
    }
};
```

### 使用示例 (假设)

```bash
# 获取图像信息
$ kimiz tool image --action info --file "screenshot.png"
→ Width: 1920, Height: 1080, Format: PNG

# 格式转换
$ kimiz tool image --action convert --input "photo.jpg" --output "photo.png"
```

---

## 参考

- zigimg: https://github.com/zigimg/zigimg
- 相关工具评估:
  - `docs/research/odiff-image-diff-analysis.md`
  - `docs/research/zpdf-pdf-processing-analysis.md`

---

*文档版本: 1.0*  
*最后更新: 2026-04-05*  
*维护者: kimiz-core-team*
