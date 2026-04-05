### Task-REF-006: 简化 Workspace Context
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 4h
**参考**: [Simplified Architecture Proposal](../../docs/design/simplified-architecture-proposal.md)

**描述**:
将复杂的 Workspace Context（技术栈检测、代码模式识别、重要文件分析）简化为简单的 AGENTS.md + Git 信息收集。

**当前计划** (复杂):
```zig
pub const WorkspaceContext = struct {
    // Git 信息
    repo_root: []const u8,
    git_branch: []const u8,
    git_status: GitStatus,
    recent_commits: []const Commit,
    
    // 项目文档
    agents_md: ?[]const u8,
    readme_md: ?[]const u8,
    project_config: ProjectConfig,  // 解析 pyproject.toml, package.json, etc.
    
    // 文件结构
    source_tree: FileTree,
    tech_stack: []const []const u8,  // 检测到的技术栈
    code_patterns: []const []const u8,  // 代码模式识别
    important_files: []const []const u8,
    
    pub fn analyzeProject(self: *Self) !void;  // 复杂的分析逻辑
};
```

**简化后**:
```zig
// src/core/context.zig
pub const WorkspaceContext = struct {
    allocator: std.mem.Allocator,
    
    // AGENTS.md (最优先)
    agents_md: ?[]const u8,
    
    // Git 信息 (简单收集)
    git_branch: ?[]const u8,
    git_status: ?[]const u8,
    
    // 简单的文件树 (仅顶层)
    top_level_files: []const []const u8,
    
    pub fn collect(allocator: std.mem.Allocator, cwd: []const u8) !WorkspaceContext {
        return .{
            .agents_md = try readAgentsMd(allocator, cwd),
            .git_branch = try getGitBranch(allocator, cwd),
            .git_status = try getGitStatus(allocator, cwd),
            .top_level_files = try listTopLevelFiles(allocator, cwd),
        };
    }
    
    pub fn toPrompt(self: WorkspaceContext) ![]const u8 {
        var buf: std.ArrayList(u8) = .empty;
        
        // 优先使用 AGENTS.md
        if (self.agents_md) |content| {
            try buf.appendSlice(content);
            try buf.appendSlice("\n\n");
        }
        
        // 添加 Git 信息
        if (self.git_branch) |branch| {
            try std.fmt.format(buf.writer(), "Current branch: {s}\n", .{branch});
        }
        
        // 添加简单的文件树
        try buf.appendSlice("Project files:\n");
        for (self.top_level_files) |file| {
            try std.fmt.format(buf.writer(), "  {s}\n", .{file});
        }
        
        return buf.toOwnedSlice();
    }
    
    pub fn deinit(self: *Self) void;
};
```

**AGENTS.md 格式**:

```markdown
# AGENTS.md

## Project Overview
This is a Zig project that implements a coding agent.

## Common Commands
- Build: `zig build`
- Test: `zig build test`
- Run: `zig build run`

## Code Style
- 4 spaces indentation
- Snake_case for functions
- PascalCase for types

## Important Files
- src/main.zig - Entry point
- src/agent/agent.zig - Core agent loop
- build.zig - Build configuration
```

**搜索路径**:
1. 当前目录 `.`
2. 父目录 `..` (向上递归)
3. 全局 `~/.kimiz/AGENTS.md`

**需要修改的文件**:
- [ ] 删除 `TASK-FEAT-003-implement-workspace-context.md` (原复杂版本)
- [ ] 创建 `src/core/context.zig` (简化版)
- [ ] 修改 `src/agent/agent.zig` (集成简化版)

**验收标准**:
- [ ] 能读取 AGENTS.md
- [ ] 能收集 Git 分支和状态
- [ ] 能列出顶层文件
- [ ] 生成的提示文本格式良好
- [ ] 代码减少 70%+
- [ ] 启动时间 < 100ms
- [ ] 编译通过

**依赖**:
- TASK-BUG-013-fix-page-allocator-abuse

**阻塞**:
- Agent 上下文感知

**笔记**:
AGENTS.md 是 Pi-Mono 和 Claude Code 都支持的标准。简单但有效。
