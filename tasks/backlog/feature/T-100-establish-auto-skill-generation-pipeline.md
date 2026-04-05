### T-100: establish-auto-skill-generation-pipeline
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 12h

**描述**:
建立 auto skill 自动生成流水线原型，实现 KimiZ 自我进化的第一步。

这是 KimiZ 核心战略（ZIG-LLM-SELF-EVOLUTION-STRATEGY）的 Phase 2 起点。本任务需要：
1. 创建 `src/skills/auto/` 目录作为自动生成 skill 的隔离区
2. 编写 skill 生成模板（JSON/YAML schema → Zig 源码）
3. 实现一个 `scripts/generate-skill.zig` 脚本或构建步骤
4. 让 LLM 能根据自然语言描述生成第一个有效的 `.zig` skill 文件
5. 生成的 skill 能够通过 `zig build` 编译

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
