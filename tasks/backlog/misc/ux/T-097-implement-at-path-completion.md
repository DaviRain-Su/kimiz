### T-097: implement-at-path-completion
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 8h

**描述**:
实现 @ 路径补全功能，让用户在输入时快速引用项目文件。

kimi-cli 输入 `@` 后自动补全文件路径。本任务需要：
1. 在 REPL 输入层监听 `@` 字符触发补全
2. 复用 fff 的文件索引或实现轻量级文件扫描
3. 提供 fuzzy 路径补全列表，支持 Tab/方向键选择
4. 补全后插入文件的相对路径到输入中
5. 支持 @ 目录 和 @文件 两种引用方式

参考: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md (GAP-13)

**验收标准**:
- [ ] 核心功能实现
- [ ] 集成到主循环/CLI
- [ ] 基础测试覆盖
- [ ] 文档更新

**依赖**: 

**笔记**:
- 来自差距分析文档: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md
