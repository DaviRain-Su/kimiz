# 智能任务路由与多模型协同系统

## 核心概念

**智能任务路由 (Intelligent Task Routing)** 是 kimiz 的核心差异化功能：

```
用户任务 → 任务分析 → 智能路由 → 最优模型执行 → 结果汇总
                ↓
         ┌──────┴──────┐
         ↓             ↓
    任务分解      模型选择
    (哪些子任务)   (哪个模型最适合)
```

## 1. 系统架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    Orchestrator Agent (协调器)                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Task Analyzer (任务分析器)                  │   │
│  │  - 意图识别 (代码生成/分析/文档/测试)                     │   │
│  │  - 复杂度评估 (简单/中等/复杂)                           │   │
│  │  - 所需能力识别 (推理/多模态/长上下文/代码执行)           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              ↓                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │            Task Router (任务路由器)                      │   │
│  │  - 匹配最优模型                                          │   │
│  │  - 考虑成本/速度/质量平衡                                 │   │
│  │  - 支持并行/串行策略                                      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              ↓                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │           Sub-Agent Pool (子代理池)                      │   │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐       │   │
│  │  │Sub-Agent│ │Sub-Agent│ │Sub-Agent│ │Sub-Agent│ ...   │   │
│  │  │ GPT-4o  │ │ Claude  │ │ Gemini  │ │  Kimi   │       │   │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              ↓                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │           Result Aggregator (结果聚合器)                 │   │
│  │  - 收集子任务结果                                        │   │
│  │  - 冲突检测与解决                                        │   │
│  │  - 生成最终响应                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## 2. 核心类型定义

```zig
// src/agent/router.zig

/// 任务类型识别
pub const TaskType = enum {
    // 代码相关
    code_generation,        // 代码生成
    code_review,           // 代码审查
    code_refactor,         // 代码重构
    code_debug,            // 代码调试
    test_generation,       // 测试生成
    
    // 文档相关
    documentation,         // 文档编写
    code_explanation,      // 代码解释
    
    // 分析相关
    architecture_design,   // 架构设计
    performance_analysis,  // 性能分析
    security_audit,        // 安全审计
    
    // 多模态相关
    image_analysis,        // 图像分析
    pdf_analysis,          // PDF 文档分析
    ui_design,             // UI 设计（图片生成代码）
    
    // 研究相关
    web_research,          // 网络研究
    data_analysis,         // 数据分析
    
    // 其他
    general_chat,          // 普通对话
    tool_execution,        // 工具执行
};

/// 任务复杂度
pub const TaskComplexity = enum {
    simple,     // 简单任务 (< 100 tokens 输出)
    moderate,   // 中等任务 (100-1000 tokens)
    complex,    // 复杂任务 (1000-5000 tokens)
    very_complex, // 非常复杂 (> 5000 tokens)
};

/// 所需能力
pub const RequiredCapability = enum {
    reasoning,          // 深度推理
    code_generation,    // 代码生成
    code_analysis,      // 代码分析
    multimodal_image,   // 图像理解
    multimodal_pdf,     // PDF 理解
    long_context,       // 长上下文
    tool_use,           // 工具使用
    fast_response,      // 快速响应
    cost_efficient,     // 成本效益
};

/// 任务分析结果
pub const TaskAnalysis = struct {
    task_type: TaskType,
    complexity: TaskComplexity,
    required_capabilities: []const RequiredCapability,
    estimated_tokens: u32,           // 预估 token 数
    can_parallelize: bool,           // 是否可以并行
    suggested_sub_tasks: []const SubTaskSuggestion,
    user_query: []const u8,          // 原始查询
};

/// 子任务建议
pub const SubTaskSuggestion = struct {
    id: []const u8,
    description: []const u8,
    task_type: TaskType,
    complexity: TaskComplexity,
    required_capabilities: []const RequiredCapability,
    dependencies: []const []const u8,  // 依赖的其他子任务 ID
    estimated_time_ms: u32,           // 预估执行时间
};

/// 模型能力评分
pub const ModelCapabilityScore = struct {
    model: *const Model,
    scores: std.EnumArray(RequiredCapability, f32),  // 0.0 - 1.0
    cost_per_1k_tokens: f64,
    avg_latency_ms: u32,
};

/// 路由决策
pub const RoutingDecision = struct {
    strategy: RoutingStrategy,
    assignments: []const TaskAssignment,
    total_estimated_cost: f64,
    total_estimated_time_ms: u32,
    reasoning: []const u8,  // 决策理由
};

pub const RoutingStrategy = enum {
    single_model,       // 单一模型处理
    parallel_models,    // 多模型并行（投票/互补）
    pipeline,          // 流水线（一个模型的输出给下一个）
    hierarchical,      // 分层（主模型分解，子模型执行）
};

/// 任务分配
pub const TaskAssignment = struct {
    sub_task_id: []const u8,
    model: *const Model,
    provider: KnownProvider,
    fallback_model: ?*const Model,  // 失败时的备选
    timeout_ms: u32,
    max_retries: u8,
};
```

