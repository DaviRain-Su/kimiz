# Kimiz 架构简化任务清单

**日期**: 2026-04-05  
**目标**: 简化架构，降低复杂度，提高可维护性  
**参考**: [Simplified Architecture Proposal](./docs/design/simplified-architecture-proposal.md)

---

## 简化原则

1. **极简核心**: 只保留最基本功能
2. **扩展驱动**: 高级功能通过 Extensions 实现
3. **实用主义**: 优先解决实际问题

---

## 阶段 1: 核心简化 (Week 1-2)

### P0 - 立即执行

- [ ] **TASK-REF-003**: 简化 Memory 系统为单层 Session
  - 📁 `tasks/backlog/refactor/TASK-REF-003-simplify-memory-system.md`
  - ⏱️ 8h
  - 🎯 三层 → 单层 + Compaction
  - 📉 代码减少 60%

- [ ] **TASK-REF-004**: 移除 Learning 系统
  - 📁 `tasks/backlog/refactor/TASK-REF-004-remove-learning-system.md`
  - ⏱️ 2h
  - 🎯 完全移除，改为简单配置
  - 📉 代码减少 400+ 行

- [ ] **TASK-REF-005**: 移除 Smart Routing
  - 📁 `tasks/backlog/refactor/TASK-REF-005-remove-smart-routing.md`
  - ⏱️ 2h
  - 🎯 自动路由 → 手动选择
  - 📉 代码减少 300+ 行

### P1 - 重要

- [ ] **TASK-REF-006**: 简化 Workspace Context
  - 📁 `tasks/backlog/refactor/TASK-REF-006-simplify-workspace-context.md`
  - ⏱️ 4h
  - 🎯 复杂检测 → AGENTS.md + Git 信息
  - 📉 代码减少 70%

- [ ] **TASK-FEAT-007**: 简化 Tools 系统
  - 📁 `tasks/backlog/feature/TASK-FEAT-007-simplify-tools.md`
  - ⏱️ 4h
  - 🎯 7个工具 → 5个核心工具
  - 📉 代码减少 30%

**阶段 1 总计**: 5个任务，20小时，预计代码减少 2000+ 行

---

## 阶段 2: Extension 系统 (Week 3-4)

- [ ] **TASK-FEAT-006**: 实现 Extension 系统
  - 📁 `tasks/backlog/feature/TASK-FEAT-006-implement-extension-system.md`
  - ⏱️ 16h
  - 🎯 WASM 运行时 + Extension API
  - 📈 新增 ~3000 行，但功能无限扩展

**阶段 2 总计**: 1个任务，16小时

---

## 被移除/替换的原任务

### 完全移除

| 原任务 | 原因 | 替代方案 |
|--------|------|----------|
| `src/learning/root.zig` | 价值 unclear | 简单配置 |
| `src/ai/routing.zig` | 过度设计 | 手动选择 |
| `TASK-FEAT-002-implement-skills-registration` | 与 Extension 重复 | Extension 系统 |

### 大幅简化

| 原任务 | 新任务 | 变化 |
|--------|--------|------|
| 三层 Memory | 单层 Session | 复杂度 -60% |
| 复杂 Workspace Context | AGENTS.md | 复杂度 -70% |
| 7个 Tools | 5个 Tools | 数量 -30% |

### 延后实现

| 功能 | 实现方式 | 时间 |
|------|----------|------|
| Advanced Skills | Extension | 后期 |
| Learning | Extension | 后期 |
| Sub-agents | Extension | 后期 |
| Web Search | Extension | 后期 |

---

## 代码量变化预估

| 模块 | 当前 | 简化后 | 变化 |
|------|------|--------|------|
| Memory | ~800 行 | ~300 行 | -500 |
| Learning | ~400 行 | 0 行 | -400 |
| Routing | ~300 行 | 0 行 | -300 |
| Workspace | ~600 行 | ~200 行 | -400 |
| Tools | ~1500 行 | ~1000 行 | -500 |
| Extension | 0 行 | ~3000 行 | +3000 |
| **总计** | **~11,000 行** | **~10,000 行** | **-1000 行** |

**说明**: 虽然总代码量变化不大，但结构更清晰，核心更简单。

---

## 依赖关系

```
阶段 1: 核心简化
├── TASK-REF-003 (Memory)
│   └── 影响: Agent, Session
├── TASK-REF-004 (Learning)
│   └── 影响: Config, Agent
├── TASK-REF-005 (Routing)
│   └── 影响: CLI, TUI
├── TASK-REF-006 (Workspace)
│   └── 影响: Agent
└── TASK-FEAT-007 (Tools)
    └── 影响: Agent

阶段 2: Extension 系统
└── TASK-FEAT-006 (Extension)
    ├── 依赖: 阶段 1 完成
    └── 影响: Agent, TUI, CLI
```

---

## 验收标准

### 阶段 1 完成标准

- [ ] Memory 系统简化为单层 Session
- [ ] Learning 系统完全移除
- [ ] Smart Routing 完全移除
- [ ] Workspace Context 简化为 AGENTS.md
- [ ] Tools 简化为 5 个核心工具
- [ ] 代码量减少 2000+ 行
- [ ] 所有测试通过
- [ ] 编译通过

### 阶段 2 完成标准

- [ ] Extension 系统可以加载 WASM
- [ ] Extension 可以注册工具
- [ ] Extension 可以注册命令
- [ ] Extension 可以监听事件
- [ ] 提供示例 Extension
- [ ] 文档完整

---

## 风险评估

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 重构引入 Bug | 高 | 中 | 充分测试，逐步迁移 |
| Extension 系统复杂 | 中 | 高 | 使用成熟 WASM 运行时 |
| 功能减少用户不满 | 中 | 中 | 提供官方 Extensions |
| 时间超预期 | 中 | 中 | 明确 MVP，分阶段交付 |

---

## 与 Pi-Mono 对比 (简化后)

| 维度 | 简化后 Kimiz | Pi-Mono |
|------|-------------|---------|
| 核心代码量 | ~7,000 行 | ~30,000 行 |
| Extension 代码量 | ~3,000 行 | (内置) |
| 总代码量 | ~10,000 行 | ~30,000 行 |
| 核心功能 | 精简 | 极简 |
| 扩展性 | 强 (WASM) | 强 (TypeScript) |
| 开发语言 | Zig | TypeScript |
| 性能 | 高 | 中 |

**结论**: 简化后的 Kimiz 在保持竞争力的同时，代码量仅为 Pi 的 1/3。

---

## 下一步行动

1. **审查此清单** - 确认简化范围
2. **开始阶段 1** - 从 Memory 系统开始
3. **并行开发** - REF-003, REF-004, REF-005 可以并行
4. **定期回顾** - 每完成一个任务评估效果

---

**维护者**: Kimiz Team  
**状态**: 待执行  
**目标完成**: 4周内完成阶段 1+2
