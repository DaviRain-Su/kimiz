# Addy Osmani Agent Skills 分析与 Kimiz 整合方案

**研究日期**: 2026-04-05  
**来源**: @datachaz (Charly Wargnier) + @addyosmani (Google)  
**项目链接**: https://github.com/addyosmani/agent-skills  
**分发方式**: GStack / `npx skills add addyosmani/agent-skills`  
**背景**: Google 内部工程最佳实践的开源技能包

---

## 1. 执行摘要

Addy Osmani (Google Chrome 团队前端负责人) 开源的 **Agent Skills** 是一套基于 Google 内部工程文化的**工作流技能包**，包含：

- **19 个工程技能** —— 覆盖软件全生命周期
- **7 个斜杠命令** —— /spec, /plan, /build, /test, /review, /code-simplify, /ship
- **Markdown + frontmatter 格式** —— 任何支持 Markdown 的 agent 都可消费
- **硬性约束** —— 防止模型"抄近路"，强制走完整工程流程

**核心洞察**: 这不是工具集，而是**工程文化的编码化** —— 把 "spec before code", "test before merge" 变成可复用的结构化工件。

---

## 2. 技能包结构分析

### 2.1 7 个核心 Slash Commands (工作流主线)

```
用户请求
    │
    ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   /spec     │────►│   /plan     │────►│   /build    │
│   (Define)  │     │  (分解任务)  │     │ (增量实现)  │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                          ┌────────────────────┼────────────────────┐
                          │                    │                    │
                          ▼                    ▼                    ▼
                   ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
                   │   /test     │      │  /review    │      │/code-simplify│
                   │  (验证)     │      │  (审查)     │      │  (优化)     │
                   └──────┬──────┘      └──────┬──────┘      └──────┬──────┘
                          │                    │                    │
                          └────────────────────┼────────────────────┘
                                               │
                                               ▼
                                        ┌─────────────┐
                                        │    /ship    │
                                        │  (发布)     │
                                        └─────────────┘
```

| 命令 | 阶段 | 目的 | 防止的"抄近路" |
|------|------|------|----------------|
| `/spec` | Define | 先写规格，再动代码 | 直接开写，需求不清 |
| `/plan` | Plan | 拆成可验证的小任务 | 一团乱麻，无法追踪 |
| `/build` | Build | 增量实现，干净 API | 面条代码，接口混乱 |
| `/test` | Verify | TDD，DevTools 测试 | 不写测试，靠运气 |
| `/review` | Review | 代码质量、安全、性能 | 自我感觉良好 |
| `/code-simplify` | Refine | 简化复杂度 | 过度工程 |
| `/ship` | Ship | CI/CD，ADR，检查清单 | 仓促上线 |

### 2.2 19 个工程技能分类

```
agent-skills/
├── define/
│   ├── requirements-engineering.md      # 需求工程
│   ├── technical-specification.md       # 技术规格
│   └── architecture-design.md           # 架构设计
│
├── plan/
│   ├── task-decomposition.md            # 任务分解
│   ├── estimation.md                    # 工作量估算
│   └── dependency-mapping.md            # 依赖映射
│
├── build/
│   ├── incremental-implementation.md    # 增量实现
│   ├── context-engineering.md           # 上下文工程
│   ├── clean-api-design.md              # 干净 API
│   └── refactoring-patterns.md          # 重构模式
│
├── verify/
│   ├── test-driven-development.md       # TDD
│   ├── browser-devtools-testing.md      # 浏览器测试
│   ├── systematic-debugging.md          # 系统调试
│   └── security-scanning.md             # 安全扫描
│
├── review/
│   ├── code-quality-review.md           # 代码质量
│   ├── security-hardening.md            # 安全加固
│   └── performance-optimization.md      # 性能优化
│
└── ship/
    ├── git-workflow.md                  # Git 工作流
    ├── ci-cd-pipeline.md                # CI/CD
    ├── architecture-decision-records.md # ADR
    └── pre-flight-checklist.md          # 发布检查清单
```

