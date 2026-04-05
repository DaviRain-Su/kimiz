### T-019: 实现 Google Provider
**状态**: completed
**优先级**: P1
**创建**: 2026-04-05
**完成**: 2026-04-05
**预计耗时**: 4h
**实际耗时**: 4h

**描述**:
实现 Google (Gemini) Provider，支持 Gemini 2.0 Flash 等模型。

**文件**:
- `src/ai/providers/google.zig`

**已实现功能**:
- [x] 请求/响应序列化
- [x] 流式/非流式调用
- [x] 工具调用支持
- [x] Token 成本计算
- [x] 错误处理

**支持的模型**:
- Gemini 2.0 Flash
- Gemini 1.5 Pro
- Gemini 1.5 Flash

**验收标准**:
- [x] 非流式调用成功
- [x] 流式输出正常
- [x] 工具调用正确解析
- [x] 成本计算准确

**依赖**: T-002, T-003, T-004

**笔记**:
完整的 Google Provider 实现。
注意：URL 分配 defer 位置问题，参见 TASK-BUG-003。
