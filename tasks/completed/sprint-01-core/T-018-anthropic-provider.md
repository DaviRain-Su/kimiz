### T-018: 实现 Anthropic Provider
**状态**: completed
**优先级**: P1
**创建**: 2026-04-05
**完成**: 2026-04-05
**预计耗时**: 4h
**实际耗时**: 4h

**描述**:
实现 Anthropic (Claude) Provider，支持 Claude 3.5 Sonnet 等模型。

**文件**:
- `src/ai/providers/anthropic.zig`

**已实现功能**:
- [x] 请求/响应序列化
- [x] 流式/非流式调用
- [x] 工具调用支持
- [x] Token 成本计算
- [x] 错误处理

**支持的模型**:
- Claude 3.5 Sonnet
- Claude 3 Opus
- Claude 3 Haiku

**验收标准**:
- [x] 非流式调用成功
- [x] 流式输出正常
- [x] 工具调用正确解析
- [x] 成本计算准确

**依赖**: T-002, T-003, T-004

**笔记**:
完整的 Anthropic Provider 实现，与 OpenAI Provider 接口一致。
注意：StreamContext 存在未使用问题，参见 TASK-BUG-009。
