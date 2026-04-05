# KimiZ vs Kimi CLI (MoonshotAI) 差距分析与追赶规划

**文档版本**: 1.0  
**日期**: 2026-04-05  
**状态**: 草案  

---

## 1. 执行摘要

MoonshotAI 官方的 `kimi-cli` 是一个功能极为完善的 Python 编码代理，拥有 **Web UI、ACP 协议集成、MCP 支持、Shell 模式、Plan 模式、完善的会话管理** 等企业级特性。相比之下，**KimiZ 目前处于 v0.4.0 MVP 阶段**，核心循环和工具链已稳定，但在**用户体验、生态集成、会话管理**方面存在显著差距。

本文档系统梳理了两者的功能差距，并制定了分阶段的追赶路线图。

**关键结论**：
- **KimiZ 的底层优势**：Zig 原生编译，启动快 10-50 倍（26ms vs 1-3s），二进制仅 6MB
- **KimiZ 的核心差距**：没有 Web UI、没有会话持久化、没有 Shell 模式、没有 MCP、没有 IDE 集成
- **追赶策略**：先补齐**会话管理 + Shell 模式 + Slash 命令体系**（3-4 周），再逐步推进 **TUI/Web UI + MCP + ACP**（8-12 周）

---

## 2. 功能对比总览

| 维度 | Kimi CLI (官方) | KimiZ (当前) | 差距等级 |
|------|----------------|--------------|----------|
| **核心代理循环** | ✅ 稳定 | ✅ 稳定 | 🟢 无差距 |
| **文件工具** | ✅ Read/Edit/Write/Grep/Bash | ✅ 6 个核心工具 | 🟢 无差距 |
| **启动速度** | ⚠️ 1-3s (Python) | ✅ 26ms (Zig) | 🟢 KimiZ 领先 |
| **二进制大小** | ⚠️ Python 依赖 | ✅ 6MB 单文件 | 🟢 KimiZ 领先 |
| **多 Provider** | ✅ Kimi/OpenAI/Anthropic | ✅ 5 个 Provider | 🟢 无差距 |
| **Web UI** | ✅ `kimi web` | ❌ 无 | 🔴 核心差距 |
| **ACP/IDE 集成** | ✅ `kimi acp` + VSCode + Zed + JetBrains | ❌ 无 | 🔴 核心差距 |
| **MCP 支持** | ✅ `kimi mcp` (HTTP/stdio/OAuth) | ❌ PRD 明确不做 | 🔴 核心差距 |
| **Shell 模式** | ✅ Ctrl-X 切换 | ❌ 无 | 🔴 核心差距 |
| **会话管理** | ✅ Resume/Continue/Export/Import | ❌ 仅单会话 | 🔴 核心差距 |
| **Plan 模式** | ✅ Shift-Tab 切换 | ❌ 无 | 🟡 中等差距 |
| **YOLO 模式** | ✅ 完整的审批记忆 | ⚠️ 代码有但不完整 | 🟡 中等差距 |
| **Slash 命令** | ✅ 20+ 个内置命令 | ❌ 极少 | 🟡 中等差距 |
| **Zsh 集成** | ✅ 官方插件 | ❌ 无 | 🟡 中等差距 |
| **剪贴板/图片粘贴** | ✅ 支持 | ❌ 无 | 🟡 中等差距 |
| **Thinking 模式** | ✅ 可切换 | ❌ 无 | 🟡 中等差距 |
| **后台任务** | ✅ 支持 | ❌ 无 | 🟡 中等差距 |
| **@ 路径补全** | ✅ 支持 | ❌ 无 | 🟡 中等差距 |
| **多行输入** | ✅ 支持 | ❌ 无 | 🟡 中等差距 |
| **Agent/Subagent** | ✅ Agent 工具 | ⚠️ 代码有但未启用 | 🟡 中等差距 |
| **Skill 体系** | ⚠️ 有但非核心 | ✅ Skill-Centric 架构 | 🟢 KimiZ 领先 |

---

## 3. 差距详解

### 3.1 核心差距（🔴 必须尽快补齐）

#### GAP-1: 没有 Web UI (`kimi web`)
**kimi-cli**: 提供完整的浏览器图形界面，支持会话管理、文件引用、代码高亮、流式输出。
**KimiZ**: 完全没有 Web UI，只有 CLI REPL。
**影响**: 无法吸引习惯 GUI 的用户，也无法在浏览器中查看长代码和对话历史。
**建议**: 使用 Zig 的 HTTP server + 轻量级前端（如 Preact 或纯 HTML/JS）实现一个嵌入式 Web UI。

