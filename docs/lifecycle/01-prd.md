# PRD — kimiz：高性能 AI Coding Agent

**版本**: 0.3.0  
**日期**: 2026-04-05  
**状态**: 草案  
**参考**: [badlogic/pi-mono](https://github.com/badlogic/pi-mono), [Claude Code](https://github.com/didilili/claude-code-restored), [Harness Engineering](https://zhanghandong.github.io/harness-engineering-from-cc-to-ai-coding/)

---

## 1. 核心认知：Skill 优先架构

### 1.1 为什么 Skill 优先？

现代 Code Agent 的演进路径：

```
CLI 命令 → Skill 抽象 → 智能组合
   ↓           ↓            ↓
  底层      可复用        自动化
  操作      能力单元      工作流
```

**Skill 的核心价值**:
1. **可复用**: 一次定义，多处使用
2. **可组合**: 多个 Skill 组合成复杂工作流
3. **可学习**: Agent 可以学习如何更好地使用 Skill
4. **可扩展**: 用户和第三方可以定义新 Skill

### 1.2 kimiz 的 Skill 架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Skill-Centric Architecture               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                 Skill Registry                       │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ │   │
│  │  │  Built-in│ │  Project │ │  User    │ │ Learned│ │   │
│  │  │  Skills  │ │  Skills  │ │  Skills  │ │ Skills │ │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └────────┘ │   │
│  └─────────────────────────────────────────────────────┘   │
│                           │                                 │
│                           ▼                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Skill Execution Engine                  │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ │   │
│  │  │  Parse   │ │  Plan    │ │  Execute │ │ Verify │ │   │
│  │  │  Intent  │ │  Steps   │ │  Actions │ │ Result │ │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └────────┘ │   │
│  └─────────────────────────────────────────────────────┘   │
│                           │                                 │
│                           ▼                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Tool & API Layer                        │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ │   │
│  │  │  File    │ │  Code    │ │  Search  │ │  LLM   │ │   │
│  │  │  System  │ │  Analysis│ │  & Query │ │  APIs  │ │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └────────┘ │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**CLI 是 Skill 的底层实现**: 用户通过 CLI 调用 Skill，Skill 背后使用 Tools 和 APIs 完成任务。

---

## 2. 项目定位

### 2.1 核心理念

kimiz 是一个**Skill-Centric、高性能、原生编译的 AI Coding Agent**，用 Zig 语言实现。

**设计哲学**:
- **Skill 优先**: 一切功能都是 Skill，CLI 是 Skill 的调用方式
- **性能优先**: 原生编译，毫秒级启动，无运行时依赖
- **可扩展**: 用户可定义自己的 Skill，形成个人工作流
- **智能进化**: Skill 使用数据驱动 Agent 学习优化

### 2.2 与参考项目的区别

| 特性 | kimiz | pi-mono | Claude Code | Kimi Code |
|------|-------|---------|-------------|-----------|
| **架构** | Skill-Centric | Module-based | Tool-based | Tool-based |
| **扩展性** | 用户 Skill | 插件 | 有限 | 有限 |
| **学习** | Skill 使用优化 | 无 | 有限 | 有限 |
| **语言** | Zig | TypeScript | TypeScript | Python |
| **启动速度** | <100ms | 1-3s | 1-2s | 网络依赖 |
| **智能路由** | ✅ | ❌ | ❌ | ❌ |

### 2.3 核心差异化：市面上唯一的自我学习 Code Agent

**现状分析**: 市面上的 Code Agent（Claude Code, Kimi Code, Cursor, Copilot 等）都是**无状态的**——每次交互都从零开始，不积累用户偏好，不学习用户习惯。

**kimiz 的突破**:

| 维度 | 其他 Code Agent | kimiz |
|------|----------------|-------|
| **架构** | Tool-based | **Skill-Centric + 自我学习** |
| **个性化** | 无 | **越用越懂用户** |
| **Token 效率** | 恒定消耗 | **递减消耗（最高省 80%）** |
| **响应速度** | 2-5s | **<100ms（Skill 命中时）** |
| **准确率** | 60-70% | **95%+（学习后）** |

**核心价值主张**:
> **"The AI Coding Agent that learns you"**
> 
> 唯一会学习用户的 Code Agent，从第 1 天的"通用工具"进化为第 30 天的"个人编码分身"。

**量化效果**:
```
场景: "优化这段代码"

Claude Code (每次):
  往返: 2-3 次澄清
  Token: 5000
  时间: 5s
  准确率: 60%

kimiz (第 1 次):
  往返: 2-3 次澄清
  Token: 4500
  时间: 4s
  准确率: 65%
  [系统学习用户偏好]

kimiz (第 10 次):
  往返: 1 次
  Token: 800 (省 84%)
  时间: 0.5s (快 10x)
  准确率: 95%
  [直接命中 learned-skill]
```

**护城河**:
- **数据护城河**: 用户使用 100 小时后产生 100+ learned skills，迁移成本极高
- **技术护城河**: Zig 高性能 + 本地 AI 计算优化 + 多模型协同
- **体验护城河**: 越用越好用，竞品无法复制个人学习数据

---

## 3. 架构设计

### 2.1 多模块架构（借鉴 pi-mono）

```
kimiz/
├── kimiz-core/          # 核心类型和工具
│   ├── types/           # 共享数据类型
│   ├── errors/          # 错误处理
│   └── utils/           # 通用工具
│
├── kimiz-ai/            # 统一 LLM API 层
│   ├── providers/       # OpenAI, Anthropic, Google, Kimi...
│   ├── routing/         # 智能模型路由
│   ├── streaming/       # SSE 流式处理
│   └── multimodal/      # 图片/PDF 支持
│
├── kimiz-agent/         # Agent 运行时
│   ├── loop/            # Agent 主循环
│   ├── tools/           # 内置工具集
│   ├── memory/          # 记忆系统
│   ├── learning/        # 自适应学习
│   └── parallel/        # 并行 Sub-Agent
│
├── kimiz-cli/           # 命令行界面
│   ├── repl/            # 交互式 REPL
│   ├── tui/             # 终端 UI (libvaxis)
│   ├── commands/        # 子命令系统
│   └── config/          # 配置管理
│
└── kimiz-prompts/       # 提示词工程
    ├── templates/       # 提示词模板
    ├── optimization/    # 提示词优化
    └── versioning/      # 提示词版本管理
```

### 2.2 核心设计决策

#### ❌ 不集成 MCP (Model Context Protocol)

**原因**:
- MCP 会导致 Context 爆炸，与我们的轻量理念冲突
- 增加架构复杂度，违背简单优先原则
- 当前 MCP 生态不成熟，工具质量参差不齐

**替代方案**:
- 内置精心设计的工具集
- 简单的工具注册机制
- 未来可考虑插件系统（非 MCP）

#### ✅ 优先 CLI，TUI 增强

**CLI 优先**:
- 所有功能都可通过命令行使用
- 支持脚本化和自动化
- 快速启动，即时响应

**TUI 增强**:
- 提供现代化的终端界面
- 流式输出、代码高亮、图片显示
- 会话管理、历史浏览

---

## 3. 功能规格

### 3.1 kimiz-core: 核心基础设施

**职责**: 提供全项目共享的基础类型和工具

**功能**:
- 核心数据类型（Message, Context, Tool 等）
- 统一的错误处理体系
- 内存分配工具
- 异步运行时抽象（libxev）

### 3.2 kimiz-ai: 统一 LLM API

**职责**: 封装多 Provider 差异，提供统一接口

**支持的 Provider**:
| Provider | 模型 | 特殊能力 |
|----------|------|----------|
| OpenAI | GPT-4o, GPT-4o-mini, o3-mini | 工具调用、结构化输出 |
| Anthropic | Claude 3.5/4 Sonnet, Haiku | 长上下文、代码能力 |
| Google | Gemini 2.5 Pro, Flash | 多模态、PDF 原生支持 |
| Kimi | K2.5 | 中文优化、长上下文 |
| Fireworks | 开源模型托管 | 成本优化 |

**核心功能**:
- ✅ 统一 API 接口（stream/complete）
- ✅ 智能模型路由（根据任务类型选择最优模型）
- ✅ 多模态输入（图片、PDF）
- ✅ 流式响应处理
- ✅ 成本跟踪和优化
- ✅ 失败自动重试和模型回退

### 3.3 kimiz-agent: Agent 运行时

**职责**: 实现智能 Agent 的核心逻辑

**核心组件**:

#### Agent Loop (借鉴 Claude Code)

```
┌─────────────────────────────────────────┐
│           Agent Loop                    │
├─────────────────────────────────────────┤
│  1. Receive user input                  │
│  2. Retrieve relevant memories          │
│  3. Build enhanced prompt               │
│  4. Select optimal model                │
│  5. Stream LLM response                 │
│  6. Parse tool calls                    │
│  7. Execute tools                       │
│  8. Return results to LLM (if needed)   │
│  9. Repeat 5-8 until done               │
│  10. Store interaction to memory        │
└─────────────────────────────────────────┘
```

#### 内置工具集

| 工具 | 功能 | 安全级别 |
|------|------|----------|
| ReadFile | 读取文件内容 | 只读 |
| WriteFile | 写入文件 | 需确认 |
| StrReplace | 替换文件内容 | 需确认 |
| Glob | 文件模式匹配 | 只读 |
| Grep | 文本搜索 | 只读 |
| Bash | 执行 shell 命令 | 需确认 |
| Python | 执行 Python 代码 | 沙箱 |
| WebSearch | 网络搜索 | 只读 |

#### 记忆系统 (借鉴 mem0，简化实现)

**三层记忆**:
- **短期记忆**: 当前会话上下文
- **工作记忆**: 项目级别的知识（代码库理解、技术栈）
- **长期记忆**: 用户偏好、学习到的模式

**存储**: SQLite（单文件，零配置）

#### 自适应学习

**学习内容**:
- 用户代码风格（命名规范、缩进偏好等）
- 常用工具和模式
- 模型表现数据（用于智能路由）
- 项目特定知识

### 3.4 kimiz-cli: 命令行界面

**职责**: 提供用户交互界面

#### CLI 模式

```bash
# 直接执行命令
kimiz "实现一个 LRU 缓存"

# 指定模型
kimiz --model claude-sonnet-4 "重构这个函数"

# 使用特定 Provider
kimiz --provider openai --model gpt-4o "解释这段代码"

# 分析图片
kimiz --image screenshot.png "这个错误是什么意思"

# 分析 PDF
kimiz --pdf spec.pdf "总结需求"

# 进入 REPL 模式
kimiz --repl

# 启动 TUI
kimiz --tui
```

#### TUI 模式

**界面布局**:
```
┌─────────────────────────────────────────────────────────────┐
│  kimiz v0.1.0                    [Plan Mode] [Model: GPT-4o]│
├──────────┬──────────────────────────────────────────────────┤
│          │                                                   │
│ Sessions │  ┌────────────────────────────────────────────┐  │
│          │  │ User: 实现一个线程安全的 LRU 缓存          │  │
│ [S1] ✓   │  │                                            │  │
│ [S2]     │  │ Assistant: 我来为你实现一个线程安全的     │  │
│ [S3] ✓   │  │ LRU 缓存：                                 │  │
│          │  │                                            │  │
│ [+ New]  │  │ ┌────────────────────────────────────┐    │  │
│          │  │ │ pub const LRUCache = struct {      │    │  │
│          │  │ │     // ... 实现代码                 │    │  │
│          │  │ │ };                                 │    │  │
│          │  │ └────────────────────────────────────┘    │  │
│          │  │                                            │  │
│          │  │ [Tool: ReadFile] → [Tool: WriteFile] ✓    │  │
│          │  └────────────────────────────────────────────┘  │
│          │                                                   │
├──────────┴──────────────────────────────────────────────────┤
│  > _                                                        │
│  [Ctrl+Enter]发送 [Ctrl+N]新会话 [Ctrl+P]Plan模式 [?]帮助   │
└─────────────────────────────────────────────────────────────┘
```

**快捷键**:
| 快捷键 | 功能 |
|--------|------|
| Ctrl+N | 新建会话 |
| Ctrl+Shift+N | 复制当前会话 |
| Ctrl+P | 切换 Plan/YOLO 模式 |
| Ctrl+R | 重新生成响应 |
| Ctrl+C | 取消当前操作 |
| ? | 显示帮助 |

### 3.5 kimiz-prompts: 提示词工程

**职责**: 管理和优化提示词

**核心功能**:
- 提示词模板管理
- 动态提示词构建（根据用户偏好、项目上下文）
- 提示词版本控制
- A/B 测试框架

**提示词优化策略**（借鉴 Claude Code）:
- 系统提示词 + 动态上下文
- 自动压缩长上下文
- 缓存优化
- 增量更新

---

## 4. 非功能需求

### 4.1 性能目标

| 指标 | 目标 | 说明 |
|------|------|------|
| 启动时间 | < 100ms | 冷启动到可交互 |
| 内存占用 | < 50MB | 典型使用场景 |
| 二进制大小 | < 20MB | 单文件可执行 |
| 首次 Token 延迟 | < 500ms | 从发送到首 token |
| 流式输出 | 实时 | 无缓冲延迟 |

### 4.2 技术栈

| 组件 | 选择 | 理由 |
|------|------|------|
| 语言 | Zig 0.15.2 | 性能、内存安全、交叉编译 |
| TUI | libvaxis | 现代终端功能、图片支持 |
| 异步 | libxev | 高性能事件循环 |
| HTTP | std.http | 标准库，无额外依赖 |
| JSON | std.json | 标准库，0.15 已完善 |
| 日志 | nexlog | 结构化日志、文件轮转 |
| CLI | zig-clap | 类型安全、易用 |
| 存储 | SQLite | 单文件、零配置 |

### 4.3 兼容性

- **平台**: macOS (arm64/x86_64), Linux (x86_64)
- **终端**: iTerm2, Kitty, WezTerm, Windows Terminal
- **Shell**: bash, zsh, fish

---

## 5. 安全设计

### 5.1 工具执行安全

| 安全层级 | 措施 |
|----------|------|
| 只读工具 | 无需确认，直接执行 |
| 写操作 | 需用户确认（YOLO 模式可跳过） |
| 命令执行 | 沙箱环境，超时限制 |
| 网络访问 | 工具级别控制 |

### 5.2 数据安全

- API Key 存储: 环境变量或加密本地存储
- 记忆数据: 本地 SQLite，不上传云端
- 日志脱敏: 自动过滤敏感信息

---

## 6. 成功标准

### 6.1 功能验收

- [ ] 支持 5+ Provider，可无缝切换
- [ ] Tool Calling 准确率和成功率 > 95%
- [ ] TUI 流畅运行，支持 1000+ 消息会话
- [ ] 记忆系统有效提升响应质量（用户感知）
- [ ] 智能路由降低 30%+ 成本（相比固定模型）

### 6.2 性能验收

- [ ] 启动时间 < 100ms
- [ ] 内存占用 < 50MB
- [ ] 流式输出无卡顿

### 6.3 质量验收

- [ ] 单元测试覆盖率 > 80%
- [ ] 零内存泄漏（valgrind 检测）
- [ ] 跨平台编译通过

---

## 7. 里程碑规划

### Phase 1: 核心基础设施 (4 周)

| 周 | 内容 |
|----|------|
| 1 | 项目结构、核心类型、错误处理 |
| 2 | HTTP 层、OpenAI Provider |
| 3 | SSE 解析、流式响应 |
| 4 | CLI 基础、REPL 模式 |

### Phase 2: Agent 运行时 (4 周)

| 周 | 内容 |
|----|------|
| 5 | Agent Loop、工具系统 |
| 6 | 多 Provider 支持 |
| 7 | Tool Calling、内置工具 |
| 8 | 记忆系统基础 |

### Phase 3: 智能增强 (4 周)

| 周 | 内容 |
|----|------|
| 9 | 智能路由、模型选择 |
| 10 | 自适应学习 |
| 11 | 多模态（图片、PDF）|
| 12 | TUI 界面 |

### Phase 4: 优化和发布 (4 周)

| 周 | 内容 |
|----|------|
| 13 | 性能优化 |
| 14 | 提示词工程 |
| 15 | 测试和文档 |
| 16 | 发布准备 |

---

## 8. 不纳入范围

明确不做，避免范围蔓延：

- ❌ **MCP 集成**: 避免 Context 爆炸，保持简单
- ❌ **Web UI**: 专注终端体验
- ❌ **IDE 插件**: 优先 CLI/TUI
- ❌ **Slack/Discord Bot**: 非核心场景
- ❌ **云端服务**: 纯本地运行
- ❌ **模型训练/微调**: 仅使用现有 API
- ❌ **多语言支持**: 先专注英文和中文

---

## 9. 附录

### 9.1 参考资源

- [pi-mono](https://github.com/badlogic/pi-mono): 架构参考
- [Claude Code Restored](https://github.com/didilili/claude-code-restored): Agent Loop 实现
- [Harness Engineering](https://zhanghandong.github.io/harness-engineering-from-cc-to-ai-coding/): Prompt 工程
- [mem0](https://github.com/mem0ai/mem0): 记忆系统设计

### 9.2 术语表

| 术语 | 说明 |
|------|------|
| Agent | 能自主决策和执行任务的 AI 系统 |
| Tool Calling | LLM 调用外部工具的能力 |
| SSE | Server-Sent Events，流式数据传输协议 |
| TUI | Terminal User Interface，终端用户界面 |
| Plan Mode | 先规划再执行的模式 |
| YOLO Mode | 自动执行无需确认的模式 |
| Provider | LLM API 供应商（OpenAI, Anthropic 等）|

