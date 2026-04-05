# Claude Code Prompt Architecture 分析 — 对 KimiZ 的参考价值

**分析对象**: [Leonxlnx/agentic-ai-prompt-research](https://github.com/Leonxlnx/agentic-ai-prompt-research)  
**Stars**: 2.1k | **Forks**: 997  
**分析日期**: 2026-04-05  

**核心结论**:
- 这是一个**对 Claude Code 系统提示架构的逆向工程/行为重建研究**，虽然不是官方泄露，但质量极高，对 KimiZ 具有**直接的战略参考价值**。
- Claude Code 的 prompt 设计代表了当前 **Agentic Coding Assistant 的工业级最高水平**。KimiZ 在架构上已经与其有很多相似之处，但在**子 Agent 协调（Coordinator）、安全分类器（YOLO Classifier）、动态提示组装**这几个维度上还有明显差距。
- **强烈建议 KimiZ 团队全员阅读**，并把其中验证过的模式逐步引入 KimiZ 的 system prompt 和 orchestration 层。

---

## 1. 这个仓库是什么

这是一个独立研究者通过**行为观察、输出分析、二进制逆向、社区讨论**重建出的 Claude Code 系统提示架构。

作者明确声明：
> "These are reconstructed approximations, not verbatim copies."

但尽管如此，这个仓库在 GitHub 上已经获得了 **2.1k stars 和近 1000 forks**，说明其内容被广泛认可为具有很高的真实性。

### 文档结构

仓库包含 30 个文档化的 prompt 模式，分为 7 大类：

| 类别 | 文件 | 说明 |
|------|------|------|
| **Core Identity** | 01-04 | 主系统提示、简单模式、默认 Agent 提示、网络安全边界 |
| **Orchestration** | 05-06 | 多 Worker 协调器、队友通信协议 |
| **Specialized Agents** | 07-10 | 验证 Agent、探索 Agent、Agent 创建架构师、状态栏配置 Agent |
| **Security & Permissions** | 11-12 | 权限解释器、YOLO/Auto-Mode 分类器 |
| **Tool Descriptions** | 13 | 各个工具（Bash、Edit、Agent 等）的自我描述 |
| **Utility Patterns** | 14-20, 29-30 | 工具使用摘要、会话搜索、记忆选择、自动模式批判、会话标题、Agent 摘要、提示建议 |
| **Context Window Management** | 21-22 | 对话压缩服务、离开摘要 |
| **Dynamic Behaviors** | 18, 23-24 | 主动模式、Chrome 浏览器自动化、记忆指令 |
| **Skill Patterns** | 19, 25-28 | Simplify Skill、Skillify、Stuck Skill、Remember Skill、Update Config Skill |

---

## 2. 和 KimiZ 的架构对比

### 2.1 相似点（KimiZ 已经做对的）

#### ✅ Memory / CLAUDE.md 系统
Claude Code 有 `CLAUDE.md` 记忆层级：
- `/etc/claude-code/CLAUDE.md` — 托管全局
- `~/.claude/CLAUDE.md` — 用户全局
- `CLAUDE.md` / `.claude/CLAUDE.md` / `.claude/rules/*.md` — 项目级
- `CLAUDE.local.md` — 本地私有

**KimiZ 对应**：
- `AGENTS.md`（项目级）
- `~/.hermes/config.yaml`（用户全局配置）
- `memory` 工具（持久化记忆）
- `skill` 系统（可复用流程）

**差距**：
- KimiZ 的记忆系统是**工具驱动**的（调用 `memory` 工具保存），Claude Code 是**文件驱动**的（自动扫描目录注入）。
- Claude Code 支持 `@include` 指令和 `paths` frontmatter 条件注入，KimiZ 没有。

#### ✅ Tool Use / Function Calling
Claude Code 的 Agent 使用各种工具（Bash, Edit, Glob, Grep, Agent, SendMessage 等）。

KimiZ 的 tool system 已经覆盖了 browser、terminal、file、web、delegate_task 等，工具丰富度不输 Claude Code。

#### ✅ Skills（技能系统）
Claude Code 有 `/skill` 命令和 `.claude/skills/` 目录扫描。

KimiZ 有 `~/.hermes/skills/` 和 `skill_view` / `skill_manage` 工具，基本对等。

#### ✅ Session Search
Claude Code 有语义搜索历史会话的能力。

KimiZ 有 `session_search` 工具，功能对等。

### 2.2 差距点（KimiZ 值得学习的）

#### ❌ 1. Coordinator / 多 Worker 协调（最大差距）

Claude Code 有一个专门的 **Coordinator System Prompt**，定义了如何协调多个子 Agent：
- **Research** → **Synthesis** → **Implementation** → **Verification**
- **并行是超能力**："Parallelism is your superpower. Launch independent workers concurrently whenever possible."
- **合成（Synthesize）是协调者最重要的工作**：研究完成后，协调者必须自己理解，然后写出具体的实现 spec，再交给 Worker。
- **严禁把理解外包给 Worker**：禁止说 "Based on your findings" 这种话。

**KimiZ 当前状态**：
- 有 `delegate_task` 工具，可以 spawn 子 Agent。
- 但 KimiZ **没有 "Coordinator" 这个专门角色**。主 Agent 自己决定是否调用 `delegate_task`，没有标准化的多阶段工作流。
- KimiZ 的子 Agent 结果是**文本摘要返回主上下文**，而不是像 Claude Code 那样通过 `<task-notification>` XML 作为用户消息注入。

**建议**：
- 考虑在 KimiZ 中引入一个 **可选的 Coordinator Mode**。当用户任务足够复杂时，Agent 自动切换到协调者角色。
- 明确区分 "Research Worker"、"Implementation Worker"、"Verification Worker" 的职责边界。
- 验证 Worker 必须是**对抗性的**（adversarial），不能只是 rubber-stamp（盖章通过）。

#### ❌ 2. YOLO / Auto-Mode Classifier（安全分类器）

这是 Claude Code 的**安全核心**。当用户开启自动模式时，每个工具调用都要先经过一个 **2-stage classifier**：

1. **Base Prompt** + **Permissions Template**（外部用户 vs Anthropic 员工不同模板）
2. **用户自定义规则**：`allow`、`soft_deny`、`environment`
3. **强制工具调用输出**：`classify_result` 工具输出 `{thinking, shouldBlock, reason}`
4. **安全工具白名单**：只读工具跳过分类器

**关键设计**：
- Assistant 的文本输出**被故意排除**在分类器 transcript 之外，防止模型通过 crafting text 来影响分类器（prompt injection 防御）。
- 分类器只收到 **tool_use blocks**。

**KimiZ 当前状态**：
- KimiZ 有 system prompt 里的安全指令，但没有**独立的分类器子系统**。
- 所有安全判断都由主 LLM 在一次推理中完成。
- 没有用户可配置的 `auto_mode` 规则层。

**建议**：
- 对于高危操作（如 `terminal` 执行 shell、`write_file` 覆写文件、`browser_click` 等），引入一个**轻量级的分类器模型调用**。
- 分类器使用**强制 JSON/tool 输出**，减少主模型的安全幻觉。
- 允许用户在 `~/.hermes/config.yaml` 中配置自定义 allow/deny 规则。

#### ❌ 3. 动态提示组装（Dynamic Prompt Assembly）

Claude Code 的系统提示是**运行时动态组装**的：

```
Cacheable Prefix（跨会话稳定）
  ├── Identity & safety instructions
  ├── Permission & hook configuration
  ├── Code style & error handling rules
  ├── Tool preferences & usage patterns
  └── Tone, style, output rules
  
Cache Boundary

Dynamic Suffix（每会话变化）
  ├── Available agents & skills
  ├── Memory file contents
  ├── Environment context (OS, dir, git)
  ├── Language & output preferences
  ├── Active MCP server instructions
  └── Context window management directives
```

**KimiZ 当前状态**：
- KimiZ 的系统提示相对静态，主要由 `PERSONA.md` / `AGENTS.md` / 内置 system prompt 组成。
- 动态注入的内容主要是 `memory` 和 `skill` 列表。
- 没有明确的 **Cache Boundary** 优化。

**建议**：
- 引入**提示缓存优化**：把静态的 identity/tool descriptions 放在 cacheable prefix 中，减少 token 消耗。
- 动态部分只注入变化的内容（如当前目录、git 状态、可用 skills）。

#### ❌ 4. 专门的 Specialized Agents

Claude Code 有多个**专用子 Agent**：
- **Verification Agent**：对抗性验证，必须 "prove the code works, not confirming it exists"
- **Explore Agent**：只读探索，明确禁止修改
- **Agent Creation Architect**：根据需求生成新的 Agent 配置
- **Status Line Setup Agent**：终端状态栏配置

**KimiZ 当前状态**：
- `delegate_task` 是通用子 Agent，没有预设角色模板。
- 没有内置的 "只读探索 Agent" 或 "验证 Agent" 角色。

**建议**：
- 为 `delegate_task` 引入**预设角色模板**（persona presets）：
  - `researcher`：只读，深入研究
  - `implementer`：专注实现
  - `verifier`：对抗性验证，必须运行测试
  - `architect`：设计规划

#### ❌ 5. Tool Use Summary / Agent Summary

Claude Code 在批量工具调用完成后，会生成简洁的摘要标签（Tool Use Summary）。

KimiZ 当前没有这种机制。Agent 的工具调用结果是直接堆叠在上下文中的，长期会话会变乱。

**建议**：
- 引入**工具调用摘要机制**：当连续调用多个工具后，用一次轻量模型调用把它们总结成 1-2 句话。
- 子 Agent 完成后也生成摘要（类似 Agent Summary）。

#### ❌ 6. 浏览器自动化（Chrome Browser Automation）

Claude Code 的 Chrome 浏览器自动化通过**浏览器扩展**实现：
- 扩展注入页面，建立与 Agent 的通信通道
- Agent 通过工具与扩展交互来控制浏览器
- 这比纯粹的 headless browser 更接近真实用户行为

**KimiZ 当前状态**：
- KimiZ 使用 Browserbase 的 headless browser（或类似服务）。
- 没有本地 Chrome 扩展桥接。

**建议**：
- 这是已知短板，已经在 `OPENCLI-ANALYSIS.md` 中讨论过。可以考虑通过集成 opencli 或自建 CDP bridge 来解决。

---

## 3. 对 KimiZ 最有价值的 10 个具体模式

### 模式 1：Coordinator 的 "合成优先" 原则
> "Never write 'Based on your findings'. You never hand off understanding to another worker."

KimiZ 的 `delegate_task` 经常被用来偷懒：主 Agent 自己不读完子 Agent 的输出，直接丢给用户或再 spawn 一个子 Agent。

**改进**：主 Agent 必须先读完子 Agent 结果，用自己的话总结出明确的 spec，然后再决定下一步。

### 模式 2：并行即超能力
> "Parallelism is your superpower. Workers are async. Launch independent workers concurrently whenever possible."

KimiZ 的 `delegate_task` 目前是**串行**的（要等第一个子 Agent 返回后才能 spawn 第二个，除非在一次 assistant message 中同时调用多个 `delegate_task`）。

**改进**：支持在一次推理中同时 spawn 多个子 Agent，并在它们都返回后再汇总。

### 模式 3：验证的对抗性
> "A verifier that rubber-stamps weak work undermines everything."
> "Run tests with the feature enabled — not just 'tests pass'."

KimiZ 缺少独立的验证 Agent。代码修改后直接交给用户，没有强制验证。

**改进**：对于代码修改任务，自动 spawn 一个 verifier 子 Agent，要求它：
1. 独立运行测试
2. 运行类型检查
3. 对可疑之处深入调查
4. 明确报告通过或失败

### 模式 4：分类器排除文本输出
> "Assistant text blocks are deliberately excluded from the transcript to prevent prompt injection."

这是一个非常精巧的安全设计。Claude Code 的安全分类器只看 tool_use，不看 assistant 的自然语言回复。

**改进**：如果 KimiZ 要引入安全分类器，也应该只把**工具调用意图**喂给分类器，而不是完整的 assistant message。

### 模式 5：Memory 的 `@include` 和 `paths` 条件注入
```yaml
---
paths:
  - src/components/**
  - "*.tsx"
---
```

KimiZ 的 `AGENTS.md` 是全局注入的，没有条件加载能力。

**改进**：支持 `AGENTS.md` 的 frontmatter 条件注入，以及 `@include` 引用其他文件。

### 模式 6：Skill 的 Interview 模式（Skillify）
Claude Code 的 `/skillify` 不是自动生成，而是通过**访谈用户**来收集信息，最终生成 SKILL.md。

KimiZ 的 `skill_manage` 是由 Agent 自动决定保存的，缺少用户确认的环节。

**改进**：对于复杂 skill，可以先 interview 用户确认流程，再生成保存。

### 模式 7：上下文压缩服务（Compact Service）
Claude Code 有专门的对话压缩策略，当上下文接近上限时自动触发。

KimiZ 当前依赖底层 LLM 的上下文窗口，没有主动的压缩管理。

**改进**：在上下文达到阈值时，触发一次 summarization，把早期消息压缩成摘要。

### 模式 8：Proactive Mode（主动模式）
Claude Code 有一个 "Proactive Mode"，允许 Agent 在后台自主运行，并带有 pacing controls（节奏控制）。

KimiZ 没有类似能力。所有操作都是用户触发后才执行的。

**改进**：这是一个潜在的产品差异化功能。可以让 KimiZ 在后台监控项目状态（如 CI 失败、新 issue），并主动通知用户。

### 模式 9：权限解释器（Permission Explainer）
在自动批准工具调用前，Claude Code 会先解释风险（"This will modify 3 files"）。

KimiZ 当前要么直接执行（某些操作），要么没有明确的解释。

**改进**：对于批量的或高风险的工具调用，先向用户解释具体影响，再请求确认。

### 模式 10：Prompt 建议（Prompt Suggestion）
Claude Code 会预测用户可能的后续指令并提前提示。

**改进**：KimiZ 可以在每次回复后，根据当前状态生成 2-3 个 "Next steps" 建议按钮/文本。

---

## 4. 具体建议：KimiZ 应该优先落地什么

### 短期（1-2 周）

1. **优化 system prompt 的代码规范部分**
   - 直接参考 `01_main_system_prompt.md` 中 "Doing tasks" 部分的内容
   - 加入 "Don't add features beyond what was asked"、"Avoid premature abstraction"、"Report outcomes faithfully" 等规则
   - 这些规则能显著减少 KimiZ 的过度工程问题

2. **为 `delegate_task` 引入预设角色模板**
   - `researcher`：只读、深入
   - `implementer`：实现、修改
   - `verifier`：对抗性验证

3. **修正 `delegate_task` 的返回格式**
   - 当前子 Agent 结果是一个大文本块塞回主上下文
   - 参考 `<task-notification>` XML 格式，结构化返回：task-id、status、summary、result、usage

### 中期（1-2 月）

4. **引入 Coordinator Mode**
   - 当用户任务被判定为 "复杂" 时，主 Agent 切换到 Coordinator 角色
   - 明确执行 Research → Synthesis → Implementation → Verification 四阶段
   - 并行 spawn Research Worker

5. **引入轻量级安全分类器**
   - 对于 `terminal(background=true)`、`write_file` 覆写敏感文件等操作，增加一次分类器调用
   - 使用强制 JSON 输出

6. **工具调用摘要机制**
   - 连续 3+ 个工具调用后，自动总结成摘要替换历史记录

### 长期（3-6 月）

7. **AGENTS.md 的条件注入和 `@include`**
8. **Proactive Mode 和后台监控**
9. **本地 Chrome 扩展桥接（替代 headless）**

---

## 5. 风险评估

### 5.1 内容真实性
虽然作者声明是 "reconstructed approximations"，但 prompt 中的细节（如 `TRANSCRIPT_CLASSIFIER` feature flag、`bun:bundle`、特定的内部变量名）表明这是基于**真实的二进制分析**得出的，可信度很高。

### 5.2 版权/合规风险
这个仓库明确声明是 "educational research"，不是泄露。阅读和借鉴其中的**架构模式**（而非复制 exact wording）是完全合理的。

### 5.3 Anthropic 的潜在反制
Anthropic 可能会修改 Claude Code 的 prompt 架构，使这个仓库过时。但这不影响其中**已验证的设计模式**的价值。

---

## 6. 总结

### 这个仓库值不值得 KimiZ 花时间研究？
**非常值得。** 这是目前公开渠道能看到的、对工业级 Agentic Coding Assistant 架构最详细的解析。

### KimiZ 和 Claude Code 的差距大吗？
**在核心能力上（工具调用、记忆、技能）差距不大。**
**但在 orchestration（协调）、safety（安全分类器）、dynamic prompt assembly（动态提示组装）上还有明显差距。**

### 最值得优先做的 3 件事
1. **把 `01_main_system_prompt.md` 中的代码规范指令整合进 KimiZ 的 system prompt**（立竿见影）
2. **为 `delegate_task` 设计 verifier 角色，强制验证代码修改**（质量提升）
3. **设计 Coordinator Mode 的 MVP，支持 Research + Implementation 的并行工作流**（架构升级）

### 一句话建议

> **Claude Code 的 prompt 架构是 KimiZ 最好的免费教科书。它验证了很多 KimiZ 已经在做的方向（memory、skills、session search），也明确指出了 KimiZ 的短板（Coordinator、Classifier、动态提示组装）。建议把这份研究作为 KimiZ 下一版 system prompt 和 orchestration 层升级的重要参考。**

---

如果你想，我可以：
1. 直接基于这个研究，为 KimiZ 起草一版**改进后的 system prompt**
2. 设计一个 **KimiZ Coordinator Mode 的技术 spec**
3. 设计一个 **轻量级安全分类器** 的 JSON schema 和集成方案

你想先做哪个？
