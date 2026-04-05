# Kimiz 简化架构提案

**日期**: 2026-04-05  
**状态**: 提案阶段  
**目标**: 在保持竞争力的同时降低复杂度

---

## 背景

通过与 Pi-Mono 的对比分析，发现 Kimiz 当前设计存在以下问题：

1. **过度设计**: 三层记忆、Learning 系统、Smart Routing
2. **功能重复**: Skills 与 Extension 概念重叠
3. **维护成本高**: 复杂的功能需要大量代码和测试
4. **开发周期长**: 难以快速迭代

本提案旨在简化架构，同时保持核心差异化。

---

## 核心原则

### 1. 极简核心
- 核心只保留最基本功能
- 高级功能通过 Extension 实现
- 优先保证稳定性和性能

### 2. 可扩展性
- 强大的 Extension 系统
- 清晰的 API 边界
- 鼓励社区贡献

### 3. 实用主义
- 不追求理论上的完美
- 优先解决实际问题
- 快速迭代，持续改进

---

## 简化后的架构

### 模块结构

```
src/
├── main.zig              # CLI 入口
├── core/
│   ├── types.zig         # 核心类型 (Message, Tool, etc.)
│   ├── session.zig       # 会话管理 (简化版)
│   └── context.zig       # 上下文收集 (简化版)
├── agent/
│   ├── agent.zig         # Agent 核心循环
│   ├── tools.zig         # 工具注册和执行
│   └── builtins/         # 内置工具
│       ├── read.zig
│       ├── write.zig
│       ├── edit.zig
│       ├── bash.zig
│       └── grep.zig
├── ai/
│   ├── provider.zig      # Provider 接口
│   ├── client.zig        # HTTP 客户端
│   └── providers/        # 各 Provider 实现
│       ├── openai.zig
│       ├── anthropic.zig
│       └── ...
├── tui/
│   ├── app.zig           # TUI 应用
│   ├── editor.zig        # 编辑器组件
│   └── widgets.zig       # UI 组件
├── extension/
│   ├── runtime.zig       # WASM 运行时
│   ├── api.zig           # Extension API
│   └── loader.zig        # 加载器
└── utils/
    ├── config.zig        # 配置管理
    └── log.zig           # 日志
```

**代码量目标**: ~8,000 行 (比当前减少 30%)

---

## 关键变更

### 变更 1: 简化 Memory 系统

**当前**: 三层记忆 (Short-term, Working, Long-term)

**简化后**: 单层 Session + Compaction

```zig
// src/core/session.zig
pub const Session = struct {
    id: []const u8,
    messages: std.ArrayList(Message),
    metadata: SessionMetadata,
    
    // 自动压缩
    pub fn compact(self: *Session) !void;
    
    // 分支支持
    pub fn fork(self: *Session) !Session;
    
    // 持久化
    pub fn save(self: Session) !void;
    pub fn load(allocator: std.mem.Allocator, id: []const u8) !Session;
};
```

**收益**:
- 代码减少 60%
- 逻辑更简单
- 性能更好

### 变更 2: 用 Extension 替代 Skills

**当前**: 编译时定义的 Skills 系统

**简化后**: 运行时 Extension 系统

```zig
// src/extension/api.zig
pub const ExtensionApi = struct {
    // 注册工具
    registerTool: *const fn (def: ToolDefinition) void,
    
    // 注册命令
    registerCommand: *const fn (name: []const u8, handler: CommandHandler) void,
    
    // UI 定制
    registerWidget: *const fn (position: WidgetPosition, widget: Widget) void,
    
    // 事件监听
    onEvent: *const fn (event_type: EventType, handler: EventHandler) void,
};

// Extension 示例 (WASM)
// 可以用任何语言编写，编译为 WASM
```

**收益**:
- 动态加载，无需重新编译
- 社区可以贡献 Extensions
- 功能范围无限制

### 变更 3: 移除 Learning 系统

**当前**: 自适应学习用户偏好

**简化后**: 用户手动配置 + Extensions 可选实现

```json
// ~/.kimiz/config.json
{
  "default_model": "claude-sonnet-4",
  "auto_approve_tools": ["read", "grep"],
  "theme": "dark"
}
```

**收益**:
- 移除 400+ 行代码
- 行为可预测
- 用户可控

### 变更 4: 移除 Smart Routing

**当前**: 根据任务自动选择模型

**简化后**: 用户手动选择 + 简单快捷键

```bash
# 手动选择
kimiz --model claude-sonnet-4

# 或在 TUI 中
Ctrl+L  # 打开模型选择器
```

**收益**:
- 移除 300+ 行代码
- 简单直接
- 无意外行为

### 变更 5: 简化 Workspace Context

**当前**: 复杂的技术栈检测、代码模式识别

**简化后**: AGENTS.md + 简单的 Git 信息

