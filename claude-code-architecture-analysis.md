# Claude Code 源代码架构分析报告

## 概述

本报告基于对 Claude Code 源代码（v2.1.88）的深度分析，包括官方 TypeScript 实现（约 163,000 行）和 nano-claude-code Python 实现（约 5,000 行）。Claude Code 是 Anthropic 开发的 AI 辅助编程工具，采用多层架构设计，支持复杂的工具调用、会话管理和多代理协调。

---

## 1. 整体项目结构和模块划分

### 1.1 目录结构

```
claude-code-source-code/
├── src/
│   ├── main.tsx              # CLI 入口和 REPL 引导 (4,683 行)
│   ├── query.ts              # 核心 Agent 循环 (785KB, 最大文件)
│   ├── QueryEngine.ts        # SDK/Headless 查询生命周期引擎
│   ├── Tool.ts               # 工具接口定义 + buildTool 工厂
│   ├── commands.ts           # Slash 命令定义 (~25K 行)
│   ├── tools.ts              # 工具注册和预设
│   ├── context.ts            # 用户输入上下文处理
│   ├── history.ts            # 会话历史管理
│   ├── cost-tracker.ts       # API 成本跟踪
│   │
│   ├── cli/                  # CLI 基础设施
│   ├── commands/             # ~87 个 slash 命令实现
│   ├── components/           # React/Ink 终端 UI (33 子目录)
│   ├── tools/                # 40+ 工具实现 (44 子目录)
│   ├── services/             # 业务逻辑层 (22 子目录)
│   ├── utils/                # 工具函数库
│   ├── state/                # 应用状态管理
│   ├── types/                # TypeScript 类型定义
│   ├── hooks/                # React Hooks
│   ├── coordinator/          # 多代理协调
│   ├── tasks/                # 任务管理
│   ├── memdir/               # 长期记忆管理
│   └── plugins/              # 插件系统
│
├── docs/                     # 深度分析文档
├── vendor/                   # 第三方依赖
└── types/                    # 全局类型定义
```

### 1.2 模块职责划分

| 模块 | 职责 | 关键文件 |
|------|------|----------|
| **Core** | Agent 循环、查询处理 | `query.ts`, `QueryEngine.ts` |
| **Tools** | 工具定义、注册、执行 | `Tool.ts`, `tools.ts`, `tools/` |
| **Commands** | Slash 命令实现 | `commands.ts`, `commands/` |
| **UI** | 终端界面渲染 | `components/`, `ink/` |
| **Services** | 业务逻辑 | `services/` |
| **State** | 状态管理 | `state/`, `hooks/` |
| **Utils** | 工具函数 | `utils/` |

---

## 2. 核心组件设计

### 2.1 Agent 架构

Claude Code 采用 **基于生成器的 Agent 循环** 设计：

```typescript
// query.ts - 核心 Agent 循环
export async function* query(
  params: QueryParams,
): AsyncGenerator<StreamEvent | Message | ToolUseSummaryMessage, Terminal> {
  // 初始化状态
  let state: State = {
    messages: params.messages,
    toolUseContext: params.toolUseContext,
    // ... 其他状态
  };
  
  // 主循环
  while (true) {
    // 1. 应用上下文压缩
    const { compactionResult } = await deps.autocompact(...);
    
    // 2. 调用 LLM API
    const response = await deps.callClaudeAPI(...);
    
    // 3. 处理工具调用
    if (hasToolCalls(response)) {
      yield* runTools(toolCalls, ...);
    }
    
    // 4. 检查终止条件
    if (shouldTerminate(response)) {
      return terminal;
    }
    
    // 继续下一轮
  }
}
```

**设计亮点：**
- 使用 `AsyncGenerator` 实现流式输出
- 状态通过 `State` 对象在迭代间传递
- 支持工具调用的并发执行

### 2.2 LLM 交互层

```typescript
// QueryEngine.ts - SDK/Headless 接口
export class QueryEngine {
  private config: QueryEngineConfig;
  private mutableMessages: Message[];
  private abortController: AbortController;
  
  async *submitMessage(
    prompt: string | ContentBlockParam[],
    options?: { uuid?: string; isMeta?: boolean },
  ): AsyncGenerator<SDKMessage, void, unknown> {
    // 构建系统提示
    const systemPrompt = await buildEffectiveSystemPrompt(...);
    
    // 执行查询循环
    yield* query({
      messages: this.mutableMessages,
      systemPrompt,
      // ... 其他参数
    });
  }
}
```

