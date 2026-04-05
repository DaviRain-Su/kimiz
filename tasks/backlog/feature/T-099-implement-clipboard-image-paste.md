### T-099: implement-clipboard-image-paste
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 12h

**描述**:
实现剪贴板内容读取和图片粘贴，支持多模态输入。

kimi-cli 支持从剪贴板粘贴文本、图片、截图。本任务需要：
1. 实现跨平台剪贴板文本读取（macOS/Linux/Windows）
2. 实现图片从剪贴板读取（macOS pbpaste、Linux xclip/xsel、Windows PowerShell）
3. 将图片内容转换为 base64 或文件路径，传递给多模态 Provider
4. 支持用户发送截图并让 AI 分析（如分析报错截图）
5. 先支持 Kimi/Google 等有多模态能力的 Provider

参考: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md (GAP-10)

**验收标准**:
- [ ] 核心功能实现
- [ ] 集成到主循环/CLI
- [ ] 基础测试覆盖
- [ ] 文档更新

**依赖**: 

**笔记**:
- 来自差距分析文档: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md