#### GAP-2: 没有 ACP/IDE 集成 (`kimi acp`)
**kimi-cli**: 支持 Agent Client Protocol，可与 VS Code、Zed、JetBrains 等 IDE 无缝集成。
**KimiZ**: 没有 ACP 服务器模式，也没有官方 IDE 插件。
**影响**: 无法进入 IDE 生态，限制了专业开发者的使用场景。
**建议**: 先实现 ACP 服务器（stdio/HTTP），再逐步开发 VS Code 插件。

#### GAP-3: 没有 MCP 支持 (`kimi mcp`)
**kimi-cli**: 完整的 MCP 客户端，支持 `add/list/remove/auth`，HTTP 和 stdio transport，甚至 OAuth。
**KimiZ**: PRD 明确不做 MCP，认为会导致 Context 爆炸。
**影响**: 无法接入飞速发展的 MCP 生态（如 Context7、Browser Tools、Database Tools 等），功能扩展性受限。
**建议**: **重新审视 PRD 决策**。可以做一个"精简版 MCP 支持"：限制同时加载的 MCP server 数量，对工具结果做 Token 压缩，避免 Context 爆炸。

#### GAP-4: 没有 Shell 模式 (Ctrl-X)
**kimi-cli**: 按 Ctrl-X 可在 Agent 模式和 Shell 模式间切换，Shell 模式下直接执行命令。
**KimiZ**: 只有 REPL，执行 shell 命令必须通过 AI agent 调用 bash tool，效率低。
**影响**: 用户无法快速执行命令，交互体验割裂。
**建议**: 在 REPL 中增加 Shell 模式，检测 `Ctrl-X` 或前缀 `$` 来直接执行 shell 命令。

#### GAP-5: 没有会话持久化 (`--continue`, `--session`, `/resume`)
**kimi-cli**: 完整的会话生命周期：创建、恢复、导出、导入、标题管理。
**KimiZ**: 仅支持单会话，进程退出即丢失。
**影响**: 无法延续多天的工作，无法管理多个任务上下文。
**建议**: 用 SQLite 持久化会话历史，实现 `--continue`, `--session`, `/sessions`, `/resume`, `/title`。

---

### 3.2 中等差距（🟡 重要但可排期）

#### GAP-6: 没有 Plan 模式 (Shift-Tab)
**kimi-cli**: Plan 模式下 AI 只能使用只读工具探索代码库，生成规划文件供用户审批。
**KimiZ**: 没有专门的只读规划模式，AI 会直接动手改代码。
**建议**: 在 Agent loop 中增加 Plan mode 状态，限制可用工具为 ReadFile/Grep/Glob，并输出 Markdown 规划文件。

#### GAP-7: YOLO 模式不完整
**kimi-cli**: 完整的审批体系，支持"允许本次/允许本会话/始终允许"，且会随会话持久化。
**KimiZ**: `src/harness/tool_approval.zig` 有代码但可能未完全集成到主循环。
**建议**: 完善 tool_approval 模块，实现三级审批策略（Ask / Session / Always）。

#### GAP-8: Slash 命令体系薄弱
**kimi-cli**: 20+ 个命令（`/help`, `/new`, `/sessions`, `/export`, `/import`, `/clear`, `/compact`, `/plan`, `/yolo`, `/model`, `/editor`, `/theme`, `/skill:<name>`, `/flow:<name>`, `/add-dir` 等）。
**KimiZ**: 几乎没有内置 Slash 命令。
**建议**: 建立统一的 Slash command parser，按优先级逐个实现。

#### GAP-9: 没有 Zsh 集成
**kimi-cli**: 官方 `zsh-kimi-cli` 插件，按 Ctrl-X 即可在 Zsh 和 Kimi 间切换。
**KimiZ**: 没有官方 Shell 插件。
**建议**: 开发 `zsh-kimiz` 插件，监听 Ctrl-X 键位，调用 `kimiz`。

#### GAP-10: 没有剪贴板/图片/媒体粘贴
**kimi-cli**: 支持从剪贴板粘贴文本、图片、截图。
**KimiZ**: 不支持多模态输入（虽然 PRD 有规划，但代码中未实现）。
**建议**: 先实现剪贴板文本读取，再逐步支持图片（需要多模态 Provider 支持）。

#### GAP-11: 没有 Thinking 模式切换
**kimi-cli**: 可以开关模型的 thinking/reasoning 模式。
**KimiZ**: 没有显式控制 thinking 的命令或配置。
**建议**: 增加 `--thinking` 参数或 `/thinking` 命令。

