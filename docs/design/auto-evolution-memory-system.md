# 自适应记忆与学习系统 (Auto-Evolution)

基于 Karpathy Auto Research 理念的自进化 AI Agent 系统

## 核心理念

> "The future of AI is not just about better models, but about systems that can learn and evolve from their interactions."
> — Andrej Karpathy

### 三大支柱

1. **持续学习 (Continuous Learning)**
   - 每次交互都是学习机会
   - 自动提取用户偏好和模式
   - 无需显式训练，边用边学

2. **长期记忆 (Long-term Memory)**
   - 跨会话保持上下文
   - 记住用户习惯和偏好
   - 积累领域知识

3. **自我优化 (Self-Optimization)**
   - 根据反馈调整行为
   - 自动改进提示词
   - 优化工具使用策略

---

## 系统架构

```
┌─────────────────────────────────────────────────────────────────┐
│                     kimiz Auto-Evolution                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   Short     │    │    Work     │    │   Long      │         │
│  │   Term      │◄──►│   Memory    │◄──►│   Term      │         │
│  │   Memory    │    │   (Context) │    │   Memory    │         │
│  │  (Session)  │    │  (Project)  │    │  (Global)   │         │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘         │
│         │                  │                  │                 │
│         └──────────────────┼──────────────────┘                 │
│                            ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Memory Consolidation Engine                │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐ │   │
│  │  │ Pattern  │  │ Preference│  │ Knowledge│  │ Feedback│ │   │
│  │  │Extractor │  │  Learner  │  │  Builder │  │  Loop   │ │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └─────────┘ │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                    │
│                            ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Adaptive Behavior System                   │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐ │   │
│  │  │ Prompt   │  │  Model   │  │  Tool    │  │ Response│ │   │
│  │  │Optimizer │  │ Selector │  │  Router  │  │ Adapter │ │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └─────────┘ │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 1. 三层记忆系统

### 1.1 短期记忆 (Short-Term Memory)

**作用**: 当前会话的上下文
**生命周期**: 会话期间
**存储**: 内存

```zig
// src/memory/short_term.zig

pub const ShortTermMemory = struct {
    /// 当前会话的消息历史
    messages: std.ArrayList(Message),
    
    /// 当前会话的元数据
    session_id: []const u8,
    start_time: i64,
    
    /// 临时上下文变量
    context_vars: std.StringHashMap([]const u8),
    
    /// 当前任务栈
    task_stack: std.ArrayList(Task),
    
    pub fn init(allocator: std.mem.Allocator, session_id: []const u8) ShortTermMemory;
    pub fn deinit(self: *ShortTermMemory) void;
    
    /// 添加消息到当前会话
    pub fn addMessage(self: *ShortTermMemory, message: Message) void;
    
    /// 获取当前上下文窗口
    pub fn getContextWindow(self: *ShortTermMemory, max_tokens: u32) []const Message;
    
    /// 设置临时变量
    pub fn setVar(self: *ShortTermMemory, key: []const u8, value: []const u8) void;
    
    /// 获取临时变量
    pub fn getVar(self: *ShortTermMemory, key: []const u8) ?[]const u8;
};
```

### 1.2 工作记忆 (Working Memory)

**作用**: 项目级别的持久化记忆
**生命周期**: 长期
**存储**: 本地文件 (JSON/SQLite)

```zig
// src/memory/working.zig

pub const WorkingMemory = struct {
    /// 项目/工作区标识
    project_id: []const u8,
    
    /// 存储后端
    storage: MemoryStorage,
    
    /// 项目特定的知识
    project_knowledge: ProjectKnowledge,
    
    /// 代码库理解
    codebase_understanding: CodebaseUnderstanding,
    
    /// 会话历史摘要
    session_summaries: std.ArrayList(SessionSummary),
    
    pub fn init(allocator: std.mem.Allocator, project_path: []const u8) !WorkingMemory;
    pub fn deinit(self: *WorkingMemory) void;
    
    /// 保存当前会话摘要
    pub fn saveSessionSummary(self: *WorkingMemory, summary: SessionSummary) !void;
    
    /// 获取相关历史会话
    pub fn getRelevantSessions(self: *WorkingMemory, query: []const u8, limit: u32) []const SessionSummary;
    
    /// 更新代码库理解
    pub fn updateCodebaseUnderstanding(self: *WorkingMemory, analysis: CodeAnalysis) !void;
    
    /// 获取项目特定的提示词增强
    pub fn getPromptEnhancement(self: *WorkingMemory) []const u8;
};

