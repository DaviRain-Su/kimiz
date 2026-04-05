### TASK-FEAT-018: 创建 Idea File 模板系统
**状态**: pending
**优先级**: P4 (nice-to-have)
**创建**: 2026-04-05
**预计耗时**: 2h
**说明**: 用户配置层，非 Agent 核心功能。可选实现。

**描述**:
创建 Kimiz Idea File 模板系统，让用户通过填写结构化配置文件来定义 Agent 的行为偏好、知识库结构和工作流程，实现"想法驱动"的 Agent 配置。

**背景**:
Karpathy 提出的 Idea File 方法论：分享"想法"而不是"代码"，让 Agent 根据用户需求自动实现和配置。

Kimiz Idea File 允许用户定义：
- 个人偏好和工作流程
- 知识库结构 (Obsidian Vault)
- 工具链集成
- Agent 行为模式
- 记忆组织方式

**Idea File 格式** (YAML/TOML):
```yaml
# Kimiz Idea File
# 用这个文件来配置你的 AI Agent 行为
# 让 Agent 读取后可自动完成配置

version: "1.0"

# === 身份与偏好 ===
identity:
  name: "小龙虾"
  description: "你的个人 AI 助手，专注于代码和学习"
  personality: |
    - 简洁直接，不废话
    - 主动建议优化方案
    - 遇到问题会先思考再行动

# === 工作流程 ===
workflow:
  morning:
    - "检查昨天的任务进度"
    - "读取每日日志模板"
    - "生成今日计划"
  
  coding:
    - "先理解需求再写代码"
    - "写测试用例"
    - "更新相关文档"
  
  learning:
    - "记录新学到的东西"
    - "关联到已有知识"
    - "生成简短总结"

# === 工具链 ===
tools:
  editor: "zed"  # zed, vscode, neovim
  terminal: "wezterm"
  ai: "claude"   # claude, gpt, gemini
  
  # 代码相关
  code_review: true
  linter: "zig fmt"
  formatter: "zig fmt"
  
  # 知识管理
  knowledge_base: "obsidian"
  knowledge_path: "~/notes"
  
  # 搜索
  search: "fff"  # fff, ripgrep, default
  fuzzy_search: true

# === 记忆系统 ===
memory:
  # 长期记忆存储格式
  format: "obsidian"  # obsidian, json, markdown
  
  # 记忆分类
  categories:
    - name: "学习笔记"
      tags: ["learn", "note"]
      template: "learning_template.md"
    
    - name: "代码片段"
      tags: ["code", "snippet"]
      template: "code_template.md"
    
    - name: "想法"
      tags: ["idea", "thought"]
      template: "idea_template.md"
    
    - name: "项目文档"
      tags: ["project", "doc"]
      template: "project_template.md"
  
  # 遗忘策略
  forget:
    enabled: true
    inactive_days: 90      # 90天未访问降低优先级
    archive_after: 180     # 180天后归档
    min_importance: 3      # 重要性低于3的可以遗忘

# === Agent 行为 ===
behavior:
  # 解释级别
  explanation: "concise"  # concise, detailed, minimal
  
  # 主动程度
  proactiveness: "medium" # low, medium, high
  
  # 确认时机
  confirm_before:
    - "删除文件"
    - "修改配置文件"
    - "执行破坏性命令"
  
  # 忽略规则
  ignore_patterns:
    - "node_modules/**"
    - ".git/**"
    - "*.lock"
  
  # 最大重试次数
  max_retries: 3

# === 知识库 (Obsidian) ===
knowledge:
  vault_path: "~/notes"
  
  # 目录结构
  structure:
    - "memories/       # 记忆存储"
    - "journals/       # 每日日志"
    - "inbox/          # 收件箱"
    - "projects/       # 项目文档"
    - "learning/       # 学习笔记"
    - "archive/        # 归档"
  
  # 模板
  templates:
    daily: "templates/daily.md"
    weekly: "templates/weekly.md"
    learning: "templates/learning.md"
    idea: "templates/idea.md"
    code: "templates/code.md"
  
  # 标签系统
  tags:
    priority: ["p1", "p2", "p3", "p4", "p5"]
    status: ["todo", "in-progress", "done", "blocked"]
    domains: ["code", "learn", "idea", "doc", "meta"]

# === 技能 (Skills) ===
skills:
  # 启用的技能
  enabled:
    - "code-review"
    - "git-master"
    - "write-test"
    - "search"
  
  # 技能特定配置
  configs:
    code-review:
      auto_review: true
      min_confidence: 0.8
    
    git-master:
      auto_commit: false
      branch_prefix: "agent/"
    
    search:
      engine: "fff"
      fuzzy_threshold: 0.7

# === 安全与限制 ===
security:
  # 允许执行的命令
  allowed_commands:
    - "zig"
    - "git"
    - "npm"
    - "cargo"
  
  # 禁止的操作
  forbidden:
    - "rm -rf /"
    - "curl | sh"
    - "sudo without confirmation"
  
  # 沙箱模式
  sandbox:
    enabled: true
    timeout_seconds: 300

# === 个性化指令 ===
custom_instructions: |
  ## 我的编码风格
  - 优先使用 const 而不是 var
  - 错误处理使用 try/catch
  - 注释要解释"为什么"而不是"是什么"
  
  ## 我的文档风格
  - README 要包含：背景、用法、示例
  - 代码注释使用英文
  - 文档使用中文
  
  ## 其他
  - 周六日不主动工作
  - 假期期间降低提醒频率
  - 重要决策需要我确认
```

