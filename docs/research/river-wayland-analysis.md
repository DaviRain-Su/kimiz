# River Wayland 合成器分析与 Kimiz 关联评估

**研究日期**: 2026-04-05  
**项目链接**: https://codeberg.org/river/river  
**平台**: Codeberg  
**评估目标**: 与 kimiz 的关系（注意：River 是 Wayland 合成器，不是库/工具）

---

## 1. 项目概述

**River** 是一个 **Zig 编写的 Wayland 合成器（窗口管理器）**：

- **类型**: Wayland 合成器 / 平铺式窗口管理器
- **特点**:
  - 类似 dwm/i3 的平铺式管理
  - 原生 Wayland 支持（非 X11）
  - 使用 Zig 编写
  - 简洁高效
- **定位**: Linux 系统的窗口管理器
- **技术**: Wayland 协议 + Zig

**重要**: River 是**系统级组件**（窗口管理器），不是库或工具，无法被 "整合" 进 kimiz。

---

## 2. 与 Kimiz 的关系分析

### 2.1 关系类型

| 关系 | 说明 | 价值 |
|------|------|------|
| **运行环境** | kimiz 在 River 管理的窗口中运行 | ⭐⭐⭐⭐ 高 |
| **整合** | 无法整合（系统组件） | ❌ 不可能 |
| **依赖** | kimiz 不依赖 River | N/A |
| **推荐** | 可向 Linux 用户推荐 | ⭐⭐⭐ 中 |

### 2.2 kimiz 在 River 中运行

```
River (Wayland 合成器)
    └── 终端窗口 (Ghostty/Alacritty)
        └── bash/zsh
            └── kimiz run "task"
                └── TUI 界面
```

**受益点**:
- 平铺式窗口管理，高效利用屏幕
- Wayland 原生性能
- 简洁的工作流

---

## 3. 与 Ghostty 的对比

| 组件 | 类型 | 作用 | 与 kimiz 关系 |
|------|------|------|--------------|
| **River** | Wayland 合成器 | 管理窗口 | 运行环境 |
| **Ghostty** | 终端模拟器 | 渲染终端 | 运行环境 |
| **kimiz** | CLI/TUI 应用 | AI Coding Agent | 应用程序 |

**完整链**:
```
River (窗口管理)
    └── Ghostty (终端)
        └── kimiz (应用)
            └── TUI 界面
```

---

## 4. 对 kimiz TUI 的影响

### Wayland 兼容性

kimiz TUI (`TASK-FEAT-001`) 需要确保在 Wayland 环境下正常工作：

| 特性 | Wayland 支持 | 注意事项 |
|------|-------------|---------|
| **TUI 渲染** | ✅ | 通过终端模拟器间接支持 |
| **鼠标事件** | ✅ | 终端转发鼠标事件 |
| **剪贴板** | ✅ | 需通过终端访问 |
| **图像显示** | ⚠️ | 依赖终端的图像协议支持 |

### 推荐配置

```bash
# River 配置优化 kimiz 体验
# ~/.config/river/init

# 设置终端快捷键
riverctl map normal Super+Return spawn ghostty

# 设置 kimiz 快捷键
riverctl map normal Super+k spawn "ghostty -e kimiz"

# 工作流优化
# Super+Shift+k = 在新窗口打开 kimiz
riverctl map normal Super+Shift+k spawn "ghostty -e kimiz"
```

---

## 5. 决策

### 结论: 不能整合，但可推荐

> **"River 是 Wayland 窗口管理器，无法整合进 kimiz，但可向 Linux 用户推荐"**

| 评估项 | 结论 |
|--------|------|
| 整合 | ❌ 不可能（系统组件） |
| 依赖 | ❌ 不需要 |
| 推荐 | ✅ 向 Linux/Wayland 用户推荐 |
| 测试 | ✅ 应在 River 中测试 TUI |

### 行动建议

1. **Linux 用户**: 推荐 River + Ghostty + kimiz 组合
2. **兼容性**: 确保 kimiz TUI 在 Wayland 下正常
3. **文档**: 提供 Wayland 环境配置建议

---

## 6. 桌面环境对比

| 环境 | 类型 | 与 kimiz 兼容性 | 推荐度 |
|------|------|----------------|--------|
| **River** | Wayland 平铺 | ✅ 完美 | ⭐⭐⭐⭐⭐ |
| **Sway** | Wayland 平铺 | ✅ 完美 | ⭐⭐⭐⭐⭐ |
| **Hyprland** | Wayland 平铺 | ✅ 完美 | ⭐⭐⭐⭐ |
| **GNOME** | Wayland 桌面 | ✅ 良好 | ⭐⭐⭐⭐ |
| **KDE** | Wayland/X11 | ✅ 良好 | ⭐⭐⭐⭐ |
| **i3** | X11 平铺 | ✅ 良好 | ⭐⭐⭐⭐ |
| **dwm** | X11 平铺 | ✅ 良好 | ⭐⭐⭐⭐ |

---

## 7. 参考

- **River**: https://codeberg.org/river/river
- **Wayland**: https://wayland.freedesktop.org/
- **Ghostty** (终端): https://github.com/ghostty-org/ghostty
- **Sway** (类似): https://swaywm.org/

---

*文档版本: 1.0*  
*最后更新: 2026-04-05*  
*维护者: kimiz-core-team*
