### T-119: integrate-git-worktree-for-subagent-isolation
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 12h

**描述**:
将 git worktree 集成到 KimiZ 子代理/后台任务的文件系统隔离机制中。

受 Swarm 启发，用 git worktree 为每个子代理创建轻量级隔离工作区，避免多个 agent 同时修改同一目录导致的文件冲突。需要：
1. 实现 `WorktreeManager`，支持为指定 repo 创建/删除/列出 worktree
2. 每个子代理启动时自动在独立 worktree 中运行
3. worktree 基于 bare clone 缓存创建，避免重复拉取完整 git 历史
4. 支持 worktree 命名规范（如 `feature-x`, `bugfix-y`, `auto-skill-z`）
5. 子代理退出后可选保留或清理 worktree

参考文档: docs/SWARM-PENBERG-ANALYSIS.md

**验收标准**:
- [ ] 核心设计/原型实现
- [ ] 集成测试通过
- [ ] 与现有任务（T-094, T-110, T-115）兼容
- [ ] 文档更新

**依赖**: 

**笔记**:
- 来自 Swarm 分析文档: docs/SWARM-PENBERG-ANALYSIS.md
- 这是 KimiZ 构建"物理隔离 + 受控协同"子代理模型的核心组成部分