### 2.3 Markdown Skill 格式示例

```markdown
---
id: technical-specification
name: Technical Specification
description: Write comprehensive technical specs before coding
category: define
version: 1.0.0
author: addyosmani
tags: [spec, planning, requirements]
---

# Technical Specification

## Context
You are a senior software engineer at Google. Your task is to write a comprehensive technical specification before any code is written.

## Required Sections

### 1. Problem Statement
- What problem are we solving?
- Who are the users?
- What is the success criteria?

### 2. Proposed Solution
- High-level approach
- Key technical decisions
- Alternative approaches considered

### 3. Implementation Plan
- Milestones
- Dependencies
- Risk mitigation

### 4. Testing Strategy
- Unit tests
- Integration tests
- Performance benchmarks

## Output Format
Produce a markdown document with all sections filled. Do not write any code until the spec is approved.

## Constraints
- [ ] All sections must be non-empty
- [ ] Must include at least one alternative approach
- [ ] Must define measurable success criteria
- [ ] Must be reviewed before proceeding to /plan
```

---

## 3. 核心设计原则

### 3.1 防止"抄近路"的机制

| 抄近路行为 | Skill 约束 | 强制执行方式 |
|------------|-----------|--------------|
| 直接写代码不写 spec | `/spec` 必须先执行 | 检查清单约束 |
| 不写测试 | `/test` 阶段强制要求 | 覆盖率检查 |
| 不审查直接合并 | `/review` 必须通过 | 质量门禁 |
| 无计划乱改 | `/plan` 分解必须可验证 | 任务追踪 |

### 3.2 Google 工程文化编码

```
Google 文化              Agent Skills 实现
────────────             ─────────────────
Design Docs              → technical-specification.md
Code Review              → code-quality-review.md
Testing Culture          → test-driven-development.md
Blameless Postmortems    → systematic-debugging.md
DRY Principle            → refactoring-patterns.md
API Design Guide         → clean-api-design.md
```

---

## 4. 与 Kimiz 的整合方案

### 4.1 整合架构

```
Addy Skills (Markdown)
         │
         │ npx skills add addyosmani/agent-skills
         ▼
┌─────────────────────────────────────────────────────────────┐
│                  Kimiz Skill Loader                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │ Frontmatter     │  │ Markdown Body   │  │ Constraint   │ │
│  │ Parser          │  │ → Prompt        │  │ Validator    │ │
│  │ (YAML/TOML)     │  │   Template      │  │ (Checklist)  │ │
│  └────────┬────────┘  └────────┬────────┘  └──────┬───────┘ │
│           │                    │                   │        │
│           └────────────────────┼───────────────────┘        │
│                                │                            │
│                                ▼                            │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              kimiz SkillRegistry                      │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐ │   │
│  │  │ /spec    │ │ /plan    │ │ /build   │ │ /test   │ │   │
│  │  │ Skill    │ │ Skill    │ │ Skill    │ │ Skill   │ │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └─────────┘ │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
         │
         │ 执行
         ▼
┌─────────────────────────────────────────────────────────────┐
│                  Kimiz Agent Loop                            │
│         (强制走 /spec → /plan → /build → /test 流程)         │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 具体整合点

#### 1. Markdown Skill Loader (新增模块)

```zig
// src/skills/markdown_loader.zig
pub const MarkdownSkillLoader = struct {
    /// Parse skill from markdown file
    pub fn parse(allocator: Allocator, content: []const u8) !Skill {
        // 1. Extract frontmatter (YAML between ---)
        const frontmatter = try extractFrontmatter(content);
        
        // 2. Parse metadata
        const meta = try parseFrontmatter(frontmatter);
        
        // 3. Extract markdown body as prompt template
        const template = extractBody(content);
        
        // 4. Parse constraint checklist
        const constraints = parseConstraints(template);
        
        return Skill{
            .id = meta.id,
            .name = meta.name,
            .category = mapCategory(meta.category),
            .prompt_template = template,
            .constraints = constraints,
        };
    }
};
```

#### 2. Slash Command 映射

| Addy Command | Kimiz 实现 | 说明 |
|--------------|-----------|------|
| `/spec` | `kimiz skill run spec` 或 `#spec` | 技术规格技能 |
| `/plan` | `kimiz skill run plan` 或 `#plan` | 任务规划技能 |
| `/build` | `kimiz skill run build` 或 `#build` | 增量实现技能 |
| `/test` | `kimiz skill run test` 或 `#test` | 测试驱动技能 |
| `/review` | `kimiz skill run review` 或 `#review` | 代码审查技能 |
| `/code-simplify` | `kimiz skill run simplify` 或 `#simplify` | 简化优化技能 |
| `/ship` | `kimiz skill run ship` 或 `#ship` | 发布流程技能 |

