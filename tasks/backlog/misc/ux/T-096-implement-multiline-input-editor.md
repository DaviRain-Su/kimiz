### T-096: implement-multiline-input-editor
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 6h

**描述**:
实现多行输入和外部编辑器集成，改善长文本输入体验。

kimi-cli 支持 Shift-Enter 换行和 `/editor` 调用外部编辑器。本任务需要：
1. 在 REPL 中支持 Shift-Enter 输入多行文本（不直接发送）
2. 实现 `/editor` 命令，调用 `$EDITOR` 编辑临时文件
3. 编辑器保存后自动将内容作为用户输入发送
4. 支持粘贴多行文本时的自动处理
5. 在 TUI 模式下（如果已启用）提供更好的多行编辑框

参考: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md (GAP-14)

**验收标准**:
- [ ] 核心功能实现
- [ ] 集成到主循环/CLI
- [ ] 基础测试覆盖
- [ ] 文档更新

**依赖**: 

**笔记**:
- 来自差距分析文档: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md
