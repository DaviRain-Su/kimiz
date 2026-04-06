### TASK-BUG-011: 修复模型检测 'o' 前缀歧义问题
**状态**: pending
**优先级**: P3
**创建**: 2026-04-05
**预计耗时**: 15分钟

**描述**:
detectProvider() 函数检查模型 ID 是否以 'o' 开头来判断 OpenAI，可能误判其他 provider 的模型。

**问题代码**: src/cli/root.zig:108
```zig
fn detectProvider(model_id: []const u8) core.Provider {
    if (std.mem.startsWith(u8, model_id, "gpt-")) return .openai;
    if (std.mem.startsWith(u8, model_id, "claude-")) return .anthropic;
    if (std.mem.startsWith(u8, model_id, "gemini-")) return .google;
    if (std.mem.startsWith(u8, model_id, "k")) return .kimi;
    if (std.mem.startsWith(u8, model_id, "o")) return .openai;  // ❌ 太宽泛
    return .openai; // default
}
```

**问题**:
1. 任何以 'o' 开头的模型都会被识别为 OpenAI
2. 例如 "opus-turbo"、"octopus-v1" 等都会误判
3. 其他 provider 可能有以 'o' 开头的模型

**修复方案**:

**更精确的检查**:
```zig
fn detectProvider(model_id: []const u8) core.Provider {
    if (std.mem.startsWith(u8, model_id, "gpt-")) return .openai;
    if (std.mem.startsWith(u8, model_id, "o1-") or 
        std.mem.startsWith(u8, model_id, "o3-")) return .openai;  // ✅ 精确匹配
    if (std.mem.startsWith(u8, model_id, "claude-")) return .anthropic;
    if (std.mem.startsWith(u8, model_id, "gemini-")) return .google;
    if (std.mem.startsWith(u8, model_id, "k1") or
        std.mem.startsWith(u8, model_id, "moonshot-")) return .kimi;
    
    return .openai; // default
}
```

**或者使用完整列表**:
```zig
const OPENAI_MODELS = [_][]const u8{
    "gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo",
    "o1-preview", "o1-mini", "o3-mini",
};

fn detectProvider(model_id: []const u8) core.Provider {
    for (OPENAI_MODELS) |model| {
        if (std.mem.eql(u8, model_id, model)) return .openai;
    }
    // ... 其他 provider
}
```

**验收标准**:
- [ ] 修改 'o' 前缀检查为更精确的规则
- [ ] 添加测试用例验证各种模型 ID
- [ ] 测试边缘情况（如 "opus", "o2" 等）
- [ ] 文档化支持的模型列表

**依赖**: 无

**相关文件**:
- src/cli/root.zig

**笔记**:
当前实现可能还能工作，但不够健壮，未来可能出问题。
