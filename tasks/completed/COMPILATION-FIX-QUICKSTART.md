# 编译错误快速修复指南

**日期**: 2026-04-05
**状态**: ✅ 已完成
**实际用时**: ~30分钟
**完成日期**: 2026-04-05

---

## 🎯 目标

修复当前编译错误，让项目可以正常编译运行。

---

## ✅ 已修复的错误

| # | 错误 | 文件 | 修复方式 |
|---|------|------|----------|
| 1 | `var` 应为 `const` | `src/harness/self_review.zig:395` | `var lint_result` → `const lint_result` |
| 2 | `std.Io.IoUring` 不存在 | `src/http.zig:38` | 重写为接受 `std.Io` 参数，使用 `std.process.Init.io` |
| 3 | `ArrayListUnmanaged{}` 初始化语法 | `src/skills/root.zig:90` | 改为 `.empty` |
| 4 | `std.time.Timer` 不存在 | `src/skills/root.zig:217` | 暂时移除计时（TODO） |
| 5 | `std.posix.getcwd` 不存在 | `src/cli/root.zig:178` | 改用 `std.c.getcwd` |
| 6 | `std.http.Client` API 全面变更 | `src/http.zig` | 重写使用 `request`/`sendBodyComplete`/`receiveHead`/`reader` |
| 7 | `std.Thread.Mutex` 不存在 | `src/utils/io_manager.zig` | 移除 Mutex（单线程初始化场景） |
| 8 | `std.time.sleep` 不存在 | `src/http.zig:90` | 暂时移除重试延迟（TODO） |

---

## 修改的文件

1. `src/harness/self_review.zig` - var → const
2. `src/http.zig` - 完全重��� HTTP Client，使用 Zig 0.16 API
3. `src/utils/io_manager.zig` - 移除 IoUring，改为存储 std.Io 实例
4. `src/main.zig` - 添加 `initIoManager(allocator, init.io)`
5. `src/skills/root.zig` - ArrayListUnmanaged 初始化 + 移除 Timer
6. `src/cli/root.zig` - posix.getcwd → std.c.getcwd

---

## ✅ 验收结果

- [x] `zig build` 编译成功���无错误
- [x] `zig build test` 所有测试通过
