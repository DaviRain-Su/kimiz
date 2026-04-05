### T-093: implement-thinking-mode
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 6h

**描述**:
实现 Thinking 模式切换，允许用户显式控制模型的推理深度。

kimi-cli 支持开关模型的 thinking/reasoning 模式。本任务需要：
1. 在 AI Provider 层支持 reasoning/thinking 参数传递
2. 添加 CLI flag `--thinking` 和 REPL 命令 `/thinking`
3. 在配置文件中支持 `thinking_mode` 默认设置
4. 确保 Kimi/OpenAI/Anthropic 等支持 reasoning 的模型能正确使用
5. 在状态栏或提示中显示当前 thinking 模式状态

参考: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md (GAP-11)

**验收标准**:
- [ ] 核心功能实现
- [ ] 集成到主循环/CLI
- [ ] 基础测试覆盖
- [ ] 文档更新

**依赖**: 

**笔记**:
- 来自差距分析文档: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md
