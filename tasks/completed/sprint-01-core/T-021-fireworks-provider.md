### T-021: 实现 Fireworks Provider
**状态**: completed
**优先级**: P2
**创建**: 2026-04-05
**完成**: 2026-04-05
**预计耗时**: 3h
**实际耗时**: 3h

**描述**:
实现 Fireworks AI Provider，支持开源模型托管服务。

**文件**:
- `src/ai/providers/fireworks.zig`

**已实现功能**:
- [x] 请求/响应序列化
- [x] 流式/非流式调用
- [x] 工具调用支持
- [x] 错误处理

**支持的模型**:
- Llama 3.1 系列
- Mistral 系列
- 其他开源模型

**验收标准**:
- [x] 非流式调用成功
- [x] 流式输出正常
- [x] 兼容 OpenAI API 格式

**依赖**: T-002, T-003, T-004

**笔记**:
Fireworks Provider 实现，兼容 OpenAI API 接口。