**关键特性：**
- 支持流式响应
- 内置重试机制 (`withRetry`)
- 支持模型回退 (fallback)
- Token 预算管理

### 2.3 工具系统设计

#### 2.3.1 工具接口定义

```typescript
// Tool.ts - 核心工具接口
export type Tool<
  Input extends AnyObject = AnyObject,
  Output = unknown,
  P extends ToolProgressData = ToolProgressData,
> = {
  name: string;
  aliases?: string[];              // 向后兼容的别名
  searchHint?: string;             // ToolSearch 关键词
  
  // 核心执行方法
  call(
    args: z.infer<Input>,
    context: ToolUseContext,
    canUseTool: CanUseToolFn,
    parentMessage: AssistantMessage,
    onProgress?: ToolCallProgress<P>,
  ): Promise<ToolResult<Output>>;
  
  // 元数据方法
  description(input: z.infer<Input>, options: {...}): Promise<string>;
  readonly inputSchema: Input;      // Zod 验证模式
  outputSchema?: z.ZodType<unknown>;
  
  // 并发控制
  isConcurrencySafe(input: z.infer<Input>): boolean;
  
  // 权限控制
  isReadOnly(input: z.infer<Input>): boolean;
  isDestructive?(input: z.infer<Input>): boolean;
  
  // 其他元数据
  isEnabled(): boolean;
  shouldDefer?: boolean;           // 延迟加载
  alwaysLoad?: boolean;            // 始终加载
  maxResultSizeChars: number;      // 结果大小限制
  strict?: boolean;                // 严格模式
};
```

#### 2.3.2 工具注册与发现

```typescript
// tools.ts - 工具注册中心
export function getAllBaseTools(): Tools {
  return [
    AgentTool,
    TaskOutputTool,
    BashTool,
    FileReadTool,
    FileEditTool,
    FileWriteTool,
    GlobTool,
    GrepTool,
    WebFetchTool,
    WebSearchTool,
    TodoWriteTool,
    // ... 40+ 工具
  ];
}

// 动态工具池组装
export function assembleToolPool(
  permissionContext: ToolPermissionContext,
  mcpTools: Tools,
): Tools {
  const builtInTools = getTools(permissionContext);
  const allowedMcpTools = filterToolsByDenyRules(mcpTools, permissionContext);
  
  // 去重并排序（保持缓存稳定性）
  return uniqBy(
    [...builtInTools].sort(byName).concat(allowedMcpTools.sort(byName)),
    'name',
  );
}
```

#### 2.3.3 工具执行编排

```typescript
// services/tools/toolOrchestration.ts
export async function* runTools(
  toolUseMessages: ToolUseBlock[],
  assistantMessages: AssistantMessage[],
  canUseTool: CanUseToolFn,
  toolUseContext: ToolUseContext,
): AsyncGenerator<MessageUpdate, void> {
  // 分区：并发安全 vs 非并发安全
  for (const { isConcurrencySafe, blocks } of partitionToolCalls(...)) {
    if (isConcurrencySafe) {
      // 并发执行只读工具
      yield* runToolsConcurrently(blocks, ...);
    } else {
      // 串行执行写入工具
      yield* runToolsSerially(blocks, ...);
    }
  }
}
```

---

## 3. 状态管理和会话系统

### 3.1 应用状态架构

```typescript
// 状态分层设计
AppState (全局状态)
├── toolPermissionContext    # 工具权限上下文
├── mcp                      # MCP 服务器连接
├── fileHistory              # 文件历史快照
├── attribution              # 提交归因信息
└── ...

QueryEngine (会话状态)
├── mutableMessages: Message[]     # 消息历史
├── readFileState: FileStateCache  # 文件读取缓存
├── permissionDenials              # 权限拒绝记录
└── totalUsage                     # Token 使用统计

State (查询循环状态)
├── messages: Message[]
├── toolUseContext: ToolUseContext
├── autoCompactTracking            # 自动压缩跟踪
└── turnCount                      # 轮次计数
```

### 3.2 消息格式

```typescript
// 统一消息格式 (types/message.ts)
type Message = 
  | UserMessage           # 用户输入
  | AssistantMessage      # AI 响应
  | SystemMessage         # 系统消息
  | AttachmentMessage     # 附件（记忆、CLAUDE.md）
  | ProgressMessage       # 进度更新
  | ToolUseSummaryMessage # 工具使用摘要
  | TombstoneMessage;     # 压缩标记

// 消息内容块
interface AssistantMessage {
  type: 'assistant';
  message: {
    content: Array<TextBlock | ToolUseBlock | ThinkingBlock>;
    stop_reason: string | null;
    usage: Usage;
  };
  uuid: string;
  apiError?: string;
}
```

