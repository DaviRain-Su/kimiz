### Task-FEAT-002: 实现 Skills 注册和发现机制
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 6h

**描述**:
技能中心架构（Skill-Centric）是 Kimiz 的核心差异化特性，但当前只有注册表框架，没有实际注册任何技能。

**当前状态**:
```zig
// src/skills/root.zig
pub fn registerBuiltinSkills(registry: *SkillRegistry) !void {
    _ = registry;  // ❌ 空实现
}
```

**需要实现的功能**:

1. **内置技能实现**

   a. **代码审查技能** (`src/skills/code_review.zig`)
   ```zig
   pub const code_review_skill = Skill{
       .id = "code-review",
       .name = "Code Review",
       .description = "Review code for bugs, style issues, and improvements",
       .category = .review,
       .params = &[_]SkillParam{
           .{ .name = "filepath", .param_type = .filepath, .required = true },
           .{ .name = "focus", .param_type = .selection, .required = false },
       },
       .execute_fn = executeCodeReview,
   };
   ```

   b. **文档生成技能** (`src/skills/doc_gen.zig`)
   ```zig
   pub const doc_gen_skill = Skill{
       .id = "doc-gen",
       .name = "Documentation Generator",
       .description = "Generate documentation for code",
       .category = .doc,
       .params = &[_]SkillParam{
           .{ .name = "target", .param_type = .filepath, .required = true },
           .{ .name = "style", .param_type = .selection, .required = false },
       },
       .execute_fn = executeDocGen,
   };
   ```

   c. **重构技能** (`src/skills/refactor.zig`)
   ```zig
   pub const refactor_skill = Skill{
       .id = "refactor",
       .name = "Code Refactoring",
       .description = "Refactor code according to best practices",
       .category = .refactor,
       .params = &[_]SkillParam{
           .{ .name = "filepath", .param_type = .filepath, .required = true },
           .{ .name = "goal", .param_type = .string, .required = true },
       },
       .execute_fn = executeRefactor,
   };
   ```

   d. **测试生成技能** (`src/skills/test_gen.zig`)
   ```zig
   pub const test_gen_skill = Skill{
       .id = "test-gen",
       .name = "Test Generator",
       .description = "Generate unit tests for code",
       .category = .test,
       .params = &[_]SkillParam{
           .{ .name = "filepath", .param_type = .filepath, .required = true },
           .{ .name = "framework", .param_type = .selection, .required = false },
       },
       .execute_fn = executeTestGen,
   };
   ```

2. **技能注册**
```zig
// src/skills/root.zig
pub fn registerBuiltinSkills(registry: *SkillRegistry) !void {
    try registry.register(code_review.code_review_skill);
    try registry.register(doc_gen.doc_gen_skill);
    try registry.register(refactor.refactor_skill);
    try registry.register(test_gen.test_gen_skill);
    try registry.register(builtin_skill);  // 通用内置技能
}
```

3. **技能与 Agent 集成**
```zig
// Agent 初始化时注册技能
pub fn init(allocator: std.mem.Allocator, options: AgentOptions) !Self {
    // ...
    
    // 注册内置技能
    var skill_registry = skills.SkillRegistry.init(allocator);
    try skills.registerBuiltinSkills(&skill_registry);
    
    // 将技能转换为工具
    const skill_tools = try self.convertSkillsToTools(&skill_registry);
    
    return .{
        // ...
        .skill_registry = skill_registry,
        .skill_tools = skill_tools,
    };
}
```

4. **技能发现机制**
```zig
// 用户可以通过自然语言触发技能
// "review this code" -> 触发 code-review 技能
// "generate docs for src/main.zig" -> 触发 doc-gen 技能

pub fn detectSkillFromInput(input: []const u8) ?[]const u8 {
    const patterns = .{
        .{ &.{"review", "check", "audit"}, "code-review" },
        .{ &.{"document", "doc", "readme"}, "doc-gen" },
        .{ &.{"refactor", "rewrite", "improve"}, "refactor" },
        .{ &.{"test", "testing", "unit test"}, "test-gen" },
    };
    
    const lower = std.ascii.lowerString(..., input);
    for (patterns) |pattern| {
        for (pattern[0]) |keyword| {
            if (std.mem.indexOf(u8, lower, keyword) != null) {
                return pattern[1];
            }
        }
    }
    return null;
}
```

**需要修改的文件**:
- [ ] src/skills/root.zig
- [ ] src/skills/code_review.zig（完善）
- [ ] src/skills/doc_gen.zig（完善）
- [ ] src/skills/refactor.zig（完善）
- [ ] src/skills/test_gen.zig（完善）
- [ ] src/skills/builtin.zig（完善）
- [ ] src/agent/root.zig（集成）

**验收标准**:
- [ ] 4 个内置技能完整实现
- [ ] 技能注册到注册表
- [ ] Agent 可以调用技能
- [ ] 自然语言触发技能工作
- [ ] 技能执行结果正确返回
- [ ] 编译通过，测试通过

**依赖**:
- URGENT-FIX-compilation-errors
- TASK-BUG-013-fix-page-allocator-abuse

**阻塞**:
- Skill-Centric 架构的核心功能

**笔记**:
技能系统是 Kimiz 的核心差异化特性。每个技能应该封装一个完整的工作流，而不仅仅是单个工具调用。