pub const ProjectKnowledge = struct {
    /// 项目技术栈
    tech_stack: []const []const u8,
    
    /// 项目架构模式
    architecture_patterns: []const []const u8,
    
    /// 命名约定
    naming_conventions: std.StringHashMap([]const u8),
    
    /// 重要文件/模块
    key_files: []const KeyFileInfo,
    
    /// 常见任务模板
    task_templates: []const TaskTemplate,
};

pub const CodebaseUnderstanding = struct {
    /// 模块依赖图
    dependency_graph: DependencyGraph,
    
    /// 代码统计
    code_stats: CodeStats,
    
    /// 最近修改的文件
    recent_changes: []const FileChange,
    
    /// 代码质量指标
    quality_metrics: QualityMetrics,
};
```

### 1.3 长期记忆 (Long-Term Memory)

**作用**: 用户级别的全局记忆
**生命周期**: 永久
**存储**: SQLite + 向量数据库 (可选)

```zig
// src/memory/long_term.zig

pub const LongTermMemory = struct {
    /// 用户标识
    user_id: []const u8,
    
    /// 存储路径
    storage_path: []const u8,
    
    /// 数据库连接
    db: sqlite.Database,
    
    /// 向量存储 (用于语义搜索)
    vector_store: ?VectorStore,
    
    pub fn init(allocator: std.mem.Allocator, user_id: []const u8) !LongTermMemory;
    pub fn deinit(self: *LongTermMemory) void;
    
    /// 存储记忆
    pub fn store(self: *LongTermMemory, entry: MemoryEntry) !void;
    
    /// 语义搜索记忆
    pub fn search(self: *LongTermMemory, query: []const u8, limit: u32) ![]const MemoryEntry;
    
    /// 获取用户偏好
    pub fn getUserPreferences(self: *LongTermMemory) UserPreferences;
    
    /// 更新用户偏好
    pub fn updatePreferences(self: *LongTermMemory, delta: PreferenceDelta) !void;
    
    /// 获取学习到的模式
    pub fn getLearnedPatterns(self: *LongTermMemory) []const LearnedPattern;
};

pub const MemoryEntry = struct {
    id: []const u8,
    timestamp: i64,
    category: MemoryCategory,
    content: []const u8,
    embedding: ?[]const f32,  // 用于语义搜索
    metadata: std.StringHashMap([]const u8),
    importance: f32,  // 0.0 - 1.0
    access_count: u32,
    last_accessed: i64,
};

pub const MemoryCategory = enum {
    user_preference,      // 用户偏好
    coding_pattern,       // 编码模式
    project_context,      // 项目上下文
    conversation_summary, // 对话摘要
    tool_usage,          // 工具使用习惯
    error_pattern,       // 错误模式
    success_pattern,     // 成功模式
};

pub const UserPreferences = struct {
    /// 首选编程语言
    preferred_languages: []const []const u8,
    
    /// 代码风格偏好
    code_style: CodeStylePreference,
    
    /// 沟通风格
    communication_style: CommunicationStyle,
    
    /// 详细程度偏好
    verbosity_level: VerbosityLevel,
    
    /// 常用工具
    frequently_used_tools: []const []const u8,
    
    /// 避免的实践
    avoided_practices: []const []const u8,
    
    /// 自定义快捷指令
    custom_shortcuts: std.StringHashMap([]const u8),
};
```

---

## 2. 记忆整合引擎

### 2.1 模式提取器

自动从交互中提取模式：

```zig
// src/memory/pattern_extractor.zig