### 3.3 会话持久化

```typescript
// 会话存储策略
- 主会话文件: ~/.claude/sessions/{sessionId}.json
- 边链文件: 用于 Agent 恢复
- 内存存储: 临时会话数据

// 自动保存触发点
- 每次工具调用后
- 上下文压缩后
- 用户输入前
```

---

## 4. 工具系统详解

### 4.1 内置工具列表 (40+)

| 类别 | 工具 | 说明 |
|------|------|------|
| **文件操作** | FileReadTool, FileEditTool, FileWriteTool | 文件读写编辑 |
| **代码搜索** | GlobTool, GrepTool | 文件/内容搜索 |
| **系统执行** | BashTool, PowerShellTool | 命令执行 |
| **Web 访问** | WebFetchTool, WebSearchTool | 网页获取/搜索 |
| **任务管理** | TaskCreateTool, TaskUpdateTool, TaskGetTool, TaskListTool | 任务生命周期 |
| **子代理** | AgentTool | 创建子代理 |
| **代码环境** | NotebookEditTool, REPLTool, LSPTool | 交互式环境 |
| **Git 工作流** | EnterWorktreeTool, ExitWorktreeTool | Git 工作树 |
| **配置权限** | ConfigTool, AskUserQuestionTool | 配置和询问 |
| **记忆规划** | TodoWriteTool, EnterPlanModeTool, ExitPlanModeTool | 规划和待办 |
| **自动化** | ScheduleCronTool, RemoteTriggerTool, SleepTool | 定时和触发 |
| **MCP 集成** | MCPTool, ListMcpResourcesTool, ReadMcpResourceTool | 外部工具 |

### 4.2 工具执行流程

```
用户输入
  ↓
LLM 生成 tool_use 块
  ↓
StreamingToolExecutor.addTool()  # 添加到队列
  ↓
processQueue()  # 检查并发条件
  ↓
runToolUse()    # 执行工具
  ├─ validateInput()   # 输入验证
  ├─ checkPermissions() # 权限检查
  ├─ call()            # 实际执行
  └─ onProgress()      # 进度回调
  ↓
生成 tool_result 块
  ↓
追加到消息历史
```

### 4.3 并发控制策略

```typescript
// 分区策略：将工具调用分为并发安全和非并发安全
function partitionToolCalls(toolUses: ToolUseBlock[]): Batch[] {
  return toolUses.reduce((acc, toolUse) => {
    const tool = findToolByName(tools, toolUse.name);
    const isConcurrencySafe = tool?.isConcurrencySafe(parsedInput);
    
    if (isConcurrencySafe && lastBatch?.isConcurrencySafe) {
      // 合并到当前并发批次
      lastBatch.blocks.push(toolUse);
    } else {
      // 创建新批次
      acc.push({ isConcurrencySafe, blocks: [toolUse] });
    }
  }, []);
}

// 默认并发限制
const MAX_TOOL_USE_CONCURRENCY = 10;
```

---

## 5. 提示词工程 (Prompt Engineering)

### 5.1 系统提示结构

```
系统提示 = 
  [静态部分 - 全局缓存]
  ├── 身份说明 (You are an interactive agent...)
  ├── 系统说明 (System)
  ├── 任务指南 (Doing tasks)
  ├── 谨慎执行 (Executing actions with care)
  ├── 工具使用 (Using your tools)
  ├── 动态边界标记 (__SYSTEM_PROMPT_DYNAMIC_BOUNDARY__)
  │
  [动态部分 - 会话特定]
  ├── 会话特定指南 (Session-specific guidance)
  ├── 输出风格 (Output Style)
  ├── 语言设置 (Language)
  ├── MCP 说明 (MCP Instructions)
  └── 工具定义 (Tool Schemas)
```

### 5.2 提示词构建流程

