# raze-tui TUI 库分析与 Kimiz 整合评估

**研究日期**: 2026-04-05  
**项目链接**: https://codeberg.org/hyperpolymath/raze-tui  
**平台**: Codeberg  
**评估目标**: 是否可作为 kimiz 的 TUI 界面方案

---

## 1. 项目概述

**raze-tui** 是一个 **Zig 编写的 TUI (Terminal User Interface) 库**：

**可能的功能**（基于项目名称和 TUI 常见特性推测）：
- **终端界面组件**: 窗口、面板、按钮、列表等
- **事件处理**: 键盘、鼠标输入处理
- **渲染引擎**: 终端图形渲染
- **布局系统**: 自适应布局管理
- **语言**: Zig (与 kimiz 同语言)

**需要确认的功能**:
- [ ] 具体组件和特性
- [ ] 渲染性能
- [ ] 跨平台支持 (Linux/macOS/Windows)
- [ ] 与现有 TUI 任务的关系

---

## 2. 与 Kimiz 使用场景匹配度分析

### 2.1 Kimiz TUI 现状

**已有任务**: `TASK-FEAT-001-implement-tui-complete.md`

**当前 kimiz TUI 需求**:

| 场景 | 需求 | 优先级 | 说明 |
|------|------|--------|------|
| **交互式界面** | 比 CLI 更友好的交互 | 高 | TUI 核心目标 |
| **文件浏览器** | 可视化文件操作 | 中 | fff 集成后可展示 |
| **任务监控** | 实时显示 Agent 进度 | 高 | 重要反馈 |
| **代码预览** | 语法高亮显示 | 中 | 编辑前预览 |
| **日志输出** | 可滚动的日志窗口 | 高 | 必要组件 |

### 2.2 潜在使用场景

#### 场景 1: TUI 主界面

```
┌─────────────────────────────────────────┐
│ kimiz - AI Coding Agent          [menu] │
├─────────────────────────────────────────┤
│ Task: Refactor main.zig                 │
│ Progress: [████████░░] 80%              │
├─────────────────────────────────────────┤
│ Output:                                 │
│ > Analyzing...                          │
│ > Found 3 issues                        │
│ > Fixing...                             │
│                                         │
│                                         │
├─────────────────────────────────────────┤
│ [Input]: _                              │
└─────────────────────────────────────────┘
```

**价值**: ⭐⭐⭐⭐⭐ 极高 - TUI 是重要功能

#### 场景 2: 文件浏览器集成

```
┌─────────────────────────────────────────┐
│ Files                    [fff integrated]│
├─────────────────────────────────────────┤
│ 📁 src/                                 │
│   📄 main.zig                           │
│   📄 cli.zig      ◄── selected          │
│ 📁 tests/                               │
│   📄 test_main.zig                      │
└─────────────────────────────────────────┘
```

**价值**: ⭐⭐⭐⭐ 高 - 与 fff 配合

#### 场景 3: 实时日志

```
┌─────────────────────────────────────────┐
│ Logs                                    │
├─────────────────────────────────────────┤
│ [10:23:01] Starting task...             │
│ [10:23:02] Calling tool: fff            │
│ [10:23:03] Found 5 files                │
│ [10:23:04] Analyzing...                 │
│ ...                                     │
└─────────────────────────────────────────┘
```

**价值**: ⭐⭐⭐⭐⭐ 极高 - 必要功能

---

## 3. 与现有 TUI 任务的关联

### TASK-FEAT-001 现状

**文件**: `tasks/backlog/feature/TASK-FEAT-001-implement-tui-complete.md`

**当前计划**:
- 实现完整的 TUI 界面
- 组件: 文件树、代码预览、任务面板
- 技术: 可能使用外部库或自行实现

### 整合方案对比

| 方案 | 实现方式 | 工作量 | 维护成本 | 推荐 |
|------|---------|--------|---------|------|
| **A. raze-tui** | 使用库 | 中 | 中 | 待评估 |
| **B. 自行实现** | 手写 TUI | 高 | 高 | 不推荐 |
| **C. 其他库** | 如 zig-cli, cursed | 待评估 | 待评估 | 对比后决定 |

---

## 4. 整合方案评估