**Agent 解析逻辑**:
```zig
// src/config/idea_file.zig
pub const IdeaFile = struct {
    version: []const u8,
    identity: Identity,
    workflow: Workflow,
    tools: Tools,
    memory: MemoryConfig,
    behavior: Behavior,
    knowledge: KnowledgeConfig,
    skills: SkillsConfig,
    security: SecurityConfig,
    custom_instructions: []const u8,
};

pub const IdeaFileParser = struct {
    allocator: std.mem.Allocator,
    
    /// 从 Idea File 生成 Kimiz 配置
    pub fn parse(self: *Self, content: []const u8) !Config {
        const idea = try self.parseYAML(content);
        
        return Config{
            .agent_name = idea.identity.name,
            .explanation_level = try self.parseExplanationLevel(idea.behavior.explanation),
            .proactiveness = try self.parseProactiveness(idea.behavior.proactiveness),
            .memory = try self.parseMemoryConfig(idea.memory),
            .knowledge_vault = idea.knowledge.vault_path,
            .skills = try self.parseSkills(idea.skills),
            .custom_instructions = idea.custom_instructions,
            // ...
        };
    }
    
    /// 验证 Idea File 格式
    pub fn validate(self: *Self, content: []const u8) !ValidationResult {
        var errors = std.ArrayList([]const u8).init(self.allocator);
        var warnings = std.ArrayList([]const u8).init(self.allocator);
        
        // 检查必需字段
        if (!self.hasField(content, "version")) {
            try errors.append("Missing required field: version");
        }
        
        if (!self.hasField(content, "identity")) {
            try errors.append("Missing required section: identity");
        }
        
        // 检查版本兼容性
        const version = self.getField(content, "version");
        if (!self.isCompatible(version)) {
            try warnings.append(
                std.fmt.allocPrint(self.allocator,
                    "Version {s} may not be fully compatible", .{version}
                ));
        }
        
        return ValidationResult{
            .valid = errors.items.len == 0,
            .errors = errors.toOwnedSlice(),
            .warnings = warnings.toOwnedSlice(),
        };
    }
};
```

**Kimiz 启动时加载 Idea File**:
```zig
// src/main.zig
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // 1. 查找 Idea File
    const idea_file_path = try findIdeaFile();
    
    if (idea_file_path) |path| {
        // 2. 解析 Idea File
        const content = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
        defer allocator.free(content);
        
        var parser = IdeaFileParser{ .allocator = allocator };
        const config = try parser.parse(content);
        
        // 3. 验证配置
        const validation = try parser.validate(content);
        if (!validation.valid) {
            std.log.warn("Idea File has errors:", .{});
            for (validation.errors) |err| {
                std.log.err("  - {s}", .{err});
            }
            return error.InvalidIdeaFile;
        }
        
        // 4. 打印警告
        for (validation.warnings) |warn| {
            std.log.warn("  {s}", .{warn});
        }
        
        // 5. 应用配置
        try applyConfig(config);
        
        std.debug.print("✓ Loaded Idea File: {s}\n", .{path});
    } else {
        // 使用默认配置
        std.debug.print("No Idea File found, using defaults\n", .{});
    }
    
    // 6. 启动 Agent
    try agent.start();
}

fn findIdeaFile() !?[]const u8 {
    const search_paths = .{
        "./KIMIZ.md",
        "./idea.md",
        "~/.config/kimiz/idea.md",
        "~/.kimiz/idea.md",
    };
    
    inline for (search_paths) |path| {
        const expanded = try expandTilde(path);
        if (std.fs.cwd().openFile(expanded, .{})) |file| {
            defer file.close();
            return expanded;
        } else |_| {
            continue;
        }
    }
    
    return null;
}
```

**模板片段示例**:
```markdown
# 学习笔记模板 (templates/learning.md)

---
type: learning
created: {{date}}
tags: []
---

# {{title}}

## 来源
> {{source}}

## 核心内容

## 我的理解

## 关联记忆
- [[]]

## 实践应用

---

## 标签
\#learn #{{topic}}
```

**验收标准**:
- [ ] `zig build` 编译通过
- [ ] Idea File 格式解析正确 (YAML/TOML)
- [ ] 所有配置字段正确映射到 Config 结构
- [ ] 验证逻辑正确 (错误/警告分离)
- [ ] 默认值正确填充
- [ ] 文档齐全 (KIMIZ.md 模板)
- [ ] 向后兼容 (旧配置仍可用)

**依赖**:
- TASK-INFRA-006 (Obsidian Wiki 集成)

**阻塞**:
- 无

**笔记**:
- 参考 Karpathy 的 Idea File 方法论
- 支持 YAML 和 TOML 格式
- 配置热加载 (修改后自动生效)
- 支持多语言 (i18n)