```typescript
// constants/prompts.ts
export async function getSystemPrompt(
  tools: Tools,
  mainLoopModel: string,
  additionalWorkingDirectories: string[],
  mcpClients: MCPServerConnection[],
): Promise<string[]> {
  const sections = [
    // 1. 静态部分（可缓存）
    getSimpleIntroSection(outputStyleConfig),
    getSimpleSystemSection(),
    getSimpleDoingTasksSection(),
    getActionsSection(),
    getUsingYourToolsSection(enabledTools),
    SYSTEM_PROMPT_DYNAMIC_BOUNDARY,  // 缓存边界
    
    // 2. 动态部分（会话特定）
    getSessionSpecificGuidanceSection(enabledTools, skillToolCommands),
    getOutputStyleSection(outputStyleConfig),
    getLanguageSection(languagePreference),
    getMcpInstructionsSection(mcpClients),
    getToolDefinitionsSection(tools, ...),  // 工具 JSON Schema
  ];
  
  return sections.filter(Boolean);
}
```

### 5.3 上下文注入

```typescript
// context.ts - 动态上下文
export const getUserContext = memoize(async () => {
  const claudeMd = await getClaudeMds();  // CLAUDE.md 内容
  return {
    claudeMd,
    currentDate: `Today's date is ${getLocalISODate()}.`,
  };
});

export const getSystemContext = memoize(async () => {
  const gitStatus = await getGitStatus();  // Git 状态
  return {
    gitStatus,
  };
});
```

### 5.4 提示词缓存策略

```typescript
// 缓存断点策略
const SYSTEM_PROMPT_DYNAMIC_BOUNDARY = '__SYSTEM_PROMPT_DYNAMIC_BOUNDARY__';

// 服务器端缓存策略
// - 边界前：scope='global' - 跨组织共享
// - 边界后：scope='organization' 或 'user' - 会话特定
```

---

## 6. 错误处理和重试机制

### 6.1 重试策略架构

```typescript
// services/api/withRetry.ts
export async function* withRetry<T>(
  getClient: () => Promise<Anthropic>,
  operation: (client: Anthropic, attempt: number, context: RetryContext) => Promise<T>,
  options: RetryOptions,
): AsyncGenerator<SystemAPIErrorMessage, T> {
  const maxRetries = getMaxRetries(options);
  
  for (let attempt = 1; attempt <= maxRetries + 1; attempt++) {
    try {
      return await operation(client, attempt, retryContext);
    } catch (error) {
      // 错误分类和处理
      if (isRetryableError(error)) {
        const delay = calculateBackoff(attempt, error);
        yield createErrorMessage(error);
        await sleep(delay);
        continue;
      }
      throw error;
    }
  }
}
```

### 6.2 错误分类

| 错误类型 | 处理策略 | 说明 |
|----------|----------|------|
| 529 Overloaded | 最多重试 3 次 | 服务器过载 |
| 429 Rate Limit | 按 Retry-After 等待 | 速率限制 |
| 401/403 Auth | 刷新 Token 后重试 | 认证错误 |
| ECONNRESET | 禁用 Keep-Alive 后重试 | 连接重置 |
| max_output_tokens | 自动恢复循环 | 输出限制 |
| prompt_too_long | 触发上下文压缩 | 提示过长 |

### 6.3 模型回退机制

```typescript
// 当主模型失败时回退到备用模型
export class FallbackTriggeredError extends Error {
  constructor(
    public readonly originalModel: string,
    public readonly fallbackModel: string,
  ) {
    super(`Model fallback triggered: ${originalModel} -> ${fallbackModel}`);
  }
}

// 回退触发条件
- 连续 529 错误超过阈值
- 特定模型不可用
- 用户指定的回退模型
```

---

## 7. 并发和并行处理

### 7.1 工具并发执行

```typescript
// StreamingToolExecutor.ts
export class StreamingToolExecutor {
  private tools: TrackedTool[] = [];
  private siblingAbortController: AbortController;
  
  addTool(block: ToolUseBlock, assistantMessage: AssistantMessage): void {
    // 添加到队列并立即处理
    this.tools.push({
      id: block.id,
      block,
      status: 'queued',
      isConcurrencySafe: tool.isConcurrencySafe(input),
    });
    void this.processQueue();
  }
  
  private canExecuteTool(isConcurrencySafe: boolean): boolean {
    const executing = this.tools.filter(t => t.status === 'executing');
    return executing.length === 0 || 
           (isConcurrencySafe && executing.every(t => t.isConcurrencySafe));
  }
}
```

### 7.2 并行读取优化

```typescript
// 文件预取
using pendingMemoryPrefetch = startRelevantMemoryPrefetch(
  state.messages,
  state.toolUseContext,
);

