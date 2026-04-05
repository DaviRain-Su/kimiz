### Task-FEAT-014: 实现 AGENTS.md 结构化知识系统
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 8h

**描述**:
参考 OpenAI 的 harness engineering 实践，实现 AGENTS.md 结构化知识系统。核心洞察：**AGENTS.md 应该是目录，不是百科全书。** 100 行导航指向 docs/ 下的结构化知识。

**背景**:
OpenAI 发现：
- 塞满规则的大文件失败了
- 上下文窗口是稀缺资源
- 最终方案：~100 行 AGENTS.md 作为导航 + docs/ 结构化知识库
- Vercel 验证：压缩的 8KB AGENTS.md 达到 100% eval 通过率

**目标功能**:

1. **KnowledgeBase 结构**
```zig
pub const KnowledgeBase = struct {
    project_overview: []const u8,      // 项目概览
    architecture_doc: []const u8,       // 架构文档
    code_standards: []const u8,         // 代码规范
    quality_checklist: []const u8,      // 质量清单
    execution_plans: []const ExecutionPlan, // 执行计划
    tech_debt: []const TechDebtItem,   // 技术债追踪
};
```

2. **AGENTS.md 解析器**
```zig
// 解析 AGENTS.md 为导航结构
pub fn parseAgentsMd(path: []const u8) !AgentsMd {
    // 识别 ## 标题作为章节
    // 识别 [link](path) 作为文档链接
    // 识别 ```code``` 作为示例
}

// 生成 Agent 可读的上下文摘要
pub fn buildContextSummary(kb: *const KnowledgeBase) []const u8 {
    // 生成压缩的上下文摘要
    // 控制在 8KB 以内
}
```

3. **文档结构**
```
project/
├── AGENTS.md                    # 导航目录 (~100 行)
├── docs/
│   ├── overview.md             # 项目概览
│   ├── architecture/
│   │   ├── system-design.md
│   │   └── api-spec.md
│   ├── standards/
│   │   ├── coding-style.md
│   │   ├── git-conventions.md
│   │   └── pr-process.md
│   ├── execution-plans/
│   │   ├── ep-001-feature-flags.md
│   │   └── ep-002-authentication.md
│   └── quality/
│       └── scorecard.md
└── src/
```

4. **与 WorkspaceContext 集成**
```zig
pub fn buildAgentContext(
    workspace: *WorkspaceInfo,
    kb: *KnowledgeBase,
) !AgentContext {
    return .{
        .workspace = workspace,
        .project_overview = kb.project_overview,
        .architecture = kb.architecture_doc,
        .standards = kb.code_standards,
        .quality = kb.quality_checklist,
        // 从 docs/ 动态加载相关文档
    };
}
```

**验收标准**:
- [ ] 能解析标准 AGENTS.md 格式
- [ ] 生成 <8KB 的压缩上下文
- [ ] 与 WorkspaceContext 正确集成
- [ ] 自动发现并加载 docs/ 下的文档
- [ ] 支持 execution plans 结构

**依赖**:
- Task-FEAT-006 (WorkspaceContext)

**阻塞**:
- 无

**笔记**:
这是 OpenAI harness engineering 的核心发现。
