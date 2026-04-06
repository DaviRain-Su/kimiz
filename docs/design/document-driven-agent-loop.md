# Document-Driven Agent Loop — Architecture Design

**Task**: T-120  
**Version**: 1.0  
**Last Updated**: 2026-04-06  
**Status**: Design

---

## 1. 核心问题

当前 Agent Loop 的**记忆完全依赖上下文窗口**。一旦对话超过 context window，早期任务和决策完全丢失。Agent：

- 不知道自己正在执行哪个任务
- 不会主动记录工作过程
- 无法对比 Spec 和实现是否一致
- 经验教训随着 session 结束而消失

**解决方案**：将文档系统（`tasks/active/`、`docs/specs/`、`docs/lessons-learned/`）作为 Agent 的**长期记忆和控制面**，让 Agent 的工作流**围绕文档展开**而非围绕对话。

---

## 2. 架构设计

### 2.1 改造前 vs 改造后

#### 改造前（纯对话驱动）

```
User Prompt → Agent Loop → LLM Call → Tool Execute → Tool Result → LLM Call → ...
    ↑                                                                      |
    └──────────────────────────────────────────────────────────────────────┘
                    所有状态停留在 context window 内
```

#### 改造后（文档驱动）

```
User Prompt → Document-Setup Phase → Agent Loop → Document-Cleanup Phase
                    │                       │                       │
                    ▼                       ▼                       ▼
            Read active tasks         Auto-update               Write lessons-
            Load task log             task log inline            learned + sync
            Inject task context       Check spec drift           task status
```

### 2.2 三阶段 Agent Loop

```
┌─────────────────────────────────────────────────────────────────┐
│                    Document-Driven Agent Loop                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Phase 1: SETUP (每次 prompt 开始时)                            │
│  ┌─────────────────────────────────────────────┐               │
│  │ 1. Read current active tasks from tasks/     │               │
│  │ 2. Load task Log section as context          │               │
│  │ 3. Read relevant specs from docs/specs/      │               │
│  │ 4. Read DESIGN-REFERENCES.md for guidelines  │               │
│  │ 5. Inject as prefixed system context          │               │
│  └─────────────────────────────────────────────┘               │
│                           │                                     │
│                           ▼                                     │
│  Phase 2: LOOP (现有 Agent Loop + 内联文档更新)                  │
│  ┌─────────────────────────────────────────────┐               │
│  │ Normal LLM call → Tool execute → ...        │               │
│  │                                              │               │
│  │ + 关键节点调用 update_task_log 工具:          │               │
│  │   - 完成一个工具 → 追加 Log 条目              │               │
│  │   - 编译失败 → 记录错误和修正计划             │               │
│  │   - 文件修改 → 记录改动摘要                   │               │
│  └─────────────────────────────────────────────┘               │
│                           │                                     │
│                           ▼                                     │
│  Phase 3: CLEANUP (Agent Loop 结束时)                           │
│  ┌─────────────────────────────────────────────┐               │
│  │ 1. Write lessons-learned entry               │               │
│  │ 2. Update task status (todo → done)          │               │
│  │ 3. Check spec-vs-code consistency            │               │
│  │ 4. Update task file and sprint README        │               │
│  └─────────────────────────────────────────────┘               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. 新工具设计

### 3.1 Tool 1: `read_active_task`

**用途**: Agent 主动读取当前活跃任务和参考文档。

**Zig 函数签名**:

```zig
pub fn readActiveTask(
    arena: std.mem.Allocator,
    args: std.json.Value,
) !ToolResult {
    const args_parsed = try parseArguments(arena, args, struct {
        task_id: ?[]const u8 = null,
        read_spec: bool = true,
        read_references: bool = true,
    });

    // 1. If task_id provided, read that specific task file
    // 2. Otherwise, read tasks/active/sprint-*/README.md
    // 3. If read_spec=true, read the linked spec file
    // 4. If read_references=true, read DESIGN-REFERENCES.md
    // 5. Return combined markdown as ToolResult
}
```

**参数 JSON Schema**:

```json
{
  "type": "object",
  "properties": {
    "task_id": {
      "type": "string",
      "description": "Optional task ID (e.g., 'T-120'). If omitted, reads the sprint board."
    },
    "read_spec": {
      "type": "boolean",
      "default": true,
      "description": "Whether to also read the task's technical spec."
    },
    "read_references": {
      "type": "boolean",
      "default": true,
      "description": "Whether to also read DESIGN-REFERENCES.md."
    }
  }
}
```

**返回值**: 完整的任务上下文（Markdown 格式），包括任务描述、Spec、参考文档摘要。

**安全约束**: 只读操作，无写权限。

---

### 3.2 Tool 2: `update_task_log`

**用途**: 在任务文件的 `Log` 章节追加执行记录。

**Zig 函数签名**:

```zig
pub fn updateTaskLog(
    arena: std.mem.Allocator,
    args: std.json.Value,
) !ToolResult {
    const args_parsed = try parseArguments(arena, args, struct {
        task_id: []const u8,
        log_entry: []const u8,
        append_to_section: ?[]const u8 = "Log",
    });

    // 1. Read the task file
    // 2. Find the `## Log` section (or append_to_section)
    // 3. Append the new entry with timestamp
    // 4. Write atomically: write to .tmp, then rename
    // 5. Return success confirmation
}
```

**参数 JSON Schema**:

```json
{
  "type": "object",
  "required": ["task_id", "log_entry"],
  "properties": {
    "task_id": {
      "type": "string",
      "description": "Task ID to update (e.g., 'T-120')."
    },
    "log_entry": {
      "type": "string",
      "description": "The log entry to append. Format: '- `YYYY-MM-DD` — description'"
    },
    "append_to_section": {
      "type": "string",
      "default": "Log",
      "description": "Which markdown section to append to. Defaults to 'Log'."
    }
  }
}
```

**原子操作实现**:

```zig
// Atomic write pattern (read → modify → write)
const tmp_path = try std.fmt.allocPrint(allocator, "{s}.tmp", .{ task_path });
defer allocator.free(tmp_path);

