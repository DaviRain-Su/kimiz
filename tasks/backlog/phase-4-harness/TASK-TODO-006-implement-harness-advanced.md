# TASK-TODO-006: 实现 Harness 高级功能

**状态**: pending  
**优先级**: P2  
**类型**: Feature  
**预计耗时**: 8小时  
**阻塞**: 无 (增强功能)

## 描述

Harness 系统的一些高级功能需要实现。

## 受影响的文件

- **src/harness/context_truncation.zig**
  - `truncateWithSummarization()` (第 149 行) - TODO: Implement actual summarization using AI

- **src/harness/reasoning_trace.zig**
  - `loadTrace()` (第 255 行) - TODO: Implement full deserialization

## 功能需求

### 1. AI 驱动的上下文摘要
- 使用 AI 模型对长上下文进行摘要
- 保留关键信息
- 可配置的摘要长度

### 2. Reasoning Trace 完整序列化
- 完整的 trace 保存/加载
- 支持历史 trace 查询
- Trace 分析和可视化

## 验收标准

- [ ] 上下文摘要功能
- [ ] 摘要质量评估
- [ ] Trace 完整序列化
- [ ] Trace 查询接口
- [ ] 性能测试

## 依赖

- TASK-TODO-001 (JSON 序列化)
- AI Provider 功能正常

## 相关任务

- TASK-FEAT-012 (Reasoning Trace)
- TASK-FEAT-008 (Context Truncation)
