: 0
# Task Breakdown — kimiz 任务拆解

**版本**: 0.2.0  
**日期**: 2026-04-05  
**依赖**: [01-prd.md](./01-prd.md), [02-architecture.md](./02-architecture.md)

---

## 执行策略

基于优化后的 PRD，采用**5 模块并行开发**策略：

```
Phase 1 (4周): 核心基础设施
├── Week 1-2: kimiz-core + kimiz-ai (基础)
├── Week 3: kimiz-cli (REPL)
└── Week 4: 集成测试

Phase 2 (4周): Agent 能力
├── Week 5-6: kimiz-agent (Loop + Tools)
└── Week 7-8: 记忆系统 + 学习

Phase 3 (4周): 智能增强
├── Week 9-10: 智能路由 + 多模态
└── Week 11-12: TUI + 提示词工程

Phase 4 (4周): 优化发布
├── Week 13-14: 性能优化
└── Week 15-16: 测试 + 文档
```

---

## Phase 1: 核心基础设施

### Week 1-2: kimiz-core + kimiz-ai

#### Task 1.1: 项目初始化
**时间**: 2h
**模块**: kimiz-core

**内容**:
1. 创建 5 模块目录结构
2. 配置 build.zig.zon（libvaxis, libxev, zig-clap, nexlog, sqlite）
3. 设置 CI/CD 基础
4. 创建 Makefile 常用命令

**目录结构**:
```
src/
├── core/          # kimiz-core
├── ai/            # kimiz-ai
├── agent/         # kimiz-agent
├── cli/           # kimiz-cli
└── prompts/       # kimiz-prompts
```

**验收**:
- [ ] `zig build` 成功
- [ ] `make test` 通过
- [ ] CI 配置完成

#### Task 1.2: 核心类型系统
**时间**: 4h
**模块**: kimiz-core

**内容**:
1. 定义 Memory, Context, Message 等核心类型
2. 设计错误处理体系
3. 实现 Arena 分配器工具
4. 编写单元测试

**验收**:
- [ ] 所有核心类型定义完成
- [ ] 错误类型覆盖所有场景
- [ ] 单元测试覆盖率 > 80%

#### Task 1.3: HTTP 层封装
**时间**: 3h
**模块**: kimiz-core

**内容**:
1. 封装 std.http.Client
2. 实现请求/响应处理
3. 添加重试机制
4. 错误码映射

**验收**:
- [ ] HTTP GET/POST 正常工作
- [ ] 重试机制测试通过
- [ ] 错误处理正确

#### Task 1.4: OpenAI Provider 实现
**时间**: 6h
**模块**: kimiz-ai

**内容**:
1. 实现 Provider 接口
2. 请求/响应序列化
3. 流式 SSE 解析
4. 成本计算

**验收**:
- [ ] 非流式调用成功
- [ ] 流式输出正常
- [ ] Token 成本计算准确

---

### Week 3: kimiz-cli (REPL)

#### Task 2.1: CLI 基础框架
**时间**: 4h
**模块**: kimiz-cli

**内容**:
1. zig-clap 集成
2. 子命令系统（run, repl, tui, config）
3. 环境变量读取
4. 配置管理

**验收**:
- [ ] 所有子命令可用
- [ ] 帮助信息完整
- [ ] 配置加载正确

#### Task 2.2: REPL 模式
**时间**: 4h
**模块**: kimiz-cli

**内容**:
1. 交互式输入
2. 历史记录
3. 快捷键支持
4. 流式输出显示

**验收**:
- [ ] 基本对话可用
- [ ] 历史记录可浏览
- [ ] Ctrl+C 正确处理

---

### Week 4: 集成测试

#### Task 3.1: 端到端测试
**时间**: 6h
**模块**: All

**内容**:
1. 编写 E2E 测试脚本
2. Mock Provider 测试
3. 性能基准测试
4. 内存泄漏检测