#### GAP-12: 没有后台任务
**kimi-cli**: 支持将任务放到后台执行，前台继续交互。
**KimiZ**: Agent loop 是阻塞的，无法并发。
**建议**: 用 Zig 的异步运行时（libxev）实现后台任务队列。

#### GAP-13: 没有 @ 路径补全
**kimi-cli**: 输入 `@` 后自动补全项目文件路径。
**KimiZ**: 没有路径补全机制。
**建议**: 在 REPL 输入层集成 fuzzy 路径补全（可复用 fff 的索引）。

#### GAP-14: 没有多行输入
**kimi-cli**: 支持 Shift-Enter 或编辑器模式输入多行文本。
**KimiZ**: REPL 似乎是单行输入。
**建议**: 支持 Shift-Enter 换行，或集成外部编辑器（如 `vim` / `$EDITOR`）。

#### GAP-15: Subagent 未启用
**kimi-cli**: 内置 Agent 工具，可以创建子代理处理子任务。
**KimiZ**: `src/agent/subagent.zig` 有代码但可能未在主循环中启用。
**建议**: 完成 Subagent 集成，使其成为可用工具。

---

### 3.3 KimiZ 的领先优势（🟢 差异化卖点）

虽然存在不少差距，但 KimiZ 在以下方面是明确领先的，应在追赶过程中继续保持：

1. **极致性能**：26ms 启动 vs kimi-cli 的 1-3s，6MB 单文件 vs Python 环境依赖
2. **Skill-Centric 架构**：kimi-cli 的 Skill 只是附加功能，而 KimiZ 从设计之初就是以 Skill 为核心
3. **原生编译**：Zig 的零依赖、交叉编译能力，适合分发到各种环境
4. **Extension/WASM 系统**：虽然还不成熟，但这是 kimi-cli 完全没有的扩展机制

---

## 4. 分阶段追赶路线图

### Phase 1: 用户体验基础（4 周）
**目标**：补齐最影响日常使用的核心差距。

| 周 | 任务 | 产出 |
|----|------|------|
| 1 | 实现会话持久化（SQLite） | `--continue`, `--session`, `/sessions`, `/resume`, `/title` |
| 1 | 实现 `/new`, `/clear`, `/compact` | Slash 命令基础框架 |
| 2 | 实现 Shell 模式 | `Ctrl-X` 或 `$` 前缀直接执行 shell |
| 2 | 完善 YOLO/审批模式 | `tool_approval` 完整集成到主循环 |
| 3 | 实现 Plan 模式 | `Shift-Tab` 切换，只读工具限制 |
| 3 | 扩展 Slash 命令 | `/plan`, `/yolo`, `/export`, `/import`, `/help` |
| 4 | 多行输入 + 编辑器集成 | `Shift-Enter`, `/editor` 调用 `$EDITOR` |
| 4 | @ 路径补全 | 基于 fff 的文件路径补全 |

**Phase 1 验收标准**：
- [ ] 可以 `kimiz --continue` 恢复昨天的会话
- [ ] 按 `Ctrl-X` 可以直接执行 `git status`
- [ ] 输入 `/plan` 进入只读规划模式
- [ ] 可以 `/export` 导出会话为 Markdown
- [ ] 输入 `@src/` 有文件路径补全

### Phase 2: 生态集成（4-6 周）
**目标**：接入外部生态，扩展使用场景。

| 周 | 任务 | 产出 |
|----|------|------|
| 5-6 | MCP 客户端（精简版） | `kimiz mcp add/list/remove`，限制 3 个 server |
| 5-6 | 集成 CodeDB + FFF | 结构化代码查询、快速文件搜索 |
| 7-8 | ACP 服务器模式 | `kimiz acp`，支持 stdio transport |
| 7-8 | VS Code Extension (基础版) | 在 VS Code agent panel 中使用 KimiZ |
| 9-10 | Zsh 插件 | `zsh-kimiz`，Ctrl-X 快速切换 |

**Phase 2 验收标准**：
- [ ] 可以加载 Context7 MCP server 查询文档
- [ ] VS Code 的 agent panel 能连接到 KimiZ
- [ ] Zsh 中按 Ctrl-X 进入 KimiZ

### Phase 3: 高级体验（6-8 周）
**目标**：Web UI、后台任务、Thinking 模式等企业级特性。

| 周 | 任务 | 产出 |
|----|------|------|
| 11-12 | Web UI 原型 | `kimiz web`，基础聊天界面 |
| 13-14 | Web UI 完整版 | 会话管理、代码高亮、文件引用 |
| 15-16 | 后台任务 + Steer | 任务后台执行，运行中可发消息调整 |
| 17-18 | 剪贴板/图片粘贴 + 多模态 | 截图分析、图片输入 |

