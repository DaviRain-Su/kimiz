# kimiz 记忆系统实现规划

## 设计原则

借鉴 mem0 的核心思想，但保持轻量和嵌入式：

1. **简单优先**: 先实现核心功能，后续迭代
2. **嵌入式**: 无需独立服务，直接集成在 kimiz 中
3. **SQLite 为主**: 单文件数据库，零配置
4. **可选向量搜索**: 初期用全文搜索，后期可选向量

---

## 架构设计

```
┌─────────────────────────────────────────┐
│         kimiz Memory System             │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────┐   ┌─────────┐   ┌────────┐│
│  │  Add    │   │ Update  │   │ Search ││
│  │ Memory  │   │ Memory  │   │ Memory ││
│  └────┬────┘   └────┬────┘   └────┬───┘│
│       │             │             │    │
│       └─────────────┼─────────────┘    │
│                     ▼                  │
│         ┌─────────────────┐            │
│         │   SQLite Store  │            │
│         │  ┌───────────┐  │            │
│         │  │ memories  │  │            │
│         │  │ patterns  │  │            │
│         │  │ feedback  │  │            │
│         │  └───────────┘  │            │
│         └─────────────────┘            │
│                     │                  │
│                     ▼                  │
│         ┌─────────────────┐            │
│         │  Optional:      │            │
│         │  Vector Index   │            │
│         │  (SQLite-vec)   │            │
│         └─────────────────┘            │
│                                         │
└─────────────────────────────────────────┘
```

---

## 数据库 Schema

### 核心表结构

```sql
-- 记忆条目表
CREATE TABLE memories (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    project_id TEXT,
    session_id TEXT,
    
    -- 记忆内容
    content TEXT NOT NULL,
    memory_type TEXT NOT NULL,  -- 'fact', 'preference', 'pattern', 'feedback'
    
    -- 分类标签
    category TEXT,  -- 'code_style', 'architecture', 'tool_usage', etc.
    tags TEXT,      -- JSON array
    
    -- 元数据
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    access_count INTEGER DEFAULT 0,
    last_accessed INTEGER,
    importance REAL DEFAULT 0.5,  -- 0.0 - 1.0
    
    -- 向量嵌入 (可选)
    embedding BLOB,
    
    -- 索引
    INDEX idx_user_project (user_id, project_id),
    INDEX idx_type_category (memory_type, category),
    INDEX idx_created (created_at),
    INDEX idx_importance (importance)
);

-- 记忆关联表 (实现记忆图谱)
CREATE TABLE memory_links (
    source_id TEXT NOT NULL,
    target_id TEXT NOT NULL,
    relation_type TEXT NOT NULL,  -- 'related', 'supersedes', 'depends_on'
    strength REAL DEFAULT 1.0,
    PRIMARY KEY (source_id, target_id),
    FOREIGN KEY (source_id) REFERENCES memories(id),
    FOREIGN KEY (target_id) REFERENCES memories(id)
);

-- 用户偏好表
CREATE TABLE user_preferences (
    user_id TEXT PRIMARY KEY,
    
    -- 代码风格偏好
    preferred_languages TEXT,  -- JSON array
    code_style_json TEXT,      -- JSON object
    
    -- 沟通偏好
    communication_style TEXT,
    verbosity_level TEXT,
    
    -- 模型偏好
    preferred_models TEXT,     -- JSON object by task type
    
    -- 更新时间
    updated_at INTEGER NOT NULL
);

-- 会话摘要表
CREATE TABLE session_summaries (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    project_id TEXT,
    session_id TEXT NOT NULL,
    
    -- 摘要内容
    summary TEXT NOT NULL,
    key_topics TEXT,  -- JSON array
    
    -- 统计
    message_count INTEGER,
    start_time INTEGER,
    end_time INTEGER,
    
    -- 索引
    INDEX idx_user_project (user_id, project_id)
);

-- 模型表现记录表
CREATE TABLE model_performance (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    model_id TEXT NOT NULL,
    task_type TEXT NOT NULL,
    
    -- 表现指标
    success BOOLEAN NOT NULL,
    quality_score REAL,  -- 0.0 - 5.0
    latency_ms INTEGER,
    cost REAL,
    
    -- 时间
    timestamp INTEGER NOT NULL,
    
    -- 索引
    INDEX idx_user_model (user_id, model_id),
    INDEX idx_task (task_type)
);
```

