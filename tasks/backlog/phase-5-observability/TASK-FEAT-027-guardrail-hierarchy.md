# TASK-FEAT-027: Guardrail Hierarchy System

**状态**: pending  
**优先级**: P1  
**预计工时**: 10小时  
**指派给**: TBD  
**标签**: harness, safety, guardrails

---

## 背景

基于 Nyk 四大支柱研究，生产级 Harness 需要四层护栏体系，从硬限制到审计日志。

---

## 目标

实现完整的 Guardrail 分层系统，确保 Agent 安全、可控、可审计地执行。

---

## 详细需求

### 1. Guardrail Layers

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 4: Hard Limits (硬限制)                                │
│ ├── 成本上限 (token/调用次数)                                │
│ ├── 文件保护 (只读模式)                                      │
│ ├── 超时限制                                                 │
│ └── 操作次数限制                                             │
├─────────────────────────────────────────────────────────────┤
│ Layer 3: Safety Nets (安全网)                                │
│ ├── 模拟执行 (dry-run)                                       │
│ ├── 沙箱环境                                                 │
│ └── 回滚机制                                                 │
├─────────────────────────────────────────────────────────────┤
│ Layer 2: Golden Path (黄金路径)                              │
│ ├── 强制流程 (必须走 /spec→/plan→/build)                     │
│ ├── 检查清单 (必须完成所有项)                                │
│ └── 质量门禁                                                 │
├─────────────────────────────────────────────────────────────┤
│ Layer 1: Audit Logs (审计日志)                               │
│ ├── 完整操作记录                                             │
│ ├── 决策链路追踪                                             │
│ └── 失败模式归档                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2. Hard Limits Layer

```zig
// src/harness/guardrails.zig
pub const HardLimits = struct {
    /// Token usage limit
    max_tokens_per_session: u32 = 100_000,
    max_tokens_per_request: u32 = 10_000,
    
    /// API call limits
    max_api_calls_per_session: u32 = 100,
    max_api_calls_per_minute: u32 = 20,
    
    /// Time limits
    max_session_duration_minutes: u32 = 60,
    max_tool_execution_seconds: u32 = 30,
    
    /// File protection
    protected_files: []const []const u8,
    protected_patterns: []const []const u8,  // e.g., "*.key", "*.secret"
    
    pub fn enforce(self: *HardLimits, operation: Operation) !EnforcementResult;
};
```

### 3. Safety Nets Layer

```zig
pub const SafetyNets = struct {
    /// Dry run mode
    dry_run: bool = false,
    
    /// Sandbox environment
    sandbox: SandboxConfig,
    
    /// Rollback capability
    rollback: RollbackManager,
    
    pub fn executeWithSafety(self: *SafetyNets, operation: Operation) !SafetyResult {
        if (self.dry_run) {
            return self.simulate(operation);
        }
        
        // Create checkpoint for rollback
        const checkpoint = try self.rollback.createCheckpoint();
        errdefer self.rollback.restore(checkpoint);
        
        return self.executeInSandbox(operation);
    }
};
```

### 4. Golden Path Layer

```zig
pub const GoldenPath = struct {
    /// Required workflow steps
    required_steps: []const WorkflowStep,
    
    /// Checklist items
    checklist: []const ChecklistItem,
    
    /// Quality gates
    quality_gates: []const QualityGate,
    
    pub fn validate(self: *GoldenPath, execution: Execution) !ValidationResult {
        // Check all required steps completed
        // Check all checklist items checked
        // Check all quality gates passed
    }
};

pub const WorkflowStep = struct {
    id: []const u8,
    name: []const u8,
    required: bool,
    validator: ?*const fn () bool,
};

pub const ChecklistItem = struct {
    id: []const u8,
    description: []const u8,
    checked: bool,
};
```

### 5. Audit Logs Layer

```zig
pub const AuditLogger = struct {
    log_file: std.fs.File,
    
    /// Log any action
    pub fn logAction(self: *AuditLogger, action: Action) !void {
        const entry = AuditEntry{
            .timestamp = std.time.timestamp(),
            .action = action,
            .context = self.getCurrentContext(),
        };
        try self.append(entry);
    }
    
    /// Query audit trail
    pub fn query(self: *AuditLogger, filter: AuditFilter) ![]AuditEntry;
    
    /// Export audit log
    pub fn export(self: *AuditLogger, format: ExportFormat) ![]u8;
};
```

### 6. Guardrail Manager

```zig
pub const GuardrailManager = struct {
    hard_limits: HardLimits,
    safety_nets: SafetyNets,
    golden_path: GoldenPath,
    audit_logger: AuditLogger,
    
    /// Main entry: check all layers
    pub fn check(self: *GuardrailManager, operation: Operation) !GuardrailResult {
        // Layer 4: Hard limits
        try self.hard_limits.enforce(operation);
        
        // Layer 3: Safety nets
        const safety_result = try self.safety_nets.executeWithSafety(operation);
        
        // Layer 2: Golden path
        try self.golden_path.validate(self.execution);
        
        // Layer 1: Audit log
        try self.audit_logger.logAction(operation);
        
        return .{ .allowed = true };
    }
};
```

---

## 验收标准

- [ ] 实现四层 Guardrail 体系
- [ ] Hard Limits: token/调用/超时/文件保护
- [ ] Safety Nets: dry-run/沙箱/回滚
- [ ] Golden Path: 强制流程/检查清单/质量门禁
- [ ] Audit Logs: 完整操作记录/决策链路
- [ ] GuardrailManager 统一入口
- [ ] 支持 `kimiz run --dry-run` 模拟模式
- [ ] 支持 `kimiz audit log` 查看审计日志

---

## 相关文件

- `src/harness/resource_limits.zig`
- `src/harness/agent_linter.zig`
- `src/harness/reasoning_trace.zig`
- `src/harness/self_review.zig`

---

## 参考

- docs/research/harness-four-pillars-nyk-analysis.md
- "护栏分层: 从硬限制 → 安全网 → 黄金路径 → 审计日志"