## 3. 模型能力矩阵

```zig
// src/agent/model_capabilities.zig

/// 预定义的模型能力评分
pub const MODEL_CAPABILITY_MATRIX = &[_]ModelCapabilityScore{
    // GPT-4o - 全能型
    .{
        .model = &Models.gpt_4o,
        .scores = .{
            .reasoning = 0.85,
            .code_generation = 0.90,
            .code_analysis = 0.88,
            .multimodal_image = 0.85,
            .multimodal_pdf = 0.60,  // 需转换图片
            .long_context = 0.80,
            .tool_use = 0.90,
            .fast_response = 0.70,
            .cost_efficient = 0.60,
        },
        .cost_per_1k_tokens = 0.0025,
        .avg_latency_ms = 800,
    },
    
    // GPT-4o-mini - 快速/便宜
    .{
        .model = &Models.gpt_4o_mini,
        .scores = .{
            .reasoning = 0.70,
            .code_generation = 0.75,
            .code_analysis = 0.72,
            .multimodal_image = 0.70,
            .multimodal_pdf = 0.50,
            .long_context = 0.75,
            .tool_use = 0.80,
            .fast_response = 0.90,
            .cost_efficient = 0.95,
        },
        .cost_per_1k_tokens = 0.00015,
        .avg_latency_ms = 400,
    },
    
    // Claude Sonnet 4 - 深度分析
    .{
        .model = &Models.claude_sonnet_4,
        .scores = .{
            .reasoning = 0.95,
            .code_generation = 0.88,
            .code_analysis = 0.92,
            .multimodal_image = 0.85,
            .multimodal_pdf = 0.90,  // 原生 PDF 支持
            .long_context = 0.95,    // 200K 上下文
            .tool_use = 0.85,
            .fast_response = 0.60,
            .cost_efficient = 0.50,
        },
        .cost_per_1k_tokens = 0.003,
        .avg_latency_ms = 1200,
    },
    
    // Claude Haiku 4 - 快速
    .{
        .model = &Models.claude_haiku_4,
        .scores = .{
            .reasoning = 0.75,
            .code_generation = 0.78,
            .code_analysis = 0.76,
            .multimodal_image = 0.75,
            .multimodal_pdf = 0.80,
            .long_context = 0.85,
            .tool_use = 0.80,
            .fast_response = 0.85,
            .cost_efficient = 0.90,
        },
        .cost_per_1k_tokens = 0.0008,
        .avg_latency_ms = 500,
    },
    
    // Gemini 2.5 Pro - 多模态/长上下文
    .{
        .model = &Models.gemini_2_5_pro,
        .scores = .{
            .reasoning = 0.90,
            .code_generation = 0.85,
            .code_analysis = 0.86,
            .multimodal_image = 0.90,
            .multimodal_pdf = 0.95,  // 最强 PDF 支持
            .long_context = 0.98,    // 1M 上下文
            .tool_use = 0.80,
            .fast_response = 0.65,
            .cost_efficient = 0.85,  // 便宜
        },
        .cost_per_1k_tokens = 0.00125,
        .avg_latency_ms = 1000,
    },
    
    // Gemini 2.0 Flash - 极速
    .{
        .model = &Models.gemini_2_0_flash,
        .scores = .{
            .reasoning = 0.75,
            .code_generation = 0.78,
            .code_analysis = 0.76,
            .multimodal_image = 0.80,
            .multimodal_pdf = 0.85,
            .long_context = 0.90,
            .tool_use = 0.75,
            .fast_response = 0.95,
            .cost_efficient = 0.98,  // 最便宜
        },
        .cost_per_1k_tokens = 0.0001,
        .avg_latency_ms = 300,
    },
    
    // Kimi K2.5 - 中文/长上下文
    .{
        .model = &Models.kimi_k2_5,
        .scores = .{
            .reasoning = 0.88,
            .code_generation = 0.87,
            .code_analysis = 0.85,
            .multimodal_image = 0.82,
            .multimodal_pdf = 0.85,
            .long_context = 0.92,    // 256K
            .tool_use = 0.88,
            .fast_response = 0.75,
            .cost_efficient = 0.80,
        },
        .cost_per_1k_tokens = 0.0005,
        .avg_latency_ms = 700,
    },
};
```

