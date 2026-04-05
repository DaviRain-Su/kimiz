### T-122: cross-agent-event-bus
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 16h

**描述**:
实现跨 Agent 事件总线，让物理隔离的子代理能够感知彼此的状态变更。

在保持文件系统隔离的同时，建立受控的上下文共享。需要：
1. 设计轻量级 Event Bus 架构（内存队列 + 可选持久化）
2. 定义标准事件类型：file_modified, file_deleted, test_completed, build_failed, skill_generated 等
3. 子代理在执行关键操作前可查询事件总线："是否有其他 agent 正在修改这个文件？"
4. 实现事件的订阅/发布机制和 TTL（过期自动清理）
5. 可选：集成到 TUI/CLI 的实时监控面板

参考文档: docs/SWARM-PENBERG-ANALYSIS.md, docs/NULLCLAW-ANALYSIS.md (NullClaw bus.zig)

**验收标准**:
- [ ] 核心设计/原型实现
- [ ] 集成测试通过
- [ ] 与现有任务（T-094, T-110, T-115）兼容
- [ ] 文档更新

**依赖**: 

**笔记**:
- 来自 Swarm 分析文档: docs/SWARM-PENBERG-ANALYSIS.md
- 这是 KimiZ 构建"物理隔离 + 受控协同"子代理模型的核心组成部分
