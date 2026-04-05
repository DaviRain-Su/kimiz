### T-020: 实现 Kimi Provider
**状态**: completed
**优先级**: P1
**创建**: 2026-04-05
**完成**: 2026-04-05
**预计耗时**: 4h
**实际耗时**: 4h

**描述**:
实现 Kimi (Moonshot AI) Provider，支持 k1 等模型。

**文件**:
- `src/ai/providers/kimi.zig`

**已实现功能**:
- [x] 请求/响应序列化
- [x] 流式/非流式调用
- [x] streamCode 特殊支持（k1 模型）
- [x] 工具调用支持
- [x] Token 成本计算

**支持的模型**:
- k1 (特殊流式支持)
- moonshot-v1-8k
- moonshot-v1-32k
- moonshot-v1-128k

**验收标准**:
- [x] 非流式调用成功
- [x] 流式输出正常
- [x] k1 模型 streamCode 正常
- [x] 工具调用正确解析

**依赖**: T-002, T-003, T-004

**笔记**:
完整的 Kimi Provider 实现，包含 k1 模型的特殊处理。
注意：Authorization header 内存泄漏，参见 TASK-BUG-002。
