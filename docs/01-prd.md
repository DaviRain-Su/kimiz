# PRD — kimiz：Zig 语言实现的 AI Agent 工具包

**版本**: 0.1.0  
**日期**: 2026-04-04  
**状态**: 草稿  
**参考**: [badlogic/pi-mono](https://github.com/badlogic/pi-mono)

---

## 1. 项目背景

pi-mono 是一套用 TypeScript 编写的 AI Agent 工具链，包含统一多模型 LLM API、Agent 运行时、Terminal UI 等核心组件，在 GitHub 上获得 31K+ Star。

kimiz 目标是用 **Zig 语言** 重新实现 pi-mono 的核心能力，提供：
- 原生编译的高性能 LLM 客户端
- 无 GC、内存安全的 Agent 运行时
- 可嵌入其他 Zig/C/C++ 项目的库形态

---

## 2. 目标用户

| 用户类型 | 场景 |
|----------|------|
| Zig 开发者 | 在 Zig 项目中调用 LLM API，无需引入 JS 运行时 |
| 系统程序员 | 构建嵌入式/IoT/CLI AI 工具，需要极小二进制 |
| 跨语言集成者 | 通过 C ABI 从 C/C++/Rust 调用 AI 能力 |

---

## 3. 功能范围（MVP）

### ✅ 纳入范围

#### Module A: `kimiz-ai`（对应 pi-ai）
- **多 Provider 统一 API**：OpenAI、Anthropic、Google Gemini、Kimi、Fireworks
- **核心数据类型**：Message、Context、Tool、AssistantMessage、Usage
- **多模态支持**：
  - 图片输入（base64 编码），支持所有 Provider 的 Vision 模型
  - **PDF 文档输入**：支持 Gemini 和 Claude 的原生 PDF 理解
  - 图片/文档 URL 支持
- **联网搜索**：
  - 统一搜索接口，整合多 Provider 能力
  - OpenAI web_search 工具
  - 可插拔搜索后端（Tavily、SerpAPI 等）
- **代码执行**：
  - 本地 Python/Bash 沙箱执行
  - 安全限制（超时、内存、网络）
- **流式响应**：SSE 解析 + 事件协议（text_delta / toolcall_delta / image_delta 等）
- **非流式响应**：complete() 函数
- **Tool Calling**：工具定义、参数解析、工具结果回传
- **成本计算**：基于 token 数量计算 API 费用
- **API Key 环境变量读取**

#### Module B: `kimiz-agent`（对应 pi-agent-core）
- **Agent 状态机**：管理 messages、tool 执行循环
- **事件系统**：agent_start / turn_start / message_update / tool_execution_* / agent_end
- **工具执行**：顺序执行（MVP，并行后续支持）
- **Context 管理**：消息历史管理
- **Agent 集群（Auto-Parallel）**：
  - 自动任务分解识别
  - 跨 Provider 并行 Sub-Agent 执行
  - 结果汇总与冲突解决
- **内置工具**：
  - 文件操作（ReadFile, WriteFile, Glob, Grep）
  - 代码执行（Python/Bash 沙箱）
  - 联网搜索（统一接口）
  - 子 Agent 委派

#### Module C: `kimiz` CLI + TUI（对应 pi-coding-agent 和 pi-tui）
- **交互式 REPL**：读取用户输入，调用 Agent，打印响应
- **TUI 界面**：使用 libvaxis 实现现代化终端界面
  - 消息气泡显示（支持 Markdown 渲染）
  - 代码块语法高亮
  - **图片显示**：支持终端图片显示（Kitty/iTerm2 协议）
  - 会话侧边栏（Plan/YOLO 模式切换）
  - 流式输出实时显示
  - 快捷键支持（Ctrl+N 新建会话等）
- **多模态输入**：支持粘贴/拖拽图片到 TUI
- **环境变量配置**：API Key、模型选择
- **配置文件支持**：YAML/TOML 格式配置

### ❌ 不纳入范围（MVP）

- pi-web-ui：Web 组件（与 Zig 生态不符）
- pi-mom：Slack Bot 集成
- pi-pods：vLLM 部署管理
- OAuth 认证流程（GitHub Copilot、Gemini CLI 等）
- Amazon Bedrock（SDK 依赖复杂）
- 所有 OpenAI Responses API（只实现 Completions API）
- WebSocket 传输
- 浏览器端支持

---

## 4. 非功能需求

| 需求 | 目标 |
|------|------|
| **依赖管理** | 核心功能优先使用 Zig 标准库；TUI、异步运行时、日志、CLI 使用精选第三方库 |
| **第三方库** | libvaxis (TUI), libxev (异步), zig-clap (CLI), nexlog (日志) |
| **内存管理** | 所有公共 API 接受 `std.mem.Allocator`，调用方负责生命周期 |
| **错误处理** | 所有 IO/网络操作返回 Zig error union，无 panic（正常路径） |
| **C ABI** | 核心 AI 调用提供 C 导出函数（`export fn`） |
| **编译速度** | `zig build` 应在 10s 内完成（避免过度泛型） |
| **测试覆盖** | 所有数据解析逻辑有 unit test；网络调用有 mock test |

---

## 5. 成功标准

1. **OpenAI 对话**：`zig build run -- "Hello"` 能调用 gpt-4o-mini 并打印响应
2. **Anthropic 对话**：切换 provider 到 anthropic/claude-haiku 正常工作
3. **Tool Calling**：定义一个 `get_time` tool，Agent 能正确调用并回传结果
4. **流式输出**：SSE 流式打印每个 token（text_delta 事件）
5. **错误处理**：无效 API Key 返回清晰错误消息，不 crash
6. **TUI 界面**：`zig build run -- --tui` 启动现代化终端界面
7. **并发 Agent**：多个 Agent 可以并行执行不阻塞
8. **日志记录**：所有 HTTP 请求和 Agent 事件被记录到文件
9. **多模态支持**：能发送图片给 GPT-4o / Claude 并获取描述
10. **PDF 支持**：能发送 PDF 文档给 Gemini/Claude 进行分析
11. **联网搜索**：Agent 能使用搜索工具获取最新信息
12. **代码执行**：Agent 能在本地沙箱执行 Python/Bash 代码
13. **所有测试通过**：`zig build test` 全部绿

---

## 6. 约束与假设

- **Zig版本**: `0.15.2`（与 build.zig.zon 保持一致）
- **目标平台**: macOS (arm64/x86_64)、Linux (x86_64)；Windows 暂不保证
- **HTTP 实现**: 使用 Zig 标准库 `std.http.Client`（0.15 版本）
- **JSON 实现**: 使用 Zig 标准库 `std.json`
- **SSE 解析**: 手工实现，无外部依赖
- **TUI 实现**: 使用 `libvaxis` 库
- **异步运行时**: 使用 `libxev` 库
- **日志**: 使用 `nexlog` 库
- **CLI 解析**: 使用 `zig-clap` 库
- **API 协议**: OpenAI Completions API 格式（`/v1/chat/completions`）；Anthropic Messages API；Google Generative AI REST API

---

## 7. 里程碑

| 里程碑 | 内容 | 目标 |
|--------|------|------|
| M1 | 核心数据类型 + JSON 序列化 | 类型系统就绪 |
| M1.5 | 第三方库集成（日志、异步、CLI） | 基础设施就绪 |
| M2 | OpenAI Provider 非流式 | 第一个 LLM 调用成功 |
| M3 | 流式 SSE 解析 | 流式输出正常 |
| M4 | Anthropic + Google + Kimi + Fireworks Provider | 多 Provider 支持 |
| M5 | Tool Calling | Agent 工具执行 |
| M6 | Agent 运行时 | 完整 Agent 循环 |
| M7 | TUI 界面 | 现代化终端界面 |
| M8 | CLI + 配置文件 | 可用的命令行工具 |

---

## 验收标准（进入 Phase 2 的门槛）

- [ ] 所有 "纳入范围" 功能有明确描述
- [ ] 所有 "不纳入范围" 功能有明确理由
- [ ] 成功标准可量化、可测试
- [ ] 约束条件已明确（平台、版本、依赖）