## 4. 任务分析器

```zig
// src/agent/task_analyzer.zig

pub const TaskAnalyzer = struct {
    allocator: std.mem.Allocator,
    ai: *Ai,  // 用于 LLM 辅助分析
    
    /// 分析用户任务
    pub fn analyze(
        self: *TaskAnalyzer,
        arena: std.mem.Allocator,
        user_query: []const u8,
        context: ?[]const u8,
    ) !TaskAnalysis {
        // 1. 基于规则快速分类
        const rule_based_type = self.classifyByRules(user_query);
        
        // 2. 使用 LLM 深度分析（如果规则不确定）
        const analysis = if (rule_based_type == .general_chat)
            try self.analyzeWithLLM(arena, user_query, context)
        else
            self.buildAnalysis(arena, user_query, rule_based_type);
        
        // 3. 评估复杂度
        analysis.complexity = self.assessComplexity(user_query, analysis.task_type);
        
        // 4. 识别所需能力
        analysis.required_capabilities = self.identifyCapabilities(analysis);
        
        // 5. 建议子任务（如果可并行）
        if (analysis.can_parallelize) {
            analysis.suggested_sub_tasks = try self.suggestSubTasks(arena, analysis);
        }
        
        return analysis;
    }
    
    /// 基于关键词规则分类
    fn classifyByRules(self: *TaskAnalyzer, query: []const u8) TaskType {
        const lower = std.ascii.toLower(query);
        
        // 代码生成
        if (containsAny(lower, &.{"写代码", "生成代码", "实现", "create function", "write code", "generate"})) {
            return .code_generation;
        }
        
        // 代码审查
        if (containsAny(lower, &.{"审查", "review", "检查代码", "code review", "analyze code"})) {
            return .code_review;
        }
        
        // 重构
        if (containsAny(lower, &.{"重构", "优化", "refactor", "improve", "optimize"})) {
            return .code_refactor;
        }
        
        // 调试
        if (containsAny(lower, &.{"调试", "debug", "fix bug", "错误", "error"})) {
            return .code_debug;
        }
        
        // 测试
        if (containsAny(lower, &.{"测试", "test", "unit test", "测试用例"})) {
            return .test_generation;
        }
        
        // 图像分析
        if (containsAny(lower, &.{"图片", "图像", "截图", "image", "picture", "screenshot"})) {
            return .image_analysis;
        }
        
        // PDF 分析
        if (containsAny(lower, &.{"pdf", "文档", "document", "论文", "paper"})) {
            return .pdf_analysis;
        }
        
        // 网络研究
        if (containsAny(lower, &.{"搜索", "查一下", "search", "查找", "research", "最新"})) {
            return .web_research;
        }
        
        return .general_chat;
    }
    
    /// 使用 LLM 进行深度分析
    fn analyzeWithLLM(
        self: *TaskAnalyzer,
        arena: std.mem.Allocator,
        query: []const u8,
        context: ?[]const u8,
    ) !TaskAnalysis {
        const prompt = std.fmt.allocPrint(arena,
            \Analyze the following task and classify it:
            \\n            \Query: {s}
            \Context: {s}
            \\n            \Classify into one of: code_generation, code_review, code_refactor, 
            \code_debug, test_generation, documentation, architecture_design, 
            \performance_analysis, security_audit, image_analysis, pdf_analysis, 
            \ui_design, web_research, data_analysis, general_chat
            \\n            \Also assess complexity (simple/moderate/complex/very_complex) and 
            \identify required capabilities.
            \\n            \Return JSON format.
        , .{ query, context orelse "none" });
        
        // 使用轻量级模型进行分析（成本低）
        const model = Models.gpt_4o_mini;
        const result = try self.ai.complete(arena, &model, .{
            .messages = &[_]Message{.{
                .user = .{
                    .content_text = prompt,
                    .timestamp = std.time.milliTimestamp(),
                },
            }},
        }, .{});
        
        // 解析 LLM 返回的 JSON
        return try parseAnalysisJson(arena, result.content[0].text.text);
    }
    
    /// 评估复杂度
    fn assessComplexity(self: *TaskAnalyzer, query: []const u8, task_type: TaskType) TaskComplexity {
        // 基于任务类型和查询长度评估
        const len = query.len;
        
        return switch (task_type) {
            .code_generation => if (len < 50) .simple else if (len < 200) .moderate else .complex,
            .code_review => if (len < 100) .simple else .moderate,
            .architecture_design => .complex,
            .security_audit => .complex,
            .general_chat => if (len < 30) .simple else .moderate,
            else => .moderate,
        };
    }
    
    /// 识别所需能力
    fn identifyCapabilities(self: *TaskAnalyzer, analysis: TaskAnalysis) []const RequiredCapability {
        var capabilities = std.ArrayList(RequiredCapability).init(self.allocator);
        
        // 根据任务类型添加必需能力
        switch (analysis.task_type) {
            .code_generation => {
                capabilities.append(.code_generation) catch {};
                capabilities.append(.tool_use) catch {};
            },
            .code_review, .security_audit => {
                capabilities.append(.code_analysis) catch {};
                capabilities.append(.reasoning) catch {};
            },
            .image_analysis => {
                capabilities.append(.multimodal_image) catch {};
            },
            .pdf_analysis => {
                capabilities.append(.multimodal_pdf) catch {};
            },
            .web_research => {
                capabilities.append(.tool_use) catch {};
            },
            else => {},
        }
        
        // 根据复杂度添加能力
        if (analysis.complexity == .complex or analysis.complexity == .very_complex) {
            capabilities.append(.reasoning) catch {};
        }
        
        return capabilities.toOwnedSlice();
    }
};
```

