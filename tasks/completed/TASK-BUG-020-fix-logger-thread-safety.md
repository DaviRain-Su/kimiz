### Task-BUG-020: 修复全局 Logger 线程安全问题
**状态**: pending
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 2h

**描述**:
全局 Logger 使用 Mutex 保护，但 `getLogger()` 返回的指针可能在多线程中被同时使用，存在潜在的线程安全问题。

**当前代码**:
```zig
// src/utils/log.zig:178-195
var global_logger: ?Logger = null;
var logger_mutex: std.Thread.Mutex = .{};

pub fn getLogger() *Logger {
    logger_mutex.lock();
    defer logger_mutex.unlock();

    if (global_logger) |*logger| {
        return logger;  // ❌ 返回指针后 Mutex 解锁
    }
    // ...
}
```

**问题**:
1. 返回指针后 Mutex 立即解锁
2. 多线程可能同时访问 Logger 实例
3. 文件写入可能交错
4. 日志行可能混合

**修复方案**:

方案 1: 每个线程独立的 Logger（复杂）
```zig
threadlocal var thread_logger: ?Logger = null;
```

方案 2: 使用更粗粒度的锁（简单）
```zig
pub fn log(self: *Logger, level: LogLevel, comptime fmt: []const u8, args: anytype) void {
    // 已经在 Logger 内部使用 Mutex
    self.mutex.lock();
    defer self.mutex.unlock();
    // ...
}
```

方案 3: 使用无锁队列（高性能）
```zig
const LogQueue = struct {
    // 使用 std.atomic.Queue
    // 生产者（多线程）入队
    // 消费者（单线程）出队写入文件
};
```

**推荐方案**:
方案 2 足够满足当前需求，Logger 内部已经有 Mutex。

**验收标准**:
- [ ] 多线程日志不交错
- [ ] 性能可接受
- [ ] 编译通过，测试通过

**依赖**:
- 无

**阻塞**:
- 无直接阻塞

**笔记**:
这是一个潜在的并发问题。当前代码在单线程场景下工作正常，但在多线程 Agent 中可能出现问题。