#### 3. 工作流引擎集成

```zig
// src/skills/workflow_engine.zig
pub const WorkflowEngine = struct {
    /// Enforce workflow: spec -> plan -> build -> test -> review -> ship
    pub fn canExecute(self: *Self, skill_id: []const u8) !bool {
        const workflow_order = &[_][]const u8{
            "spec", "plan", "build", "test", "review", "ship"
        };
        
        // Check if prerequisite skills have been executed
        const required_prev = findPrerequisite(skill_id, workflow_order);
        if (required_prev) |prev| {
            if (!self.execution_log.contains(prev)) {
                return error.PrerequisiteNotMet;
            }
        }
        
        return true;
    }
};
```

#### 4. 约束验证器

```zig
// src/skills/constraint_validator.zig
pub const ConstraintValidator = struct {
    /// Validate checklist constraints in skill output
    pub fn validate(output: []const u8, constraints: []Constraint) !ValidationResult {
        for (constraints) |constraint| {
            switch (constraint.type) {
                .checklist => {
                    // Check if all checkboxes are checked
                    if (!allChecked(output, constraint.pattern)) {
                        return .{ .valid = false, .missing = constraint };
                    }
                },
                .section_present => {
                    // Check if required section exists
                    if (!hasSection(output, constraint.name)) {
                        return .{ .valid = false, .missing = constraint };
                    }
                },
                // ... more constraint types
            }
        }
        return .{ .valid = true };
    }
};
```

---

## 5. 实施路线图

### Phase 1: Markdown Skill 支持 (1-2 周)

```
Week 1:
├── Day 1-2: Frontmatter parser (YAML/TOML)
├── Day 3-4: Markdown → Skill transformer
└── Day 5: Constraint checklist parser

Week 2:
├── Day 1-2: Skill loader integration
├── Day 3-4: Load Addy Skills into registry
└── Day 5: Basic slash command support
```

### Phase 2: 工作流引擎 (1-2 周)

```
Week 3:
├── Day 1-2: Workflow state machine
├── Day 3-4: Prerequisite validation
└── Day 5: Execution logging

Week 4:
├── Day 1-2: Constraint validator
├── Day 3-4: Error messages & guidance
└── Day 5: Integration testing
```

### Phase 3: Kimiz 化适配 (1 周)

```
Week 5:
├── Day 1-2: Kimiz-specific prompt templates
├── Day 3-4: Zig/C project context injection
└── Day 5: Documentation & examples
```

---

## 6. 使用场景示例

### 场景 1: 新功能开发 (完整流程)

```bash
# 用户: 我要添加一个 HTTP 客户端模块
$ kimiz run "添加 HTTP 客户端模块"

# Kimiz 强制执行:
1. /spec  → 生成 technical-spec.md
2. /plan  → 生成 task-breakdown.md  
3. /build → 实现 src/http/client.zig
4. /test  → 生成 tests/http_client_test.zig
5. /review → 代码审查报告
6. /ship  → 提交 PR，ADR 记录
```

