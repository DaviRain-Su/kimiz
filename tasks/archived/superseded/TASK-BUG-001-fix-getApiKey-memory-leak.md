### Task-BUG-001: 修复 getApiKey 内存泄漏
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**开始**: 
**完成**: 
**耗时**: 

**描述**:
`src/core/root.zig` 中的 `getApiKey` 函数使用 `std.process.getEnvVarOwned` 分配内存，但返回的 `?[]const u8` 从未被释放，导致每次调用都会泄漏内存。

**问题代码**:
```zig
pub fn getApiKey(provider: Provider) ?[]const u8 {
    const env_var = switch (provider) {
        .openai => "OPENAI_API_KEY",
        .anthropic => "ANTHROPIC_API_KEY",
        .kimi => "KIMI_API_KEY",
        .google => "GOOGLE_API_KEY",
    };
    return std.process.getEnvVarOwned(std.heap.page_allocator, env_var) catch null;
}
```

**修复方案**:
1. 修改函数签名，接受 allocator 参数
2. 或者使用静态缓冲区缓存结果
3. 或者改用不分配内存的 API

**验收标准**:
- [ ] 修复内存泄漏问题
- [ ] 更新所有调用者正确处理内存
- [ ] 添加内存泄漏测试

**依赖**:
- 无

**相关文件**:
- `src/core/root.zig` 第 279 行

**笔记**:
