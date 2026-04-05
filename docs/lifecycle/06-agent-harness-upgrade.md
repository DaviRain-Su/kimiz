# Kimiz Agent Harness 升级架构

**日期**: 2026-04-05  
**基于**: Sebastian Raschka《Components of A Coding Agent》  
**目标**: 将 kimiz 从 "能用" 升级到 "好用" 级别

---

## 升级愿景

```
当前状态                          目标状态
─────────────────────────────    ─────────────────────────────
✓ Agent 框架基础                ✓ 完整的 Agent Harness
✓ 工具系统框架                  ✓ Prompt 缓存降低 50% 成本
✓ 三层内存系统                  ✓ 上下文管理防止 overflow
❌ 无 Git 上下文收集            ✓ WorkspaceContext 完整收集
❌ 无 Prompt 缓存               ✓ 分层 prompt + cache tokens
❌ 无 Context Truncation       ✓ 智能上下文压缩
❌ 工具审批未完成               ✓ 交互式审批流程
❌ 无 Session 持久化            ✓ 中断恢复能力
❌ 无子 Agent                   ✓ 有界委托机制
```

---

## 核心架构变更

### 1. 新增模块: `src/harness/`

```
src/
├── harness/                      # NEW: Agent Harness 层
│   ├── root.zig                  # Harness 导出
│   ├── workspace.zig            # WorkspaceContext
│   ├── prompt_cache.zig         # PromptCache
│   ├── context_manager.zig      # 上下文管理
│   ├── session.zig              # 会话持久化
│   └── subagent.zig             # 子 Agent
```

### 2. 模块职责划分

| 模块 | 职责 | 对应 Raschka 组件 |
|------|------|-------------------|
| `workspace.zig` | Git 上下文、项目分析 | #1 Live Repo Context |
| `prompt_cache.zig` | Prompt 缓存复用 | #2 Prompt Shape + Cache |
| `context_manager.zig` | 上下文截断压缩 | #4 Context Reduction |
| `session.zig` | 会话持久化恢复 | #5 Transcripts + Memory |
| `subagent.zig` | 子 Agent 委托 | #6 Delegation |

### 3. 数据流变更

```
当前数据流:
User → Agent → AI → Response → Memory

目标数据流:
User → Agent
        ├→ WorkspaceContext (静态，缓存)
        ├→ PromptCache (stable prefix，缓存)
        ├→ WorkingMemory (项目知识)
        ├→ ShortTermMemory (会话记忆)
        ├→ ConversationHistory (动态，截断)
        └→ LongTermMemory (持久)
            ↓
        AI Provider (分层 prompt)
            ↓
        Response → Memory.remember()
```

---

## 升级路线图

### Phase 1: 核心增强 (1-2 周)

#### Sprint A: Context Collection
```
Task-FEAT-006: WorkspaceContext (4h)
  └─ 实现 Git 上下文收集
  └─ 实现项目文档收集
  └─ 集成到 WorkingMemory
```

#### Sprint B: Prompt Optimization  
```
Task-FEAT-007: Prompt Caching (6h)
  └─ 实现 PromptCache
  └─ 实现 stable prefix
  └─ 集成到 Agent.runLoop()
```

#### Sprint C: Context Safety
```
Task-FEAT-008: Context Truncation (3h)
  └─ 实现消息历史限制
  └─ 实现工具输出截断
  └─ 实现历史去重
```

### Phase 2: 交互增强 (2-3 周)

#### Sprint D: Safety
```
Task-FEAT-009: Tool Approval (4h)
  └─ 实现交互式审批
  └─ 完善 YOLO 模式
  └─ 审批历史记录
```

### Phase 3: 高级特性 (3-4 周)

#### Sprint E: Persistence
```
Task-FEAT-010: Session Persistence (6h)
  └─ 会话保存/恢复
  └─ REPL /reset 命令
  └─ 会话列表管理
```

#### Sprint F: Advanced
```
Task-FEAT-011: Subagent Delegation (8h)
  └─ 子 Agent 实现
  └─ 深度限制
  └─ 并行任务处理
```

### Phase 4: Observability (Week 5-6)

#### Sprint G: Trace
```
Task-FEAT-012: Reasoning Trace (6h)
  └─ 完整记录 thought → action → observation
  └─ Trace 保存/加载
  └─ CLI trace 命令
```

#### Sprint H: Safety
```
Task-FEAT-013: Resource Limits (4h)
  └─ 步数/成本/内存/超时限制
  └─ CLI 配置选项
  └─ 优雅退出
```

### Phase 5: Agent Engineering (Week 7-8) - 论文新增

#### Sprint I: Knowledge
```
Task-FEAT-014: AGENTS.md 结构化知识 (8h)
  └─ KnowledgeBase 结构
  └─ 文档解析和加载
  └─ 与 WorkspaceContext 集成
```

#### Sprint J: Constraints
```
Task-FEAT-015: Agent Linter 约束系统 (6h)
  └─ LinterRule 结构
  └─ 默认规则集
  └─ 与 Agent 集成
```

### Phase 6: Advanced Automation (Week 9-10)

#### Sprint K: Maintenance
```
Task-FEAT-016: AI Slop 垃圾回收 (6h)
  └─ SlopPattern 检测
  └─ QualityScorer
  └─ 自动修复
```

