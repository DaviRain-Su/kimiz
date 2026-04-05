# Factory Plugins 分析 — Prompt-based Skill 市场的标杆设计

**文档版本**: 1.0  
**日期**: 2026-04-05  
**分析对象**: [Factory-AI/factory-plugins](https://github.com/Factory-AI/factory-plugins)  
**分析结论**: Factory 的 skill 市场在**组织形式、元技能设计、方法论沉淀**上做得非常成熟，是 KimiZ 设计 auto skill 生态的重要参考。但核心差异不变：Factory 是 Prompt-based，KimiZ 是编译型。

---

## 1. Factory Plugins 是什么

**定位**: "Official Factory plugins marketplace containing curated skills, droids, and tools."

这是一个**开源的 skill 市场仓库**，用户可以通过 Factory Droid CLI 直接安装：

```bash
# 添加市场源
droid plugin marketplace add https://github.com/Factory-AI/factory-plugins

# 安装插件
droid plugin install security-engineer@factory-plugins

# 或浏览
/plugins
```

**Stars**: 38  
**插件数量**: 4 个官方插件（core, security-engineer, droid-evolved, autoresearch）

---

## 2. 插件目录结构 — 行业标准级规范

Factory 定义了一套非常清晰的插件格式：

```
plugin-name/
├── .factory-plugin/
│   └── plugin.json          # 插件元数据
├── skills/
│   └── skill-name/
│       └── SKILL.md         # YAML frontmatter + markdown body
├── droids/                  # Droid 定义（可选）
├── commands/                # 自定义命令（可选）
├── mcp.json                 # MCP server 配置（可选）
└── hooks.json               # Hook 配置（可选）
```

### 2.1 plugin.json — 最小化但完整的元数据

```json
{
  "name": "core",
  "description": "Core Skills for essential functionalities and integrations",
  "author": {
    "name": "Factory",
    "email": "support@factory.ai"
  }
}
```

**特点**：
- 没有版本号（可能在 marketplace 层面统一管理）
- 没有复杂的依赖声明
- 极简，但足够识别

### 2.2 SKILL.md — 自描述的 Prompt 文档

这是 Factory skill 的核心。一个 SKILL.md 包含：

```markdown
---
name: review
version: 2.0.0
description: |
  Review code changes and identify high-confidence, actionable bugs.
  Use when the user wants to:
  - Review a pull request or branch diff
  - Find bugs, security issues, or correctness problems in code changes
  - Get a structured summary of review findings
---

# 正文：详细的 prompt 指令
...
```

**对 KimiZ 的价值**：
- YAML frontmatter + markdown body 是一种非常优雅的文档格式
- 即使 KimiZ 的 skill 是编译型 Zig 代码，**文档形式**仍然可以参考
- `description` 里明确写 "Use when..." 是 LLM 选择 skill 的关键信号

---

## 3. 四个官方插件的启示

### 3.1 core — 基础技能包

**Skills**:
- `review` — 代码审查（two-pass pipeline）
- `init` — 项目初始化
- `session-navigation` — 会话历史搜索和导航

**启示**：core 是预装的。这验证了 KimiZ `builtin.zig` 的设计方向：一部分 skill 必须随二进制分发，确保开箱即用。

### 3.2 security-engineer — 垂直领域专家

**Skills**:
- `security-review` — STRIDE-based 安全分析
- `threat-model-generation` — 威胁模型生成
- `commit-security-scan` — 提交/PR 安全扫描
- `vulnerability-validation` — 漏洞验证

**启示**：
- 垂直领域（security）可以打包成一个独立的插件
- KimiZ 未来也可以有 `security-engineer` 插件，但它是**编译型 skill 集合**，而不是 prompt 集合
- `STRIDE-based` 这种明确的 methodology 标签很重要，让用户知道 skill 用什么方法论

### 3.3 droid-evolved — 元技能和创造力

**Skills**:
- `session-navigation` — 搜索历史会话
- `human-writing` — 去除 AI 写作痕迹
- `skill-creation` — **创建和改进 Droid skills（元技能）**
- `visual-design` — 图像生成
- `frontend-design` — 网页设计
- `browser-navigation` — 浏览器自动化

**最关键的发现**：`skill-creation` 是一个 **meta-skill**。

它教 agent 如何：
1. 从会话中提取可复用的模式
2. 写成 SKILL.md
3. 决定什么时候应该创建 skill（"Not everything deserves to be a skill"）
4. 维护和迭代 skill

里面甚至引用了学术论文：
- **Voyager** — 代理可以建立技能库
- **CASCADE** — 技能可以在代理间共享
- **SEAgent** — 从失败中学习
- **Reflexion** — 语言反馈比数值分数更有效

**对 KimiZ 的价值**：
- KimiZ 也应该有一个 **编译型元技能**：`auto-skill-generation`
- 这个 skill 不是教 LLM 写 markdown，而是**生成 Zig 代码、触发编译、注册到 AutoRegistry**
- Factory 的 `skill-creation` 是 T-100 的**思想启蒙教材**

### 3.4 autoresearch — 自主实验循环

这是最新加入的插件（2026-03-29），描述是 "autonomous experiment loop for optimization"。

**启示**：
- Factory 也在往"自主进化"方向走
- 但仍然是 prompt-based 的实验循环，不是代码生成+编译验证

---

## 4. review skill 的 Two-Pass Pipeline — 方法论巅峰

`plugins/core/skills/review/SKILL.md` 是一份**方法论文档的杰作**，值得全文学习。

### 4.1 共享方法论（Shared Methodology）

SKILL.md 里有一块 `<!-- BEGIN_SHARED_METHODOLOGY --> ... <!-- END_SHARED_METHODOLOGY -->`，这是可以被其他 skill 复用的标准审查方法论。

内容包括：
- **Bug Patterns**: null safety, resource leaks, injection, OAuth/CSRF, concurrency, missing error handling...
- **Systematic Analysis Patterns**: logic & variable usage, type compatibility, async/await, security, concurrency, API contract
- **Analysis Discipline**: Verify with Grep/Read, trace data flow, check elsewhere, verify tests
- **Reporting Gate**: 明确什么该报、什么不该报
- **Confidence Calibration**: P0/P1/P2/P3 分级
- **Deduplication**: 不重复报、修复后标记 resolved

**对 KimiZ 的价值**：
- 这段方法论可以直接改编为 KimiZ `code_review.zig` 的**系统 prompt 模板**
- `BEGIN_SHARED_METHODOLOGY` 的注释块设计非常聪明：可以被 LLM 或工具提取、复用、版本管理
- KimiZ 的 `ReviewConfig` 可以对应到这里的 P0-P3 分级和 focus area

### 4.2 Two-Pass Review Pipeline

```
Pass 1: Candidate Generation
    ├── Step 0: Understand PR intent
    ├── Step 1: Triage and group modified files
    └── Step 2: Review each file cluster

Pass 2: Validation
    ├── Verify candidates with grep/read
    ├── Assess confidence
    └── Finalize findings
```

**对 KimiZ 的价值**：
- 如果 KimiZ 的 `code_review` skill 要调用 LLM，可以明确要求 LLM 分两阶段思考
- 第一阶段：广泛扫描潜在问题
- 第二阶段：逐一验证、过滤低置信度项
- 这和 T-102（编译错误反馈循环）的"生成→验证→修复"模式是同一类方法论

---

## 5. 与 KimiZ 的对比

| 维度 | Factory Plugins | KimiZ (目标) |
|------|-----------------|--------------|
| **Skill 形态** | Prompt (SKILL.md) | 编译型 Zig 代码 |
| **执行方式** | 运行时注入 system prompt | 本地函数调用 |
| **扩展方式** | 写 markdown | 写 Zig + 编译 |
| **验证方式** | 人工评审 PR | 编译器 + 测试 |
| **市场形态** | GitHub 仓库 + CLI 市场 | GitHub 仓库 + AutoRegistry |
| **元技能** | `skill-creation` (写 markdown) | `auto-skill-generation` (写 Zig) |
| **方法论沉淀** | Two-pass pipeline, Shared Methodology | Comptime DSL, Compilation Feedback Loop |

---

## 6. 值得 KimiZ 直接借鉴的 5 个设计

### 6.1 Skill 文档格式：YAML frontmatter + Markdown body

即使 KimiZ 的 skill 是 `.zig` 文件，也应该有一个并行的 `SKILL.md` 文档：

```
src/skills/auto/my-skill/
├── my_skill.zig       # 编译型实现
└── SKILL.md           # 文档 + prompt 模板
```

`SKILL.md` 的 YAML frontmatter 可以包含：
```yaml
---
name: my-skill
version: 1.0.0
description: |
  What this skill does.
  Use when:
  - Condition A
  - Condition B
author: kimiz-auto-generated
compile_target: my_skill.zig
---
```

### 6.2 元技能（Meta-Skill）设计

Factory 的 `skill-creation` 验证了：让 agent 学会"如何创建 skill"是自我进化的起点。

KimiZ 应该设计一个编译型元技能：
```zig
// auto-skill-generation.zig
pub const SKILL_ID = "auto-skill-generation";
pub const SKILL_NAME = "Auto Skill Generation";
pub const SKILL_DESCRIPTION = "Generate Zig skill source code from natural language description, compile it, and register to AutoRegistry";
```

这个 skill 的 execute 函数会：
1. 调用 LLM 生成 Zig 代码
2. 写入 `src/skills/auto/{name}/`
3. 触发 `zig build test`
4. 编译通过 → 注册到 AutoRegistry
5. 编译失败 → 反馈错误给 LLM 修复

### 6.3 Two-Pass Pipeline 方法论

所有需要 LLM 生成的 KimiZ skill，都可以要求两阶段思考：

```
Pass 1: 候选生成（发散）
Pass 2: 验证筛选（收敛）
```

这适用于：
- code review（发现→验证）
- auto skill generation（生成→编译验证）
- refactoring（方案→测试验证）

### 6.4 插件分类命名

Factory 的插件命名很有规律：
- `core` — 基础必装
- `security-engineer` — 垂直角色
- `droid-evolved` — 元能力和创造力
- `autoresearch` — 自主实验

KimiZ 未来的 skill 市场也可以按角色/领域组织：
- `kimiz-core` — builtin skills
- `kimiz-security` — 安全审查 skill 集合
- `kimiz-evolved` — auto-generated skills
- `kimiz-subagent` — 子代理编排 skills

### 6.5 Shared Methodology 注释块

Factory 用 XML/HTML 注释标记共享方法论块：
```markdown
<!-- BEGIN_SHARED_METHODOLOGY -->
...
<!-- END_SHARED_METHODOLOGY -->
```

KimiZ 可以在 `SKILL.md` 或 prompt 模板中使用类似设计，方便 LLM 提取和复用。

---

## 7. 一个关键差异：Factory 不会走到编译型

Factory 的全部生态都建立在 **SKILL.md = prompt** 的假设上。

这意味着：
- 他们的 `skill-creation` 元技能永远只能生成 markdown
- 他们的 `security-review` 永远只能调用 LLM 做分析
- 他们的 `autoresearch` 只能在 prompt 层面做实验

这不是缺陷，而是**架构选择**。对于 Factory 的目标用户（需要快速定制 agent 行为的普通开发者），prompt-based 是正确的。

但对于 KimiZ 的目标（Hardness Engineer，自我进化的工程代理），**编译型 skill 是必须跨越的门槛**。

---

## 8. 结论

### Factory Plugins 证明了什么
1. **Skill 市场是必要的**：用户需要发现、安装、管理技能的标准化方式
2. **元技能是自我进化的起点**：`skill-creation` 是 Factory 生态中最有远见的设计
3. **方法论比 prompt 更重要**：Two-pass pipeline、Shared Methodology 是可迁移的智力资产
4. **YAML frontmatter + Markdown 是 skill 文档的最佳实践**

### KimiZ 应该做什么
1. **建立 `SKILL.md` 文档标准**：即使 skill 是 `.zig` 编译型，也需要并行的文档
2. **设计编译型元技能 `auto-skill-generation`**：参考 Factory 的 `skill-creation`，但输出 Zig 代码
3. **引入 Two-Pass Pipeline 方法论**：应用到 code review、auto skill generation、refactoring
4. **规划 skill 分类体系**：core / security / evolved / subagent
5. **绝不退回到 Prompt-based**：借鉴组织形式，但坚持编译型路线

---

## 9. 关联任务

- **T-100**: auto skill generation pipeline ← 直接受 Factory `skill-creation` 启发
- **T-101**: AutoRegistry ← 对应 Factory 的 plugin marketplace + install 机制
- **T-103**: comptime Skill DSL ← 给编译型 skill 提供类似 YAML frontmatter 的结构化声明
- **T-106**: flags.zig ← `droid plugin install` 的 CLI 体验标杆
- **T-121**: global context injection ← Factory 的 `SKILL.md` 注入机制是 prompt-based 版本

---

## 10. 参考

- [Factory Plugins GitHub](https://github.com/Factory-AI/factory-plugins)
- [Factory Droid Review GitHub Action](https://github.com/Factory-AI/droid-code-review)
- [KimiZ 自我进化战略](ZIG-LLM-SELF-EVOLUTION-STRATEGY.md)
