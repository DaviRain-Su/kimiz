### Task-FEAT-011: 实现 Delegation 子 Agent 机制
**状态**: pending
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 8h

**描述**:
实现有界子 Agent 委托机制，用于并行处理子任务。

**目标功能**:

1. **子 Agent 特性**
```zig
pub const SubAgent = struct {
    parent: *Agent,
    depth: u32,              // 当前深度
    max_depth: u32 = 1,     // 最大深度限制
    read_only: bool = true,  // 只读模式
    max_steps: u32 = 3,     // 最大步数限制
    
    pub fn run(self: *SubAgent, task: []const u8) ![]const u8 {
        // 创建子 Agent 执行任务
        // 有深度和步数限制
        // 只允许安全工具
    }
};
```

2. **Delegate 工具**
```zig
pub const DelegateArgs = struct {
    task: []const u8,        // 任务描述
    max_steps: u32 = 3,      // 子 Agent 步数限制
};

// delegate 工具定义
const DelegateTool = Tool{
    .name = "delegate",
    .description = "Ask a bounded read-only child agent to investigate.",
    .parameters_json = "{...}",
};
```

3. **使用示例**
```
User: Check all README files in the project for consistency
Agent: I'll delegate this to a sub-agent for parallel investigation
  └─ SubAgent: Read and analyze docs/README.md
  └─ SubAgent: Read and analyze docs/ARCHITECTURE.md
  └─ SubAgent: Read and analyze README.md
Agent: [汇总结果]
```

4. **安全约束**
   - 子 Agent 始终 read_only
   - 深度限制防止无限递归
   - 步数限制防止资源耗尽

**验收标准**:
- [ ] delegate 工具正常工作
- [ ] 深度限制生效
- [ ] 只读模式正确限制工具
- [ ] 结果正确返回父 Agent

**依赖**:
- Task-FEAT-009 (Tool Approval)
- Task-FEAT-010 (Session Persistence)

**阻塞**:
- 无

**笔记**:
这是高级功能，提升 Agent 并行处理能力。