### 场景 2: 代码审查 (单技能)

```bash
# 直接调用 review 技能
$ kimiz skill run review --target src/auth.zig

# 输出:
# - 代码质量评分
# - 安全问题检查
# - 性能优化建议
# - 重构建议
```

### 场景 3: TDD 模式

```bash
# /test 技能强制执行 TDD
$ kimiz skill run test --feature "user authentication"

# 流程:
# 1. 先生成测试用例 (先失败)
# 2. 最小实现通过测试
# 3. 重构优化
```

---

## 7. 与现有系统的协同

### 7.1 与 Harness 层的整合

```
┌─────────────────────────────────────────────────────────────┐
│                    Kimiz Harness Layer                       │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│  │ Addy Skills  │ │   Memory     │ │   Learning   │        │
│  │ (Workflow)   │ │  (Context)   │ │  (Adaptive)  │        │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘        │
│         │                │                │                │
│         └────────────────┼────────────────┘                │
│                          │                                 │
│                          ▼                                 │
│  ┌──────────────────────────────────────────────────────┐ │
│  │                  Agent Loop                           │ │
│  │  (强制 spec→plan→build→test 流程，防止抄近路)         │ │
│  └──────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 7.2 与 Subagent 的整合

```
# /build 技能可以委派子任务
Parent Agent (/build)
    │
    ├── Subagent 1: 设计 API 接口
    ├── Subagent 2: 实现核心逻辑  
    └── Subagent 3: 编写单元测试
    │
    └── 合并结果，统一输出
```

---

## 8. 价值评估

### 8.1 对 Kimiz 的价值

| 维度 | 收益 |
|------|------|
| **工程纪律** | 强制 Google 级工程流程，减少"快但错" |
| **学习曲线** | 新手自动获得资深工程师工作流 |
| **质量保证** | 结构化的 spec/plan/test 流程 |
| **社区资源** | 复用 19 个高质量技能，无需自建 |

### 8.2 与现有方案的对比

| 方案 | 优点 | 缺点 |
|------|------|------|
| **裸模型** | 灵活 | 抄近路，质量不稳定 |
| **Prompt 模板** | 简单 | 无法强制流程 |
| **Addy Skills** | 结构完整，文化编码 | 通用，需适配具体项目 |
| **+ Kimiz 集成** | 强制流程 + 项目适配 | 需要一定学习成本 |

---

## 9. 参考资源

- **Addy Skills GitHub**: https://github.com/addyosmani/agent-skills
- **GStack**: https://github.com/garrytan/gstack (分发平台)
- **Google Engineering Practices**: https://google.github.io/eng-practices/
- **Addy Osmani Blog**: https://addyosmani.com/blog/

---

## 10. 关键结论

> **"Addy Skills 是工程文化的'操作系统'，Kimiz 应该成为它的'运行时'"**

### 核心观点

1. **不是替代，是增强**: Addy Skills 提供流程框架，Kimiz 提供执行引擎
2. **强制优于建议**: 通过技能系统硬性约束，而非提示词软性建议
3. **可复用性**: 19 个技能直接复用，站在 Google 工程文化肩膀上
4. **渐进 adoption**: 可以先用单技能，再逐步引入完整工作流

### 下一步建议

| 优先级 | 行动 | 预期产出 |
|--------|------|----------|
| P0 | 实现 Markdown skill loader | 可加载 Addy Skills |
| P1 | 集成 workflow engine | 强制 /spec→/plan→/build 流程 |
| P2 | Kimiz 化适配 | Zig/C 项目专用优化 |
| P3 | 社区贡献 | 向 Addy Skills 提交 Zig-specific skills |

---

*文档版本: 1.0*  
*最后更新: 2026-04-05*  
*维护者: kimiz-core-team*
