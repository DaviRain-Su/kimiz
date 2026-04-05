### T-092: enable-subagent-tool
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 8h

**描述**:
启用 Subagent 工具，让 KimiZ 支持创建子代理处理子任务。

这是 kimi-cli 的独有特性之一。KimiZ 的 `src/agent/subagent.zig` 已有代码实现，但尚未在主 Agent 循环中作为可用工具暴露。本任务需要：
1. 将 `subagent.zig` 注册为可用的 Agent 工具
2. 定义 Subagent 的调用接口（任务描述、上下文传递）
3. 确保子代理的结果能正确返回到父代理的上下文中
4. 限制子代理的递归深度，防止无限派生
5. 添加基础测试验证子代理工作流

参考: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md (GAP-15)

**验收标准**:
- [ ] 核心功能实现
- [ ] 集成到主循环/CLI
- [ ] 基础测试覆盖
- [ ] 文档更新

**依赖**: 

**笔记**:
- 来自差距分析文档: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md