## 5. 智能路由器

```zig
// src/agent/router.zig

pub const TaskRouter = struct {
    allocator: std.mem.Allocator,
    config: RouterConfig,
    
    /// 路由决策
    pub fn route(
        self: *TaskRouter,
        arena: std.mem.Allocator,
        analysis: TaskAnalysis,
        available_models: []const *const Model,
    ) !RoutingDecision {
        
        // 1. 筛选符合条件的模型
        const candidates = try self.filterCandidates(arena, analysis, available_models);
        
        // 2. 评分排序
        const scored = try self.scoreModels(arena, analysis, candidates);
        
        // 3. 决策路由策略
        const strategy = self.selectStrategy(analysis, scored);
        
        // 4. 生成任务分配
        const assignments = try self.createAssignments(arena, analysis, scored, strategy);
        
        // 5. 计算预估成本和时间
        const cost = self.estimateTotalCost(assignments);
        const time = self.estimateTotalTime(assignments, strategy);
        
        return .{
            .strategy = strategy,
            .assignments = assignments,
            .total_estimated_cost = cost,
            .total_estimated_time_ms = time,
            .reasoning = try self.generateReasoning(arena, analysis, assignments),
        };
    }
    
    /// 筛选候选模型
    fn filterCandidates(
        self: *TaskRouter,
        arena: std.mem.Allocator,
        analysis: TaskAnalysis,
        models: []const *const Model,
    ) ![]const *const Model {
        var candidates = std.ArrayList(*const Model).init(arena);
        
        for (models) |model| {
            // 检查模型是否支持所有必需能力
            if (self.modelSupportsCapabilities(model, analysis.required_capabilities)) {
                try candidates.append(model);
            }
        }
        
        return candidates.toOwnedSlice();
    }
    
    /// 模型评分
    fn scoreModels(
        self: *TaskRouter,
        arena: std.mem.Allocator,
        analysis: TaskAnalysis,
        candidates: []const *const Model,
    ) ![]const ScoredModel {
        var scored = std.ArrayList(ScoredModel).init(arena);
        
        for (candidates) |model| {
            const capability_score = self.calculateCapabilityScore(model, analysis.required_capabilities);
            const cost_score = self.calculateCostScore(model);
            const speed_score = self.calculateSpeedScore(model);
            
            // 加权总分
            const total_score = 
                capability_score * self.config.weight_capability +
                cost_score * self.config.weight_cost +
                speed_score * self.config.weight_speed;
            
            try scored.append(.{
                .model = model,
                .total_score = total_score,
                .capability_score = capability_score,
                .cost_score = cost_score,
                .speed_score = speed_score,
            });
        }
        
        // 按总分排序
        std.sort.insertion(ScoredModel, scored.items, {}, compareScore);
        
        return scored.toOwnedSlice();
    }
    
    /// 选择路由策略
    fn selectStrategy(
        self: *TaskRouter,
        analysis: TaskAnalysis,
        scored: []const ScoredModel,
    ) RoutingStrategy {
        // 简单任务：单一模型
        if (analysis.complexity == .simple) {
            return .single_model;
        }
        
        // 可并行且有多个高分模型：并行
        if (analysis.can_parallelize and scored.len >= 2) {
            // 如果前两个模型分数接近，使用并行投票
            if (scored[0].total_score - scored[1].total_score < 0.1) {
                return .parallel_models;
            }
        }
        
        // 复杂任务：分层处理
        if (analysis.complexity == .very_complex) {
            return .hierarchical;
        }
        
        return .single_model;
    }
    
    /// 创建任务分配
    fn createAssignments(
        self: *TaskRouter,
        arena: std.mem.Allocator,
        analysis: TaskAnalysis,
        scored: []const ScoredModel,
        strategy: RoutingStrategy,
    ) ![]const TaskAssignment {
        var assignments = std.ArrayList(TaskAssignment).init(arena);
        
        switch (strategy) {
            .single_model => {
                // 使用评分最高的模型
                if (scored.len > 0) {
                    try assignments.append(.{
                        .sub_task_id = "main",
                        .model = scored[0].model,
                        .provider = scored[0].model.provider,
                        .fallback_model = if (scored.len > 1) scored[1].model else null,
                        .timeout_ms = self.estimateTimeout(analysis),
                        .max_retries = 2,
                    });
                }
            },
            
            .parallel_models => {
                // 多个模型并行执行同一任务（投票机制）
                for (scored[0..@min(3, scored.len)]) |scored_model| {
                    try assignments.append(.{
                        .sub_task_id = "main",
                        .model = scored_model.model,
                        .provider = scored_model.model.provider,
                        .fallback_model = null,
                        .timeout_ms = self.estimateTimeout(analysis),
                        .max_retries = 1,
                    });
                }
            },
            
            .hierarchical => {
                // 为每个子任务分配最适合的模型
                for (analysis.suggested_sub_tasks) |sub_task| {
                    const best_model = self.findBestModelForSubTask(scored, sub_task);
                    try assignments.append(.{
                        .sub_task_id = sub_task.id,
                        .model = best_model.model,
                        .provider = best_model.model.provider,
                        .fallback_model = null,
                        .timeout_ms = sub_task.estimated_time_ms * 2,
                        .max_retries = 2,
                    });
                }
            },
            
            .pipeline => {
                // TODO: 实现流水线策略
            },
        }
        
        return assignments.toOwnedSlice();
    }
    
    /// 为子任务找到最佳模型
    fn findBestModelForSubTask(
        self: *TaskRouter,
        scored: []const ScoredModel,
        sub_task: SubTaskSuggestion,
    ) ScoredModel {
        var best_score: f32 = 0;
        var best_model = scored[0];
        
        for (scored) |scored_model| {
            const score = self.calculateSubTaskScore(scored_model.model, sub_task);
            if (score > best_score) {
                best_score = score;
                best_model = scored_model;
            }
        }
        
        return best_model;
    }
};

pub const RouterConfig = struct {
    weight_capability: f32 = 0.5,  // 能力权重
    weight_cost: f32 = 0.2,        // 成本权重
    weight_speed: f32 = 0.3,       // 速度权重
    
    max_parallel_models: usize = 3,  // 最大并行模型数
    enable_fallback: bool = true,    // 启用失败回退
};

pub const ScoredModel = struct {
    model: *const Model,
    total_score: f32,
    capability_score: f32,
    cost_score: f32,
    speed_score: f32,
};
```