---

## Zig 实现

### 核心类型

```zig
// src/memory/types.zig

pub const Memory = struct {
    id: []const u8,
    user_id: []const u8,
    project_id: ?[]const u8,
    session_id: ?[]const u8,
    
    content: []const u8,
    memory_type: MemoryType,
    category: ?[]const u8,
    tags: []const []const u8,
    
    created_at: i64,
    updated_at: i64,
    access_count: u32,
    last_accessed: ?i64,
    importance: f32,
    
    pub const MemoryType = enum {
        fact,        // 事实性知识
        preference,  // 用户偏好
        pattern,     // 学习到的模式
        feedback,    // 用户反馈
        context,     // 上下文信息
    };
};

pub const UserPreferences = struct {
    user_id: []const u8,
    
    // 代码风格
    preferred_languages: []const []const u8,
    code_style: CodeStylePreference,
    
    // 沟通风格
    communication_style: CommunicationStyle,
    verbosity_level: VerbosityLevel,
    
    // 模型偏好: task_type -> model_id
    preferred_models: std.StringHashMap([]const u8),
    
    updated_at: i64,
};

pub const CodeStylePreference = struct {
    indentation: IndentationStyle,
    max_line_length: u32,
    prefer_explicit_types: bool,
    naming_convention: NamingConvention,
    
    pub const IndentationStyle = enum { spaces_2, spaces_4, tabs };
    pub const NamingConvention = enum { snake_case, camelCase, PascalCase };
};
```

### 存储层

```zig
// src/memory/store.zig

pub const MemoryStore = struct {
    allocator: std.mem.Allocator,
    db: sqlite.Database,
    config: StoreConfig,
    
    pub fn init(allocator: std.mem.Allocator, db_path: []const u8, config: StoreConfig) !MemoryStore;
    pub fn deinit(self: *MemoryStore) void;
    
    // 记忆 CRUD
    pub fn addMemory(self: *MemoryStore, memory: Memory) !void;
    pub fn getMemory(self: *MemoryStore, id: []const u8) !?Memory;
    pub fn updateMemory(self: *MemoryStore, memory: Memory) !void;
    pub fn deleteMemory(self: *MemoryStore, id: []const u8) !void;
    
    // 搜索
    pub fn searchMemories(
        self: *MemoryStore,
        arena: std.mem.Allocator,
        query: SearchQuery,
    ) ![]const Memory;
    
    // 用户偏好
    pub fn getUserPreferences(self: *MemoryStore, user_id: []const u8) !?UserPreferences;
    pub fn updateUserPreferences(self: *MemoryStore, prefs: UserPreferences) !void;
    
    // 模型表现
    pub fn recordModelPerformance(self: *MemoryStore, record: ModelPerformanceRecord) !void;
    pub fn getModelPerformance(
        self: *MemoryStore,
        arena: std.mem.Allocator,
        user_id: []const u8,
        model_id: []const u8,
    ) ![]const ModelPerformanceRecord;
};

pub const SearchQuery = struct {
    user_id: []const u8,
    project_id: ?[]const u8 = null,
    memory_type: ?MemoryType = null,
    category: ?[]const u8 = null,
    tags: ?[]const []const u8 = null,
    text_query: ?[]const u8 = null,  // 全文搜索
    limit: u32 = 10,
    min_importance: ?f32 = null,
};
```

### 记忆管理器

