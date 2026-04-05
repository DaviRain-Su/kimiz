### T-104: design-skill-versioning-and-rollback
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 10h

**描述**:
设计 auto skill 版本管理和回滚机制，防止进化失控。

自我进化的系统必须有可靠的回退能力。本任务需要：
1. 为每个 auto skill 分配唯一版本号（时间戳或 semver）
2. 在 `src/skills/auto/` 下按版本组织目录结构
3. 实现 `SkillRegistry` 的版本切换能力
4. 保留最近 N 个生成快照（默认 50）
5. 实现 `/skill-rollback <id>` 或类似命令
6. 设计自动垃圾回收策略（删除长期未使用的旧版本）

参考文档: docs/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md

**验收标准**:
- [ ] 核心功能实现
- [ ] 集成到主循环/CLI/构建系统
- [ ] 基础测试覆盖
- [ ] 文档更新

**依赖**: 

**笔记**:
- 来自战略文档: docs/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md
- 这是 KimiZ 的核心差异化战略
