# MVP 阶段 A: 稳定核心任务

**目标**: 可用的 REPL + 文件工具，使用 **Kimi (kimi-k2.5)** 作为默认模型  
**时间**: 2 周  
**优先级**: P0 (最高)

## 前置条件 ✅ 已完成 (2026-04-05)

- [x] 编译通过 (`zig build` + `zig build test`)
- [x] HTTP Client 实现（使用 Zig 0.16 `std.http.Client`）
- [x] IoManager 初始化（通过 `std.process.Init.io`）
- [x] Zig 0.16 API 迁移完成

---

## 任务清单

### MVP-A1: 修复 Agent 循环稳定性

**状态**: ✅ completed  
**预计工时**: 8 小时  
**指派给**: TBD

**问题描述**:
- tool_calls 解析不稳定
- 消息历史管理有 bug
- 错误恢复不完善

**实施步骤**:
1. 修复 tool_calls JSON 解析错误
2. 修复消息历史越界问题
3. 添加错误恢复机制（单次错误不崩溃）
4. 测试连续 10 轮对话

**验收标准**:
- [x] REPL 可以连续对话 10 轮无错误
- [x] 单次工具错误不导致崩溃
- [x] 消息历史正确维护

---

### MVP-A2: 简化 Memory 系统

**状态**: ✅ completed  
**预计工时**: 6 小时  
**指派给**: TBD

**问题描述**:
- 三层记忆架构（短/工/长）过度设计
- 当前只有类型定义，无实际存储

**实施步骤**:
1. 移除三层记忆架构
2. 实现单层 Session 记忆
3. 修复内存泄漏
4. 简化 Memory API

**代码变更**:
```zig
// 之前：三层记忆
ShortTermMemory / WorkingMemory / LongTermMemory

// 之后：单层 Session 记忆
SessionMemory: 仅保存当前会话上下文
```

**验收标准**:
- [x] 同一会话内上下文连贯
- [x] 内存使用 < 100MB
- [x] 无内存泄漏（arena 分配器）

---

### MVP-A3: 默认使用 Kimi（保留其他 Provider）

**状态**: ✅ completed (默认模型已设为 kimi-k2.5)  
**预计工时**: 2 小时  
**指派给**: TBD

**目标**: 默认使用 Kimi (kimi-k2.5)，保留其他 Provider 代码

**实施步骤**:
1. 更新 CLI 默认模型为 `kimi-k2.5`
2. 保留所有 Provider 代码（暂不删除）
3. 测试 Kimi 流式响应

**代码变更**:
```zig
// src/cli/root.zig
const model_id = getEnvVar(allocator, "KIMIZ_MODEL") catch |err| switch (err) {
    error.NotFound => "kimi-k2.5",  // 默认 Kimi
    else => return err,
};
```

**验收标准**:
- [x] 默认使用 kimi-for-coding 模型
- [x] 保留其他 Provider（可通过环境变量切换）
- [x] Kimi 流式响应稳定

---

### MVP-A4: 工具可靠性

**状态**: ✅ completed  
**预计工时**: 6 小时  
**指派给**: TBD

**问题描述**:
- read_file 大文件处理有问题
- edit 行号计算可能出错
- 缺少工具错误恢复

**实施步骤**:
1. 修复 read_file 大文件（>1MB）处理
2. 修复 edit 行号边界问题
3. 添加工具超时机制
4. 添加工具错误恢复

**验收标准**:
- [x] 可以处理 10MB 文件
- [x] edit 行号计算 100% 准确
- [x] 工具超时不阻塞 Agent
- [x] 工具错误有友好提示

---

## 依赖关系

```
MVP-A3 (精简 Provider)
    │
    ▼
MVP-A1 (修复 Agent 循环)
    │
    ├──▶ MVP-A2 (简化 Memory)
    │
    └──▶ MVP-A4 (工具可靠性)
```

---

## 时间线

```
Week 1:
Day 1: MVP-A3 (设置默认 Kimi，保留其他 Provider)
Day 2-4: MVP-A1 (修复 Agent 循环稳定性)
Day 5: 测试 Agent 稳定性

Week 2:
Day 1-2: MVP-A2 (简化 Memory)
Day 3-4: MVP-A4 (工具可靠性)
Day 5: 集成测试 + 修复
```

---

## 成功标准

阶段 A 完成时必须满足：

- [x] REPL 可以连续对话 10 轮无错误
- [x] 文件编辑准确率达 95%
- [x] 错误恢复：单次错误不崩溃
- [x] 内存使用 < 100MB
- [x] 启动时间 < 1 秒
- [x] 默认使用 Kimi API

---

## 产出

- **kimiz v0.3.0** - 稳定的 MVP
- 功能：REPL + 文件工具 + Kimi

---

**创建日期**: 2026-04-05
**更新日期**: 2026-04-05
**状态**: ✅ 已完成
