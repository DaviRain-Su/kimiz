### T-088: implement-plan-mode
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 10h

**描述**:
实现 Plan 模式（只读规划模式），让 AI 在动手改代码前先探索代码库并生成规划文件。

这是与官方 kimi-cli 的中等差距之一（GAP-6）。kimi-cli 的 Plan 模式下 AI 只能使用 ReadFile/Grep/Glob 等只读工具。本任务需要：
1. 在 Agent loop 中增加 Plan mode 状态
2. 限制 Plan mode 下的可用工具（只读工具）
3. 实现 Shift-Tab 或 `/plan` 命令切换
4. AI 输出规划到 Markdown 文件
5. 用户审批后可自动执行规划

参考文档: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md

**验收标准**:
- [ ] 核心功能实现
- [ ] 集成到主循环/CLI
- [ ] 基础测试覆盖
- [ ] 文档更新

**依赖**: 

**笔记**:
- 来自差距分析文档: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md