```zig
// src/core/context.zig
pub const WorkspaceContext = struct {
    // 读取 AGENTS.md
    agents_md: ?[]const u8,
    
    // Git 信息
    git_branch: ?[]const u8,
    git_status: ?[]const u8,
    
    // 简单的文件树 (顶层)
    file_tree: []const []const u8,
    
    pub fn collect(allocator: std.mem.Allocator) !WorkspaceContext;
    pub fn toPrompt(self: WorkspaceContext) ![]const u8;
};
```

**收益**:
- 代码减少 70%
- 启动更快
- 足够实用

### 变更 6: 简化 Prompt Cache

**当前**: 应用层实现复杂的缓存逻辑

**简化后**: 依赖 Provider 的缓存机制

```zig
// 利用 Anthropic 的 prompt caching
// 或 OpenAI 的 cached tokens
// 不需要应用层复杂实现
```

**收益**:
- 移除 500+ 行代码
- 更可靠
- 性能更好

---

## 保留的差异化功能

### 1. 多 Provider 支持 ✅

继续支持 OpenAI, Anthropic, Google, Kimi 等

### 2. 强大的 TUI ✅

交互式界面是核心竞争力

### 3. Extension 系统 ✅

虽然简化核心，但 Extension 系统要强大

### 4. 会话管理 ✅

分支、恢复、导出等功能

---

## 实施计划

### 阶段 1: 核心重构 (Week 1-3)

**Week 1: 简化基础**
- [ ] 简化 Memory → Session
- [ ] 简化 Workspace Context
- [ ] 移除 Learning 系统
- [ ] 移除 Smart Routing

**Week 2: 修复和优化**
- [ ] 修复编译错误
- [ ] 优化 HTTP 客户端
- [ ] 简化 Provider 实现

**Week 3: 工具简化**
- [ ] 保留 5 个核心工具
- [ ] 简化工具接口
- [ ] 添加工具测试

### 阶段 2: Extension 系统 (Week 4-6)

**Week 4: 设计 API**
- [ ] 设计 Extension API
- [ ] 定义 WASM 接口
- [ ] 编写规范文档

**Week 5: 实现运行时**
- [ ] WASM 运行时集成
- [ ] Extension 加载器
- [ ] 沙箱执行

**Week 6: 测试和文档**
- [ ] 编写示例 Extensions
- [ ] 测试 Extension 系统
- [ ] 编写开发者文档

### 阶段 3: 完善 (Week 7-8)

**Week 7: TUI 完善**
- [ ] 完善交互界面
- [ ] 添加主题支持
- [ ] 优化性能

**Week 8: 测试和发布**
- [ ] 集成测试
- [ ] 性能测试
- [ ] 文档完善
- [ ] 发布准备

---

## 风险评估

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| Extension 系统复杂 | 高 | 高 | 采用成熟的 WASM 运行时 (Wasmtime) |
| 功能减少用户不满 | 中 | 中 | 提供官方 Extensions 补充 |
| 重构引入 Bug | 高 | 中 | 充分测试，逐步迁移 |
| 开发时间超预期 | 中 | 中 | 明确 MVP，分阶段交付 |

---

## 对比总结

| 维度 | 当前 Kimiz | 简化后 Kimiz | Pi-Mono |
|------|-----------|-------------|---------|
| 代码量 | ~11,000 行 | ~8,000 行 | ~30,000 行 |
| 核心功能 | 完整 | 精简 | 极简 |
| 扩展性 | 有限 | 强 | 极强 |
| 开发速度 | 慢 | 快 | 快 |
| 维护成本 | 高 | 中 | 中 |
| 用户体验 | 理论更好 | 实际更好 | 好 |
| 差异化 | Skills, Learning | Extension 生态 | Extension 生态 |

---

## 决策点

### 决策 1: 是否接受此简化提案?

**选项 A**: 接受，按此计划执行  
**选项 B**: 部分接受，保留某些功能  
**选项 C**: 拒绝，继续当前设计

**建议**: 选项 A 或 B

### 决策 2: Extension 系统的优先级?

**选项 A**: 高优先级，先实现 Extension 系统  
**选项 B**: 中优先级，核心稳定后再实现  
**选项 C**: 低优先级，后期再考虑

**建议**: 选项 B

### 决策 3: 是否保留任何 Learning 功能?

**选项 A**: 完全移除  
**选项 B**: 仅保留统计记录  
**选项 C**: 作为 Extension 实现

**建议**: 选项 C

---

## 下一步行动

1. **审查此提案** - 团队讨论，确定方向
2. **创建简化任务** - 将变更分解为具体任务
3. **开始重构** - 从 Memory 系统开始
4. **保持沟通** - 定期评估进展

---

**维护者**: Kimiz Team  
**状态**: 待讨论  
**目标日期**: 2026-04-12 前确定方向
