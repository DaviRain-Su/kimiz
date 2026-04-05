# Kimi 特性利用路线图

**目标**: 充分利用 Kimi (kimi-k2.5) 的独特特性  
**核心特性**:
- 中文优化 - 更好的中文编程体验
- 长上下文 (200k) - 大代码库理解

---

## Kimi 特性分析

### 1. 中文优化

**优势**:
- 中文编程术语理解更好
- 中文注释生成更准确
- 中文技术对话更流畅

**利用场景**:
```
用户: "帮我重构这个函数，让它更高效"
Kimi: 理解中文意图，生成优化后的代码 + 中文解释
```

### 2. 长上下文 (200k tokens)

**优势**:
- 可放入整个中型项目的代码
- 跨文件理解能力
- 减少 RAG 依赖

**利用场景**:
```
把整个 src/ 目录作为上下文发送给 Kimi
→ Kimi 可以理解整个项目架构
→ 不需要频繁搜索文件
```

---

## MVP 阶段 Kimi 特性利用

### 阶段 A: 基础 Kimi 支持

**MVP-A3-KIMI**: 优化 Kimi 配置

```zig
// src/ai/models.zig - Kimi 模型配置
pub const kimi_k25 = Model{
    .id = "kimi-k2.5",
    .provider = .{ .known = .kimi },
    .api = .{ .known = .@"openai-completions" },
    .context_window = 256_000,  // 256k 上下文
    .max_tokens = 8192,
    .cost = .{
        .input_token_cost = 0.5,   // 非常便宜
        .output_token_cost = 2.0,
    },
    .supports_thinking = true,
    .supports_tools = true,
};
```

**特性**:
- [ ] 默认启用流式输出
- [ ] 配置合理的 thinking_budget
- [ ] 支持 reasoning tokens 显示

---

### 阶段 B: 长上下文优化

**MVP-B5-KIMI**: 长上下文利用

**问题**: 当前实现每次只发送少量上下文

**优化**:
```zig
// 利用 Kimi 的 256k 上下文
pub fn buildLongContext(allocator: Allocator, workspace: WorkspaceInfo) !Context {
    // 收集更多文件到上下文
    // - 当前编辑文件
    // - 相关依赖文件
    // - 项目结构信息
    // - 最多利用 200k tokens
}
```

**实现**:
- [ ] 智能文件收集（利用长上下文）
- [ ] 跨文件理解支持
- [ ] 项目架构感知

**验收标准**:
- [ ] 可以一次性发送 50+ 文件到 Kimi
- [ ] Kimi 能回答跨文件的问题
- [ ] 上下文构建 < 500ms

---

### 阶段 C: 中文体验优化

**MVP-C6-KIMI**: 中文编程体验

**优化点**:

1. **中文 Prompt 模板**
```
系统提示词:
"你是一个专业的中文编程助手。请用中文回答技术问题，
代码注释优先使用中文。"
```

2. **中文工具描述**
```zig
// tools/read_file.zig
.description = "读取文件内容。支持大文件分块读取，
可以指定行范围。适用于查看代码、配置文件等。"
```

3. **中文错误消息**
```zig
// 错误提示
"❌ 文件未找到: {path}"
"✅ 成功读取 {lines} 行"
"🤔 正在分析代码..."
```

**实现**:
- [ ] 中文系统提示词
- [ ] 中文工具描述
- [ ] 中文 CLI 输出
- [ ] 中文错误提示

---

## 进阶 Kimi 特性（MVP 后）

### 特性 1: Kimi Code API 深度集成

**Kimi Code API 优势**:
- 专为代码优化
- 支持 Plan/Normal 模式
- 内置代码理解能力

**实现**:
```zig
// 自动选择合适的 API
if (task.isCodeIntensive()) {
    useKimiCodeApi(.plan);  // Plan 模式深度思考
} else {
    useStandardApi();        // 快速响应
}
```

### 特性 2: 智能上下文管理

**利用长上下文**:
```
不需要 RAG，直接把整个项目发过去
→ Kimi 自己找相关代码
→ 减少复杂度
```

**实现**:
- [ ] 项目级上下文打包
- [ ] 增量上下文更新
- [ ] 智能文件优先级

### 特性 3: 中文代码审查

**场景**:
```
用户: "审查这段代码"
Kimi: 用中文指出问题 + 给出修改建议 + 解释原因
```

---

## 与 MVP 的整合

### 当前 MVP 任务调整

| 原任务 | 调整 | Kimi 特性 |
|--------|------|-----------|
| MVP-A3 | 设置默认 Kimi | 启用流式 + thinking |
| MVP-A2 | 简化 Memory | 利用长上下文减少记忆依赖 |
| MVP-B1 | 错误处理 | 中文错误消息 |
| MVP-B4 | 文档 | 中文文档 |

### 新增 Kimi 专属任务

```
MVP-B5: Kimi 长上下文优化 (6h)
├── 大文件收集
├── 项目上下文打包
└── 跨文件理解

MVP-C6: Kimi 中文体验 (4h)
├── 中文 Prompt 模板
├── 中文 CLI 输出
└── 中文错误消息
```

---

## 实施建议

### 今天可以做

1. **设置默认 Kimi** (5 分钟)
   ```zig
   error.NotFound => "kimi-k2.5"
   ```

2. **启用 thinking 显示** (10 分钟)
   ```zig
   // 显示 Kimi 的思考过程
   if (details.reasoning_tokens > 0) {
       print("🤔 思考中... ({d} tokens)\n", .{details.reasoning_tokens});
   }
   ```

### 本周做

3. **长上下文收集** (6 小时)
   - 收集更多文件到上下文
   - 测试 200k 上下文效果

4. **中文体验** (4 小时)
   - 中文提示词
   - 中文 CLI 输出

---

## 竞争优势

利用 Kimi 特性后：

| 特性 | Claude Code | Kimi Code | kimiz + Kimi |
|------|-------------|-----------|--------------|
| 中文体验 | 一般 | 好 | **优秀** |
| 长上下文利用 | 200k | 200k | **256k** |
| 启动速度 | 1-2s | 网络 | **<100ms** |
| 成本 | 高 | 低 | **最低** |
| 本地处理 | 否 | 否 | **是** |

---

**关键洞察**: 
> 与其做"支持多 Provider 的通用 Agent"，不如做"把 Kimi 用到极致的专用 Agent"

MVP 阶段专注 Kimi，把长上下文和中文优化做到极致，这就是差异化优势。

---

**创建日期**: 2026-04-05  
**关联**: MVP-ROADMAP.md, PRD 文档
