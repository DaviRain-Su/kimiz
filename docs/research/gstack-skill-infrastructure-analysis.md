# GStack Skill 基础设施分析与 Kimiz 整合机会

**研究日期**: 2026-04-05  
**来源**: @garrytan (Garry Tan, YC 总裁) Twitter/X 帖子  
**项目链接**: https://github.com/garrytan/gstack  
**背景**: GStack 重构为声明式配置的 coding agent skill 适配器

---

## 1. 执行摘要

GStack 是 YC 总裁 Garry Tan 开发的一个 **coding agent skill 基础设施**，其核心创新是将 skill 分发和 agent 适配完全模块化：

- **声明式配置**: 每个 agent 支持只需一个 TypeScript config 文件
- **零代码添加**: 新增 agent 支持无需修改 generator、setup 或 tooling
- **跨 agent 复用**: 同一套 skills 可无缝应用到多个 coding agent
- **即将支持**: OpenClaw、OpenCode、Slate 的原生支持

**关键洞察**: GStack 是 **Skill 层的基础设施**，与 kimiz 的 Extension/Skill 系统存在天然的整合机会。

---

## 2. GStack 架构解析

### 2.1 核心设计

```
┌─────────────────────────────────────────────────────────────────┐
│                      GStack Ecosystem                            │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   Skills     │  │   Configs    │  │  Generator   │          │
│  │   (Markdown) │  │   (TypeScript)│  │   (Tooling)  │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                 │                  │                 │
│         └─────────────────┼──────────────────┘                 │
│                           │                                    │
│                           ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Host Adapter (Agent-specific)                │   │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐       │   │
│  │  │ Claude  │ │ Cursor  │ │OpenCode │ │  Kimiz  │◄──────┤   │
│  │  │ Config  │ │ Config  │ │ Config  │ │ Config? │       │   │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘       │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 HostConfig 结构

```typescript
// GStack HostConfig 示例 (推测结构)
interface HostConfig {
  // Agent 标识
  id: string;                    // "claude", "cursor", "kimiz"
  name: string;                  // 显示名称
  
  // Skill 输出配置
  skillsDir: string;             // skills 存放路径
  frontmatter: {
    whitelist: string[];         // 允许的前置元数据
    blacklist: string[];         // 过滤的前置元数据
  };
  
  // 路径/工具重写规则
  pathRewrites: Record<string, string>;
  toolRewrites: Record<string, string>;
  
  // 安装配置
  binaryDetection: string[];     // 自动检测的二进制名
  symlinks: string[];            // 安装时创建的 symlink
  
  // 特殊处理
  customHandlers?: {
    preInstall?: () => void;
    postInstall?: () => void;
  };
}
```

---

## 3. 与 Kimiz 的对比分析

### 3.1 当前 Kimiz Skill/Extension 系统

```
┌─────────────────────────────────────────────────────────────────┐
│                     Kimiz Skill System                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Built-in Skills (Zig 编译时)        WASM Extensions (运行时)    │
│  ┌──────────────────────────┐       ┌────────────────────────┐  │
│  │ • code_review.zig        │       │ • Custom Tools         │  │
│  │ • refactor.zig           │       │ • Custom Skills        │  │
│  │ • test_gen.zig           │       │ • Dynamic Loading      │  │
│  │ • doc_gen.zig            │       │ • Package Manager      │  │
│  │ • debug.zig              │       │   (Git-based)          │  │
│  └──────────────────────────┘       └────────────────────────┘  │
│                                                                  │
│  Registration: 编译时硬编码          Registration: 动态加载      │
│  Format: Zig 源码                    Format: WASM 二进制         │
│  Distribution: 随二进制分发          Distribution: Git 仓库      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 能力对比矩阵

| 能力 | GStack | Kimiz Built-in | Kimiz WASM Ext |
|------|--------|----------------|----------------|
| **Skill 格式** | Markdown + frontmatter | Zig 源码 | WASM 二进制 |
| **分发方式** | npm/npx | 编译进二进制 | Git 拉取 |
| **动态加载** | ✅ 安装时 | ❌ 编译时 | ✅ 运行时 |
| **跨 agent 复用** | ✅ 核心特性 | ❌ 仅 kimiz | ⚠️ 需适配 |
| **声明式配置** | ✅ HostConfig | ❌ 代码注册 | ⚠️ manifest |
| **版本管理** | ✅ npm 生态 | ❌ 随版本绑定 | ✅ Git tag |
| **社区生态** | ✅ 开源 skills | ❌ 内置 only | 🆕 新兴 |

