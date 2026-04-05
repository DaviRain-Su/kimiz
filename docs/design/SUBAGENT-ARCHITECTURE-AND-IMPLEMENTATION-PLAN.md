# Sub-agent 机制分析与实现计划

**文档版本**: 1.0  
**日期**: 2026-04-05  
**状态**: 设计完成，可直接集成  

---

## 1. Kimi 官方 sub-agent 是怎么实现的

### 1.1 核心结论：不是多模型，是同一模型的上下文切换

根据 kimi-cli 官方文档（`customization/agents.html`）和实际架构分析：

- **Kimi 只运行一个底层大模型实例**（如 `kimi-k2.5`）
- Sub-agent 不是独立的模型进程，而是**应用层的 Agent 配置切换**
- 每个 sub-agent 有独立的 `system_prompt`、可用工具集、描述和文件路径
- 主 agent 通过内置的 **`Agent` 工具** 来"雇佣/调度" sub-agent

### 1.2 官方 agent 配置示例

```yaml
version: 1
agent:
  extend: default
  subagents:
    coder:
      path: ./coder.yaml
      description: "Handle coding tasks"
    reviewer:
      path: ./reviewer.yaml
      description: "Code review expert"
```

### 1.3 Agent 工具的定义方式

主 agent 的可用工具列表里有 `Agent` 工具（类似我们的 `delegate`）。当模型输出发送给某个 sub-agent 时，CLI 实际做的工作是：

1. 加载 sub-agent 的 YAML 配置
2. 用 sub-agent 的 system prompt 构建新的请求上下文
3. 发送给**同一个 LLM endpoint**
4. 在受限模式下运行（步骤上限、可选只读模式）
5. 将结果返回给主 agent 的 conversation

### 1.4 "100 sub-agents" 的真相

Kimi 博客提到 K2.5 支持 "agent swarm up to 100"。这不是同时跑 100 个 LLM 实例，而是：

- **规划阶段**：主模型把任务拆成 N 个子任务
- **调度阶段**：逐个或按批通过 `Agent` 工具调用派发
- **执行阶段**：每个 sub-agent 是串行/伪并发的上下文切换
- 从模型提供商角度，这仍然是**多个 API 请求**，不是单请求内并发

---

## 2. KimiZ 当前基础

### 2.1 已有实现：`src/agent/subagent.zig`

KimiZ 已经有一个相当完整的 `SubAgent` 模块：

| 组件 | 状态 | 说明 |
|------|------|------|
| `SubAgentConfig` | ✅ | `max_depth`, `max_steps`, `read_only`, `custom_tools` |
| `SubAgent` struct | ✅ | 带 `parent: ?*Agent` 指针，支持深度追踪 |
| `init()` | ✅ | 检查深度限制，过滤只读工具 |
| `run(task)` | ✅ | 启动内部 `Agent`，执行 prompt，收集最终回复 |
| `deinit()` | ✅ | 释放资源 |
| `delegate` tool | ✅ | 完整的 `Tool` + `AgentTool` + `execute()` 实现 |
| **注册到主 Agent** | ❌ | 唯一缺失环节 |

### 2.2 当前 `delegate` 工具的参数

```json
{
  "task": "string (required)",
  "read_only": "boolean (default: false)",
  "max_steps": "integer (default: 50)",
  "max_depth": "integer (default: 3)"
}
```

### 2.3 与 kimi-cli 的差异

| 维度 | kimi-cli | KimiZ |
|------|----------|-------|
| 配置格式 | YAML agent files | 代码内 `SubAgentConfig` |
| sub-agent 类型 | 命名角色（coder, reviewer...） | 通用 `delegate`，通过参数控制行为 |
| 启动入口 | `Agent` 工具 | `delegate` 工具 |
| 并发能力 | 宣称 swarm up to 100 | 当前仅串行 |

---

## 3. 最小可行集成方案（MVP）

### 3.1 目标
让主 Agent 能够识别并执行 `delegate` tool call，从而真正启用 sub-agent 功能。

### 3.2 需要修改的文件

1. **`src/agent/agent.zig`**
   - 在 `Agent` struct 中存储 `subagent_delegate_ctx: ?subagent.DelegateContext`
   - 在 `init()` 中初始化该 context（传入 self 指针和当前 options）
   - 将 `subagent.createAgentTool(&self.subagent_delegate_ctx)` 加入 tools 数组
   - 在 `deinit()` 中清理

2. **`src/agent/root.zig`**
   - 确认 `subagent` 模块被正确导出

3. **`src/cli/root.zig`**（可选）
   - 如果未来要支持 `--agent` 参数选择不同角色，再扩展

### 3.3 关键注意事项

#### A. 生命周期问题
`DelegateContext` 持有一个 `parent_agent: ?*Agent` 指针。这个指针在主 Agent 的栈/堆地址必须在 sub-agent 执行期间保持稳定。由于 KimiZ 的 REPL 中 `ai_agent` 是栈变量，它的地址在 `runInteractive` 期间是稳定的。sub-agent 的执行不会跨出这个函数范围，因此是安全的。

