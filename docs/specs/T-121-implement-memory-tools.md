# T-121-IMPLEMENT: 实现 Agent 长期记忆工具

**任务类型**: Implementation  
**优先级**: P1  
**预计耗时**: 4h  
**前置任务**: T-120-DESIGN

---

## 参考文档

- [TigerBeetle Patterns](../research/TIGERBEETLE-PATTERNS-ANALYSIS.md) - Zig 状态机、显式错误处理、资源边界
- [NullClaw Lessons](../guides/NULLCLAW-LESSONS-QUICKREF.md) - 工具沙箱与优雅降级
- [docs/design/document-driven-agent-loop.md](../design/document-driven-agent-loop.md) - 本任务的设计文档（由 T-120 产出）

---

## 背景

T-120 设计了文档驱动的 Agent 工作流。本任务负责将设计落地为 3 个内置工具，并注册到 KimiZ 的工具注册表中。

---

## 需要实现的工具

### 1. `read_active_task`

**功能**: 自动定位当前 Sprint 中第一个 `status: todo` 或 `status: in-progress` 的任务文件，读取其内容并返回给 Agent。

**输入参数**:
```json
{
  "sprint_dir": "tasks/active/sprint-2026-04"  // 可选，默认自动检测最新 sprint
}
```

**输出**:
```json
{
  "task_id": "T-092-VERIFY",
  "task_file": "tasks/active/sprint-2026-04/T-092-verify-delegate-tool.md",
  "content": "...markdown content..."
}
```

**实现要求**:
- 扫描 `tasks/active/` 下最新的 Sprint 目录
- 读取 `README.md` 中的任务表格，找到第一个 `todo` 或 `in-progress`
- 如果找不到，返回明确的错误信息

### 2. `update_task_log`

**功能**: 在指定任务文件的 `## Log` 章节追加一条带时间戳的记录。

**输入参数**:
```json
{
  "task_id": "T-092-VERIFY",
  "message": "验证 delegate 工具注册成功，AI 能正确调用 subagent.createAgentTool"
}
```

**输出**:
```json
{
  "success": true,
  "appended_line": "- 2026-04-06 16:00: 验证 delegate 工具注册成功，AI 能正确调用 subagent.createAgentTool"
}
```

**实现要求**:
- 自动在 `tasks/active/<sprint>/<task-file>.md` 中查找 `## Log` 章节
- 如果不存在 `## Log`，在文件末尾自动创建
- 时间戳格式：`YYYY-MM-DD HH:MM`
- 必须是原子写操作（先写临时文件，再 rename）

### 3. `sync_spec_with_code`

**功能**: 对比 Technical Spec 和实际代码，找出不一致项。

**输入参数**:
```json
{
  "spec_path": "docs/specs/T-092-verify-delegate-tool.md",
  "code_paths": ["src/agent/agent.zig", "src/cli/root.zig"]
}
```

**输出**:
```json
{
  "inconsistencies": [
    {
      "type": "missing_implementation",
      "spec_reference": "Agent 必须注册 subagent.createAgentTool",
      "code_path": "src/agent/agent.zig",
      "detail": "未找到 registerSubAgentTool 的调用"
    }
  ]
}
```

**实现要求**:
- v1 版本可以基于关键词匹配（Spec 中的函数名、文件名是否出现在代码中）
- 返回结构化 JSON，不要返回大段文本
- 如果完全一致，返回空数组

---

## 集成要求

1. 在 `src/agent/tools/` 下创建 `document_tools.zig`
2. 在 `src/agent/registry.zig` 或 `src/cli/root.zig` 中注册这 3 个工具
3. 每个工具必须有自己的单元测试（`zig build test` 覆盖）

---

## 验收标准

- [ ] `read_active_task` 能正确返回当前最高优先级待办任务
- [ ] `update_task_log` 能原子性地在任务文件追加日志
- [ ] `sync_spec_with_code` 能检测 Spec 和代码之间的明显不一致
- [ ] 3 个工具均已注册到 Agent 的工具表中
- [ ] 所有新增代码通过 `zig build test`
- [ ] `zig build` 零错误
