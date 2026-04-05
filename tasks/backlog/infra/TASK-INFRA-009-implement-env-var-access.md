### TASK-INFRA-009: 实现环境变量访问

**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 2小时
**阻塞**: API Key 读取

**描述**:
当前环境变量访问被禁用，返回 `null`。需要实现完整的环境变量访问功能，用于读取 API Keys。

**背景**:
Zig 0.16 中 `std.process.getEnvVarOwned` 已被移除。环境变量现在通过 `Init.environ_map` 访问。

**解决方案**:

### 方案 1: 通过 main 函数参数传递 (推荐)

Zig 0.16 的 `main` 函数可以接收 `std.process.Init` 参数：

```zig
pub fn main(init: std.process.Init) !void {
    // 访问环境变量
    const env_map = init.environ_map;
    if (env_map.get("OPENAI_API_KEY")) |api_key| {
        // 使用 API key
    }
}
```

**修改步骤**:

1. **修改 main.zig 接收 Init 参数**
```zig
const std = @import("std");
const cli = @import("cli/root.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    
    // 将 environ_map 传递给需要环境变量的模块
    try cli.run(allocator, init.environ_map);
}
```

2. **修改 cli.run 接收 environ_map**
```zig
pub fn run(
    allocator: std.mem.Allocator,
    environ_map: *std.process.Environ.Map,
) !void {
    // 存储 environ_map 供后续使用
    g_environ_map = environ_map;
    
    // ... 其余代码
}

// 全局变量或线程局部存储
threadlocal var g_environ_map: ?*std.process.Environ.Map = null;

// 获取环境变量的辅助函数
pub fn getEnvVar(allocator: std.mem.Allocator, name: []const u8) ?[]const u8 {
    const env_map = g_environ_map orelse return null;
    return env_map.get(name);
}
```

3. **修改 core.getApiKey 使用新的环境变量访问**
```zig
pub fn getApiKey(allocator: std.mem.Allocator, provider: KnownProvider) ?[]const u8 {
    const env_var = switch (provider) {
        .openai => "OPENAI_API_KEY",
        .anthropic => "ANTHROPIC_API_KEY",
        .google => "GOOGLE_API_KEY",
        .kimi => "KIMI_API_KEY",
        .fireworks => "FIREWORKS_API_KEY",
        .openrouter => "OPENROUTER_API_KEY",
    };
    
    // 使用新的环境变量访问方式
    return cli.getEnvVar(allocator, env_var);
}
```

### 方案 2: 使用 POSIX getenv (备选)

如果不通过 Init 传递，可以直接使用 POSIX 函数：

```zig
const c = @cImport({
    @cInclude("stdlib.h");
});

pub fn getEnvVar(name: []const u8) ?[]const u8 {
    const c_name = std.cstr.addNullByte(std.heap.page_allocator, name) catch return null;
    defer std.heap.page_allocator.free(c_name);
    
    const value = c.getenv(c_name.ptr);
    if (value == null) return null;
    
    return std.mem.span(value);
}
```

**缺点**: 需要链接 libc，不够 Zig 风格。

**推荐方案**: 方案 1

**验收标准**:
- [ ] 可以从环境变量读取 API Keys
- [ ] 支持所有需要的变量 (OPENAI_API_KEY, ANTHROPIC_API_KEY, 等)
- [ ] 错误处理完善 (变量不存在时的处理)
- [ ] 内存管理正确
- [ ] 单元测试通过

**依赖**:
- 无

**阻塞**:
- 所有需要 API Key 的功能

**参考**:
- Zig 0.16 std.process.Init 文档
- Zig 0.16 std.process.Environ 文档