## 6. 使用示例

```zig
// 创建智能路由 Agent
var smart_agent = SmartAgent.init(allocator, .{
    .available_models = &[_]*const Model{
        &Models.gpt_4o,
        &Models.gpt_4o_mini,
        &Models.claude_sonnet_4,
        &Models.gemini_2_5_pro,
        &Models.kimi_k2_5,
    },
    .router_config = .{
        .weight_capability = 0.5,
        .weight_cost = 0.2,
        .weight_speed = 0.3,
    },
});
defer smart_agent.deinit();

// 执行任务
const result = try smart_agent.execute(arena, 
    \请帮我：
    \1. 分析这个 Zig 项目的架构问题
    \2. 生成优化后的代码
    \3. 为关键函数编写单元测试
);

// 查看路由决策
std.debug.print("路由策略: {s}\n", .{@tagName(result.routing_decision.strategy)});
std.debug.print("预估成本: ${d:.4}\n", .{result.routing_decision.total_estimated_cost});
std.debug.print("决策理由: {s}\n", .{result.routing_decision.reasoning});

// 查看各子任务使用的模型
for (result.sub_results) |sub| {
    std.debug.print("任务 '{s}' 使用模型: {s}\n", .{
        sub.task_id,
        sub.model.name,
    });
}
```

