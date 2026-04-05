### Task-BUG-019: 修复 getApiKey 内存管理问题
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 2h

**描述**:
`getApiKey` 函数返回由 `page_allocator` 分配的内存，但函数签名没有明确表明调用者需要释放。这容易导致内存泄漏。

**当前代码**:
```zig
// src/core/root.zig:178
pub fn getApiKey(provider: KnownProvider) ?[]const u8 {
    const env_var = switch (provider) {
        .openai => "OPENAI_API_KEY",
        // ...
    };
    return std.process.getEnvVarOwned(std.heap.page_allocator, env_var) catch null;
}

// src/ai/models.zig:175 (重复定义)
pub fn getApiKey(provider: KnownProvider) ?[]const u8 {
    // 相同实现
}
```

**问题**:
1. 函数签名不明确（调用者不知道需要释放）
2. 使用 `page_allocator` 分配
3. 多处调用后没有正确释放
4. 两个文件中有重复定义

**修复方案**:

方案 1: 明确 allocator 参数（推荐）
```zig
// 统一在一个地方定义
// src/core/root.zig
pub fn getApiKey(allocator: std.mem.Allocator, provider: KnownProvider) error{OutOfMemory}!?[]const u8 {
    const env_var = switch (provider) {
        .openai => "OPENAI_API_KEY",
        .anthropic => "ANTHROPIC_API_KEY",
        .google => "GOOGLE_API_KEY",
        .kimi => "KIMI_API_KEY",
        .fireworks => "FIREWORKS_API_KEY",
        .openrouter => "OPENROUTER_API_KEY",
    };
    return std.process.getEnvVarOwned(allocator, env_var) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => return null,
        else => |e| return e,
    };
}

// 使用示例
const api_key = try core.getApiKey(arena.allocator(), provider);
// arena 释放时自动释放 api_key
```

方案 2: 使用固定缓冲区（简单但不通用）
```zig
pub fn getApiKey(provider: KnownProvider, buf: []u8) ?[]const u8 {
    // 将结果写入提供的缓冲区
}
```

**需要修改的文件**:
- [ ] src/core/root.zig
- [ ] src/ai/models.zig（删除重复定义，使用 core 的）
- [ ] src/ai/providers/openai.zig
- [ ] src/ai/providers/anthropic.zig
- [ ] src/ai/providers/google.zig
- [ ] src/ai/providers/kimi.zig
- [ ] src/ai/providers/fireworks.zig

**验收标准**:
- [ ] 统一在 core/root.zig 定义
- [ ] 添加 allocator 参数
- [ ] 删除 models.zig 的重复定义
- [ ] 所有调用点更新
- [ ] 正确处理错误（区分未设置和分配失败）
- [ ] 编译通过，测试通过

**依赖**:
- URGENT-FIX-compilation-errors
- TASK-BUG-013-fix-page-allocator-abuse

**阻塞**:
- 无直接阻塞

**笔记**:
这是 API 设计问题。修复后调用者明确知道需要释放内存，且可以使用 arena 简化管理。
