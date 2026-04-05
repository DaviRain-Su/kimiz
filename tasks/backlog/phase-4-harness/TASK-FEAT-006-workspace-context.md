### Task-FEAT-006: 实现 WorkspaceContext 收集 Git 上下文
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 4h

**描述**:
参考 Raschka mini-coding-agent 的 WorkspaceContext 实现，为 kimiz 添加完整的仓库上下文收集能力。

**目标功能**:

1. **Git 上下文收集**
   - 当前分支名称 (`git branch --show-current`)
   - 默认分支名称 (`git symbolic-ref`)
   - Git 状态 (`git status --short`)
   - 最近 5 次提交 (`git log --oneline -5`)

2. **项目文档收集**
   - README.md (裁剪到 1200 字符)
   - AGENTS.md / CLAUDE.md (如果存在)
   - pyproject.toml / package.json 等项目配置

3. **WorkspaceInfo 结构**
```zig
pub const WorkspaceInfo = struct {
    cwd: []const u8,
    repo_root: []const u8,
    branch: []const u8,
    default_branch: []const u8,
    git_status: []const u8,
    recent_commits: []const []const u8,
    project_docs: std.StringHashMap([]const u8),
};
```

**验收标准**:
- [ ] 能正确收集 Git 分支和状态
- [ ] 能收集项目文档内容
- [ ] 集成到 WorkingMemory.analyzeProject()
- [ ] 单元测试覆盖

**依赖**:
- 无

**阻塞**:
- Prompt Caching (Task-FEAT-007)

**笔记**:
这是实现 Prompt Caching 的前提条件。
