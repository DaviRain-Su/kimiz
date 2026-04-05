### T-090: implement-acp-server-mode
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 16h

**描述**:
实现 ACP (Agent Client Protocol) 服务器模式，让 KimiZ 能与 IDE 集成。

这是与官方 kimi-cli 的核心差距之一（GAP-2）。kimi-cli 通过 `kimi acp` 支持 VS Code、Zed、JetBrains。本任务需要：
1. 研究 ACP 协议规范
2. 实现 `kimiz acp` 子命令，启动 ACP server
3. 支持 stdio transport（最简单）
4. 处理 IDE 的线程创建、消息收发、工具调用
5. 提供基础的 IDE 集成文档

参考文档: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md

**验收标准**:
- [ ] 核心功能实现
- [ ] 集成到主循环/CLI
- [ ] 基础测试覆盖
- [ ] 文档更新

**依赖**: 

**笔记**:
- 来自差距分析文档: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md