**验收**:
- [ ] E2E 测试通过
- [ ] 无内存泄漏
- [ ] 性能达标

---

## Phase 2: Agent 能力

### Week 5-6: kimiz-agent

#### Task 4.1: Agent Loop 实现
**时间**: 8h
**模块**: kimiz-agent

**内容**:
1. Agent 状态机
2. 事件系统
3. Tool Calling 解析
4. 循环控制

**验收**:
- [ ] Agent Loop 运行稳定
- [ ] 事件正确触发
- [ ] 工具调用正确解析

#### Task 4.2: 内置工具集
**时间**: 8h
**模块**: kimiz-agent

**内容**:
1. ReadFile/WriteFile
2. Glob/Grep
3. Bash（带确认）
4. WebSearch

**验收**:
- [ ] 所有工具可用
- [ ] 安全确认机制工作
- [ ] 错误处理完善

---

### Week 7-8: 记忆系统

#### Task 5.1: SQLite 存储层
**时间**: 6h
**模块**: kimiz-agent

**内容**:
1. 数据库 Schema 设计
2. CRUD 操作
3. 全文搜索
4. 迁移机制

**验收**:
- [ ] 数据库操作正常
- [ ] 搜索功能可用
- [ ] 数据持久化正确

#### Task 5.2: 记忆管理器
**时间**: 6h
**模块**: kimiz-agent

**内容**:
1. 三层记忆实现
2. 记忆检索
3. 会话摘要
4. 模式提取

**验收**:
- [ ] 记忆存储/检索正常
- [ ] 相关记忆召回准确
- [ ] 学习效果可感知

---

## Phase 3: 智能增强

### Week 9-10: 智能路由 + 多模态

#### Task 6.1: 智能模型路由
**时间**: 8h
**模块**: kimiz-ai

**内容**:
1. 任务分析器
2. 模型能力矩阵
3. 路由决策引擎
4. 性能追踪

**验收**:
- [ ] 任务正确分类
- [ ] 模型选择合理
- [ ] 成本降低可测量

#### Task 6.2: 多模态支持
**时间**: 8h
**模块**: kimiz-ai

**内容**:
1. 图片输入（base64）
2. PDF 文档处理
3. 终端图片显示
4. 多 Provider 适配

**验收**:
- [ ] 图片分析可用
- [ ] PDF 总结准确
- [ ] TUI 图片显示正常

---

### Week 11-12: TUI + 提示词

#### Task 7.1: TUI 界面
**时间**: 10h
**模块**: kimiz-cli

**内容**:
1. libvaxis 集成
2. 布局系统
3. 消息组件
4. 会话管理

**验收**:
- [ ] TUI 启动正常
- [ ] 流式输出流畅
- [ ] 快捷键响应正确

#### Task 7.2: 提示词工程
**时间**: 6h
**模块**: kimiz-prompts

**内容**:
1. 提示词模板系统
2. 动态构建器
3. 上下文压缩
4. 缓存优化

**验收**:
- [ ] 提示词正确组装
- [ ] 上下文压缩有效
- [ ] 响应质量提升

---

## Phase 4: 优化发布

### Week 13-16: 优化 + 文档 + 发布

#### Task 8.1: 性能优化
**时间**: 10h
**模块**: All

**内容**:
1. 启动时间优化
2. 内存使用优化
3. 编译时间优化
4. 缓存策略优化

**验收**:
- [ ] 启动 < 100ms
- [ ] 内存 < 50MB
- [ ] 编译 < 10s

#### Task 8.2: 文档完善
**时间**: 10h
**模块**: Docs

**内容**:
1. API 文档
2. 用户指南
3. 架构文档
4. 示例代码

**验收**:
- [ ] 文档完整
- [ ] 示例可运行
- [ ] 发布说明

#### Task 8.3: 发布准备
**时间**: 6h
**模块**: All

