### Task-FEAT-003: 实现 Workspace Context (实时仓库上下文)
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 6h
**参考**: [Coding Agent Components Analysis](../../docs/design/coding-agent-components-analysis.md)

**描述**:
根据 Sebastian Raschka 的文章，Workspace Context 是 Coding Agent 的第一核心组件。它负责收集 Git 仓库信息、项目文档和文件结构，为 Agent 提供上下文感知能力。

**功能需求**:

1. **Git 信息收集**
   - 当前分支名称
   - Git 状态（是否有未提交更改）
   - 最近提交历史（最近 5-10 条）
   - 远程仓库信息

2. **项目文档读取**
   - AGENTS.md（Agent 指令）
   - README.md（项目说明）
   - pyproject.toml / package.json / build.zig（项目配置）
   - .cursorrules / .claude.md（AI 助手配置）

3. **文件结构分析**
   - 源代码目录结构
   - 主要入口文件识别
   - 技术栈检测

**实现方案**:

```zig
// src/context/workspace.zig
pub const WorkspaceContext = struct {
    allocator: std.mem.Allocator,
    
    // Git 信息
    repo_root: []const u8,
    git_branch: []const u8,
    git_status: GitStatus,
    recent_commits: []const Commit,
    
    // 项目文档
    agents_md: ?[]const u8,
    readme_md: ?[]const u8,
    project_config: ?ProjectConfig,
    
    // 文件结构
    source_tree: FileTree,
    tech_stack: []const []const u8,
    
    pub fn collect(allocator: std.mem.Allocator, cwd: []const u8) !WorkspaceContext;
    pub fn toPromptText(self: WorkspaceContext) ![]const u8;
    pub fn deinit(self: *WorkspaceContext) void;
};

pub const GitStatus = struct {
    has_uncommitted_changes: bool,
    modified_files: []const []const u8,
    untracked_files: []const []const u8,
};

pub const ProjectConfig = union(enum) {
    zig: ZigConfig,      // build.zig
    python: PythonConfig, // pyproject.toml
    node: NodeConfig,    // package.json
    rust: RustConfig,    // Cargo.toml
    // ...
};
```

**与现有代码集成**:

```zig
// src/agent/agent.zig
pub const AgentOptions = struct {
    model: core.Model,
    tools: []const AgentTool = &.{},
    workspace_context: ?WorkspaceContext = null,  // 新增
    // ...
};

// Agent 初始化时收集上下文
pub fn init(allocator: std.mem.Allocator, options: AgentOptions) !Self {
    var workspace = options.workspace_context orelse 
        try WorkspaceContext.collect(allocator, ".");
    
    // ...
}
```

**验收标准**:
- [ ] 能正确检测 Git 仓库信息
- [ ] 能读取并解析 AGENTS.md 和 README.md
- [ ] 能识别项目技术栈
- [ ] 生成的上下文文本格式清晰
- [ ] 非 Git 项目也能正常工作（降级处理）
- [ ] 添加单元测试
- [ ] 编译通过，无内存泄漏

**依赖**:
- TASK-BUG-013-fix-page-allocator-abuse
- TASK-BUG-014-fix-cli-unimplemented

**阻塞**:
- 上下文感知的 Agent 功能

**笔记**:
这是 Coding Agent 的核心差异化功能。Claude Code 和 Codex 都依赖强大的上下文收集来提供准确的建议。