// 技能发现预取
const pendingSkillPrefetch = skillPrefetch?.startSkillDiscoveryPrefetch(
  null,
  messages,
  toolUseContext,
);
```

### 7.3 生成器并发模式

```typescript
// utils/generators.ts - 并发执行生成器
export async function* all<T>(
  generators: Array<AsyncGenerator<T>>,
  concurrency: number,
): AsyncGenerator<T> {
  const executing = new Set<Promise<IteratorResult<T>>>();
  const iterators = generators.map(g => [g, g.next()] as const);
  
  // 使用 Promise.race 实现并发
  while (executing.size > 0 || iterators.length > 0) {
    const { value, done } = await Promise.race(executing);
    // 处理结果...
  }
}
```

---

## 8. 配置和扩展机制

### 8.1 配置系统

```typescript
// 配置层级（优先级从低到高）
1. 默认值
2. 全局配置文件 (~/.claude/config.json)
3. 项目配置 (.claude/config.json)
4. 环境变量 (CLAUDE_CODE_*)
5. 命令行参数
6. 运行时设置
```

### 8.2 插件系统

```typescript
// plugins/ 目录结构
plugins/
├── builtinPlugins.ts       # 内置插件
├── pluginLoader.ts         # 插件加载器
└── loadPluginCommands.ts   # 插件命令加载

// 插件接口
interface Plugin {
  name: string;
  version: string;
  commands?: Command[];
  tools?: Tool[];
  hooks?: Hooks;
}
```

### 8.3 MCP (Model Context Protocol) 集成

```typescript
// 外部工具通过 MCP 协议集成
interface MCPServerConnection {
  name: string;
  tools: Tool[];
  resources: ServerResource[];
}

// MCP 工具动态加载
const mcpTools = await loadMCPTools(serverConfig);
const toolPool = assembleToolPool(permissionContext, mcpTools);
```

### 8.4 技能系统 (Skills)

```typescript
// 技能定义示例 (CLAUDE.md)
---
name: commit
triggers: ["/commit"]
description: "Create a git commit"
---

Review staged changes and create a commit with a conventional message.

## Steps
1. Run `git diff --staged` to see changes
2. Analyze the diff
3. Write a commit message
4. Execute `git commit`
```

---

## 9. 测试策略

### 9.1 测试架构

```
tests/
├── unit/                   # 单元测试
│   ├── tools/             # 工具测试
│   ├── commands/          # 命令测试
│   └── utils/             # 工具函数测试
├── integration/           # 集成测试
│   ├── api/               # API 集成
│   └── mcp/               # MCP 集成
└── e2e/                   # 端到端测试
```

### 9.2 测试模式

```typescript
// 依赖注入模式
export type QueryDeps = {
  callClaudeAPI: typeof callClaudeAPI;
  autocompact: typeof autoCompactIfNeeded;
  microcompact: typeof microcompact;
  uuid: () => string;
};

export const productionDeps = (): QueryDeps => ({
  callClaudeAPI,
  autocompact: autoCompactIfNeeded,
  microcompact,
  uuid: () => randomUUID(),
});