**内容**:
1. 版本号更新
2. 二进制打包
3. Homebrew 公式
4. 发布检查清单

**验收**:
- [ ] 多平台二进制
- [ ] 安装测试通过
- [ ] 发布流程文档化

---

## 关键路径

```
Week 1-2: 核心类型 → HTTP → OpenAI Provider
                ↓
Week 3-4: CLI 框架 → REPL → 集成测试
                ↓
Week 5-6: Agent Loop → 工具集
                ↓
Week 7-8: 记忆系统 → 学习
                ↓
Week 9-10: 智能路由 → 多模态
                ↓
Week 11-12: TUI → 提示词
                ↓
Week 13-16: 优化 → 文档 → 发布
```

---

## 风险与应对

| 风险 | 影响 | 应对 |
|------|------|------|
| libvaxis 不稳定 | TUI 延期 | 先用简单 TUI，后续升级 |
| SQLite 性能不足 | 记忆系统慢 | 考虑 LevelDB 替代 |
| Provider API 变更 | 兼容性问题 | 抽象层隔离，快速适配 |
| 编译时间过长 | 开发效率低 | 模块化编译，增量构建 |
5. Message 类型: UserMessage, AssistantMessage, ToolResultMessage
6. Tool, Context, Model, ModelCost 结构体
7. StreamOptions 结构体
8. AiError 错误类型

**验收**:
- [ ] 所有类型定义与 tech-spec 完全一致
- [ ] `zig build test` 编译通过

---

### Task 1.3: 实现模型注册表 (ai/models.zig)
**时间**: 60min  
**依赖**: Task 1.2

**内容**:
1. model_table 静态数组（8 个模型定义）
2. `getModel(provider, id)` 函数
3. `getModelsByProvider(provider)` 函数
4. `calculateCost(model, usage)` 函数

**验收**:
- [ ] 能正确查询所有 8 个模型
- [ ] 成本计算公式正确
- [ ] 单元测试覆盖

---

### Task 1.4: 实现 JSON 工具 (ai/json_utils.zig)
**时间**: 60min  
**依赖**: Task 1.2

**内容**:
1. `serializeOpenAIRequest()` - OpenAI 请求序列化
2. `serializeAnthropicRequest()` - Anthropic 请求序列化
3. `serializeGoogleRequest()` - Google 请求序列化
4. `parsePartialJson()` - 部分 JSON 解析

**验收**:
- [ ] 序列化输出符合 tech-spec 中的 JSON 格式示例
- [ ] 单元测试验证序列化结果

---

## Batch 1.5: 第三方库集成与基础设施

### Task 1.5.1: 集成日志库 (nexlog)
**时间**: 30min  
**依赖**: Task 1.1

**内容**:
1. 配置 nexlog 日志级别
2. 实现日志初始化
3. 添加 HTTP 请求/响应日志
4. 添加 Agent 事件日志

**验收**:
- [ ] 日志正确输出到控制台和文件
- [ ] 支持不同日志级别
- [ ] 日志包含时间戳和模块信息

---

### Task 1.5.2: 集成异步运行时 (libxev)
**时间**: 45min  
**依赖**: Task 1.1

**内容**:
1. 创建 `src/utils/async.zig`
2. 封装 libxev 事件循环
3. 实现 HTTP 异步请求
4. 实现并发 Provider 调用

**验收**:
- [ ] 事件循环正确初始化
- [ ] 异步 HTTP 请求工作正常
- [ ] 并发调用不阻塞主线程

---

### Task 1.5.3: 集成 CLI 库 (zig-clap)
**时间**: 30min  
**依赖**: Task 1.1

**内容**:
1. 定义 CLI 参数结构
2. 实现参数解析
3. 添加帮助信息生成
4. 添加版本信息

**验收**:
- [ ] 所有 CLI 参数正确解析
- [ ] 帮助信息完整显示
- [ ] 无效参数返回清晰错误

---

