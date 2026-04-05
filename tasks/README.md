# KimiZ 任务系统

> **统一任务管理：按阶段分组，按 Sprint 执行。**  
> 最后更新: 2026-04-06

---

## 目录结构

```
tasks/
├── README.md                 # 本文件
├── active/                   # 当前 Sprint 的正在执行任务
│   └── sprint-2026-04/
├── backlog/                  # 未来任务，按 Phase 0-10 分组
│   ├── phase-3-subagent/
│   ├── phase-4-harness/
│   ├── phase-5-observability/
│   ├── phase-6-integration/
│   ├── phase-7-automation/
│   ├── phase-8-platform/
│   └── misc/                 # UX 增强、infra、远期研究
├── completed/                # 已完成的任务，按阶段分组
│   ├── phase-0-foundation/
│   ├── phase-1-core-agent/
│   ├── phase-2-ux/
│   └── phase-3-subagent-partial/
└── archive/                  # 历史归档（不再追踪）
    ├── sprint-01-core/       # 旧 Sprint 任务
    └── old-backlog/          # 废弃/过时的 backlog 任务
```

---

## 如何使用

### 对于 Coding Agent

1. **先看入口**: `AGENT-ENTRYPOINT.md`（项目根目录）
2. **当前 Sprint**: `tasks/active/sprint-2026-04/`
3. **未来任务**: 只在当前 Sprint 完成后再去 `backlog/` 取任务
4. **不要读 archive/**: 那是历史垃圾堆

### 对于产品经理/规划者

1. **看路线图**: `docs/ROADMAP-v2.md`
2. **看已实现特性**: `docs/FEATURES.md`
3. **排期新任务**: 把新任务放到对应的 `backlog/phase-N/` 目录

---

## 任务命名规则

- **Bugfix**: `FIX-XXX-short-description.md`
- **Feature**: `TASK-XXX-short-description.md`
- **Backlog 任务**: 保留原有编号（T-XXX, TASK-FEAT-YYY）

---

## 状态迁移规则

```
backlog/phase-N/     →  active/sprint-YYYY-MM/   (Sprint 开始)
active/sprint/       →  completed/phase-N/       (Sprint 完成)
completed/phase-N/   →  archive/                 (过时/废弃)
backlog/             →  archive/                 (不再计划)
```

---

## 当前状态

- **Active**: 3 个任务（编译修复、delegate 验证、E2E 测试）
- **Backlog**: ~80 个任务，已按 8 个 phase + misc 分类
- **Completed**: ~45 个任务，已按 phase 归档
- **Archive**: 旧 sprint-01-core（22 个文件）+ 废弃 refactor/docs
