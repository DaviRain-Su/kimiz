# TASK-FEAT-023: Content Expiration System

**状态**: pending  
**优先级**: P1  
**预计工时**: 6小时  
**指派给**: TBD  
**标签**: harness, context-architecture, memory

---

## 背景

基于 Nyk 四大支柱研究，Context Architecture 要求动态注入 + 过期清理。避免 AGENTS.md 变成 2000 行百科全书。

> "根指令文件 < 200 行...过期规则每月清理" —— Nyk

---

## 目标

实现内容过期检测和自动清理机制，保持上下文精简有效。

---

## 详细需求

### 1. Expiration Metadata

```zig
// src/harness/content_expiration.zig
pub const ContentMetadata = struct {
    id: []const u8,
    created_at: i64,
    last_accessed: i64,
    access_count: u32,
    expires_at: ?i64,      // 可选过期时间
    tags: []const []const u8,
};
```

### 2. Expiration Policies

```zig
pub const ExpirationPolicy = enum {
    /// 30 天未访问过期
    stale_30d,
    /// 90 天未访问过期
    stale_90d,
    /// 访问 <3 次且超过 14 天过期
    low_usage,
    /// 永不过期
    permanent,
};
```

### 3. Auto-Cleanup Scheduler

```zig
pub const CleanupScheduler = struct {
    /// 每天检查一次
    check_interval: i64 = 24 * 60 * 60,
    
    /// 运行清理
    pub fn runCleanup(self: *CleanupScheduler) !CleanupReport;
};
```

### 4. 文件系统结构

```
.kimiz/context/
├── active/           # 活跃内容
├── archived/         # 归档内容（待清理）
└── expired/          # 已过期内容（可恢复）
```

---

## 验收标准

- [ ] 自动检测超过 30 天未访问的内容
- [ ] 低使用率内容 (<3 次/14天) 自动标记
- [ ] 提供 `kimiz context cleanup --dry-run` 预览
- [ ] 提供 `kimiz context cleanup --force` 执行清理
- [ ] 支持内容恢复（从 expired/ 恢复）
- [ ] 清理前备份到 archived/

---

## 相关文件

- `src/harness/context_truncation.zig`
- `src/memory/root.zig`
- `src/workspace/context.zig`

---

## 参考

- docs/research/harness-four-pillars-nyk-analysis.md
- "正确做法: 根指令文件 < 200 行，动态注入，过期规则每月清理"
