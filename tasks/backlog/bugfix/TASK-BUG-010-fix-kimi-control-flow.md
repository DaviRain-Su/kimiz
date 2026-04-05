### TASK-BUG-010: 修复 Kimi Provider 控制流问题
**状态**: pending
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 30分钟

**描述**:
AI 路由模块中 Kimi provider 的 stream() 分支存在控制流问题，内部 switch 表达式没有正确返回。

**问题代码**: src/ai/root.zig:87
```zig
pub fn stream(...) !void {
    const provider = detectProvider(model_id);
    
    switch (provider) {
        .kimi => {
            const kimi_provider = self.providers.kimi orelse return AiError.ProviderNotInitialized;
            switch (model_id) {
                // ❌ 这个内部 switch 没有 return
                "k1" => try kimi_provider.streamCode(context, callback),
                else => try kimi_provider.stream(context, callback),
            }
            // 缺少 return 或继续执行
        },
        .fireworks => {
            const fw = self.providers.fireworks orelse return AiError.ProviderNotInitialized;
            return fw.stream(context, callback);  // ✅ 正确
        },
        // ...
    }
}
```

**问题**:
1. kimi 分支的内部 switch 执行后没有 return
2. 可能继续执行后续代码（虽然当前没有）
3. 控制流不清晰

**修复方案**:

**添加 return**:
```zig
.kimi => {
    const kimi_provider = self.providers.kimi orelse return AiError.ProviderNotInitialized;
    return switch (model_id) {
        "k1" => kimi_provider.streamCode(context, callback),
        else => kimi_provider.stream(context, callback),
    };  // ✅ 使用 switch 表达式 + return
},
```

**或者使用统一模式**:
```zig
.kimi => {
    const kimi_provider = self.providers.kimi orelse return AiError.ProviderNotInitialized;
    if (std.mem.eql(u8, model_id, "k1")) {
        return kimi_provider.streamCode(context, callback);
    } else {
        return kimi_provider.stream(context, callback);
    }
},
```

**验收标准**:
- [ ] 修复 kimi 分支控制流
- [ ] 检查其他 provider 是否有同样问题
- [ ] 编译通过
- [ ] 测试 kimi provider 流式调用

**依赖**: 
- URGENT-FIX (编译错误修复)

**相关文件**:
- src/ai/root.zig

**笔记**:
这可能导致未定义行为，虽然当前代码可能侥幸工作。