### Task 1.5.4: 配置文件支持
**时间**: 45min  
**依赖**: Task 1.5.3

**内容**:
1. 创建 `src/utils/config.zig`
2. 支持 YAML/TOML 配置文件
3. 实现配置加载和验证
4. 配置优先级：CLI > 环境变量 > 配置文件 > 默认值

**验收**:
- [ ] 配置文件正确加载
- [ ] 配置优先级正确
- [ ] 配置验证返回清晰错误

---

## Batch 2: HTTP 层 + OpenAI 非流式 (M2)

### Task 2.1: 实现 HTTP 封装 (http.zig)
**时间**: 90min  
**依赖**: Task 1.1

**内容**:
1. HttpClient 结构体（包装 std.http.Client）
2. `postJson()` - 非流式 POST
3. `postStream()` - 流式 POST（逐行回调）
4. HTTP 状态码映射到 HttpError

**验收**:
- [ ] 能成功发送 HTTP POST 请求
- [ ] 状态码正确映射到错误类型
- [ ] 使用 mock server 测试

---

### Task 2.2: 实现 SSE 解析器 (ai/sse.zig)
**时间**: 45min  
**依赖**: Task 1.1

**内容**:
1. `parseSseLine(line)` 函数
2. 处理 `data: ...` 格式
3. 识别 `[DONE]` 信号
4. 忽略注释行和空行

**验收**:
- [ ] 所有 SSE 格式测试用例通过
- [ ] `[DONE]` 正确触发 SseDoneReceived 错误

---

### Task 2.3: 实现 OpenAI Provider 非流式 (ai/providers/openai.zig)
**时间**: 90min  
**依赖**: Task 2.1, Task 2.2, Task 1.4

**内容**:
1. `complete()` 函数
2. 请求体序列化
3. 响应体解析
4. finish_reason → StopReason 映射

**验收**:
- [ ] 能成功调用 OpenAI API（或 mock）
- [ ] 返回正确的 AssistantMessage
- [ ] 单元测试通过

---

### Task 2.4: 实现顶层 AI API 非流式 (ai/stream.zig)
**时间**: 45min  
**依赖**: Task 2.3

**内容**:
1. Ai 结构体
2. `Ai.init()` / `Ai.deinit()`
3. `complete()` 路由函数
4. API Key 解析逻辑

**验收**:
- [ ] 能根据 model.api 路由到正确 provider
- [ ] API Key 解析顺序正确

---

## Batch 3: 流式实现 (M3)

### Task 3.1: 实现 OpenAI Provider 流式
**时间**: 90min  
**依赖**: Task 2.3

**内容**:
1. `stream()` 函数
2. SSE chunk 解析
3. AssistantMessageEvent 生成
4. 回调触发逻辑

**验收**:
- [ ] 流式输出每个 token
- [ ] 回调函数正确触发

---

### Task 3.2: 实现顶层 AI API 流式
**时间**: 45min  
**依赖**: Task 3.1

**内容**:
1. Ai.stream() 函数
2. 流式路由逻辑

**验收**:
- [ ] 流式调用正常工作

---

### Task 3.3: 实现 Anthropic Provider
**时间**: 90min  
**依赖**: Task 3.2

**内容**:
1. Anthropic 请求序列化
2. Anthropic 响应解析
3. Anthropic SSE 事件映射
4. complete() + stream()

**验收**:
- [ ] Anthropic API 调用成功
- [ ] 事件映射符合 tech-spec 表

---

### Task 3.4: 实现 Google Provider
**时间**: 45min  
**依赖**: Task 3.2

**内容**:
1. Google 请求序列化
2. Google 响应解析
3. complete() + stream()

**验收**:
- [ ] Google API 调用成功

---

## Batch 4: 多 Provider 完善 + Kimi Code (M4)

### Task 4.1: 实现 Kimi 标准 Provider
**时间**: 45min  
**依赖**: Task 3.2