pub const PatternExtractor = struct {
    /// 从代码中提取模式
    pub fn extractCodePatterns(
        self: *PatternExtractor,
        arena: std.mem.Allocator,
        code_changes: []const CodeChange,
    ) ![]const CodePattern {
        var patterns = std.ArrayList(CodePattern).init(arena);
        
        // 分析代码变更
        for (code_changes) |change| {
            // 检测命名模式
            if (try self.detectNamingPattern(change)) |pattern| {
                try patterns.append(pattern);
            }
            
            // 检测架构模式
            if (try self.detectArchitecturePattern(change)) |pattern| {
                try patterns.append(pattern);
            }
            
            // 检测代码组织模式
            if (try self.detectOrganizationPattern(change)) |pattern| {
                try patterns.append(pattern);
            }
        }
        
        return patterns.toOwnedSlice();
    }
    
    /// 从对话中提取偏好
    pub fn extractPreferences(
        self: *PatternExtractor,
        arena: std.mem.Allocator,
        conversations: []const Conversation,
    ) !PreferenceDelta {
        var delta = PreferenceDelta{};
        
        // 分析用户的反馈
        for (conversations) |conv| {
            // 检测满意度信号
            if (conv.user_feedback) |feedback| {
                try self.applyFeedback(&delta, feedback);
            }
            
            // 检测隐式偏好（如重复请求某种格式）
            try self.detectImplicitPreferences(&delta, conv);
        }
        
        return delta;
    }
};
```

### 2.2 知识构建器

构建和更新知识图谱：

```zig
// src/memory/knowledge_builder.zig

pub const KnowledgeBuilder = struct {
    /// 构建代码库知识
    pub fn buildCodebaseKnowledge(
        self: *KnowledgeBuilder,
        arena: std.mem.Allocator,
        project_path: []const u8,
    ) !CodebaseKnowledge {
        var knowledge = CodebaseKnowledge{};
        
        // 扫描项目结构
        const structure = try self.scanProjectStructure(arena, project_path);
        
        // 分析依赖关系
        knowledge.dependencies = try self.analyzeDependencies(arena, structure);
        
        // 识别技术栈
        knowledge.tech_stack = try self.identifyTechStack(arena, structure);
        
        // 提取架构模式
        knowledge.patterns = try self.extractArchitecturePatterns(arena, structure);
        
        // 识别关键文件
        knowledge.key_files = try self.identifyKeyFiles(arena, structure);
        
        return knowledge;
    }
    
    /// 增量更新知识
    pub fn updateKnowledge(
        self: *KnowledgeBuilder,
        knowledge: *CodebaseKnowledge,
        changes: []const FileChange,
    ) !void {
        for (changes) |change| {
            switch (change.change_type) {
                .added => try self.incorporateNewFile(knowledge, change),
                .modified => try self.updateFileKnowledge(knowledge, change),
                .deleted => try self.removeFileKnowledge(knowledge, change),
            }
        }
    }
};
```

---

## 3. 自适应行为系统

### 3.1 提示词优化器

根据用户偏好自动优化提示词：

```zig
// src/adaptive/prompt_optimizer.zig

pub const PromptOptimizer = struct {
    long_term: *LongTermMemory,
    working: *WorkingMemory,
    
    /// 为特定任务优化提示词
    pub fn optimizePrompt(
        self: *PromptOptimizer,
        arena: std.mem.Allocator,
        base_prompt: []const u8,
        task_type: TaskType,
    ) ![]const u8 {
        var optimized = std.ArrayList(u8).init(arena);
        
        // 添加用户风格偏好
        const prefs = self.long_term.getUserPreferences();
        try self.addStylePreferences(&optimized, prefs);
        
        // 添加项目特定上下文
        try self.addProjectContext(&optimized, self.working);
        
        // 添加相关历史模式
        const patterns = try self.getRelevantPatterns(arena, task_type);
        try self.addLearnedPatterns(&optimized, patterns);
        
        // 添加基础提示词
        try optimized.appendSlice(base_prompt);
        
        return optimized.toOwnedSlice();
    }
    
    /// 根据反馈调整提示词
    pub fn adaptFromFeedback(
        self: *PromptOptimizer,
        prompt_template: *PromptTemplate,
        feedback: UserFeedback,
    ) !void {
        if (feedback.satisfaction < 0.5) {
            // 用户不满意，调整策略
            try self.adjustStrategy(prompt_template, feedback.critique);
        } else if (feedback.satisfaction > 0.8) {
            // 用户非常满意，强化这种模式
            try self.reinforcePattern(prompt_template);
        }
    }
};
```

### 3.2 模型选择器

基于历史表现动态选择模型：

```zig
// src/adaptive/model_selector.zig

