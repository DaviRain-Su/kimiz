### Task-FEAT-003: 注册内置 Skills 到 SkillRegistry
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 4h

**描述**:
`src/skills/root.zig` 中的 `registerBuiltinSkills` 函数为空，导致所有内置 Skills 未注册到系统。虽然 Skill 框架和各个 Skill 模块已实现，但无法被 Agent 使用。

**当前代码** (root.zig:237-239):
```zig
pub fn registerBuiltinSkills(registry: *SkillRegistry) !void {
    _ = registry;
    // TODO: 实现内置 skill 注册
}
```

**已有 Skill 模块**:
- `src/skills/code_review.zig` - 代码审查 Skill
- `src/skills/refactor.zig` - 重构 Skill
- `src/skills/test_gen.zig` - 测试生成 Skill
- `src/skills/doc_gen.zig` - 文档生成 Skill

**验收标准**:
- [ ] `registerBuiltinSkills` 正确注册所有内置 Skills
- [ ] Agent 能发现和列出可用 Skills
- [ ] Skills 能被 Agent 选择和执行

**依赖**:
- Skill 框架完成 (T-008)
- 各 Skill 模块实现完成

**阻塞**:
- Skill-Centric 架构无法运作

**笔记**:
这是 kimiz "Skill-Centric" 架构的核心功能。发现于 2026-04-05 代码审查。
