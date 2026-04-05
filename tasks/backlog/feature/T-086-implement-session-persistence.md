### T-086: implement-session-persistence
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 8h

**描述**:
实现 KimiZ 的会话持久化系统，支持会话的保存、恢复、导出和标题管理。

这是与官方 kimi-cli 的核心差距之一（GAP-5）。当前 KimiZ 仅支持单会话，进程退出即丢失上下文。本任务需要：
1. 设计 SQLite 会话表结构（messages, metadata, state）
2. 实现 `--continue` 自动恢复最近会话
3. 实现 `--session <id>` 恢复指定会话
4. 实现 `/sessions`, `/resume`, `/title` Slash 命令
5. 会话启动时 replay 历史消息

参考文档: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md

**验收标准**:
- [ ] 核心功能实现
- [ ] 集成到主循环/CLI
- [ ] 基础测试覆盖
- [ ] 文档更新

**依赖**: 

**笔记**:
- 来自差距分析文档: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md