pub const AdaptiveModelSelector = struct {
    long_term: *LongTermMemory,
    
    /// 选择最适合当前任务的模型
    pub fn selectModel(
        self: *AdaptiveModelSelector,
        task: TaskAnalysis,
    ) !ModelSelection {
        // 获取历史表现数据
        const performance = try self.getHistoricalPerformance(task.task_type);
        
        // 考虑用户偏好
        const prefs = self.long_term.getUserPreferences();
        
        // 考虑成本约束
        const budget = self.getBudgetConstraint();
        
        // 综合决策
        var best_score: f32 = 0;
        var best_model: ?*const Model = null;
        
        for (AVAILABLE_MODELS) |model| {
            const score = self.calculateAdaptedScore(
                model,
                task,
                performance,
                prefs,
                budget,
            );
            
            if (score > best_score) {
                best_score = score;
                best_model = model;
            }
        }
        
        return .{
            .model = best_model.?,
            .confidence = best_score,
            .reasoning = try self.generateReasoning(arena, best_model.?),
        };
    }
    
    /// 记录模型表现
    pub fn recordPerformance(
        self: *AdaptiveModelSelector,
        model: *const Model,
        task: TaskAnalysis,
        result: TaskResult,
    ) !void {
        const record = PerformanceRecord{
            .model_id = model.id,
            .task_type = task.task_type,
            .success = result.success,
            .quality_score = result.quality_score,
            .latency_ms = result.latency_ms,
            .cost = result.cost,
            .timestamp = std.time.milliTimestamp(),
        };
        
        try self.long_term.store(.{
            .category = .model_performance,
            .content = try std.json.stringifyAlloc(self.allocator, record, .{}),
            .importance = 0.7,
        });
    }
};
```

### 3.3 响应适配器

根据用户偏好调整响应风格：

```zig
// src/adaptive/response_adapter.zig

pub const ResponseAdapter = struct {
    preferences: UserPreferences,
    
    /// 适配响应风格
    pub fn adaptResponse(
        self: *ResponseAdapter,
        arena: std.mem.Allocator,
        raw_response: []const u8,
        response_type: ResponseType,
    ) ![]const u8 {
        var adapted = std.ArrayList(u8).init(arena);
        
        // 根据详细程度调整
        switch (self.preferences.verbosity_level) {
            .concise => try self.makeConcise(&adapted, raw_response),
            .normal => try adapted.appendSlice(raw_response),
            .detailed => try self.makeDetailed(&adapted, raw_response),
        }
        
        // 根据沟通风格调整
        switch (self.preferences.communication_style) {
            .formal => try self.makeFormal(&adapted),
            .casual => try self.makeCasual(&adapted),
            .technical => try self.makeTechnical(&adapted),
        }
        
        // 添加代码示例（如果相关）
        if (response_type == .code_explanation) {
            try self.addRelevantExamples(&adapted);
        }
        
        return adapted.toOwnedSlice();
    }
};
```

---

## 4. 反馈循环

### 4.1 显式反馈

用户主动提供的反馈：

```zig
// src/learning/feedback.zig

pub const FeedbackCollector = struct {
    /// 收集用户反馈
    pub fn collectExplicitFeedback(
        self: *FeedbackCollector,
        interaction_id: []const u8,
    ) !UserFeedback {
        // 在 TUI 中显示反馈选项
        const feedback = try self.promptForFeedback();
        
        // 存储反馈
        try self.storeFeedback(interaction_id, feedback);
        
        // 触发学习
        try self.triggerLearning(interaction_id, feedback);
        
        return feedback;
    }
};

pub const UserFeedback = struct {
    satisfaction: f32,  // 0.0 - 1.0
    critique: ?[]const u8,
    would_change: ?[]const u8,
    tags: []const []const u8,
};
```

### 4.2 隐式反馈

从用户行为推断：

```zig
// src/learning/implicit_feedback.zig