---

## 4. 整合机会分析

### 4.1 机会 1: GStack Skill Consumer (推荐)

**概念**: 让 kimiz 能够消费 GStack 分发的 Markdown skills

```
GStack Skills (Markdown) 
         │
         │ npx skills add addyosmani/agent-skills
         ▼
┌──────────────────────┐
│  kimiz skill-loader  │  ← 新增: Markdown skill 解析器
│  (Markdown → Skill)  │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  kimiz SkillRegistry │  ← 复用现有 registry
│  (Runtime execution) │
└──────────────────────┘
```

**实现方式**:
1. 创建 Markdown skill 解析器 (frontmatter → Skill 元数据)
2. 将 Markdown content 转换为 kimiz prompt template
3. 通过 Extension 系统动态注册

**价值**:
- 立即获得 GStack 生态的所有 skills
- 复用 Google/Addy Osmani 的工程流程 skills
- 无需重写，直接消费社区资源

---

### 4.2 机会 2: Kimiz as GStack Host

**概念**: 让 kimiz 成为 GStack 官方支持的 host 之一

```typescript
// gstack-hosts/kimiz.ts (潜在配置)
export const kimizHost: HostConfig = {
  id: "kimiz",
  name: "Kimiz AI Coding Agent",
  
  skillsDir: ".kimiz/skills",
  
  frontmatter: {
    whitelist: ["id", "name", "description", "version", "category"],
    blacklist: ["private", "experimental"]
  },
  
  // kimiz 特有路径映射
  pathRewrites: {
    "./skills": ".kimiz/skills",
    "./context": ".kimiz/context"
  },
  
  // 工具名重写 (如有必要)
  toolRewrites: {
    // kimiz 工具名与其他 agent 的差异映射
  },
  
  // 安装配置
  binaryDetection: ["kimiz"],
  symlinks: [".kimiz"],
  
  // 特殊处理
  customHandlers: {
    postInstall: () => {
      // 初始化 kimiz skill registry
      // 生成 kimiz.toml 配置
    }
  }
};
```

**所需工作**:
1. 与 Garry Tan 沟通，提交 kimiz host 配置
2. 确保 kimiz skill 加载机制与 GStack 输出兼容
3. 测试 skills 在 kimiz 中的实际效果

**价值**:
- 进入 GStack 生态，获得曝光
- 用户可以通过 GStack 一键安装 skills 到 kimiz
- 与 OpenClaw、OpenCode 等并列成为主流选择

---

### 4.3 机会 3: 借鉴声明式配置

**概念**: 学习 GStack 的 HostConfig 设计，改进 kimiz 的扩展配置

**当前 kimiz Extension Manifest**:
```toml
# kimiz.toml (当前)
name = "my-extension"
version = "1.0.0"
description = "My extension"
author = "developer"
main = "extension.wasm"
```

**借鉴 GStack 后的增强版本**:
```toml
# kimiz.toml (增强版)
name = "my-extension"
version = "1.0.0"
description = "My extension"
author = "developer"
main = "extension.wasm"

# 新增: 声明式 skills 注册
[[skills]]
id = "security-audit"
name = "Security Audit"
category = "analyze"
prompt_template = "prompts/security.md"

[[skills]]
id = "performance-check"
name = "Performance Check"
category = "analyze"
prompt_template = "prompts/perf.md"

# 新增: 与其他 agent 的兼容性声明
[compatibility]
gstack_host = "kimiz"
supported_agents = ["kimiz", "claude", "cursor"]
```

**价值**:
- 更清晰的扩展声明
- 更好的跨 agent 兼容性
- 向 GStack 生态靠拢

---

## 5. 整合路线图

### Phase 1: 研究验证 (1 周)

| 任务 | 目标 | 产出 |
|------|------|------|
| 研究 GStack 源码 | 理解 skill 加载机制 | 技术分析文档 |
| 研究 Addy Skills | 分析 Markdown skill 结构 | Skill 格式规范 |
| PoC: Markdown → kimiz | 验证转换可行性 | 原型代码 |