// 1. Read existing content
const existing = try utils.readFileAlloc(allocator, task_path, 256 * 1024);
defer allocator.free(existing);

// 2. Find the target section and insert new content
const modified = try insertLogEntry(allocator, existing, section_name, log_entry);
defer allocator.free(modified);

// 3. Write to tmp file
try utils.writeFile(tmp_path, modified);

// 4. Atomic rename
try utils.rename(tmp_path, task_path);
```

**安全约束**:
- 只能写入 `tasks/active/` 目录下的文件
- 只能追加 Log 条目，不能删除或修改已有内容（防止 Agent 擦除历史）
- 单次写入限制 4KB（防止过大 Log 条目）

---

### 3.3 Tool 3: `sync_spec_with_code`

**用途**: 对比 Spec 文档与实际代码，发现不一致并报告。

**Zig 函数签名**:

```zig
pub fn syncSpecWithCode(
    arena: std.mem.Allocator,
    args: std.json.Value,
) !ToolResult {
    const args_parsed = try parseArguments(arena, args, struct {
        task_id: []const u8,
        fix_mode: bool = false,
    });

    // 1. Read the task's spec file (docs/specs/T-XXX-*.md)
    // 2. Parse "影响文件" table to get expected files
    // 3. Check each file exists and was modified recently
    // 4. Compare spec's验收标准 with actual state
    // 5. Return diff report
    // 6. If fix_mode=true, update spec to match reality
}
```

**参数 JSON Schema**:

```json
{
  "type": "object",
  "required": ["task_id"],
  "properties": {
    "task_id": {
      "type": "string",
      "description": "Task ID to check spec consistency."
    },
    "fix_mode": {
      "type": "boolean",
      "default": false,
      "description": "If true, update spec to match actual code state."
    }
  }
}
```

**返回格式**:

```markdown
## Spec-Code Consistency Report for T-XXX

| 预期文件 | 存在 | 最后修改 | 匹配度 |
|----------|------|----------|--------|
| src/foo.zig | ✅ | 2026-04-06 | 完全匹配 |
| src/bar.zig | ❌ | — | 文件缺失 |

## 不一致项
- `影响文件` 中列出的 `src/bar.zig` 不存在
- 验收标准 #3 未满足：缺少 `zig build test` 验证记录

## 建议
1. 创建 `src/bar.zig` 实现缺失功能
2. 运行 `zig build test` 并更新 Log
```

---

## 4. System Prompt 改造方案

### 4.1 注入点

在 `Agent.prompt()` 的系统提示词之前，追加**文档上下文块**：

```
You are Kimiz, an AI coding assistant working in document-driven mode.

=== ACTIVE TASK CONTEXT ===
<Task content from read_active_task>

=== DESIGN REFERENCES ===
<Key guidelines from DESIGN-REFERENCES.md>

=== CURRENT TASK LOG (execution history) ===
<Log section from task file>

---
Now, proceed with the user request. You MUST:
1. Update the task Log after each meaningful step
2. Follow the workflow described in the active task
3. Report spec-code inconsistencies when found
```

### 4.2 注入内容模板

```zig
const doc_context = try std.fmt.allocPrint(allocator,
    \\You are Kimiz, an AI coding assistant. You follow a document-driven workflow.
    \\
    \\## Active Task Context
    \\{s}
    \\
    \\## How You Must Work
    \\1. Before coding: Read the task file, its Spec, and DESIGN-REFERENCES.md.
    \\2. While coding: Append a Log entry after each meaningful step.
    \\3. After coding: Run tests, fill Lessons Learned, update status.
    \\4. Never write code without a Spec. If spec is missing, write it first.
    \\5. Never skip tasks in the queue. Work in strict order.
    \\
    \\--- End Active Task Context ---
    \\
, .{ task_content });
```

### 4.3 改造位置

文件: `src/agent/agent.zig`, `prompt()` 方法:

```zig
pub fn prompt(self: *Self, user_content: []const u8) !void {
    if (self.messages.items.len == 0) {
        // Before: single system prompt
        // After: document context + system prompt
        
        const doc_context = try self.buildDocumentContext(self.allocator);
        defer self.allocator.free(doc_context);
        
        const system_text = try std.fmt.allocPrint(self.allocator,
            "{s}\n\n{s}",
            .{ doc_context, self.defaultSystemPrompt() },
        );
        // ... rest unchanged
    }
}