pub const ImplicitFeedbackAnalyzer = struct {
    /// 分析用户行为模式
    pub fn analyzeBehavior(
        self: *ImplicitFeedbackAnalyzer,
        session: Session,
    ) !BehaviorInsights {
        var insights = BehaviorInsights{};
        
        // 检测重复操作（可能表示不满意）
        insights.repetition_patterns = try self.detectRepetitions(session);
        
        // 检测编辑模式（用户是否大量修改 AI 输出）
        insights.edit_patterns = try self.detectEditPatterns(session);
        
        // 检测接受模式（用户是否直接使用 AI 输出）
        insights.acceptance_rate = try self.calculateAcceptanceRate(session);
        
        // 检测时间模式（用户是否快速接受或长时间犹豫）
        insights.time_patterns = try self.analyzeTimePatterns(session);
        
        return insights;
    }
};
```

---

## 5. 实现示例

### 5.1 完整使用流程

```zig
// 初始化记忆系统
var memory_system = try MemorySystem.init(allocator, .{
    .user_id = "user_123",
    .project_path = "/home/user/myproject",
});
defer memory_system.deinit();

// 创建自适应 Agent
var agent = try AdaptiveAgent.init(allocator, .{
    .memory = &memory_system,
    .models = AVAILABLE_MODELS,
});

// 执行任务（自动利用记忆）
const result = try agent.execute("实现一个 LRU 缓存", .{
    .adapt_to_user = true,
    .use_learned_patterns = true,
});

// 系统会自动：
// 1. 从长期记忆中获取用户的代码风格偏好
// 2. 从工作记忆中获取项目的技术栈信息
// 3. 选择最适合的模型（基于历史表现）
// 4. 优化提示词以匹配用户偏好
// 5. 适配响应风格
// 6. 收集反馈并学习
```

### 5.2 学习效果示例

**第一次交互**:
```
用户: 写个快速排序
AI: [生成标准快速排序代码]
用户: [大量修改代码，添加类型注解，改为函数式风格]
```

**系统学习**:
- 用户偏好：强类型、函数式编程风格
- 下次生成代码时自动添加类型注解
- 优先使用函数式风格

**第二次交互**:
```
用户: 写个二分查找
AI: [生成的代码自动包含类型注解，使用函数式风格]
用户: [直接使用，无需修改]
```

---

## 6. 存储格式

### 6.1 长期记忆存储

```json
{
  "user_id": "user_123",
  "version": "1.0",
  "created_at": "2026-01-01T00:00:00Z",
  "updated_at": "2026-04-05T12:00:00Z",
  "preferences": {
    "preferred_languages": ["Zig", "Rust", "TypeScript"],
    "code_style": {
      "indentation": "4_spaces",
      "max_line_length": 100,
      "prefer_explicit_types": true,
      "functional_style": 0.7,
      "imperative_style": 0.3
    },
    "communication_style": "technical",
    "verbosity_level": "detailed"
  },
  "learned_patterns": [
    {
      "id": "pattern_001",
      "type": "naming_convention",
      "pattern": "snake_case_for_functions",
      "confidence": 0.95,
      "examples": ["get_user_by_id", "calculate_total"]
    },
    {
      "id": "pattern_002",
      "type": "error_handling",
      "pattern": "explicit_error_union",
      "confidence": 0.88,
      "context": "Zig projects"
    }
  ],
  "model_performance": {
    "gpt-4o": {
      "code_generation": { "success_rate": 0.92, "avg_quality": 4.5 },
      "code_review": { "success_rate": 0.88, "avg_quality": 4.2 }
    },
    "claude-sonnet-4": {
      "architecture_design": { "success_rate": 0.95, "avg_quality": 4.8 }
    }
  }
}
```

---

## 7. 与 Kimi 官方的对比

| 特性 | kimiz Auto-Evolution | Kimi 官方 |
|------|---------------------|-----------|
| **个性化学习** | ✅ 深度个性化 | ⚠️ 基础个性化 |
| **跨项目记忆** | ✅ 支持 | ❌ 不支持 |
| **代码风格学习** | ✅ 自动学习 | ❌ 需手动设置 |
| **模型选择优化** | ✅ 基于历史表现 | ❌ 固定模型 |
| **提示词自适应** | ✅ 自动优化 | ❌ 固定提示词 |
| **反馈驱动改进** | ✅ 显式+隐式 | ⚠️ 仅显式 |

---

## 8. 未来扩展

1. **联邦学习**: 在保护隐私前提下，从多个用户学习通用模式
2. **迁移学习**: 将在一个项目学到的知识迁移到类似项目
3. **主动学习**: 主动询问用户以澄清偏好
4. **解释性**: 解释为什么做出某些决策（"我选择 GPT-4o 是因为您在类似任务上对其输出满意度高"）
