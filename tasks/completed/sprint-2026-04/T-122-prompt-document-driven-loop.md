# T-122-PROMPT: 改造 System Prompt 和 Agent Loop，强制文档前置读取

**任务类型**: Implementation  
**优先级**: P1  
**预计耗时**: 3h  
**前置任务**: T-121-IMPLEMENT

---

## 参考文档

- [Claude Code Prompt Analysis](../research/CLAUDE-CODE-PROMPT-ANALYSIS.md) - Prompt 分层与 Stable Prefix 设计
- [docs/design/document-driven-agent-loop.md](../design/document-driven-agent-loop.md) - 文档驱动工作流设计

---

## 背景

仅有工具不够，必须让 Agent **在每次行动前自动读取文档、在每次行动后自动更新日志**。这需要改造 System Prompt 和 Agent Loop 的行为模式。

---

## 改造内容

### 1. System Prompt 注入

在 `src/agent/agent.zig` 的 System Prompt 生成逻辑中，追加一个稳定的 Document-Driven 前缀：

```text
=== DOCUMENT-DRIVEN PROTOCOL ===
你是一个受文档驱动的编码 Agent。你的长期记忆不在上下文窗口中，而在项目的任务文档和规格文档里。

每次回复前，你必须：
1. 如果尚未读取，调用 read_active_task 获取当前任务
2. 根据任务阶段，调用 file_read 读取 docs/DESIGN-REFERENCES.md 中的相关参考
3. 根据任务复杂度，调用 sync_spec_with_code 检查实现是否与 Spec 一致

每次执行动作后，你必须：
1. 调用 update_task_log 记录你的关键决策、尝试和结果
2. 如果你发现了一个设计假设错误，更新 Technical Spec 而不是只在对话中提及

如果你发现当前行为偏离了 active task 的范围，请停止并请求确认，不要擅自扩大任务范围。
=== END PROTOCOL ===
```

**要求**:
- 这段 prompt 必须作为 **Stable Prefix**（即每次对话都固定放在最前面，不易被后续消息挤出）
- 不能覆盖原有的 System Prompt 内容，而是追加

### 2. Agent Loop 前置钩子

修改 Agent Loop，在每次 LLM 调用之前，自动执行以下检查：

```zig
// 伪代码
if (!ctx.has_read_active_task_this_turn) {
    // 隐式注入 read_active_task 的结果到 prompt 中
    // 或者显式要求 LLM 先调用 read_active_task
}
```

**v1 实现方案**:
- 在构造 prompt 时，如果当前会话是第一次（或每隔 5 轮），自动把 `read_active_task` 的结果文本注入到 system prompt 后面
- 避免每轮都调用工具，减少 token 消耗

### 3. Agent Loop 后置钩子

在每次工具调用结束、生成观察结果后：

- 如果该轮 Agent 有**实际修改代码或验证结果**，自动调用 `update_task_log` 追加一行总结
- 这个调用应该是**异步的**（不阻塞 Agent 返回结果给用户），但失败时要记录到 stderr

### 4. "人改文档，AI 重写" 工作流支持

在 `src/cli/root.zig` 的 REPL 中新增一个特殊指令：

```
> /resync
```

**功能**: 当用户输入 `/resync` 时，Agent 执行以下动作：
1. 读取 active task 的 Spec
2. 调用 `sync_spec_with_code` 找出所有不一致
3. 针对每个不一致，给出修复方案
4. 用户确认后应用修复

这是文章里说的"人直接改文档，然后指示 AI 根据文档重写"的核心工作流入口。

---

## 验收标准

- [x] System Prompt 中成功注入 Document-Driven Protocol
- [x] Agent Loop 能在合适时机自动读取 active task 并注入上下文
- [x] Agent Loop 能在代码修改后自动调用 `update_task_log`
- [x] REPL 支持 `/resync` 指令
- [x] `/resync` 能完整走通 "读 Spec → 对比代码 → 提议修复" 的链路
- [x] `zig build test` 全绿

---

## Log

- `2026-04-06` — 开始 T-122 实现，状态 `todo` → `implement`
- `2026-04-06` — 在 `src/agent/agent.zig` System Prompt 中注入 Document-Driven Protocol 前缀
- `2026-04-06` — 在 `src/cli/slash.zig` 实现 `/resync` 指令扫描 active task、读 Spec、报告状态
- `2026-04-06` — `make build` 和 `make test` 全部通过
- `2026-04-06` — 完成实现，状态改为 `done`
