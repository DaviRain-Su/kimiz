# TASK-FEAT-025: Persistent File System Memory

**状态**: pending  
**优先级**: P0  
**预计工时**: 12小时  
**指派给**: TBD  
**标签**: memory, harness, persistence

---

## 背景

基于 Nyk 四大支柱研究，Persistent Memory 要求用文件系统存储真实记忆，跨 session 持久化。

> "用文件系统存真实记忆...每次 session 开始读、结束写，append-only 可审计" —— Nyk

---

## 目标

实现文件系统级别的持久化记忆系统，替代纯内存存储。

---

## 详细需求

### 1. Memory Directory Structure

```
.kimiz/memory/
├── decisions.md              # 架构决策记录 (ADR)
├── failure-catalog.md        # 失败模式库
├── patterns.md               # 代码模式偏好
├── session-state.md          # 当前 session 状态
├── context/
│   ├── current-task.md       # 当前任务上下文
│   ├── workspace-summary.md  # 工作区摘要
│   └── recent-changes.md     # 最近变更
└── learned/
    ├── tool-effectiveness.md    # 工具效果追踪
    ├── model-performance.md     # 模型性能记录
    └── user-preferences.md      # 用户偏好学习
```

### 2. File System Memory Manager

```zig
// src/memory/persistent_files.zig
pub const FileSystemMemory = struct {
    base_path: []const u8,
    
    /// Read all memory files at session start
    pub fn loadSession(self: *FileSystemMemory) !SessionMemory;
    
    /// Write all memory files at session end
    pub fn saveSession(self: *FileSystemMemory, session: SessionMemory) !void;
    
    /// Append to a specific memory file
    pub fn appendTo(self: *FileSystemMemory, file: MemoryFile, content: []const u8) !void;
    
    /// Query memory by tag/topic
    pub fn query(self: *FileSystemMemory, query: MemoryQuery) ![]MemoryEntry;
};

pub const MemoryFile = enum {
    decisions,
    failure_catalog,
    patterns,
    session_state,
    tool_effectiveness,
    model_performance,
    user_preferences,
};
```

### 3. decisions.md (ADR) 格式

```markdown
# Architecture Decision Records

## ADR-001: Use Zig for Core Implementation
- Date: 2026-04-05
- Status: accepted
- Context: Need high-performance, single-binary agent
- Decision: Use Zig 0.15.2
- Consequences: Fast startup, steep learning curve

## ADR-002: LMDB for Long-Term Memory
- Date: 2026-04-05
- Status: proposed
- Context: JSON too slow for large memory
- Decision: Migrate to LMDB
- Consequences: Better performance, C dependency
```

### 4. failure-catalog.md 格式

```markdown
# Failure Catalog

## FC-001: Compilation Error in Self Review
- Pattern: var vs const misuse
- Symptom: Zig compile error
- Root Cause: Not checking mutability
- Fix: Always check if variable is mutated
- Prevention: AgentLinter rule
- Occurrences: 2
- Last Occurred: 2026-04-05
```

### 5. session-state.md 格式

```markdown
# Session State: 2026-04-05-001

## Context
- Project: /home/user/project
- Task: Implement HTTP client
- Started: 2026-04-05T13:00:00Z

## Progress
- [x] Research: Completed
- [x] Plan: Approved
- [ ] Build: In progress (50%)
- [ ] Test: Pending
- [ ] Review: Pending

## Decisions Made
- Use std.http over external library

## Next Steps
- Complete error handling
- Write unit tests
```

### 6. Append-Only Audit Log

```zig
// src/memory/audit_log.zig
pub const AuditLog = struct {
    /// Append-only log of all decisions
    pub fn logDecision(self: *AuditLog, decision: Decision) !void;
    pub fn logAction(self: *AuditLog, action: Action) !void;
    pub fn logFailure(self: *AuditLog, failure: Failure) !void;
    
    /// Query audit trail
    pub fn query(self: *AuditLog, filter: AuditFilter) ![]AuditEntry;
};
```

---

## 验收标准

- [ ] 自动创建 `.kimiz/memory/` 目录结构
- [ ] Session 开始时自动加载所有记忆文件
- [ ] Session 结束时自动保存更新
- [ ] 支持 ADR (decisions.md) 自动记录
- [ ] 支持失败模式自动归档 (failure-catalog.md)
- [ ] 所有写入都是 append-only，可审计
- [ ] 提供 `kimiz memory status` 查看记忆统计
- [ ] 与现有 LMDB LongTermMemory 协同工作

---

## 相关文件

- `src/memory/root.zig` (MemoryManager)
- `src/utils/session.zig` (SessionStore)
- `src/learning/root.zig` (LearningEngine)
- `docs/research/addy-osmani-agent-skills-analysis.md` (ADR 概念)

---

## 参考

- docs/research/harness-four-pillars-nyk-analysis.md
- "文件系统存储真实记忆...append-only 可审计的历史"
