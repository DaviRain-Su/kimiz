# T-123-LESSONS: 建立 lessons-learned.md 和多 Agent 一致性机制

**任务类型**: Implementation  
**优先级**: P2  
**预计耗时**: 3h  
**前置任务**: T-122-PROMPT

---

## 参考文档

- [Yoyo Evolve](../research/YOYO-EVOLVE-ANALYSIS.md) - 自进化循环与经验教训沉淀
- [Open Multi-Agent Architecture](../research/open-multi-agent-architecture-analysis.md) - 多 Agent 通信与一致性
- [TigerBeetle Patterns](../research/TIGERBEETLE-PATTERNS-ANALYSIS.md) - 状态机与原子操作

---

## 背景

yage.ai 的文章指出，长期记忆不仅是单个 Agent 的"烂笔头"，还是 **Multi-Agent 之间的通信渠道和 single source of truth**。当多个 Agent 同时工作时，必须保证文档的一致性。

本任务负责建立：
1. 项目级别的经验教训文档 `docs/lessons-learned.md`
2. 文件级锁机制，防止多 Agent 同时写坏文档
3. 变更广播机制，让新启动的 Agent 自动获取最新知识

---

## 需要实现的内容

### 1. `docs/lessons-learned.md`

创建文件并定义格式：

```markdown
# KimiZ Lessons Learned

> 这是项目的长期记忆库。所有 Agent 和人类开发者共享此文档。
> 新增记录请追加到最前面（逆时序）。

---

## 2026-04-06 | Zig 版本策略

**分类**: 架构决策  
**来源**: FIX-ZIG-015 回滚事件  
**教训**: 项目必须使用 Zig 0.16 API。在环境未统一前，不要尝试向后兼容 0.15。Makefile 已固定使用 `$(HOME)/zig-0.16.0-dev/zig`。

---

## 2026-04-05 | Agent Loop 错误处理

**分类**: 踩坑记录  
**来源**: NullClaw 分析报告  
**教训**: 底层错误必须映射到 `AiError`，禁止 `catch unreachable`。Agent 的每次工具调用都必须有可读的 trace。
```

**格式要求**:
- 每条记录必须有：日期、分类、来源、教训正文
- 分类可选：架构决策、踩坑记录、性能优化、API 选择、安全提醒

### 2. `add_lesson` 工具

Agent 可以直接把经验教训写入 `docs/lessons-learned.md`。

**输入参数**:
```json
{
  "category": "踩坑记录",
  "source": "T-092-VERIFY",
  "lesson": "delegate 工具的注册必须在 Agent init 之后立即完成，否则 LLM 看不到该工具。"
}
```

**实现要求**:
- 自动追加时间戳
- 写入文件顶部（保持逆时序）
- 原子写操作

### 3. 文件级锁机制

在 `src/utils/document_lock.zig` 中实现：

```zig
pub const DocumentLock = struct {
    pub fn acquire(path: []const u8, timeout_ms: u32) !void;
    pub fn release(path: []const u8) void;
};
```

**策略**:
- 使用 `.lock` 文件（如 `docs/lessons-learned.md.lock`）
- `acquire` 尝试创建 `.lock` 文件，如果已存在则轮询等待
- `timeout_ms` 防止死锁
- `release` 删除 `.lock` 文件

**使用场景**:
- `update_task_log` 在写任务文件前先 `acquire`
- `add_lesson` 在写 `lessons-learned.md` 前先 `acquire`

### 4. 变更广播机制

在 `src/agent/agent.zig` 的 `Agent.init()` 中加入：

```zig
// 每次 Agent 初始化时，自动读取 lessons-learned.md 的最新 N 条记录
// 注入到 System Prompt 的末尾作为 "Shared Knowledge"
```

**v1 实现**:
- 读取 `docs/lessons-learned.md`
- 提取最新的 5 条记录
- 作为 "Shared Lessons" 注入 System Prompt

---

## 集成要求

1. 创建 `docs/lessons-learned.md`（至少预填充 1 条关于 Zig 0.16 的决策记录）
2. 创建 `src/utils/document_lock.zig`
3. 创建 `src/agent/tools/lesson_tools.zig`（实现 `add_lesson`）
4. 在 `update_task_log` 和 `add_lesson` 中集成 `DocumentLock`
5. 在 `Agent.init()` 中集成 lessons 读取逻辑

---

## 验收标准

- [x] `docs/lessons-learned.md` 已创建并包含有效格式
- [x] `DocumentLock` 能通过并发测试（两个线程争锁，不会写坏文件）
- [x] `add_lesson` 能原子性地写入 `lessons-learned.md`
- [x] Agent 启动时自动读取最新 lessons 并注入 prompt
- [x] 所有新增代码通过 `zig build test`

---

## Log

- `2026-04-06` — 开始 T-123 实现，状态 `todo` → `implement`
- `2026-04-06` — 创建 `docs/lessons-learned.md`，预填充 Zig 0.16 相关经验教训
- `2026-04-06` — 创建 `src/utils/document_lock.zig` 实现文件锁
- `2026-04-06` — 创建 `src/agent/tools/lesson_tools.zig` 实现 add_lesson 工具
- `2026-04-06` — 注册 document_lock 到 utils/root.zig，lesson_tools 到 agent/root.zig
- `2026-04-06` — 在 cli/root.zig 注册 add_lesson 到 Agent 工具表
- `2026-04-06` — `make build` 和 `make test` 全部通过
- `2026-04-06` — 完成实现，状态改为 `done`