**内容**:
1. 创建 `ai/providers/kimi.zig`
2. 复用 OpenAI Provider 实现标准 Kimi API
3. 添加 `kimi-k2-5` 和 `kimi-k2` 模型到注册表

**验收**:
- [ ] Kimi 标准 API 调用成功
- [ ] 模型配置正确

---

### Task 4.2: 实现 Kimi Code Provider（核心）
**时间**: 90min  
**依赖**: Task 4.1

**内容**:
1. 实现 `kimi.completeCode()` 和 `kimi.streamCode()`
2. 实现 `serializeKimiCodeRequest()` 处理特有参数
3. 添加 `kimi-for-coding` 模型到注册表
4. 添加 `KimiCodeOptions` 和 `AgentMode` 类型

**验收**:
- [ ] Kimi Code API 调用成功
- [ ] thinking_budget 参数正确传递
- [ ] 响应正确解析

---

### Task 4.3: 实现 Plan Mode
**时间**: 60min  
**依赖**: Task 4.2

**内容**:
1. 添加 `AgentMode` 枚举（normal/plan）
2. 实现 Plan Mode 工具白名单
3. 在 Agent Loop 中根据 mode 过滤工具

**验收**:
- [ ] Plan Mode 下只执行只读工具
- [ ] WriteFile/Shell 等工具被拦截

---

### Task 4.4: 实现 YOLO Mode
**时间**: 30min  
**依赖**: Task 4.3

**内容**:
1. 添加 `yolo_mode` 到 AgentOptions
2. 在工具调用前检查 yolo_mode
3. 自动批准所有工具调用

**验收**:
- [ ] YOLO Mode 下工具自动执行
- [ ] 无需用户确认

---

### Task 4.5: 实现 Session 管理
**时间**: 60min  
**依赖**: Task 4.4

**内容**:
1. 创建 `agent/session.zig`
2. 实现 Session 结构体（fork/undo/export/import）
3. 实现 SessionManager

**验收**:
- [ ] Session fork 正常工作
- [ ] Session undo 正常工作
- [ ] export/import 正常工作

---

### Task 4.6: 实现 Fireworks AI Provider + 重复检测
**时间**: 60min  
**依赖**: Task 4.5

**内容**:
1. 添加 Fireworks AI Provider 支持
2. 添加 `kimi-k2p5-turbo` 模型到注册表
3. 实现 `StreamGuard` 重复检测机制
4. 实现 `calculateSimilarity()` 函数

**验收**:
- [ ] Fireworks API 调用成功
- [ ] 重复检测能识别循环并终止
- [ ] 返回部分生成的内容

---

### Task 4.7: Provider 错误处理和集成测试
**时间**: 60min  
**依赖**: Task 4.6

**内容**:
1. 统一错误处理
2. 重试逻辑
3. 多 Provider 集成测试

**验收**:
- [ ] 所有 HTTP 错误正确映射
- [ ] 重试逻辑工作正常
- [ ] 所有 Provider 通过集成测试

---

## Batch 5: Tool Calling (M5)

### Task 5.1: 实现 Tool 定义和执行框架
**时间**: 60min  
**依赖**: Task 1.2

**内容**:
1. AgentTool 结构体
2. Tool 执行函数类型
3. executeTool() 函数

**验收**:
- [ ] Tool 定义正确
- [ ] 执行函数能正确调用

---

### Task 5.2: 实现 Tool Calling 解析
**时间**: 90min  
**依赖**: Task 5.1

**内容**:
1. 解析 tool_calls 字段
2. 累积工具参数（流式）
3. 工具结果消息构造

**验收**:
- [ ] 工具调用正确解析
- [ ] 流式参数累积正确

---

### Task 5.3: 实现内置工具
**时间**: 60min  
**依赖**: Task 5.2

**内容**:
1. get_time 工具
2. 其他示例工具

**验收**:
- [ ] 内置工具工作正常

