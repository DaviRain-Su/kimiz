### T-008: 实现内置 Skills 集合
**状态**: in_progress
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 4h
**实际耗时**: 2h

**描述**:
根据 PRD 实现常用内置 Skills，这是用户使用的主要功能入口。

**文件**:
- `src/skills/*.zig`

**已实现 Skills**:
- [x] code_review.zig - 代码审查框架
- [x] refactor.zig - 代码重构框架
- [x] test_gen.zig - 测试生成框架
- [x] doc_gen.zig - 文档生成框架
- [x] builtin.zig - 内置技能基础

**待完善功能**:
- [ ] 各 Skill 的完整执行逻辑
- [ ] Skill 与 Agent 集成
- [ ] Skill 在 CLI 中的调用支持
- [ ] 更多具体 Skills（DebugSkill 等）

**验收标准**:
- [ ] CodeReviewSkill - 代码审查（框架存在）
- [ ] RefactorSkill - 代码重构（框架存在）
- [ ] TestGenSkill - 测试生成（框架存在）
- [ ] DocGenSkill - 文档生成（框架存在）
- [ ] DebugSkill - 调试辅助（待实现）
- [ ] 每个 Skill 都有完整的参数定义和执行逻辑

**依赖**: T-007

**笔记**:
参考 PRD Section 1.2 - CLI 是 Skill 的底层实现
框架文件已创建，需要完善执行逻辑和集成。
