# T-130: TUI Implementation - Terminal User Interface

**Status**: `frozen`  
**Priority**: P3 (deferred to post Phase-8)  
**Estimated effort**: 8h  
**Created**: 2026-04-06  
**Frozen**: 2026-04-06  
**Branch**: `feature/tui-implementation` (preserved but inactive)

---

## Background

KimiZ需要完整的终端用户界面（TUI）以提供沉浸式交互体验。此任务最早计划在Sprint 2026-04内完成。

---

## Why Frozen

在尝试集成三个不同的TUI库时，均遇到了**Zig 0.16-dev 底层API破坏性变更**导致的严重兼容性问题：

1. **libvaxis** (`DaviRain-Su/libvaxis` fork)
   - `std.fs.File` 在 Zig 0.16 中被移除，改为 `std.Io.File`
   - `std.posix.open` / `std.posix.write` / `std.posix.read` 被移除
   - `std.Thread.Mutex` API 变更
   - 信号处理函数签名变更 (`sigaction` handler)
   - 修复工作量：~30+ 处底层 POSIX / Io 改动

2. **zigtui** (`adxdits/zigtui`)
   - 同样依赖 `std.fs.File`（`src/backend/ansi.zig`）
   - `std.Io.File.writer()` API 需要传入 `std.Io` 实例和 buffer
   - 信号处理、文件写入方式需要系统性适配
   - 修复工作量：~15+ 处

3. **自研 `terminal.zig` 路径**
   - 可以绕过外部库，但 Zig 0.16 下 `std.posix.write/read` 的移除意味着连最基础的 ANSI terminal 控制都需要重写为 `posix.system.write/read`
   - 虽可行，但需要额外投入 ~2-3h 把自研方案稳定到生产可用

### 评估结论

当前 KimiZ 的核心目标仍然是 **"核心工具链夯实"**（Sprint 2026-04）。TUI 属于上层用户体验，不应该在这个阶段消耗过多 engineering hours 去适配一个尚未稳定的 Zig 0.16-dev TUI 生态。

**决策**：战略性冻结 T-130，待以下任一条件满足后重启：
- Zig 0.16 正式发布，且某个主流 TUI 库（libvaxis / zigtui / 其他）完成官方兼容
- KimiZ 进入 Phase-8（平台完善期），此时有资源专门打磨 UX 层
- 发现或 fork 出一个维护良好的、已兼容 Zig 0.16 的纯 Zig TUI 库

---

## Preserved Assets

- `feature/tui-implementation` 分支保留在远程，包含：
  - `docs/UPSTREAM-FIX-GUIDE.md`（uucode / libvaxis 上游修复指南）
  - `patches/uucode-zig016.patch`
  - 部分自研 TUI 代码尝试（`src/tui/root.zig`, `src/tui/terminal.zig`）
- `main` 分支上 TUI 已恢复为 stub：`src/tui/root.zig`

---

## Acceptance Criteria (for when unfrozen)

- [ ] `kimiz --tui` 启动并绘制聊天界面
- [ ] 支持用户输入、发送、显示 AI 回复
- [ ] Esc / Ctrl+C 安全退出并恢复终端状态
- [ ] 无编译错误、无内存泄漏

---

## Log

### 2026-04-06
- 创建 `feature/tui-implementation` 分支
- 修复 `DaviRain-Su/uucode` 上游（ commit `ed737c2` ）
- 修复 `DaviRain-Su/libvaxis` build.zig.zon（ commit `301cd45` ）
- 尝试 `zigtui` 作为替代库，发现同样需要大量 Zig 0.16 patch
- 尝试自研 `terminal.zig` TUI，已跑通 raw mode + ANSI 绘制骨架
- **用户决策**：战略冻结 T-130，优先保障核心工具链
