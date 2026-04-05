# TASK-FEAT-028: 评估 raze-tui TUI 库

**状态**: pending  
**优先级**: P2  
**预计工时**: 4小时 (评估) + 待定 (实施)  
**指派给**: TBD  
**标签**: tui, frontend, evaluation-needed

---

## 背景

发现 **raze-tui** (https://codeberg.org/hyperpolymath/raze-tui) - Zig 编写的 TUI (Terminal User Interface) 库。

**相关任务**: `TASK-FEAT-001-implement-tui-complete.md` - 实现完整 TUI 界面

**当前问题**: TASK-FEAT-001 计划自行实现 TUI 组件，工作量大。

**解决方案**: 评估 raze-tui 是否能加速 TUI 开发。

---

## 目标

评估 raze-tui 作为 kimiz TUI 界面的技术方案。

---

## 评估维度

### 功能完整性 (必需)

- [ ] **基础组件**: Window, Panel, Box
- [ ] **输入组件**: TextInput, Button, Checkbox
- [ ] **显示组件**: Label, List, Table, Tree
- [ ] **容器组件**: ScrollView, SplitView, TabView
- [ ] **对话框**: Modal, Alert, Confirm

### 渲染性能 (重要)

- [ ] **刷新率**: 60fps+ 目标
- [ ] **内存占用**: < 50MB
- [ ] **大内容处理**: 能处理 1000+ 行日志

### 事件系统 (重要)

- [ ] **键盘**: 全键盘支持，快捷键
- [ ] **鼠标**: 点击、滚动、拖拽
- [ ] **焦点管理**: Tab 切换，焦点指示

### 跨平台 (必需)

- [ ] **Linux**: 支持
- [ ] **macOS**: 支持
- [ ] **Windows**: 支持 (如果可能)

### 开发体验 (重要)

- [ ] **文档**: 清晰的 API 文档
- [ ] **示例**: 完整的工作示例
- [ ] **编译**: 易于集成到 build.zig
- [ ] **调试**: 错误信息清晰

---

## 候选方案对比

| 方案 | 来源 | 状态 | 优势 | 劣势 | 评估 |
|------|------|------|------|------|------|
| **raze-tui** | Codeberg | 待查 | Zig 原生 | 未知成熟度 | 🔍 评估中 |
| **自行实现** | - | 可行 | 完全控制 | 工作量大 | ⚠️ 备选 |
| **cursed** | 常见 | 可用 | ncurses 成熟 | C FFI | ⚠️ 备选 |
| **其他 Zig TUI** | - | 待查 | - | - | 🔍 调研中 |

---

## 评估步骤

### Phase 1: 信息收集

```bash
# 1. 克隆项目
git clone https://codeberg.org/hyperpolymath/raze-tui

# 2. 阅读文档
cat README.md

# 3. 查看示例
ls examples/

# 4. 检查依赖
cat build.zig

# 5. 测试编译
zig build
```

### Phase 2: 功能验证

```zig
// 创建一个测试程序
const raze = @import("raze-tui");

test "basic window" {
    // 测试基础窗口创建
}

test "event handling" {
    // 测试事件处理
}

test "components" {
    // 测试各种组件
}
```

### Phase 3: 集成测试

```zig
// 测试与 kimiz 的集成
// - 编译兼容性
// - 性能测试
// - 实际使用场景
```

---

## 决策标准

### 采用条件 (满足 4+ 项)

- [ ] 提供所有必需组件
- [ ] 渲染性能满足要求
- [ ] 支持 Linux + macOS
- [ ] 文档清晰完整
- [ ] 编译集成简单
- [ ] 项目活跃维护

### 不采用条件 (满足 1 项)

- [ ] 功能缺失严重
- [ ] 性能不达标
- [ ] 文档缺失
- [ ] 项目已废弃
- [ ] 编译困难

---

## 与 TASK-FEAT-001 的关系

### 如果采用 raze-tui

更新 `TASK-FEAT-001`:
```markdown
技术选型:
- ✅ 使用 raze-tui 库
- ~~自行实现组件~~

依赖:
- raze-tigi (Codeberg: hyperpolymath/raze-tui)

工作量调整:
- 原预估: 40 小时 (自行实现)
- 新预估: 20 小时 (使用库)
- 节省: 20 小时
```

### 如果不采用

继续 `TASK-FEAT-001` 原计划:
- 评估其他 TUI 库
- 或自行实现核心组件

---

## 验收标准

- [ ] 完成功能完整性评估
- [ ] 完成性能测试
- [ ] 完成集成测试
- [ ] 编写评估报告
- [ ] 做出采用/不采用决策
- [ ] 更新 TASK-FEAT-001

---

## 依赖与阻塞

**依赖**:
- raze-tui 项目可访问
- Zig 编译器

**阻塞**:
- 无

---

## 时间线

```
Day 1-2: 信息收集
├── 阅读文档
├── 查看示例
└── 测试编译

Day 3: 功能验证
├── 编写测试程序
├── 验证组件功能
└── 性能测试

Day 4: 决策
├── 编写评估报告
├── 做出决策
└── 更新相关任务
```

---

## 参考

- **raze-tui**: https://codeberg.org/hyperpolymath/raze-tui
- **Codeberg**: https://codeberg.org/
- **相关任务**: `TASK-FEAT-001-implement-tui-complete.md`
- **研究文档**: `docs/research/raze-tui-analysis.md`

---

**创建日期**: 2026-04-05  
**建议实施时机**: Phase 1 (TUI 开发前)  
**影响范围**: TASK-FEAT-001 (TUI 实现)