#### Sprint L: Review
```
Task-FEAT-017: Agent Self-Review (8h)
  └─ SelfReviewer
  └─ 多 Agent 审查循环
  └─ 质量评分卡
```

---

## 技术决策

### Q1: 为什么新增 `harness/` 目录而不是修改现有模块?

**决策**: 新增 harness/ 模块

**理由**:
1. 保持现有代码稳定，不破坏现有功能
2. 清晰的分层：新模块专注于 "Harness" 职责
3. 渐进式迁移：可以逐步将逻辑迁移到新模块
4. 易于测试：可以独立测试新模块

### Q2: PromptCache 的失效策略?

**决策**: 基于 workspace + tools 的 hash

```zig
pub fn isValid(self: *PromptCache, workspace: *WorkspaceInfo, tools: []const Tool) bool {
    const new_ws_hash = self.hashWorkspace(workspace);
    const new_tools_hash = self.hashTools(tools);
    return self.workspace_hash == new_ws_hash and 
           self.tools_hash == new_tools_hash;
}
```

**失效触发**:
- 用户进入不同目录
- 工具列表变化
- 显式调用 `invalidate()`

### Q3: Context 截断策略?

**决策**: 分层截断

```zig
pub fn truncateContext(agent: *Agent, max_bytes: usize) !void {
    // Layer 1: 工具输出截断 (MAX_TOOL_OUTPUT = 4000)
    truncateToolOutputs(agent.messages);
    
    // Layer 2: 历史去重
    deduplicateHistory(agent.messages);
    
    // Layer 3: 如果还超限，从最旧消息开始删除
    if (calculateSize(agent.messages) > max_bytes) {
        truncateFromOldest(agent.messages, max_bytes);
    }
}
```

### Q4: 子 Agent 的安全边界?

**决策**: 严格限制

```zig
pub const SubAgentOptions = struct {
    max_depth: u32 = 1,       // 最多 1 层嵌套
    max_steps: u32 = 3,       // 最多 3 步
    read_only: bool = true,   // 强制只读
    timeout_ms: u32 = 60000,  // 60 秒超时
    approval_policy: ApprovalPolicy = .never, // 强制 never
};
```

---

## 迁移策略

### 阶段 1: 向后兼容 (不破坏现有 API)

```zig
// 现有代码保持工作
var agent = try agent.Agent.init(allocator, options);
try agent.runLoop();

// 新增可选的 harness 增强
try agent.enableHarness(.{
    .workspace_context = true,
    .prompt_cache = true,
    .context_truncation = true,
});
```

### 阶段 2: 渐进迁移

```zig
// 新代码使用 harness
var harness = try harness.Harness.init(allocator, .{
    .workspace_context = true,
    .prompt_cache = true,
});
try harness.runLoop();
```

### 阶段 3: 移除旧代码 (可选)

```
未来版本可以考虑:
- 移除 Agent 中重复的上下文逻辑
- 统一使用 harness 层
```

---

## Phase 4: Production Ready (3-4 周)

#### Sprint G: Observability
```
Task-FEAT-012: Reasoning Trace (6h)
  └─ 完整记录 thought → action → observation
  └─ Trace 保存/加载
  └─ CLI trace 命令
```

#### Sprint H: Safety
```
Task-FEAT-013: Resource Limits (4h)
  └─ 步数/成本/内存/超时限制
  └─ CLI 配置选项
  └─ 优雅退出
```

---

## 验收标准

### 必须通过

- [ ] `zig build` 编译通过
- [ ] `zig build test` 所有测试通过
- [ ] Token 消耗降低 30%+ (基准测试)
- [ ] 100 轮对话不出现 context overflow
- [ ] Session 保存/恢复 100% 正确

### 建议通过

- [ ] 子 Agent 能正确处理并行任务
- [ ] 审批流程用户体验良好
- [ ] 性能无明显下降

---

## 参考实现

1. **Raschka mini-coding-agent**: https://github.com/rasbt/mini-coding-agent
2. **Claude Code**: Production-grade coding agent
3. **Letta (Sarah Wooders)**: Memory-centric agent architecture

---

## 附录: 任务依赖图

```
Phase 1 (Core)                    Phase 2 (Interactive)
─────────────────────            ──────────────────────
Task-FEAT-006 ──┬── Task-FEAT-007 ──┬── Task-FEAT-008 ── Task-FEAT-009
(Workspace)    │   (PromptCache)   │   (Truncation)   │   (Approval)
                │                    │                    │
                │                    └────────────────────┴── Task-FEAT-010
                │                                          │   (Session)
                │                                          │
Phase 3 (Advanced)                                       ├── Task-FEAT-011
──────────────────                                       │   (Subagent)
Task-FEAT-010 ──┬── Task-FEAT-011                       │
(Session)       │   (Subagent)                           │
                │                                        Phase 4 (Production)
                └─────────────────────────────────────────┼── Task-FEAT-012
                                                              │   (Trace)
                                                              │
Phase 5 (Engineering)                                    ├── Task-FEAT-013
────────────────────────                                  │   (Limits)
Task-FEAT-014 ──┬── Task-FEAT-015 ──┬── Task-FEAT-016    │
(Knowledge)      │   (Linter)        │   (Slop)           │
                │                    │                    Phase 6 (Automation)
                │                    │                    ─────────────────
                └────────────────────┴── Task-FEAT-017
                                        │   (SelfReview)
                                        │
                                        └── [End]
```
