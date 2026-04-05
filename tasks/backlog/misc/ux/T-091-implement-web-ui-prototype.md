### T-091: implement-web-ui-prototype
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 20h

**描述**:
实现 Web UI 原型，让用户可以在浏览器中使用 KimiZ。

这是与官方 kimi-cli 的核心差距之一（GAP-1）。kimi-cli 有完整的 `kimi web` 浏览器界面。本任务需要：
1. 用 Zig 的 HTTP server 实现后端 API（聊天、会话、文件引用）
2. 实现一个轻量级前端（建议纯 HTML/JS 或 Preact）
3. 支持基础的聊天界面、流式输出、代码高亮
4. 实现 `kimiz web` 子命令启动 Web UI
5. 第一阶段以"能用"为目标，不要求完整替代 CLI

参考文档: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md

**验收标准**:
- [ ] 核心功能实现
- [ ] 集成到主循环/CLI
- [ ] 基础测试覆盖
- [ ] 文档更新

**依赖**: 

**笔记**:
- 来自差距分析文档: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md
