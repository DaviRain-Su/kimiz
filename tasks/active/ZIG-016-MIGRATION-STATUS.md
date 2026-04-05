# Zig 0.16 迁移状态

**日期**: 2026-04-05
**状态**: 进行中
**阻塞**: 项目无法编译

---

## 已修复的错误 ✅

| # | 错误 | 文件 | 修复方式 |
|---|------|------|----------|
| 1 | 未使用参数 `task_type` | `src/learning/root.zig:160` | 使用 `std.time.Timer` 替代 `milliTimestamp` |
| 2 | `std.time.milliTimestamp` 不存在 | 多个文件 | 创建 `utils.milliTimestamp` 兼容函数 |
| 3 | `std.process.argsAlloc` 不存在 | `src/cli/root.zig` | 使用 `std.process.ArgIterator` |
| 4 | `argsAlloc` API 变更 | `src/cli/root.zig` | 已更新为新的 API |
| 5 | `std.http.Client` 需要 `io` 字段 | `src/http.zig` | 创建了简化版 HTTP 客户端 |
| 6 | `std.EnumArray.values()` 不是函数 | `src/skills/root.zig` | 手动迭代枚举值 |
| 7 | 重复的 struct 成员名 | `src/utils/io_helper.zig` | 重命名字段 |

---

## 待修复的错误 🔴

### 高优先级

| # | 错误 | 文件 | 说明 |
|---|------|------|------|
| 1 | `std.fs.cwd()` 不存在 | `src/workspace/context.zig` | Zig 0.16 文件系统 API 重构 |
| 2 | `std.fmt.format` 不存在 | `src/ai/providers/*.zig` | 格式化 API 变更 |
| 3 | `std.process.getEnvVarOwned` 不存在 | `src/core/root.zig` | 环境变量 API 变更 |
| 4 | Switch 未处理所有枚举值 | `src/cli/root.zig` | `tool_call_delta` 未处理 |
| 5 | `core.getApiKey(.kimi, ...)` | `src/ai/providers/kimi.zig` | 语法错误 |

### 中优先级

| # | 错误 | 文件 | 说明 |
|---|------|------|------|
| 6 | `std.fs.path` API 变更 | 多个文件 | 路径操作 API 变更 |
| 7 | `std.process.Child` API 变更 | 多个文件 | 子进程 API 变更 |
| 8 | `std.Io` 相关 API | 多个文件 | 新的 I/O 系统 |

---

## Zig 0.16 主要 API 变更

### 1. 文件系统 API
```zig
// 旧代码 (Zig 0.13)
const cwd = try std.fs.cwd().realpath(".", &buf);

// 新代码 (Zig 0.16)
// 需要通过 Io 实例访问文件系统
const io = ...; // 获取 Io 实例
const dir = try std.Io.Dir.open(io, ".");
```

### 2. 环境变量 API
```zig
// 旧代码
const value = try std.process.getEnvVarOwned(allocator, "KEY");

// 新代码
// 需要通过 Init.environ_map 访问
const env_map = init.environ_map;
const value = env_map.get("KEY");
```

### 3. HTTP Client API
```zig
// 旧代码
var client = std.http.Client{ .allocator = allocator };

// 新代码
var io_uring: std.Io.IoUring = undefined;
try io_uring.init(allocator);
var client = std.http.Client{
    .allocator = allocator,
    .io = io_uring.io(),
};
```

### 4. 时间 API
```zig
// 旧代码
const timestamp = std.time.milliTimestamp();

// 新代码
var timer = try std.time.Timer.start();
const elapsed_ms = timer.read() / std.time.ns_per_ms;
```

---

## 建议的解决方案

### 方案 1: 继续迁移到 Zig 0.16 (推荐)

**预计时间**: 2-3 天

**步骤**:
1. 实现 `std.Io` 管理器
2. 重构文件系统访问
3. 更新环境变量访问
4. 修复格式化 API 调用
5. 测试所有功能

**优点**:
- 使用最新 Zig 版本
- 更好的性能和功能

**缺点**:
- 需要大量代码修改
- 需要重新测试所有功能

### 方案 2: 降级到 Zig 0.13

**预计时间**: 1 小时

**步骤**:
1. 安装 Zig 0.13
2. 恢复原始代码
3. 编译测试

**优点**:
- 快速恢复
- 无需代码修改

**缺点**:
- 使用旧版本 Zig
- 无法使用新功能

---

## 下一步行动

1. **决定方案**: 选择继续迁移或降级
2. **创建详细任务**: 为每个待修复错误创建任务
3. **执行修复**: 按优先级逐个修复
4. **测试验证**: 确保所有功能正常

---

## 参考

- [Zig 0.16 Release Notes](https://ziglang.org/download/0.16.0/release-notes.html)
- [Zig std lib 文档](https://ziglang.org/documentation/0.16.0/std/)
