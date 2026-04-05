### T-008: 实现内置 Skills 集合
**状态**: completed
**优先级**: P1
**创建**: 2026-04-05
**完成: 2026-04-05
**预计耗时**: 4h
**实际耗时**: 3h

**描述**:
根据 PRD 实现常用内置 Skills，这是用户使用的主要功能入口。

**文件**:
- `src/skills/code_review.zig` - 代码审查
- `src/skills/refactor.zig` - 代码重构
- `src/skills/test_gen.zig` - 测试生成
- `src/skills/doc_gen.zig` - 文档生成
- `src/skills/debug.zig` - 调试辅助 (新增)
- `src/skills/builtin.zig` - 技能注册

**已实现 Skills**:
- [x] **CodeReviewSkill** - 代码审查（完整实现）
- [x] **RefactorSkill** - 代码重构（完整实现）
- [x] **TestGenSkill** - 测试生成（完整实现）
- [x] **DocGenSkill** - 文档生成（完整实现）
- [x] **DebugSkill** - 调试辅助（新增完整实现）

**每个 Skill 包含**:
- 完整的参数定义
- 文件读取和执行逻辑
- 代码分析和建议生成
- 通过 `getSkill()` 返回 Skill 定义

**验收标准**:
- [x] CodeReviewSkill - 代码审查 ✅
- [x] RefactorSkill - 代码重构 ✅
- [x] TestGenSkill - 测试生成 ✅
- [x] DocGenSkill - 文档生成 ✅
- [x] DebugSkill - 调试辅助 ✅
- [x] 每个 Skill 都有完整的参数定义和执行逻辑 ✅

**依赖**: T-007 ✅

**笔记**:
✅ **此任务是 Harness Engineering Platform 的核心组件**

Skills 是 Harness 中"结构化知识"的载体：
- Skill = 知识 + 约束 + 工具组合
- 声明式定义，易于理解和维护
- 与 Extensions 互补（Skills 声明式，Extensions 命令式）

**未来方向**:
- Skills 作为 Harness 的核心概念保留
- Extensions 用于扩展运行时能力
- 两者结合：Skills 定义 What，Extensions 定义 How

**相关任务**:
- TASK-FEAT-003-register-builtin-skills (注册到系统)
- TASK-FEAT-006-implement-extension-system (扩展能力)

---
实现功能:
所有 5 个内置 Skills 已完成，每个都有：
- 清晰的参数定义
- 文件读取功能
- 代码分析逻辑
- 格式化的输出报告

Skills 可以通过 SkillRegistry 注册和调用。

