### TASK-FEAT-021: 实现 Meta-Harness 自我进化系统
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 16h
**参考**: 
- Harrison Chase (LangChain) 关于 "Harness 层学习" 的观点
- Meta-Harness 论文 (yoonholeee)
- **AutoAgent** (Kevin Gu, dexbythirdlayer): SpreadsheetBench 96.5%, TerminalBench 55.1% (#1)
- `docs/research/autoagent-meta-harness-analysis.md`

**描述**:
实现 Meta-Harness 系统，让 Agent 能够根据运行 traces 和 eval scores 自动迭代优化 harness 自身的配置和代码，实现"让 harness 自己变聪明"的闭环。

**背景**:
Harrison Chase 强调：Agent 有三层可以学习 (Model / Harness / Context)，而 **Harness 层通过 meta-learning 可以实现自我进化**。

Meta-Harness 论文的核心思路：
- Outer-loop agent 能访问所有历史版本的 harness 代码
- 能访问之前的 reasoning traces
- 能访问 eval scores
- 能自动迭代修改 harness 的关键部分

**架构设计**:
```
┌─────────────────────────────────────────────────────────────┐
│                      Outer Loop (Meta)                        │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐  │
│  │ Trace Store │  │ Eval Scores  │  │ History Codes │  │
│  └─────────────┘  └──────────────┘  └────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           ↓ 修改
┌─────────────────────────────────────────────────────────────┐
│                      Inner Harness                           │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐  │
│  │Context Mgmt  │  │Memory System │  │Tools + Router │  │
│  └─────────────┘  └──────────────┘  └────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

**kimiz 当前学习系统 vs Meta-Harness**:

| 当前 (被动) | Meta-Harness (主动) |
|-------------|---------------------|
| 记录成功/失败 | 分析 traces 找模式 |
| 追踪性能指标 | 生成优化假设 |
| 学习用户偏好 | 自动修改 harness 配置 |
| - | 验证效果并迭代 |

**实现步骤**:

1. **创建 MetaHarness 模块**
```zig
// src/meta/root.zig
pub const MetaHarness = struct {
    allocator: std.mem.Allocator,
    inner_harness: *Agent,           // 被优化的 harness
    
    // Meta 层数据
    trace_store: TraceStore,
    eval_store: EvalStore,
    config_history: ConfigHistory,
    
    // 进化策略
    strategy: EvolutionStrategy,
    
    const Self = @This();
    
    /// 从 traces 中提取优化假设
    pub fn generateHypotheses(self: *Self) ![]Hypothesis {
        // 1. 分析历史 traces
        const traces = try self.trace_store.getRecent(100);
        
        // 2. 找失败模式
        const failures = try self.identifyFailurePatterns(traces);
        
        // 3. 找成功模式
        const successes = try self.identifySuccessPatterns(traces);
        
        // 4. 生成优化假设
        return try self.formulateHypotheses(failures, successes);
    }
    
    /// 验证优化假设
    pub fn testHypothesis(self: *Self, hypothesis: Hypothesis) !TestResult {
        // 1. 创建修改后的 harness 配置
        const modified_config = try self.applyChange(hypothesis);
        
        // 2. 运行评估
        const eval_result = try self.runEvaluation(modified_config);
        
        // 3. 比较效果
        const baseline = try self.getBaseline();
        const improvement = eval_result.score - baseline.score;
        
        return TestResult{
            .hypothesis = hypothesis,
            .improvement = improvement,
            .significant = @abs(improvement) > 0.05,
        };
    }
    
    /// 执行进化
    pub fn evolve(self: *Self) !EvolutionResult {
        // 1. 生成假设
        const hypotheses = try self.generateHypotheses();
        
        // 2. 测试每个假设
        var best: ?Hypothesis = null;
        var best_improvement: f64 = 0;
        
        for (hypotheses) |h| {
            const result = try self.testHypothesis(h);
            if (result.significant and result.improvement > best_improvement) {
                best_improvement = result.improvement;
                best = h;
            }
        }
        
        // 3. 应用最佳修改
        if (best) |h| {
            try self.applyBestChange(h);
        }
        
        return EvolutionResult{
            .tested = hypotheses.len,
            .best = best,
            .improvement = best_improvement,
        };
    }
};
```

2. **创建 TraceStore**
```zig
// src/meta/trace_store.zig
pub const TraceStore = struct {
    allocator: std.mem.Allocator,
    traces: std.MultiArrayList(HarnessTrace),
    storage_path: []const u8,
    
    /// 记录一次 harness 执行
    pub fn record(self: *Self, trace: HarnessTrace) !void {
        try self.traces.append(trace);
        
        // 定期持久化
        if (self.traces.len % 100 == 0) {
            try self.persist();
        }
    }
    
    /// 获取最近的 traces
    pub fn getRecent(self: *Self, count: usize) ![]const HarnessTrace {
        const start = if (self.traces.len > count) 
            self.traces.len - count else 0;
        return self.traces.items[start..];
    }
    
    /// 分析失败模式
    pub fn identifyFailurePatterns(self: *Self, traces: []const HarnessTrace) ![]FailurePattern {
        var patterns = std.ArrayList(FailurePattern).init(self.allocator);
        
        for (traces) |trace| {
            if (trace.outcome == .failure) {
                const pattern = try self.extractPattern(trace);
                try patterns.append(pattern);
            }
        }
        
        return patterns.toOwnedSlice();
    }
};

/// Harness 执行轨迹
pub const HarnessTrace = struct {
    timestamp: i64,
    config_version: []const u8,
    
    // 输入
    task: []const u8,
    context_snapshot: []const u8,
    
    // 执行过程
    tool_calls: []const ToolCall,
    memory_operations: []const MemoryOp,
    
    // 输出
    outcome: Outcome,
    tokens_used: u32,
    latency_ms: u32,
    
    // 可学习的点
    interesting_moments: []const InterestingMoment,
};

pub const Outcome = union(enum) {
    success: SuccessDetails,
    failure: FailureDetails,
    timeout: TimeoutDetails,
};
```

3. **创建 EvalStore**
```zig
// src/meta/eval_store.zig
pub const EvalStore = struct {
    allocator: std.mem.Allocator,
    scores: std.StringHashMap(EvalScore),
    
    /// 记录评估分数
    pub fn record(self: *Self, eval: Eval) !void {
        const gop = try self.scores.getOrPut(eval.task_id);
        gop.value_ptr.* = eval.score;
    }
    
    /// 获取基线
    pub fn getBaseline(self: *Self) !f64 {
        var total: f64 = 0;
        var count: usize = 0;
        
        var iter = self.scores.valueIterator();
        while (iter.next()) |score| {
            total += score.*;
            count += 1;
        }
        
        return if (count > 0) total / @as(f64, @intCast(count)) else 0;
    }
};

pub const EvalScore = struct {
    task_id: []const u8,
    timestamp: i64,
    
    // 多维度分数
    correctness: f64,        // 0-1
    efficiency: f64,          // 0-1
    token_efficiency: f64,    // 0-1
    
    // 综合分数
    pub fn composite(self: EvalScore) f64 {
        return self.correctness * 0.4 + 
               self.efficiency * 0.3 + 
               self.token_efficiency * 0.3;
    }
};
```

4. **创建 ConfigHistory**
```zig
// src/meta/config_history.zig
pub const ConfigHistory = struct {
    allocator: std.mem.Allocator,
    versions: std.ArrayList(ConfigVersion),
    
    /// 记录配置版本
    pub fn record(self: *Self, config: Config, eval_result: EvalScore) !void {
        try self.versions.append(.{
            .timestamp = std.time.timestamp(),
            .config = try config.clone(),
            .eval_score = eval_result,
        });
    }
    
    /// 获取历史最佳配置
    pub fn getBest(self: *Self) !?ConfigVersion {
        if (self.versions.len == 0) return null;
        
        var best: ?usize = null;
        var best_score: f64 = -1;
        
        for (self.versions, 0..) |v, i| {
            const score = v.eval_score.composite();
            if (score > best_score) {
                best_score = score;
                best = i;
            }
        }
        
        return if (best) |i| self.versions[i] else null;
    }
    
    /// 回滚到指定版本
    pub fn rollback(self: *Self, version: usize) !Config {
        return try self.versions[version].config.clone();
    }
};

pub const ConfigVersion = struct {
    timestamp: i64,
    config: Config,
    eval_score: EvalScore,
    change_description: []const u8,
};
```

5. **定义 Hypothesis 和 EvolutionStrategy**
```zig
// src/meta/evolution.zig
pub const Hypothesis = struct {
    id: []const u8,
    description: []const u8,
    
    // 假设来源
    evidence: []const Evidence,
    
    // 提议的修改
    proposed_change: ProposedChange,
    
    // 预期影响
    expected_improvement: f64,
};

pub const ProposedChange = union(enum) {
    // Context Management
    increase_context_window: IncreaseContext,
    adjust_truncation_threshold: AdjustThreshold,
    
    // Memory
    change_memory_tier_weights: WeightsAdjustment,
    modify_retention_policy: RetentionPolicy,
    
    // Tools
    add_tool: ToolDefinition,
    remove_tool: []const u8,
    modify_tool_permission: ToolPermissionChange,
    
    // Routing
    adjust_routing_strategy: RoutingStrategy,
    
    // Prompts
    modify_system_prompt: PromptModification,
    adjust_temperature: f64,
};

pub const Evidence = struct {
    trace_count: u32,
    pattern_type: PatternType,
    description: []const u8,
};

pub const EvolutionStrategy = struct {
    // 探索参数
    exploration_rate: f64 = 0.1,     // 随机探索概率
    exploitation_rate: f64 = 0.9,   // 利用已有知识概率
    
    // 收敛参数
    min_improvement: f64 = 0.01,    // 最小显著改进
    max_iterations: u32 = 50,       // 最大迭代次数
    convergence_threshold: u32 = 5,  // 连续无改进次数阈值
    
    // 多样性
    keep_top_k: u32 = 10,          // 保留 Top-K 假设
    diversity_threshold: f64 = 0.8,  // 假设多样性阈值
};
```

6. **实现假设生成逻辑**
```zig
// src/meta/hypothesis_generator.zig
pub const HypothesisGenerator = struct {
    allocator: std.mem.Allocator,
    
    /// 从失败模式生成假设
    pub fn fromFailures(self: *Self, failures: []const FailurePattern) ![]Hypothesis {
        var hypotheses = std.ArrayList(Hypothesis).init(self.allocator);
        
        for (failures) |failure| {
            switch (failure.type) {
                .context_overflow => {
                    // 尝试增加 context window
                    try hypotheses.append(.{
                        .id = try std.fmt.allocPrint(self.allocator, "ctx_{d}", .{failure.frequency}),
                        .description = "Increase context window to reduce overflow",
                        .evidence = &.{ try self.evidenceFromFailure(failure) },
                        .proposed_change = .{ .increase_context_window = .{ .by_percent = 20 } },
                        .expected_improvement = 0.1,
                    });
                    
                    // 尝试调整 truncation threshold
                    try hypotheses.append(.{
                        .id = try std.fmt.allocPrint(self.allocator, "trunc_{d}", .{failure.frequency}),
                        .description = "Adjust truncation to keep more relevant context",
                        .evidence = &.{ try self.evidenceFromFailure(failure) },
                        .proposed_change = .{ .adjust_truncation_threshold = .{ .new_threshold = 0.75 } },
                        .expected_improvement = 0.08,
                    });
                },
                
                .token_overuse => {
                    // 尝试更激进的压缩
                    try hypotheses.append(.{
                        .id = try std.fmt.allocPrint(self.allocator, "comp_{d}", .{failure.frequency}),
                        .description = "Use more aggressive compression",
                        .evidence = &.{ try self.evidenceFromFailure(failure) },
                        .proposed_change = .{ .adjust_truncation_threshold = .{ .new_threshold = 0.7 } },
                        .expected_improvement = 0.05,
                    });
                },
                
                .tool_misuse => {
                    // 尝试调整工具权限
                    try hypotheses.append(.{
                        .id = try std.fmt.allocPrint(self.allocator, "tool_{s}", .{failure.tool_name}),
                        .description = "Modify tool permission for better access",
                        .evidence = &.{ try self.evidenceFromFailure(failure) },
                        .proposed_change = .{ .modify_tool_permission = .{
                            .tool_id = failure.tool_name,
                            .new_permission = .auto_approve,
                        }},
                        .expected_improvement = 0.12,
                    });
                },
                
                else => {},
            }
        }
        
        return hypotheses.toOwnedSlice();
    }
    
    /// 从成功模式生成假设
    pub fn fromSuccesses(self: *Self, successes: []const SuccessPattern) ![]Hypothesis {
        // 成功模式可以用于强化学习
        // 但通常不会直接生成修改假设，而是作为对比基线
        return &.{};
    }
};
```

7. **实现评估循环**
```zig
// src/meta/evaluator.zig
pub const MetaEvaluator = struct {
    allocator: std.mem.Allocator,
    benchmark_suite: BenchmarkSuite,
    
    /// 运行评估
    pub fn evaluate(self: *Self, config: Config) !EvalResult {
        var total_score: f64 = 0;
        var task_results = std.ArrayList(TaskResult).init(self.allocator);
        
        for (self.benchmark_suite.tasks) |task| {
            // 创建测试 harness
            var test_harness = try self.createTestHarness(config);
            defer test_harness.deinit();
            
            // 运行任务
            const result = try test_harness.runTask(task);
            
            try task_results.append(result);
            total_score += result.score.composite();
        }
        
        return EvalResult{
            .tasks = try task_results.toOwnedSlice(),
            .overall_score = total_score / @as(f64, @intCast(self.benchmark_suite.tasks.len)),
            .timestamp = std.time.timestamp(),
        };
    }
};

pub const BenchmarkSuite = struct {
    tasks: []const BenchmarkTask,
};

pub const BenchmarkTask = struct {
    id: []const u8,
    description: []const u8,
    expected_outcome: []const u8,
    difficulty: Difficulty,
};
```

8. **与现有 Learning 模块集成**
```zig
// src/learning/root.zig
// 新增方法
pub const LearningEngine = struct {
    // ... existing fields ...
    
    // Meta-learning (新增)
    meta_harness: ?*MetaHarness,
    
    pub fn enableMetaLearning(self: *Self, allocator: std.mem.Allocator) !void {
        self.meta_harness = try allocator.create(MetaHarness);
        self.meta_harness.* = try MetaHarness.init(allocator, self);
    }
    
    /// 定期触发 meta-evolution
    pub fn periodicEvolution(self: *Self) !void {
        if (self.meta_harness) |mh| {
            // 检查是否满足进化条件
            const should_evolve = try self.shouldTriggerEvolution();
            if (should_evolve) {
                const result = try mh.evolve();
                std.log.info("Meta-evolution: tested={d}, improvement={e}", .{
                    result.tested,
                    result.improvement,
                });
            }
        }
    }
    
    fn shouldTriggerEvolution(self: *Self) !bool {
        // 条件：
        // 1. 积累足够多的 traces
        // 2. 距离上次进化超过一定时间
        // 3. 当前性能低于基线
        const traces = self.getTraceCount();
        const last_evolution = self.last_evolution_time;
        const now = std.time.timestamp();
        
        return traces > 100 and 
               (now - last_evolution) > 86400 and  // 24 hours
               try self.isPerformanceDegraded();
    }
};
```

**验收标准**:
- [ ] MetaHarness 结构完整
- [ ] TraceStore 能记录和检索 traces
- [ ] EvalStore 能追踪分数
- [ ] ConfigHistory 支持版本记录和回滚
- [ ] HypothesisGenerator 能从失败模式生成假设
- [ ] MetaEvaluator 能运行 benchmark
- [ ] 进化循环能改进 harness 配置
- [ ] `zig build test` 测试通过

**依赖**:
- TASK-INTEG-001 (Memory 集成)
- TASK-INTEG-002 (Learning 集成)
- TASK-FEAT-012 (Reasoning Trace)

**阻塞**:
- 无

**AutoAgent 整合 (2026-04-05 更新)**:

Kevin Gu 开源的 AutoAgent 提供了 Meta-Harness 的完整实现，关键成果：
- **SpreadsheetBench**: 96.5% (#1)
- **TerminalBench**: GPT-5 55.1% (#1)
- **24小时自动优化**超越所有手调方案

**核心发现 - Model Empathy**:
- 同模型配对 (Claude meta + Claude task): 96.5%
- 跨模型配对性能下降 ~18%
- **启示**: kimiz Meta-Harness 必须使用与 Task Agent 相同的模型

**整合方案**:
```zig
// src/meta/autoagent_adapter.zig
pub const AutoAgentAdapter = struct {
    /// Connect to AutoAgent optimization loop
    pub fn connect(self: *AutoAgentAdapter, config: AutoAgentConfig) !void;
    
    /// Import optimized harness from AutoAgent
    pub fn importOptimizedHarness(self: *AutoAgentAdapter) !HarnessConfig;
    
    /// Export kimiz harness for AutoAgent optimization
    pub fn exportForOptimization(self: *AutoAgentAdapter) !ExportFormat;
};
```

**优化循环**:
1. kimiz 导出当前 harness 配置
2. AutoAgent 运行 24h 优化循环
3. 导入优化后的配置
4. 验证改进效果

**参考**: `docs/research/autoagent-meta-harness-analysis.md`

---

**笔记**:
- 这是高级功能，需要在基础学习系统完成后实现
- 考虑使用更小的模型来做 meta-evolution 决策 (成本优化)
- 进化可能需要很长时间，考虑后台运行
- 安全检查：防止危险的配置修改
- **关键**: 同模型配对原则 (Model Empathy)
