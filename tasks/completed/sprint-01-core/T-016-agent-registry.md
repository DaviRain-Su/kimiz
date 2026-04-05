### T-016: 实现 Agent Registry
**状态**: completed
**优先级**: P1
**创建**: 2026-04-05
**完成**: 2026-04-05
**预计耗时**: 2h
**实际耗时**: 2h

**描述**:
实现 Agent 注册表，支持多个 Agent 实例的管理和路由。

**文件**:
- `src/agent/registry.zig` (约200行)

**已实现功能**:
- [x] AgentRegistry 结构体
- [x] Agent 注册和注销
- [x] Agent 查找和路由
- [x] Agent 生命周期管理

**验收标准**:
- [x] AgentRegistry 实现完成
- [x] 支持多 Agent 管理
- [x] Agent 可正常注册和查找
- [x] 生命周期管理正确

**依赖**: T-002 (核心类型)

**笔记**:
Agent 注册表实现，支持多 Agent 场景。