```zig
// src/memory/manager.zig

pub const MemoryManager = struct {
    store: *MemoryStore,
    ai: *Ai,  // 用于生成嵌入和摘要
    config: MemoryConfig,
    
    pub fn init(store: *MemoryStore, ai: *Ai, config: MemoryConfig) MemoryManager;
    
    /// 添加新记忆
    pub fn addMemory(
        self: *MemoryManager,
        arena: std.mem.Allocator,
        content: []const u8,
        memory_type: MemoryType,
        options: AddMemoryOptions,
    ) !void {
        // 1. 生成唯一 ID
        const id = try self.generateId(arena);
        
        // 2. 提取关键信息（可选使用 LLM）
        const extracted = try self.extractKeyInfo(arena, content);
        
        // 3. 生成嵌入向量（如果启用）
        const embedding = if (self.config.enable_embeddings)
            try self.generateEmbedding(arena, content)
        else
            null;
        
        // 4. 检查相似记忆（避免重复）
        const similar = try self.findSimilarMemories(arena, content);
        if (similar.len > 0) {
            // 更新现有记忆或合并
            try self.mergeOrUpdateMemory(similar[0], content);
            return;
        }
        
        // 5. 存储记忆
        const memory = Memory{
            .id = id,
            .content = content,
            .memory_type = memory_type,
            .category = options.category,
            .tags = extracted.tags,
            // ...
        };
        try self.store.addMemory(memory);
        
        // 6. 建立关联
        for (extracted.related_memory_ids) |related_id| {
            try self.store.addMemoryLink(id, related_id, .related);
        }
    }
    
    /// 检索相关记忆
    pub fn retrieveRelevantMemories(
        self: *MemoryManager,
        arena: std.mem.Allocator,
        query: []const u8,
        context: RetrieveContext,
    ) ![]const Memory {
        // 1. 构建搜索查询
        var search_query = SearchQuery{
            .user_id = context.user_id,
            .project_id = context.project_id,
            .limit = context.max_results,
        };
        
        // 2. 文本搜索
        const text_results = try self.store.searchMemories(arena, search_query);
        
        // 3. 如果启用向量搜索，进行语义搜索
        const semantic_results = if (self.config.enable_embeddings)
            try self.semanticSearch(arena, query)
        else
            &[]Memory{};
        
        // 4. 合并和排序结果
        return try self.mergeAndRankResults(arena, text_results, semantic_results);
    }
    
    /// 从会话中提取学习
    pub fn learnFromSession(
        self: *MemoryManager,
        arena: std.mem.Allocator,
        session: Session,
    ) !void {
        // 1. 生成会话摘要
        const summary = try self.generateSessionSummary(arena, session);
        try self.store.addSessionSummary(summary);
        
        // 2. 提取用户偏好
        const prefs = try self.extractPreferences(arena, session);
        try self.store.updateUserPreferences(prefs);
        
        // 3. 提取代码模式
        const patterns = try self.extractCodePatterns(arena, session);
        for (patterns) |pattern| {
            try self.addMemory(arena, pattern.content, .pattern, .{
                .category = "code_style",
            });
        }
        
        // 4. 记录模型表现
        for (session.interactions) |interaction| {
            try self.store.recordModelPerformance(.{
                .user_id = session.user_id,
                .model_id = interaction.model_id,
                .task_type = interaction.task_type,
                .success = interaction.success,
                .quality_score = interaction.quality_score,
            });
        }
    }
};
```

---

## 与 Agent 集成

