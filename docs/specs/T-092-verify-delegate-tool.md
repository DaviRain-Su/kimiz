# T-092-VERIFY: 验证 delegate subagent 工具注册

**任务类型**: Verification / Bugfix  
**优先级**: P0  
**阻塞**: 依赖于 FIX-ZIG-015（必须先能编译）  
**预计耗时**: 30min

---

## 参考文档

- [SUBAGENT-ARCHITECTURE-AND-IMPLEMENTATION-PLAN](../design/SUBAGENT-ARCHITECTURE-AND-IMPLEMENTATION-PLAN.md) - delegate 工具集成详细设计
- [NullClaw Lessons](../NULLCLAW-LESSONS-QUICKREF.md) - 工具安全边界与错误恢复

---

## 背景

Commit `9a24161` (`feat: register delegate subagent tool into main Agent loop`) 已经将 `delegate` 工具注册到主 Agent 的工具列表中。但由于后续代码改用了 Zig 0.16 API，导致项目无法编译，**这一功能从未被实际验证过**。

本任务的目标是：在编译恢复后，**验证 delegate 工具确实可用**，并修复任何集成问题。

---

## 相关代码

| 文件 | 作用 |
|------|------|
| `src/agent/subagent.zig` | SubAgent 核心实现（已完整） |
| `src/agent/agent.zig` | Agent Loop，需要确认 delegate 工具在 tools 数组中 |
| `src/cli/root.zig` | REPL 初始化，delegate context 的生命周期管理点 |
| `src/agent/tool.zig` | 工具定义基类 |

---

## 验证步骤

### Step 1: 确认代码集成

1. 打开 `src/cli/root.zig`，找到 `runInteractive()` 函数
2. 确认在 `ai_agent` 初始化之后，是否有类似以下代码：
   ```zig
   var subagent_ctx = subagent.DelegateContext{
       .allocator = allocator,
       .parent_agent = &ai_agent,
       .base_options = ai_agent.options,
   };
   
   const tools = [_]agent.AgentTool{
       // ... 其他工具 ...
       subagent.createAgentTool(&subagent_ctx),
   };
   ```
3. 确认 `subagent_ctx` 的生命周期覆盖了 `runInteractive` 的整个执行期间（即在函数返回前不会被释放）

### Step 2: 确认 Agent 能接收 delegate 工具

1. 打开 `src/agent/agent.zig`
2. 检查 `Agent` struct 是否包含 `subagent_delegate_ctx` 字段
3. 检查 `Agent.init()` 是否正确初始化了该字段
4. 确认 `Agent.deinit()` 正确清理资源

### Step 3: 编译并运行测试

```bash
zig build test
```

确保 `subagent.zig` 中的现有测试通过（如果有的话）。

### Step 4: REPL 功能验证

1. 启动 REPL：
   ```bash
   zig build run -- repl
   ```
2. 输入一个**明确需要委派的任务**，例如：
   > "请帮我检查一下 src/core/ 目录下的所有文件，然后告诉我每个文件的主要作用。使用子代理来完成这个检查任务。"
3. 观察输出：
   - AI 是否输出了 `delegate` tool call？
   - 子代理是否执行了 `read_file` 或 `glob` 工具？
   - 结果是否返回给了主 Agent？

**如果 AI 没有主动使用 delegate**：
- 这是正常的，因为模型不一定每次都会选择 delegate
- 你可以在 system prompt 中明确提示它使用 delegate
- 或者在 REPL 中更直接地要求："使用 delegate 工具，让子代理读取 src/core/root.zig 并总结内容"

### Step 5: 边界条件测试

1. **递归深度限制**
   - 让子代理再委派一个子代理（如果模型配合）
   - 当深度超过 `max_depth`（默认 3）时，应该返回错误 `MaxDepthExceeded`，而不是崩溃

2. **只读模式**
   - 调用 delegate 时设置 `read_only: true`
   - 子代理不应该能调用 `write_file` 工具

---

## 可能的修复

如果在验证过程中发现代码集成不完整，需要修复。常见修复点：

### 修复 A: `src/cli/root.zig` 中缺少 delegate 工具

如果 `runInteractive()` 的 tools 数组中没有 `subagent.createAgentTool()`，添加它：

```zig
var subagent_ctx = subagent.DelegateContext{
    .allocator = allocator,
    .parent_agent = &ai_agent,
    .base_options = ai_agent.options,
};

const tools = try allocator.alloc(agent.AgentTool, base_tools.len + 1);
defer allocator.free(tools);
@memcpy(tools[0..base_tools.len], base_tools);
tools[base_tools.len] = subagent.createAgentTool(&subagent_ctx);
```

### 修复 B: Agent 生命周期问题

如果 `Agent` struct 中没有 `subagent_delegate_ctx` 字段，按 `docs/design/SUBAGENT-ARCHITECTURE-AND-IMPLEMENTATION-PLAN.md` 中的代码示例添加。

---

## 验收标准

- [ ] `zig build test` 通过
- [ ] `src/cli/root.zig` 中 `delegate` 工具被正确注册到 tools 数组
- [ ] REPL 中 AI 可以调用 `delegate` 工具
- [ ] 子代理执行结果正确返回到父代理的 conversation
- [ ] 递归深度超过限制时返回错误（不崩溃）
- [ ] `read_only` 模式下子代理不能调用写操作工具

---

## 参考

- `docs/design/SUBAGENT-ARCHITECTURE-AND-IMPLEMENTATION-PLAN.md` - 详细说明了如何集成 delegate 工具
- `src/agent/subagent.zig` - 已有 90% 的实现