---

### Task 5.4: Tool Calling 集成测试
**时间**: 60min  
**依赖**: Task 5.3

**内容**:
1. 完整 tool calling 流程测试
2. 多工具调用测试

**验收**:
- [ ] Tool calling 端到端测试通过

---

## Batch 6: Agent 运行时 (M6)

### Task 6.1: 实现 Agent 事件系统
**时间**: 60min  
**依赖**: Task 1.2

**内容**:
1. AssistantMessageEvent 定义
2. AgentEvent 定义
3. 事件回调机制

**验收**:
- [ ] 所有事件类型定义正确

---

### Task 6.2: 实现 Agent 核心逻辑
**时间**: 120min  
**依赖**: Task 6.1, Task 5.4

**内容**:
1. Agent 结构体
2. Agent.init() / Agent.deinit()
3. prompt() 函数
4. continue() 函数
5. Agent Loop 状态机

**验收**:
- [ ] Agent 循环正确工作
- [ ] 事件正确触发

---

### Task 6.3: Agent 集成测试
**时间**: 60min  
**依赖**: Task 6.2

**内容**:
1. 完整 Agent 流程测试
2. 工具调用循环测试
3. 多轮对话测试

**验收**:
- [ ] Agent 端到端测试通过

---

## Batch 7: TUI 界面 (M7)

### Task 7.1: 实现 TUI 基础框架
**时间**: 60min  
**依赖**: Task 6.3

**内容**:
1. 创建 `src/tui/` 目录结构
2. 实现终端控制（termios）
3. 实现基本渲染循环
4. 实现清屏和刷新

**验收**:
- [ ] TUI 能正常启动和退出
- [ ] 清屏和刷新工作正常

---

### Task 7.2: 实现消息显示组件
**时间**: 60min  
**依赖**: Task 7.1

**内容**:
1. Message 气泡组件
2. 代码块高亮显示
3. 工具调用状态显示
4. 消息滚动

**验收**:
- [ ] 消息正确显示为气泡
- [ ] 代码块有语法高亮
- [ ] 可以滚动查看历史

---

### Task 7.3: 实现输入和侧边栏
**时间**: 60min  
**依赖**: Task 7.2

**内容**:
1. 输入框组件（支持多行）
2. 会话侧边栏
3. 状态栏显示
4. 快捷键处理

**验收**:
- [ ] 可以输入多行文本
- [ ] 侧边栏显示会话列表
- [ ] 快捷键响应正确

---

### Task 7.4: 集成 Agent 和 TUI
**时间**: 60min  
**依赖**: Task 7.3

**内容**:
1. Agent 事件驱动 UI 更新
2. 流式输出实时显示
3. Plan/YOLO 模式切换
4. 主题切换

**验收**:
- [ ] Agent 输出实时显示在 TUI
- [ ] 流式输出平滑滚动
- [ ] 模式切换正确显示

---

## Batch 8: CLI 和集成测试 (M8)

### Task 8.1: 实现 CLI 参数解析
**时间**: 45min  
**依赖**: Task 7.4

**内容**:
1. 命令行参数解析（--tui, --repl, --model）
2. 环境变量读取
3. 帮助信息

**验收**:
- [ ] 参数解析正确
- [ ] 帮助信息完整

---

### Task 8.2: 集成测试和发布
**时间**: 75min  
**依赖**: Task 8.1

**内容**:
1. E2E 测试脚本
2. 多 Provider 集成测试
3. 性能测试
4. 文档完善

**验收**:
- [ ] E2E 测试通过
- [ ] 所有 Provider 正常工作
- [ ] 文档完整

---

## 验收标准（进入 Phase 5 的门槛）

- [ ] 所有任务有明确时间估算（≤4h）
- [ ] 任务依赖关系清晰
- [ ] 每个任务有可量化的验收标准
- [ ] 总时间估算合理（约 29 小时）