**Phase 3 验收标准**：
- [ ] `kimiz web` 能在浏览器中完整替代 CLI REPL
- [ ] 可以后台执行 `zig build`，完成后语音/文字提醒
- [ ] 可以粘贴截图并让 AI 分析

---

## 5. 任务创建建议

根据本分析，建议在 KimiZ 任务系统中创建以下任务（按优先级排序）：

### P0（立即开始）
1. **T-xxx**: 实现会话持久化（SQLite）— `--continue`, `--session`, `/resume`
2. **T-xxx**: 实现 Shell 模式（Ctrl-X / `$` 前缀）
3. **T-xxx**: 完善 YOLO / 工具审批模式
4. **T-xxx**: 建立 Slash 命令框架，实现 `/new`, `/clear`, `/compact`, `/help`

### P1（Phase 1 后续）
5. **T-xxx**: 实现 Plan 模式（Shift-Tab 切换）
6. **T-xxx**: 实现 `/export`, `/import` 会话导出导入
7. **T-xxx**: 实现多行输入和 `/editor` 集成
8. **T-xxx**: 实现 `@` 文件路径补全
9. **T-xxx**: 启用 Subagent 工具

### P2（Phase 2）
10. **T-xxx**: 设计并实现精简版 MCP 客户端（重新评估 PRD）
11. **T-xxx**: 集成 CodeDB 代码索引（T-085 已创建）
12. **T-xxx**: 集成 FFF fuzzy 文件搜索
13. **T-xxx**: 实现 ACP 服务器模式 (`kimiz acp`)
14. **T-xxx**: 开发 VS Code Extension（基础版）
15. **T-xxx**: 开发 Zsh 插件 (`zsh-kimiz`)

### P3（Phase 3）
16. **T-xxx**: 设计并实现 Web UI (`kimiz web`)
17. **T-xxx**: 实现后台任务和 Steer 机制
18. **T-xxx**: 实现剪贴板/图片粘贴和多模态输入
19. **T-xxx**: 实现 Thinking 模式切换

---

## 6. 关键决策点

### 决策 1: 是否要支持 MCP？
**当前 PRD**: 明确不做 MCP，认为会导致 Context 爆炸。  
**建议**: **重新审视**。MCP 生态已成气候，完全不支持会严重限制扩展性。可以考虑：
- 限制同时加载的 MCP server 数量（如最多 3 个）
- 对 MCP 工具结果自动做 RTK 式压缩
- 仅支持 stdio transport（最简单、最安全）

### 决策 2: Web UI 的技术栈
**选项 A**: Zig HTTP server + 纯 HTML/JS（无构建步骤，最简单）  
**选项 B**: Zig HTTP server + Preact/Vue（更好的交互体验）  
**选项 C**: 使用现有 TUI 框架（libvaxis）做图形界面，不做 Web UI  
**建议**: 选项 A 或 B。Web UI 的价值在于可以在浏览器中打开，支持图片显示，且可以远程访问。

### 决策 3: ACP 协议 vs 其他 IDE 集成方式
**建议**: 优先实现 ACP。ACP 是新兴标准，已被 Zed 和 JetBrains 支持，且 VS Code 也可以通过插件支持。实现一次，多处受益。

---

## 7. 结论

KimiZ 与 MoonshotAI 官方的 kimi-cli 相比，**底层性能和核心循环不落下风，甚至在启动速度和二进制体积上大幅领先**。但差距集中在**用户体验层和生态集成层**：会话管理、Shell 模式、Slash 命令、MCP、ACP、Web UI 等。

**追赶的关键不是复制 kimi-cli 的所有功能，而是**：
1. **补齐核心体验短板**（会话 + Shell + Plan + Slash）
2. **接入外部生态**（MCP + ACP + CodeDB + FFF）
3. **保持性能优势**（Zig 原生编译始终是差异化卖点）

如果按本路线图的 Phase 1 执行，KimiZ 将在 4 周内从"能用"变成"好用"；按完整路线图执行，将在 16-18 周内具备与 kimi-cli 正面竞争的能力。

---

## 附录 A: 参考链接

- Kimi CLI 官方文档: https://moonshotai.github.io/kimi-cli/en/
- Kimi CLI GitHub: https://github.com/MoonshotAI/kimi-cli
- Agent Client Protocol: https://agentclientprotocol.com/
- KimiZ PRD: `./01-prd.md`
- KimiZ MVP Roadmap: `../tasks/MVP-ROADMAP.md`