#### B. 递归深度限制
`subagent.zig` 中已经通过 `max_depth` 和 `depth` 做了硬限制。`SubAgent.init()` 会检查 `depth > max_depth` 并返回 `MaxDepthExceeded`。

#### C. event 回调
`SubAgent.run()` 内部调用的 `agent.prompt()` 会产生事件。当前 `SubAgent.init()` 没有为内部 `Agent` 设置 event callback，这意味着 sub-agent 的执行是"静默"的（结果只通过 tool result 返回）。如果要让 sub-agent 的 thinking/tool_call 也输出到 UI，需要给内部 Agent 设置 callback。

**MVP 建议**：保持静默执行，结果返回后再由主 agent 展示。这与 kimi-cli 的行为类似（sub-agent 的过程通常折叠或不显示）。

#### D. 内存管理
`subagent.run()` 返回的结果字符串是用 `self.allocator` 分配的。`delegate` 工具的 `execute()` 函数已经正确处理了 `defer delegate_ctx.allocator.free(result)`。

---

## 4. 集成代码示例

### 4.1 Agent.init 中加入 delegate context

```zig
pub const Agent = struct {
    // ... existing fields ...
    subagent_delegate_ctx: ?subagent.DelegateContext,

    pub fn init(allocator: std.mem.Allocator, options: AgentOptions) !Self {
        // ... existing init code ...

        var subagent_delegate_ctx: ?subagent.DelegateContext = .{
            .allocator = allocator,
            .parent_agent = null, // will be set after self is created
            .base_options = options,
        };

        // Need to create agent first, then patch the pointer
        var self = Self{
            // ... all fields ...
            .subagent_delegate_ctx = subagent_delegate_ctx,
        };

        if (self.subagent_delegate_ctx) |*ctx| {
            ctx.parent_agent = &self;
        }

        return self;
    }
};
```

### 4.2 将 delegate 工具加入可用工具列表

在 `cli/root.zig` 的 REPL 初始化中：

```zig
var subagent_ctx = subagent.DelegateContext{
    .allocator = allocator,
    .parent_agent = &ai_agent,
    .base_options = ai_agent.options,
};

const tools = [_]agent.AgentTool{
    // ... existing tools ...
    subagent.createAgentTool(&subagent_ctx),
};
```

注意：`subagent_ctx` 必须在 `ai_agent` 初始化之后创建，且其生命周期必须与 `ai_agent` 相同。在 REPL 中，它可以作为栈变量放在 `runInteractive` 里，`defer` 不需要特殊处理（因为 context 本身不持有需要释放的资源）。

---

## 5. 后续可扩展方向

### 5.1 Named Sub-agents（命名子代理）
仿照 kimi-cli 的 YAML agent files，支持预定义角色：
- `coder.yaml`: 擅长代码修改
- `reviewer.yaml`: 擅长代码审查
- `tester.yaml`: 擅长写测试

将 `delegate` 工具扩展一个 `agent_name` 参数，根据名字加载不同的 `SubAgentConfig` 和 system prompt。

### 5.2 Sub-agent 结果缓存
当同一个任务被多次委派时，可以缓存结果避免重复调用 LLM。`subagent.zig` 已经有一些 harness 模块（`prompt_cache.zig`）可以复用。

### 5.3 并发批处理
在复杂重构场景中，主 agent 可能想同时派发多个独立的 sub-agent 任务（如"给 A 文件加测试"、"给 B 文件加测试"）。这需要：
- 一个 sub-agent 任务队列
- 线程池或 `std.Thread` 并发执行
- 结果聚合后返回给主 agent

### 5.4 UI 交互增强
当前 sub-agent 执行期间用户看不到进度。可以：
- 给内部 `Agent` 设置 event callback，但以折叠/缩进形式显示
- 在终端输出中显示 `🔧 [subagent] Calling tool: read_file`

---

## 6. 结论

**KimiZ 离真正可用的 sub-agent 功能只差最后一个步骤：把 `delegate` 工具注册到主 Agent 的工具列表中。**

`src/agent/subagent.zig` 已经有 90% 的实现完成度，且架构上与 kimi-cli 官方设计基本一致（共享模型、上下文切换、深度限制、工具过滤）。

### 推荐优先级
1. **P1**: 注册 `delegate` 工具到主 Agent loop（约 30 分钟工作量）
2. **P2**: 验证递归委派和只读模式（约 1 小时测试）
3. **P3**: 增加 named sub-agents 配置文件支持（约 4 小时）
4. **P4**: 并发批处理（依赖更高，暂不推荐）

---

## 附录：相关源码

- `src/agent/subagent.zig` — SubAgent 核心实现
- `src/agent/agent.zig` — Agent loop，需要注册 delegate 工具
- `src/cli/root.zig` — REPL，delegate context 生命周期管理点
