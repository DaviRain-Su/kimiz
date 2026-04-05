### TASK-INTEG-003: 集成 Skills 系统到 Agent
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 6h

**描述**:
将 Skills 系统集成到 Agent，使 Agent 能够调用 Skills 而不仅仅是 Tools。

**当前状态**:
- ✅ SkillRegistry 和 SkillEngine 实现完整
- ❌ Agent 未导入 skills 模块
- ❌ CLI 未暴露 skill 执行
- ❌ Skills 只是桩代码 (code_review, refactor, test_gen, doc_gen)

**目标**:
```
当前: Agent → Tools (bash, read_file, grep, ...)
目标: Agent → Skills (code_review, refactor, test_gen, ...)
```

**实现步骤**:

1. **在 Agent 中添加 SkillEngine**
```zig
pub const Agent = struct {
    allocator: std.mem.Allocator,
    // ...
    
    // 新增
    skill_engine: SkillEngine,
    skill_registry: *SkillRegistry,
};
```

2. **添加 skill 执行方法**
```zig
/// 执行一个 skill
pub fn executeSkill(
    self: *Self,
    skill_id: []const u8,
    params: std.StringHashMap([]const u8),
) !SkillResult {
    const skill = self.skill_registry.get(skill_id) orelse {
        return error.SkillNotFound;
    };
    
    const ctx = SkillContext{
        .allocator = self.allocator,
        .working_dir = self.options.working_dir,
        .session_id = self.session_id,
    };
    
    return self.skill_engine.execute(skill, ctx, params);
}
```

3. **在 AI Provider 中添加 skill 调用**
```zig
// 当 LLM 返回 skill_call 时
if (msg.assistant.skill_call) |skill_call| {
    const result = try self.executeSkill(
        skill_call.id,
        skill_call.params,
    );
    
    // 将结果加入消息历史
    try self.messages.append(.{
        .skill_result = .{
            .skill_id = skill_call.id,
            .result = result,
        },
    });
}
```

4. **添加 CLI skill 命令**
```zig
// src/cli/root.zig

fn runSkillCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        try stdout.print("Usage: kimiz skill <skill_id> [param=value...]\n", .{});
        return;
    }
    
    const skill_id = args[1];
    var params = std.StringHashMap([]const u8).init(allocator);
    defer params.deinit();
    
    // 解析参数
    for (args[2..]) |arg| {
        if (std.mem.indexOf(u8, arg, "=")) |eq| {
            const key = arg[0..eq];
            const value = arg[eq+1..];
            try params.put(key, value);
        }
    }
    
    var agent = try agent.Agent.init(allocator, options);
    defer agent.deinit();
    
    const result = try agent.executeSkill(skill_id, params);
    try stdout.print("Result: {s}\n", .{result.output});
}
```

5. **将 Skills 注册到 Agent**
```zig
pub fn init(allocator: std.mem.Allocator, options: AgentOptions) !Self {
    var registry = try SkillRegistry.init(allocator);
    try registerBuiltinSkills(&registry);
    
    return Self{
        // ...
        .skill_registry = &registry,
        .skill_engine = SkillEngine.init(allocator, &registry),
    };
}
```

**验收标准**:
- [ ] Agent 能执行 Skills
- [ ] CLI 有 skill 命令
- [ ] 能调用 code_review, refactor 等内置 Skills
- [ ] Skills 结果正确返回

**依赖**:
- TASK-BUG-021 (修复编译错误)

**阻塞**:
- Skill-Centric 架构

**笔记**:
当前 Skills 是桩代码，需要配合 FEAT-014~017 实现真正的 AI 驱动 Skills。
