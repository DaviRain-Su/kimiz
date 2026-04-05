### T-120: design-supervisor-daemon-session-attach-prototype
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 18h

**描述**:
设计 KimiZ 的 Supervisor Daemon + Session attach/detach 原型，实现后台任务的持久化运行。

参考 Swarm 的 supervisor 模式，让子代理/后台任务不因主 CLI 关闭而中断。需要：
1. 设计轻量级 Supervisor Daemon 架构（可选独立进程或主进程守护线程）
2. 实现 Session 生命周期管理：create / attach / detach / stop / prune
3. 使用 Unix Domain Socket (UDS) 实现 CLI 到运行中 session 的 attach/detach
4. 每个 session 的 stdout/stderr 被持久化到日志文件
5. 支持 `kimiz session list`, `kimiz session attach <id>`, `kimiz session stop <id>` 命令

参考文档: docs/SWARM-PENBERG-ANALYSIS.md, docs/NULLCLAW-ANALYSIS.md

**验收标准**:
- [ ] 核心设计/原型实现
- [ ] 集成测试通过
- [ ] 与现有任务（T-094, T-110, T-115）兼容
- [ ] 文档更新

**依赖**: 

**笔记**:
- 来自 Swarm 分析文档: docs/SWARM-PENBERG-ANALYSIS.md
- 这是 KimiZ 构建"物理隔离 + 受控协同"子代理模型的核心组成部分
