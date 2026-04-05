### T-089: implement-slash-commands-framework
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 12h

**描述**:
建立统一的 Slash 命令框架，并逐个实现高频命令。

这是与官方 kimi-cli 的中等差距之一（GAP-8）。kimi-cli 有 20+ 个 Slash 命令。本任务需要：
1. 设计 Slash command parser 和路由机制
2. 实现基础命令：`/help`, `/new`, `/clear`, `/compact`
3. 实现会话命令：`/export`, `/import`, `/title`, `/sessions`, `/resume`
4. 实现模式命令：`/plan`, `/yolo`
5. 实现工具命令：`/editor`, `/model`, `/add-dir`

参考文档: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md

**验收标准**:
- [ ] 核心功能实现
- [ ] 集成到主循环/CLI
- [ ] 基础测试覆盖
- [ ] 文档更新

**依赖**: 

**笔记**:
- 来自差距分析文档: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md