fn buildDocumentContext(self: *Self, allocator: std.mem.Allocator) ![]u8 {
    // 1. Read sprint README to find first non-done task
    // 2. Read that task file
    // 3. Read the spec if available
    // 4. Return combined context
}
```

---

## 5. 人机协作工作流

### 5.1 完整工作流图

```
Human                          AI Agent
  │                              │
  │  1. 创建/更新任务文件          │
  │  tasks/active/T-XXX.md       │
  │  (描述背景、目标、验收标准)     │
  │                              │
  ├─────────────────────────────>│
  │   "开始工作"                  │
  │                              │
  │                    2. 自动读取任务文件
  │                    3. 读取 Spec + 参考文档
  │                    4. 进入 implement 阶段
  │                    5. 编码 + 实时 Log 更新
  │                              │
  │                    6. 完成后更新状态
  │                    7. 记录 Lessons Learned
  │<──────────────────────────────┤
  │                    8. 提交 Commit (含任务 ID)
  │                              │
  │  9. 人类 Review Commit       │
  │  (检查代码质量、日志完整性)     │
  │                              │
  │  ❌ 有问题                   │  ✓ 没问题
  │  │                          │
  │  ├─ 修改任务文件标注问题       │
  │  │  (Agent 自动读取并重做)    │
  │  │                          │
  │  └─────────────────────────>│ 重做
  │                             │
  │                     ✓ 通过
  │                             │
  │  10. 更新 Sprint 看板为 done  │
  │                              │
```

### 5.2 人类纠正 AI 的完整流程

**场景**: Agent 实现了一个功能，但实现方式与 Spec 不完全一致。

**Step 1 — 人类修改任务文件**（不直接改代码）：

```markdown
# T-XXX: 实现 Foo 组件

## Log（由 Agent 维护）
- `2026-04-06` — 完成了 Foo 组件的基本实现

## Human Review Notes
- Agent 使用了 `std.json` 而非 `json_miniparse`，不符合设计决策
- 请重新实现，优先使用零分配方案
- **状态**: `implement` → `implement` (需要修正)
```

**Step 2 — Agent 在下一次 prompt 时自动读取**：

1. `read_active_task` 读到 Human Review Notes
2. 发现需要修正
3. 重新实现并更新 Log
4. 重新提交

**核心原则**: 人类不修改代码，只修改文档。文档就是指令。

---

## 6. 经验教训框架

### 6.1 Lessons Learned 格式

详见 `docs/lessons-learned-template.md`。关键分类：

| 分类 | 示例 |
|------|------|
| 架构决策 | "选择方案 A 因为..." |
| 踩坑记录 | "Zig 0.16 的 std.fs.cwd() 不可用在 build.zig 中" |
| 性能优化 | "使用 ArenaAllocator 减少 60% 分配" |
| API 选择 | "用 `parseFromSliceLeaky` 而非 `parseFromSlice`" |

### 6.2 Lessons Learned 自动收集

在 Agent Loop 的 Cleanup Phase，自动生成条目：

```zig
fn generateLessonsLearned(self: *Self, allocator: std.mem.Allocator) ![]u8 {
    // 分析本次 session 的操作：
    // - 编译错误 → 归类为"踩坑记录"
    // - API 替换 → 归类为"API 选择"
    // - 架构变更 → 归类为"架构决策"
    // - 性能变化 → 归类为"性能优化"
}
```

---

## 7. 实现优先级

| 阶段 | 内容 | 预计耗时 |
|------|------|----------|
| Phase 1 | `read_active_task` 工具 + System Prompt 注入 | 2h |
| Phase 2 | `update_task_log` 工具 + 原子写入 | 2h |
| Phase 3 | `buildDocumentContext()` 集成到 Agent Loop | 2h |
| Phase 4 | `sync_spec_with_code` 工具 | 2h |
| Phase 5 | Lessons Learned 自动生成 | 1h |

**总计**: ~9h（可分多个子任务完成）

---

## 8. 设计约束

1. **Zig 0.16 兼容**: 所有新工具必须使用 `utils.readFileAlloc`、`utils.writeFile`、`utils.rename` 等 wrapper
2. **原子操作**: 文档更新必须是 write-to-tmp + rename，防止部分写入
3. **非破坏性**: 不修改现有 Agent Loop 的核心逻辑，只在入口和出口添加钩子
4. **优雅降级**: 如果任务文件不存在或读取失败，Agent 必须继续工作（降级为纯对话模式）