## 7. 典型场景路由示例

### 场景 1: 简单代码生成
```
用户: "写一个快速排序函数"

分析:
- 任务类型: code_generation
- 复杂度: simple
- 所需能力: code_generation, tool_use

路由决策:
- 策略: single_model
- 选择: GPT-4o-mini (速度快、成本低、能力足够)
- 理由: "简单代码生成任务，使用成本效益最高的模型"
```

### 场景 2: 复杂架构设计
```
用户: "设计一个高性能的分布式消息队列系统"

分析:
- 任务类型: architecture_design
- 复杂度: very_complex
- 所需能力: reasoning, code_analysis
- 可分解: 是

路由决策:
- 策略: hierarchical
- 子任务分配:
  1. 架构概览设计 → Claude Sonnet 4 (深度推理)
  2. 核心模块代码 → GPT-4o (代码生成)
  3. 性能分析 → Gemini 2.5 Pro (长上下文)
- 理由: "复杂架构任务分解为子任务，每个子任务使用最适合的模型"
```

### 场景 3: PDF 文档分析
```
用户: "分析这个 100 页的 PDF 技术文档，提取关键架构决策"

分析:
- 任务类型: pdf_analysis
- 复杂度: complex
- 所需能力: multimodal_pdf, long_context, reasoning

路由决策:
- 策略: single_model
- 选择: Gemini 2.5 Pro (原生 PDF + 1M 上下文)
- 理由: "PDF 分析任务，Gemini 原生支持且上下文最长"
```

### 场景 4: 代码审查（并行验证）
```
用户: "审查这段代码的安全问题"

分析:
- 任务类型: security_audit
- 复杂度: moderate
- 所需能力: code_analysis, reasoning

路由决策:
- 策略: parallel_models
- 并行执行:
  1. Claude Sonnet 4 (深度分析)
  2. GPT-4o (快速扫描)
  3. Kimi K2.5 (中文注释理解)
- 结果聚合: 合并三者的发现，去重后输出
- 理由: "安全审查重要，多模型并行可提高覆盖率"
```

## 8. 与 Kimi 官方的对比

| 特性 | kimiz 智能路由 | Kimi 官方 |
|------|---------------|-----------|
| **模型选择** | ✅ 自动选择最优模型 | ❌ 固定 Kimi 模型 |
| **多模型协同** | ✅ 跨 Provider 组合 | ❌ 单一模型 |
| **任务分解** | ✅ 智能分解 + 路由 | ✅ 内置分解 |
| **成本优化** | ✅ 按任务选择性价比 | ❌ 固定成本 |
| **特殊能力** | ✅ 按需选择 (PDF/长上下文) | ✅ 原生支持 |
| **并行执行** | ✅ 多模型并行投票 | ✅ 子 Agent 并行 |

**kimiz 的独特优势**:
1. **模型自由**: 不被单一供应商锁定
2. **成本智能**: 简单任务用便宜模型，复杂任务用强模型
3. **能力组合**: PDF 用 Gemini，推理用 Claude，速度用 GPT-4o-mini
4. **投票机制**: 重要任务可多模型并行，提高准确性
