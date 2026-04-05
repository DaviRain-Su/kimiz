# Zig 0.16 迁移 - 阻塞状态

**日期**: 2026-04-05
**状态**: 阻塞 - API 变化太大
**建议**: 降级到 Zig 0.13

---

## 问题

Zig 0.16 (开发版本) 的 API 变化非常大，几乎涉及所有核心模块：

### 已发现的 API 变更

| 模块 | 旧 API | 新 API | 影响文件数 |
|------|--------|--------|-----------|
| std.json | `stringify` | 未知 | 3+ |
| std.time | `sleep` | 未知 | 1+ |
| std.ArrayList | `init(allocator)` | 未知 | 3+ |
| std.ArrayList | `appendSlice(items)` | `appendSlice(gpa, items)` | 多个 |
| std.fs | `cwd()` | 通过 Io 访问 | 多个 |
| std.process | `getEnvVarOwned` | 通过 Init.environ_map | 多个 |
| std.fmt | `format` | `allocPrint` | 多个 |

### 已修复 (7个)
1. ✅ `std.time.milliTimestamp` → `utils.milliTimestamp`
2. ✅ `std.process.argsAlloc` → `std.process.ArgIterator`
3. ✅ `std.http.Client` io 字段 → 简化版 HTTP 客户端
4. ✅ `std.EnumArray.values()` → 手动迭代
5. ✅ `io_helper.zig` 重复字段名
6. ✅ `skills/root.zig` 计时器使用
7. ✅ `std.fmt.format` → `std.fmt.allocPrint` (部分)

### 待修复 (太多)

每个文件都需要大量修改，预计需要 **2-3 天** 的全职工作。

---

## 建议方案

### 方案 A: 降级到 Zig 0.13 (推荐) ⭐

**步骤**:
1. 下载 Zig 0.13
2. 恢复原始代码 (从 git 历史)
3. 编译测试

**时间**: 1 小时
**优点**: 快速恢复，无需修改代码
**缺点**: 使用旧版本 Zig

### 方案 B: 继续 Zig 0.16 迁移

**步骤**:
1. 研究 Zig 0.16 新 API
2. 逐个修复每个错误
3. 测试所有功能

**时间**: 2-3 天
**优点**: 使用最新版本
**缺点**: 工作量大，API 可能继续变化

### 方案 C: 等待 Zig 0.16 稳定

**步骤**:
1. 降级到 Zig 0.13
2. 等待 Zig 0.16 正式发布
3. 再进行迁移

**时间**: 未知 (等待 Zig 发布)
**优点**: API 稳定后再迁移
**缺点**: 无法使用新功能

---

## 决策

建议采用 **方案 A (降级到 Zig 0.13)**，因为：

1. Zig 0.16 是开发版本，API 不稳定
2. 迁移工作量太大 (2-3天)
3. 项目原本就是在 Zig 0.13 上开发的
4. 可以快速恢复开发工作

---

## 下一步

等待决策：
- [ ] 降级到 Zig 0.13
- [ ] 或继续 Zig 0.16 迁移
