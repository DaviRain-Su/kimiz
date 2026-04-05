# Kimiz 任务管理

**当前策略**: MVP 优先，从 18k 行代码到稳定产品

---

## 🎯 当前重点: MVP 路线图

我们正在执行 **MVP 路线图**，目标是从功能分散的实验性项目转变为稳定可用的产品。

**核心原则**:
1. 先做好一件事（REPL + 文件编辑）
2. 专注 Kimi (kimi-k2.5) 模型
3. 逐步迭代，一次只加一个功能

### 路线图文档

| 阶段 | 文档 | 状态 | 目标 |
|------|------|------|------|
| **MVP 总览** | [MVP-ROADMAP.md](./MVP-ROADMAP.md) | ✅ 已创建 | 整体规划 |
| **阶段 A** | [mvp/phase-a-core-stability.md](./mvp/phase-a-core-stability.md) | 🟡 进行中 | 稳定核心 |
| **阶段 B** | [mvp/phase-b-quality.md](./mvp/phase-b-quality.md) | ⏸️ 待开始 | 质量提升 |
| **阶段 C** | [mvp/phase-c-enhancement.md](./mvp/phase-c-enhancement.md) | ⏸️ 待开始 | 选择性增强 |

---

## 📋 当前活跃任务

### P0 (立即执行)

| 任务 | 说明 | 状态 | 工时 |
|------|------|------|------|
| MVP-A1 | 修复 Agent 循环稳定性 | 🟡 进行中 | 8h |
| MVP-A2 | 简化 Memory 系统 | ⏸️ 待开始 | 6h |
| MVP-A3 | 默认使用 Kimi（保留其他 Provider） | ⏸️ 待开始 | 2h |
| MVP-A4 | 工具可靠性 | ⏸️ 待开始 | 6h |

### Bug 修复 (同时进行)

| 任务 | 说明 | 状态 |
|------|------|------|
| TASK-BUG-021 | 创建缺失工具 | 🟡 进行中 |
| TASK-BUG-023 | OpenAI tool_calls 解析 | ⏸️ 待开始 |

---

## ⏸️ 已暂停的任务

以下任务已暂停，待 MVP 稳定后考虑：

| 任务 | 原因 | 重启条件 |
|------|------|---------|
| FOUR-PILLARS-TASKS.md | 过于宏大（131h） | MVP v0.5.0 后 |
| 三层记忆架构 | 过度设计 | 用户证明需要 |
| Learning 系统 | 价值不清晰 | 用户证明需要 |
| 复杂 Harness | 过度设计 | 用户证明需要 |
| Web 搜索工具 | 非核心 | 阶段 C 考虑 |
| MCP 整合 | **PRD 明确不做** | 不做 |
| TUI 完整版 | 非核心 | 阶段 C 考虑 |
| OpenAI/Anthropic Provider | MVP 专注 Kimi | 阶段 C 考虑 |

---

## 📁 目录结构

```
tasks/
├── README.md                    # 本文件
├── MVP-ROADMAP.md              # MVP 总览
├── CRITICAL-FIXES-SUMMARY.md   # 关键修复汇总
├── TOOLS-EVALUATION-SUMMARY.md # 工具评估
├── mvp/                        # MVP 任务
│   ├── phase-a-core-stability.md
│   ├── phase-b-quality.md
│   └── phase-c-enhancement.md
├── backlog/                    # 待办任务
│   ├── bug/
│   └── feature/
├── archive/                    # 已暂停任务
│   └── FOUR-PILLARS-TASKS.md.paused
└── docs/research/              # 研究文档
    └── *.md
```

---

## 🚀 下一步行动

### 今天

1. ✅ 创建 MVP 路线图
2. 🟡 开始 MVP-A1 (Agent 循环稳定性)
3. ⏸️ 暂停四大支柱任务

### 本周

1. 完成 MVP-A3 (精简 Provider，仅保留 Kimi)
2. 完成 MVP-A1 (Agent 循环稳定性)
3. 开始 MVP-A2 (简化 Memory)

### 6 周后

1. 发布 kimiz v0.5.0 (MVP+)
2. 收集用户反馈
3. 决定下一阶段

---

## 📊 关键指标

| 指标 | 当前 | MVP 目标 |
|------|------|---------|
| 代码行数 | 18,772 | 8,000-10,000 |
| AI Provider | 5 个 | 1 个 (Kimi) |
| 核心功能 | 50+ | 5 个 |
| 稳定性 | 低 | 高 |
| 维护成本 | 高 | 低 |

---

## 💡 决策记录

### 2026-04-05: 转向 MVP 策略

**背景**: 项目有 18k 行代码，功能分散，没有一件事做得好

**决策**:
1. 暂停四大支柱任务（过于宏大）
2. 定义 MVP：REPL + 文件编辑 + Kimi
3. 6 周迭代，逐步稳定

**理由**:
- 参考 Pi (30k 行，专注核心)
- 避免"永远 beta"状态
- 先稳定，再扩展

---

**最后更新**: 2026-04-05  
**维护者**: kimiz-core-team
