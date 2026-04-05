### T-118: os-level-namespace-isolation
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 24h

**描述**:
远期任务：对高风险 skill 实现 OS 级进程隔离（namespaces / seccomp / bubblewrap）。

作为 Capability security 的第三层防御。需要：
1. 在 subagent / 后台任务执行时，fork 一个隔离进程
2. 使用 Linux namespaces 限制文件系统视图（只暴露 workspace）
3. 使用 seccomp-bpf 过滤系统调用（禁止 execve, fork 等）
4. 使用 bubblewrap / firejail 简化隔离配置
5. 建立进程间通信机制（pipe / Unix socket）传递结果

状态: 中远期（3-6个月后启动）
参考文档: docs/NULLCLAW-ANALYSIS.md, NullClaw subagent.zig

**验收标准**:
- [ ] 核心设计/原型实现
- [ ] 集成测试或验证通过
- [ ] 文档更新
- [ ] 与现有任务（T-100 ~ T-111）的兼容性确认

**依赖**: 

**笔记**:
- 来自战略文档: docs/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md
- 这是构建 Hardness Engineer 多层防御系统的核心组成部分
