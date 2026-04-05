### Task-DOCS-004: 完善 API 文档
**状态**: pending
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 4h

**描述**:
为核心模块添加完整的 API 文档，包括使用示例、参数说明、错误处理等。

**需要文档化的模块**:

1. **Core Types** (`src/core/root.zig`)
   - Message 类型及其变体
   - Model 配置
   - Tool 定义
   - Context 使用

2. **AI Module** (`src/ai/root.zig`)
   - Ai 客户端初始化
   - complete 和 stream 方法
   - 错误处理

3. **Agent Module** (`src/agent/root.zig`)
   - Agent 初始化
   - 事件系统
   - 工具注册

4. **Memory Module** (`src/memory/root.zig`)
   - 三层记忆系统
   - 记忆存储和检索
   - 记忆整合

5. **Skills Module** (`src/skills/root.zig`)
   - 技能定义
   - 技能注册
   - 技能执行

**文档格式**:
```zig
/// Complete a chat request with the AI model.
///
/// Parameters:
///   - ctx: The context containing model, messages, and configuration
///
/// Returns:
///   - AssistantMessage on success
///   - AiError on failure (see AiError for possible errors)
///
/// Example:
/// ```zig
/// var ai_client = ai.Ai.init(allocator);
/// defer ai_client.deinit();
///
/// const ctx = Context{
///     .model = model,
///     .messages = &messages,
///     .temperature = 0.7,
/// };
///
/// const response = try ai_client.complete(ctx);
/// ```
pub fn complete(self: *Self, ctx: core.Context) !core.AssistantMessage {
```

**验收标准**:
- [ ] 所有公共 API 有文档注释
- [ ] 包含使用示例
- [ ] 参数和返回值说明
- [ ] 错误情况说明
- [ ] 生成文档（zig build docs）

**依赖**:
- 无

**阻塞**:
- 无直接阻塞

**笔记**:
良好的文档对开源项目至关重要。可以使用 `zig build docs` 生成 HTML 文档。
