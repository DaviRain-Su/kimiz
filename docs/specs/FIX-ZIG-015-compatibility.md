# FIX-ZIG-015: 修复 Zig 0.15.2 编译兼容性

**任务类型**: Bugfix  
**优先级**: P0 → **已取消 (cancelled)**  
**状态**: 项目已确认目标版本为 **Zig 0.16**，此修复不再适用。为 0.15 做的兼容性修改已全部回滚。

---

## 历史记录

> 以下内容保留作为历史参考。当前代码已恢复为 Zig 0.16 API。

### 原始问题

项目代码在最近几次提交中被部分改写成 **Zig 0.16** API，但某个开发环境仍然是 **Zig 0.15.2**。这导致 `zig build` 完全失败。

### 修复内容（已回滚）

- `src/main.zig`: 回退到 `pub fn main() !void`（移除 `std.process.Init`）
- `src/http.zig`: 移除 `std.Io` 依赖
- `src/utils/io_manager.zig`: 改成 Zig 0.15 no-op shim
- `src/cli/root.zig`: 修复 args/env 类型以适配 0.15

### 回滚原因

项目 Makefile 明确指定使用 `$(HOME)/zig-0.16.0-dev/zig`，且团队统一目标版本为 0.16。因此 0.15 兼容性修复与项目方向冲突，已被撤销。

---

## 参考文档

- [TigerBeetle Patterns](../TIGERBEETLE-PATTERNS-ANALYSIS.md) - Zig 代码质量基线（显式错误处理、资源边界）
- [NullClaw Lessons](../NULLCLAW-LESSONS-QUICKREF.md) - 错误恢复与资源管理原则
- [Zig 0.16 Breaking Changes](../ZIG-0.16-BREAKING-CHANGES-SUMMARY.md) - 0.15→0.16 API 差异对照

### 编译错误输出

```
src/main.zig:5:30: error: root source file struct 'process' has no member named 'Init'
    pub fn main(init: std.process.Init) !u8 {
                         ~~~~~~~~~~~^~~~~

src/http.zig:48:51: error: no field named 'io' in struct 'http.Client'
    .client = .{ .allocator = allocator, .io = io },
                                          ^~
```

---

## 修复方案

### 策略

**回退到 Zig 0.15.2 兼容写法**，而不是升级 Zig 版本。原因：
1. Zig 0.16 尚未正式 release
2. 当前机器环境固定为 0.15.2
3. 项目其他模块（providers, tools, agent）原本就是 0.15 写法

### 1. 修复 `src/main.zig`

**当前代码 (Zig 0.16)**:
```zig
pub fn main(init: std.process.Init) !u8 {
    const allocator = init.gpa;
    try utils.initIoManager(allocator, init.io);
    defer utils.deinitIoManager();
    try cli.run(allocator, init.environ_map, init.minimal.args);
    return 0;
}
```

**目标代码 (Zig 0.15)**:
```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 让 IoManager 在 0.15 下静默初始化（no-op）
    try utils.initIoManager(allocator, null);
    defer utils.deinitIoManager();

    const env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    try cli.run(allocator, &env_map, args);
}
```

> 注意：如果 `cli.run` 的签名不接受 `&env_map`（它可能期望 `*std.process.EnvMap` 或类似类型），需要根据 `src/cli/root.zig` 中 `run` 的实际签名调整。请阅读 `src/cli/root.zig` 中 `pub fn run(...)` 的定义。

### 2. 修复 `src/http.zig`

**当前代码 (Zig 0.16)**:
```zig
pub fn initWithIo(allocator: std.mem.Allocator, io: std.Io) Self {
    return .{
        .allocator = allocator,
        .client = .{ .allocator = allocator, .io = io },
        .io_initialized = true,
    };
}

pub fn init(allocator: std.mem.Allocator) Self {
    const io = utils.getIo() catch {
        return .{
            .allocator = allocator,
            .client = undefined,
            .io_initialized = false,
        };
    };
    return initWithIo(allocator, io);
}
```

**目标代码 (Zig 0.15)**:
```zig
pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
        .client = .{ .allocator = allocator },
        .io_initialized = true,
    };
}
```

**额外修改**:
- 删除 `initWithIo` 函数
- 删除 `AiError.IoManagerNotInitialized` 的使用（如果这个 error 只在 http.zig 中使用）
- 检查 `postJsonOnce` 中是否有 `std.Io` 或 Zig 0.16 特有的 API
- 检查 `Response` struct 和流式函数中是否有 0.16 特有的改动

### 3. 修复 `src/utils/io_manager.zig`

这个文件很可能是 Zig 0.16 的兼容层。需要让它在 0.15 下编译通过。

**策略**:
- 如果 `io_manager.zig` 大量使用了 `std.Io`，最简单的方法是**把它改成一个 dummy 实现**：
  ```zig
  pub const IoManager = struct {};
  pub fn initIoManager(allocator: std.mem.Allocator, io: ?anytype) !void { _ = allocator; _ = io; }
  pub fn deinitIoManager() void {}
  pub fn getIoManager() ?*IoManager { return null; }
  pub fn getIo() !void { return error.NotSupported; }
  ```
- 或者更好的方式：检查该文件的实际内容，移除 `std.Io` 依赖，返回一个 no-op。

### 4. 级联修复

修改上述文件后，运行 `zig build`。会出现新的编译错误。逐个修复，遵循以下原则：
- **不要引入 Zig 0.16 API**
- **保持现有业务逻辑不变**
- **只修改编译错误，不重构代码**

常见需要检查的文件：
- `src/utils/fs_helper.zig`（如果使用了 `std.Io.Dir`）
- `src/utils/config.zig`
- `src/utils/session.zig`
- `src/ai/root.zig`
- `src/ai/providers/*.zig`

---

## 验收标准

- [ ] `zig build` 编译成功，**零错误**
- [ ] `zig build test` 所有测试通过
- [ ] `zig build run -- repl` 可以启动 REPL
- [ ] 在 REPL 中输入 "hello" 能收到 AI 回复（确认基本流程没被改坏）

---

## 参考

- Zig 0.15.2 `std.http.Client` 文档: 不需要 `io` 字段，初始化方式为 `std.http.Client{ .allocator = allocator }`
- Zig 0.15.2 `main()` 签名: `pub fn main() !void` 或 `pub fn main() anyerror!void`
- `docs/11-zig-0.16-migration-guide.md` - 记录了 0.15→0.16 的差异（反向阅读，了解哪些改动需要回退）