// 测试时注入 mock
test('query loop', async () => {
  const mockDeps: QueryDeps = {
    callClaudeAPI: jest.fn(),
    autocompact: jest.fn(),
    // ...
  };
  
  const result = await query(params, mockDeps);
});
```

### 9.3 关键测试场景

| 场景 | 测试方法 | 说明 |
|------|----------|------|
| 工具执行 | 单元测试 | 模拟工具输入输出 |
| 权限系统 | 集成测试 | 验证权限决策流程 |
| 上下文压缩 | 集成测试 | 验证压缩边界条件 |
| API 重试 | 单元测试 | 模拟各种错误码 |
| 并发执行 | 集成测试 | 验证并发安全 |

---

## 10. 架构图

### 10.1 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Interface                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │  REPL/CLI   │  │   SDK API   │  │  IDE Extensions         │  │
│  └──────┬──────┘  └──────┬──────┘  └───────────┬─────────────┘  │
└─────────┼────────────────┼─────────────────────┼────────────────┘
          │                │                     │
          └────────────────┴──────────┬──────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                      QueryEngine / Session                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │   Message   │  │  FileState  │  │  Permission Context     │  │
│  │   History   │  │    Cache    │  │                         │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
└──────────────────────────────────┬──────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Agent Loop (query.ts)                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │   Context   │  │   LLM API   │  │   Tool Orchestration    │  │
│  │  Compression│  │    Call     │  │   (runTools)            │  │
│  └─────────────┘  └──────┬──────┘  └───────────┬─────────────┘  │
└──────────────────────────┼─────────────────────┼────────────────┘
                           │                     │
                           ▼                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Tool System                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐   │
│  │ File Ops │ │ Bash Cmd │ │ Web Tools│ │   Agent Tool     │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────────┘   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐   │
│  │  Search  │ │   LSP    │ │   MCP    │ │   Task Tools     │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 10.2 工具执行流程

```
┌──────────┐     ┌──────────────┐     ┌──────────────┐
│  LLM API │────▶│ ToolUseBlock │────▶│   validate   │
└──────────┘     └──────────────┘     └──────┬───────┘
                                             │
                              ┌──────────────┼──────────────┐
                              ▼              ▼              ▼
                        ┌─────────┐    ┌─────────┐    ┌─────────┐
                        │  Valid  │    │ Invalid │    │  Deny   │
                        └────┬────┘    └────┬────┘    └────┬────┘
                             │              │              │
                             ▼              ▼              ▼
                        ┌─────────┐    ┌─────────┐    ┌─────────┐
                        │checkPerm│    │ Error   │    │  Deny   │
                        └────┬────┘    │ Message │    │ Message │
                             │         └─────────┘    └─────────┘
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
        ┌─────────┐    ┌─────────┐    ┌─────────┐
        │  Allow  │    │   Ask   │    │  Deny   │
        └────┬────┘    └────┬────┘    └────┬────┘
             │              │              │
             ▼              ▼              ▼
        ┌─────────┐    ┌─────────┐    ┌─────────┐
        │ execute │    │  Prompt │    │  Deny   │
        │  tool   │    │  User   │    │ Message │
        └────┬────┘    └────┬────┘    └─────────┘
             │              │
             │         ┌────┴────┐
             │         ▼         ▼
             │    ┌────────┐ ┌────────┐
             │    │ Allow  │ │  Deny  │
             │    └───┬────┘ └───┬────┘
             │        │          │
             └────────┴──────────┘
                      │
                      ▼
               ┌────────────┐
               │ ToolResult │
               └────────────┘
```

---

## 11. 对 Kimiz 项目的建议

### 11.1 值得借鉴的设计模式

1. **生成器-based Agent 循环**
   - 使用 `AsyncGenerator` 实现流式输出
   - 状态在迭代间传递，避免全局状态污染
   - 支持中间结果 yield

2. **工具系统架构**
   - 统一的 Tool 接口定义
   - 并发安全标记 (`isConcurrencySafe`)
   - 权限控制集成到工具层
   - 进度回调支持

3. **上下文压缩策略**
   - 多级压缩：microcompact → autocompact → context collapse
   - 保留关键消息边界
   - Token 使用跟踪

4. **错误处理和重试**
   - 错误分类和策略化重试
   - 指数退避 + 抖动
   - 模型回退机制

5. **提示词工程**
   - 静态/动态部分分离（缓存优化）
   - 系统提示模块化
   - 上下文注入（CLAUDE.md, Git 状态）

### 11.2 简化建议

对于 Kimiz 项目，建议从 nano-claude-code 的简化架构开始：

```
kimiz/
├── src/
│   ├── main.zig           # CLI 入口
│   ├── agent.zig          # Agent 循环（简化版）
│   ├── tools/
│   │   ├── mod.zig        # 工具注册
│   │   ├── file.zig       # 文件操作
│   │   ├── bash.zig       # 命令执行
│   │   └── search.zig     # 搜索工具
│   ├── llm/
│   │   ├── client.zig     # LLM 客户端
│   │   └── streaming.zig  # 流式处理
│   ├── context.zig        # 上下文管理
│   └── config.zig         # 配置管理
```

### 11.3 关键实现优先级

1. **Phase 1: 核心循环**
   - Agent 循环（query 函数等价物）
   - LLM 客户端（流式响应）
   - 基本工具（Read, Write, Bash）

2. **Phase 2: 工具系统**
   - 工具注册表
   - 并发执行
   - 权限控制

3. **Phase 3: 会话管理**
   - 消息历史
   - 上下文压缩
   - 会话持久化

4. **Phase 4: 高级功能**
   - 子代理
   - 技能系统
   - MCP 集成

---

## 12. 参考资源

- **Claude Code 官方源码**: `/tmp/claude-code-source/claude-code-source-code/`
- **Nano Claude Code**: `/tmp/claude-code-source/nano-claude-code/`
- **Claw Code** (Python 重写): `/tmp/claude-code-source/claw-code/`
- **架构文档**: `/tmp/claude-code-source/claude-code-source-code/docs/`

---

*报告生成时间: 2026-04-05*
*分析源码版本: Claude Code v2.1.88*
