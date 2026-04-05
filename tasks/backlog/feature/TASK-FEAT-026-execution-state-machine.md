# TASK-FEAT-026: Structured Execution State Machine

**状态**: pending  
**优先级**: P0  
**预计工时**: 14小时  
**指派给**: TBD  
**标签**: agent, execution, harness, workflow

---

## 背景

基于 Nyk 四大支柱研究，Structured Execution 要求强制流程: research → plan → execute → verify，防止模型"抄近路"。

> "强制流程: research → plan → execute → verify...计划要先 review" —— Nyk

参考 Addy Skills 的 /spec → /plan → /build → /test 流程。

---

## 目标

实现显式执行状态机，强制走完整工程流程，防止跳过关键步骤。

---

## 详细需求

### 1. Execution State Enum

```zig
// src/agent/execution_state.zig
pub const ExecutionState = enum {
    /// 初始状态
    idle,
    
    /// Phase 1: 信息收集
    researching,
    research_complete,
    
    /// Phase 2: 计划制定
    planning,
    plan_pending_review,      // 计划待审查
    plan_approved,            // 计划已批准
    plan_rejected,            // 计划被拒绝
    
    /// Phase 3: 执行实现
    executing,
    execution_paused,         // 执行暂停（如预算警告）
    
    /// Phase 4: 验证
    verifying,
    verification_failed,      // 验证失败
    
    /// Phase 5: 结果回写
    writing_back,
    
    /// 完成
    completed,
    failed,
    cancelled,
};
```

### 2. State Machine Transitions

```
Idle → Researching → ResearchComplete → Planning → PlanPendingReview
                                                        ↓
              ┌───────────────────────────────────────┘
              ↓
        PlanApproved → Executing → Verifying → WritingBack → Completed
              ↑                      ↓
              └──────────────────────┘ (verification_failed loop back)
```

### 3. State Validator

```zig
pub const StateValidator = struct {
    /// Validate if transition is allowed
    pub fn canTransition(from: ExecutionState, to: ExecutionState) bool {
        return switch (from) {
            .idle => to == .researching,
            .researching => to == .research_complete,
            .research_complete => to == .planning,
            .planning => to == .plan_pending_review,
            .plan_pending_review => to == .plan_approved or to == .plan_rejected,
            .plan_rejected => to == .planning,  // 重新规划
            .plan_approved => to == .executing,
            .executing => to == .execution_paused or to == .verifying,
            .execution_paused => to == .executing or to == .failed,
            .verifying => to == .verification_failed or to == .writing_back,
            .verification_failed => to == .executing,  // 重新执行
            .writing_back => to == .completed or to == .failed,
            else => false,
        };
    }
    
    /// Enforce golden path
    pub fn enforceGoldenPath(self: *StateValidator) !void;
};
```

### 4. Budget Enforcement

```zig
pub const ExecutionBudget = struct {
    max_tokens: u32,
    max_iterations: u32,
    max_time_seconds: u32,
    
    pub fn checkBudget(self: *ExecutionBudget, current: ExecutionMetrics) !BudgetStatus;
};

pub const BudgetStatus = enum {
    within_budget,
    warning_70_percent,
    exceeded,
};
```

### 5. Plan Review Mode

```zig
pub const PlanReview = struct {
    plan: ExecutionPlan,
    status: ReviewStatus,
    reviewer_feedback: ?[]const u8,
    
    pub fn requestReview(self: *PlanReview) !void;
    pub fn approve(self: *PlanReview, feedback: ?[]const u8) !void;
    pub fn reject(self: *PlanReview, feedback: []const u8) !void;
};

pub const ReviewStatus = enum {
    pending,
    approved,
    rejected,
};
```

### 6. Result Writeback

```zig
pub const ResultWriteback = struct {
    /// Write execution results to memory
    pub fn writeToMemory(self: *ResultWriteback, result: ExecutionResult) !void {
        // 1. Update decisions.md (if new decisions made)
        // 2. Update failure-catalog.md (if failures occurred)
        // 3. Update session-state.md
        // 4. Update learned/ tool-effectiveness
    }
};
```

### 7. Integration with Agent Loop

```zig
// In src/agent/agent.zig
pub const Agent = struct {
    execution_state: ExecutionState,
    state_machine: StateValidator,
    budget: ExecutionBudget,
    
    pub fn run(self: *Agent, task: []const u8) !void {
        // 1. Research phase
        try self.transitionTo(.researching);
        try self.doResearch(task);
        try self.transitionTo(.research_complete);
        
        // 2. Plan phase
        try self.transitionTo(.planning);
        const plan = try self.createPlan();
        try self.transitionTo(.plan_pending_review);
        
        // 3. Plan review (can be auto or manual)
        if (self.options.yolo_mode) {
            try self.approvePlan(plan, null);
        } else {
            try self.requestPlanReview(plan);
            // Wait for approval...
        }
        
        // 4. Execute phase
        try self.transitionTo(.executing);
        try self.executePlan(plan);
        
        // 5. Verify phase
        try self.transitionTo(.verifying);
        const verified = try self.verifyResult();
        if (!verified) {
            try self.transitionTo(.verification_failed);
            // Loop back to executing or fail
        }
        
        // 6. Writeback phase
        try self.transitionTo(.writing_back);
        try self.writebackResult();
        
        try self.transitionTo(.completed);
    }
};
```

---

## 验收标准

- [ ] 实现完整的 ExecutionState 状态机
- [ ] 所有状态转换必须经过 StateValidator 验证
- [ ] 强制执行 research → plan → execute → verify 流程
- [ ] 支持 Plan Review 模式（可配置 yolo_mode 跳过）
- [ ] Budget 超支时自动暂停执行
- [ ] 验证失败时支持重新执行或失败
- [ ] 执行结果自动回写到 Persistent Memory
- [ ] 提供 `kimiz run --enforce-workflow` 强制模式

---

## 相关文件

- `src/agent/agent.zig` (Agent Loop)
- `src/harness/resource_limits.zig` (预算限制)
- `src/harness/agent_linter.zig` (流程检查)
- `src/learning/root.zig` (结果回写)
- `docs/research/addy-osmani-agent-skills-analysis.md` (/spec→/plan→/build→/test)

---

## 参考

- docs/research/harness-four-pillars-nyk-analysis.md
- docs/research/addy-osmani-agent-skills-analysis.md
- "强制走流程: research → plan → execute → verify"