### Phase 2: Skill Consumer 实现 (2 周)

| 任务 | 说明 | 集成点 |
|------|------|--------|
| Markdown parser | 解析 frontmatter + content | src/skills/markdown_loader.zig |
| Skill transformer | Markdown → kimiz Skill | src/skills/transformer.zig |
| GStack CLI wrapper | `npx skills` 命令封装 | src/cli/skills_cmd.zig |
| Registry integration | 动态注册加载的 skills | src/skills/root.zig |

### Phase 3: GStack Host 申请 (并行)

| 任务 | 说明 | 负责 |
|------|------|------|
| 创建 kimiz host config | TypeScript config 文件 | 社区贡献 |
| 提交 PR 到 gstack | 申请官方支持 | 维护者 |
| 联合测试 | 验证 skills 兼容性 | 双方 |

---

## 6. 技术实现草案

### 6.1 Markdown Skill 格式 (基于 Addy Skills)

```markdown
---
id: code-review
name: Code Review
description: Perform comprehensive code review
category: review
version: 1.0.0
author: addyosmani
---

# Code Review Skill

## Context
You are an expert code reviewer. Review the provided code for:
- Security issues
- Performance bottlenecks
- Maintainability concerns

## Steps
1. Read the code carefully
2. Identify potential issues
3. Provide actionable feedback

## Output Format
```json
{
  "issues": [...],
  "suggestions": [...]
}
```
```

### 6.2 kimiz 加载器实现思路

```zig
// src/skills/markdown_loader.zig
const MarkdownSkillLoader = struct {
    /// Load skill from markdown file
    pub fn loadFromFile(allocator: Allocator, path: []const u8) !Skill {
        // 1. Read markdown content
        const content = try fs.readFile(allocator, path);
        defer allocator.free(content);
        
        // 2. Parse frontmatter (YAML/TOML)
        const frontmatter = try parseFrontmatter(content);
        
        // 3. Extract markdown body as prompt template
        const prompt_template = extractMarkdownBody(content);
        
        // 4. Create kimiz Skill
        return Skill{
            .id = frontmatter.id,
            .name = frontmatter.name,
            .description = frontmatter.description,
            .category = mapCategory(frontmatter.category),
            .execute_fn = createMarkdownSkillExecutor(prompt_template),
        };
    }
};
```

---

## 7. 生态系统价值

### 7.1 对 kimiz 的价值

| 维度 | 收益 |
|------|------|
| **Skill 生态** | 立即获得 GStack + Addy Skills 的丰富资源 |
| **社区曝光** | 进入 YC/Garry Tan 的生态系统 |
| **用户体验** | 一键安装高质量工程 skills |
| **开发效率** | 复用社区 skills，减少自建成本 |

### 7.2 对 GStack 生态的价值

| 维度 | 收益 |
|------|------|
| **多样性** | 增加 Zig/高性能 agent 选择 |
| **性能标杆** | kimiz 的 <100ms 启动可作为标杆 |
| **技术互补** | WASM 扩展 + Markdown skills 双轨制 |

---

## 8. 相关资源

- **GStack**: https://github.com/garrytan/gstack
- **Addy Skills**: https://github.com/addyosmani/agent-skills
- **OpenClaw**: https://github.com/pi-mono/claw (GStack 即将支持)
- **OpenCode**: https://github.com/sst/opencode
- **Slate**: https://github.com/slate-ai/slate

---

## 9. 关键结论

> **"GStack 是 Skill 基础设施的 npm，kimiz 应该成为它的消费方和宿主方"**

| 策略 | 优先级 | 投入 | 收益 |
|------|--------|------|------|
| **Skill Consumer** | P1 | 2-3 周 | 立即获得丰富 skill 生态 |
| **GStack Host** | P2 | 1 周 + 社区 | 进入主流生态 |
| **配置借鉴** | P3 | 持续 | 架构对齐 |

**建议下一步**:
1. 快速 PoC 验证 Markdown skill 加载
2. 联系 Garry Tan 探讨官方 host 支持
3. 评估与现有 WASM extension 系统的融合方案

---

*文档版本: 1.0*  
*最后更新: 2026-04-05*  
*维护者: kimiz-core-team*