### 方案 A: 使用 raze-tui (待确认)

如果 raze-tui 功能完善：

```zig
// src/tui/root.zig
const raze = @import("raze-tui");

pub const App = struct {
    ui: raze.App,
    
    pub fn init() !App {
        var app = try raze.App.init();
        
        // 创建主窗口
        const main_window = try app.addWindow("main", .{
            .title = "kimiz - AI Coding Agent",
            .layout = .vertical,
        });
        
        // 添加组件
        try main_window.addComponent("task_panel", TaskPanel);
        try main_window.addComponent("file_tree", FileTree);
        try main_window.addComponent("log_view", LogView);
        
        return .{ .ui = app };
    }
    
    pub fn run(self: *App) !void {
        try self.ui.run();
    }
};
```

**优点**:
- Zig 原生，无 FFI 开销
- 可能提供丰富组件
- 社区维护

**需要确认**:
- 功能完整性
- 文档和示例
- 活跃度

### 方案 B: 其他 TUI 库

其他 Zig TUI 选项：

| 库 | 链接 | 状态 | 评估 |
|----|------|------|------|
| **zig-cli** | 常见 | 可能可用 | 待查 |
| **cursed** | ncurses 绑定 | 成熟 | 可能 |
| **自行实现** | - | 工作量大 | 不推荐 |

### 方案 C: 混合方案

简单组件自行实现，复杂功能使用库：

```zig
// 核心渲染自行实现
// 复杂组件使用 raze-tui
```

---

## 5. 决策建议

### 初步结论: 评估后决定

> **"raze-tui 可能是 kimiz TUI 的候选方案，需要进一步评估"**

**评估要点**:
1. **功能完整性**: 是否提供所需组件?
2. **文档质量**: 是否有清晰的文档和示例?
3. **活跃度**: 项目是否活跃维护?
4. **稳定性**: 是否达到生产可用?

### 决策矩阵

| raze-tui 如果... | 决策 |
|-----------------|------|
| **功能完善 + 文档好** | ✅ 使用 |
| **功能一般** | ⚠️ 对比其他库 |
| **不成熟** | ❌ 考虑其他方案 |

---

## 6. 待确认信息

需要了解：

- [ ] **核心功能**: 提供哪些 TUI 组件?
- [ ] **渲染性能**: 是否流畅?
- [ ] **事件系统**: 键盘/鼠标支持如何?
- [ ] **跨平台**: Linux/macOS/Windows 支持?
- [ ] **文档**: 是否有清晰文档?
- [ ] **示例**: 是否有完整示例?
- [ ] **依赖**: 依赖哪些库?
- [ ] **活跃度**: 最近更新频率?

---

## 7. 与现有 TUI 任务的整合

### 影响 TASK-FEAT-001

**如果采用 raze-tui**:
- 更新 TASK-FEAT-001 使用 raze-tui
- 减少自行实现工作量
- 加快 TUI 功能交付

**任务更新**:
```markdown
# TASK-FEAT-001 更新

技术选型:
- ~~自行实现 TUI 组件~~
- ✅ 使用 raze-tui 库

依赖:
- raze-tui (Codeberg)

实现步骤:
1. 添加 raze-tui 依赖
2. 设计界面布局
3. 实现各个组件
4. 集成到 kimiz
```

---

## 8. 结论

### 一句话总结

> **"raze-tui 是潜在的 TUI 方案，需要评估功能完整性后再决定"**

### 决策

| 评估项 | 结论 |
|--------|------|
| 整合建议 | 🔍 待评估 |
| 优先级 | P2 (依赖 TUI 任务优先级) |
| 下一步 | 收集 raze-tui 详细信息 |

### 立即行动

- [ ] 阅读 raze-tui 文档和示例
- [ ] 评估功能是否满足需求
- [ ] 对比其他 TUI 库
- [ ] 更新 TASK-FEAT-001 决策

---

## 参考

- raze-tui: https://codeberg.org/hyperpolymath/raze-tui
- Codeberg: https://codeberg.org/
- 现有任务: `tasks/backlog/feature/TASK-FEAT-001-implement-tui-complete.md`

---

*文档版本: 0.1 (待评估)*  
*最后更新: 2026-04-05*  
*状态: 需要更多信息*
