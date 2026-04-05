# TASK-FEAT-022: Token Budget Monitor

**状态**: pending  
**优先级**: P1  
**预计工时**: 4小时  
**指派给**: TBD  
**标签**: harness, context-architecture, performance

---

## 背景

基于 Nyk 四大支柱研究 (docs/research/harness-four-pillars-nyk-analysis.md)，Context Architecture 要求实现 Token 预算管理，超过 40% 时报警。

> "Token 预算管理: 超 40% 就报警" —— Nyk

---

## 目标

实现 Token 预算监控系统，防止上下文爆炸，确保模型始终获得最优上下文。

---

## 详细需求

### 1. Token Budget Tracker

```zig
// src/harness/token_budget.zig
pub const TokenBudget = struct {
    max_tokens: u32,           // 最大预算 (如 128000)
    warning_threshold: f32,    // 警告阈值 (默认 0.4 = 40%)
    current_usage: u32,        // 当前使用
    
    pub fn track(self: *TokenBudget, tokens: u32) void;
    pub fn checkWarning(self: *TokenBudget) ?Warning;
    pub fn getUsageRatio(self: *TokenBudget) f32;
};
```

### 2. 分层预算分配

```
总预算: 128000 tokens
├── 系统提示: 20% (25600)
├── 历史对话: 40% (51200) 
├── 当前任务上下文: 30% (38400)
└── 预留/输出: 10% (12800)
```

### 3. 警告机制

- **40% 警告**: 提示考虑上下文压缩
- **70% 警告**: 强制执行 truncation
- **90% 错误**: 拒绝添加新内容

### 4. 集成点

- `src/harness/context_truncation.zig`: 触发压缩
- `src/harness/prompt_cache.zig`: 预算检查
- `src/agent/agent.zig`: 执行前验证

---

## 验收标准

- [ ] 能准确追踪 prompt 的 token 使用量
- [ ] 40% 阈值触发警告日志
- [ ] 70% 阈值自动触发 context truncation
- [ ] 提供 `kimiz status --tokens` 查看当前预算
- [ ] 单元测试覆盖 >80%

---

## 相关文件

- `src/harness/context_truncation.zig`
- `src/harness/prompt_cache.zig`
- `src/workspace/context.zig`

---

## 参考

- docs/research/harness-four-pillars-nyk-analysis.md
- Nyk: "分层逐步披露，token 预算管理，超 40% 就报警"
