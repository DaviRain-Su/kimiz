# TODO 任务汇总

**生成日期**: 2026-04-05  
**扫描范围**: src/**/*.zig  
**总计 TODO**: 24 个

---

## 按优先级分类

### P0 - 阻塞级别 (2个任务)

| 任务 | 文件 | 描述 | 预计 |
|------|------|------|------|
| TASK-TODO-001 | google.zig, kimi.zig, anthropic.zig | AI Provider JSON 序列化 | 6h |
| ~~TASK-TODO-002~~ | http.zig | ~~完整 HTTP 客户端实现~~ | ✅ 已完成 |

**关键路径**:
```
TASK-TODO-002 (HTTP) ✅ 已完成 → TASK-TODO-001 (JSON) → API 调用正常工作
```

### P1 - 高优先级 (2个任务)

| 任务 | 文件 | 描述 | 预计 |
|------|------|------|------|
| TASK-TODO-003 | workspace/context.zig | Workspace Git 上下文 | 4h |
| TASK-TODO-004 | extension/root.zig | Extension 核心功能 | 8h |

### P2 - 中优先级 (2个任务)

| 任务 | 文件 | 描述 | 预计 |
|------|------|------|------|
| TASK-TODO-005 | learning/root.zig | Learning 高级功能 | 6h |
| TASK-TODO-006 | harness/*.zig | Harness 高级功能 | 8h |

---

## 按文件分类

### AI Providers (7 TODOs)
- **google.zig**: 2 TODOs - JSON 序列化
- **kimi.zig**: 1 TODO - JSON 序列化
- **anthropic.zig**: 2 TODOs - JSON 序列化

### Core Infrastructure (8 TODOs)
- **http.zig**: 2 TODOs - HTTP 客户端
- **workspace/context.zig**: 7 TODOs - Git 功能

### Advanced Features (9 TODOs)
- **learning/root.zig**: 3 TODOs - 学习功能
- **extension/root.zig**: 4 TODOs - Extension 系统
- **harness/*.zig**: 2 TODOs - Harness 功能

---

## 关键依赖关系

```
TASK-TODO-002 (HTTP Client)
    ├── TASK-TODO-001 (JSON 序列化) - 需要 HTTP 发送请求
    ├── TASK-TODO-003 (Workspace) - 可能需要 HTTP
    └── TASK-TODO-004 (Extension) - 需要 HTTP 下载

TASK-TODO-001 (JSON 序列化)
    ├── TASK-TODO-005 (Learning) - 需要 JSON 存储
    └── TASK-TODO-006 (Harness) - 需要 JSON 存储
```

---

## 推荐执行顺序

### 阶段 1: 核心基础设施 (本周)
1. **TASK-TODO-002** - HTTP 客户端 (8h)
2. **TASK-TODO-001** - JSON 序列化 (6h)

**目标**: API 调用正常工作

### 阶段 2: 功能恢复 (下周)
3. **TASK-TODO-003** - Workspace Git 上下文 (4h)
4. **TASK-TODO-004** - Extension 核心功能 (8h)

**目标**: 完整 Workspace 和 Extension 支持

### 阶段 3: 高级功能 (第3周)
5. **TASK-TODO-005** - Learning 高级功能 (6h)
6. **TASK-TODO-006** - Harness 高级功能 (8h)

**目标**: 增强功能完整

---

## 详细任务清单

### 已完成扫描的文件

- [x] src/ai/providers/google.zig
- [x] src/ai/providers/kimi.zig
- [x] src/ai/providers/anthropic.zig
- [x] src/http.zig
- [x] src/workspace/context.zig
- [x] src/learning/root.zig
- [x] src/memory/root.zig
- [x] src/agent/agent.zig
- [x] src/extension/root.zig
- [x] src/harness/context_truncation.zig
- [x] src/harness/reasoning_trace.zig
- [x] src/harness/agent_linter.zig

### 包含 TODO 的文件 (按数量排序)

1. **src/workspace/context.zig** - 7 TODOs
2. **src/extension/root.zig** - 4 TODOs
3. **src/learning/root.zig** - 3 TODOs
4. **src/ai/providers/google.zig** - 2 TODOs
5. **src/ai/providers/anthropic.zig** - 2 TODOs
6. **src/http.zig** - 2 TODOs
7. **src/harness/context_truncation.zig** - 1 TODO
8. **src/harness/reasoning_trace.zig** - 1 TODO
9. **src/ai/providers/kimi.zig** - 1 TODO
10. **src/agent/agent.zig** - 1 TODO
11. **src/memory/root.zig** - 2 TODOs

---

## 下一步行动

1. **立即开始** TASK-TODO-002 (HTTP 客户端)
   - 这是所有其他任务的基础
   
2. **并行准备** TASK-TODO-001 (JSON 序列化)
   - 研究 Zig 0.16 std.json API

3. **本周目标**:
   - [ ] HTTP 客户端可以发送基本请求
   - [ ] 至少一个 Provider 的 JSON 序列化完成
   - [ ] 可以调用真实 API

---

**总预计工时**: 40 小时  
**关键路径**: TASK-TODO-002 → TASK-TODO-001 → API 测试