```zig
// src/agent/adaptive_agent.zig

pub const AdaptiveAgent = struct {
    base_agent: Agent,
    memory: *MemoryManager,
    
    pub fn init(
        allocator: std.mem.Allocator,
        ai: *Ai,
        memory: *MemoryManager,
        options: AgentOptions,
    ) !AdaptiveAgent;
    
    /// 执行提示（带记忆增强）
    pub fn prompt(
        self: *AdaptiveAgent,
        arena: std.mem.Allocator,
        user_input: []const u8,
    ) !void {
        // 1. 检索相关记忆
        const relevant_memories = try self.memory.retrieveRelevantMemories(
            arena,
            user_input,
            .{
                .user_id = self.user_id,
                .project_id = self.project_id,
                .max_results = 5,
            },
        );
        
        // 2. 获取用户偏好
        const prefs = try self.memory.store.getUserPreferences(self.user_id);
        
        // 3. 构建增强提示词
        const enhanced_prompt = try self.buildEnhancedPrompt(
            arena,
            user_input,
            relevant_memories,
            prefs,
        );
        
        // 4. 选择最佳模型（基于历史表现）
        const model = try self.selectBestModel(arena, user_input);
        
        // 5. 执行基础 Agent
        try self.base_agent.prompt(arena, enhanced_prompt);
        
        // 6. 记录交互用于学习
        try self.recordInteraction(arena, user_input, model);
    }
    
    /// 构建增强提示词
    fn buildEnhancedPrompt(
        self: *AdaptiveAgent,
        arena: std.mem.Allocator,
        user_input: []const u8,
        memories: []const Memory,
        prefs: ?UserPreferences,
    ) ![]const u8 {
        var prompt = std.ArrayList(u8).init(arena);
        
        // 添加相关记忆作为上下文
        if (memories.len > 0) {
            try prompt.appendSlice("Relevant context from previous interactions:\n");
            for (memories) |memory| {
                try std.fmt.format(prompt.writer(), "- {s}\n", .{memory.content});
            }
            try prompt.appendSlice("\n");
        }
        
        // 添加用户偏好
        if (prefs) |p| {
            try prompt.appendSlice("User preferences:\n");
            try std.fmt.format(prompt.writer(), "- Languages: {s}\n", .{p.preferred_languages});
            try std.fmt.format(prompt.writer(), "- Code style: {s}\n", .{@tagName(p.code_style.naming_convention)});
            try prompt.appendSlice("\n");
        }
        
        // 添加用户输入
        try prompt.appendSlice("User request:\n");
        try prompt.appendSlice(user_input);
        
        return prompt.toOwnedSlice();
    }
};
```

---

## 实现优先级

### Phase 1: 基础记忆 (MVP)
- [ ] SQLite 存储层
- [ ] 基本的记忆 CRUD
- [ ] 全文搜索
- [ ] 用户偏好存储

### Phase 2: 智能检索
- [ ] 相关记忆检索
- [ ] 会话摘要生成
- [ ] 记忆去重/合并

### Phase 3: 学习系统
- [ ] 代码模式提取
- [ ] 模型表现跟踪
- [ ] 自适应模型选择

### Phase 4: 高级功能
- [ ] 向量嵌入 (sqlite-vec)
- [ ] 记忆图谱
- [ ] 主动学习

---

## 依赖

```zig
// build.zig.zon
.{
    .dependencies = .{
        // SQLite (Zig 绑定)
        .sqlite = .{
            .url = "https://github.com/vrischmann/zig-sqlite/archive/refs/tags/v0.1.0.tar.gz",
            .hash = "...",
        },
        
        // 可选: sqlite-vec 用于向量搜索
        .sqlite_vec = .{
            .url = "...",
            .hash = "...",
        },
    },
}
```

---

## 与 mem0 的对比

| 特性 | mem0 | kimiz Memory |
|------|------|--------------|
| **语言** | Python | Zig |
| **架构** | 独立服务 | 嵌入式 |
| **存储** | 20+ 后端 | SQLite 为主 |
| **向量搜索** | 必需 | 可选 |
| **部署** | 复杂 | 零配置 |
| **定制** | 有限 | 完全可控 |
| **代码学习** | 通用 | 专为代码优化 |

---

## 总结

我们不直接使用 mem0，而是借鉴其核心设计：

1. **提取-存储-检索** 流程
2. **分层记忆**（事实/偏好/模式）
3. **关联记忆** 图谱
4. **持续学习** 机制

但保持轻量化和嵌入式，专为代码 Agent 场景优化。
