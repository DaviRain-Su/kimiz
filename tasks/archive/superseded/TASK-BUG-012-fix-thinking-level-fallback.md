### TASK-BUG-012: 修复 thinking level 无效值静默回退问题
**状态**: pending
**优先级**: P3
**创建**: 2026-04-05
**预计耗时**: 15分钟

**描述**:
parseThinkingLevel() 对于无效输入静默返回 .off，可能隐藏用户的拼写错误。

**问题代码**: src/cli/root.zig:98
```zig
fn parseThinkingLevel(level_str: []const u8) core.ThinkingLevel {
    if (std.mem.eql(u8, level_str, "off")) return .off;
    if (std.mem.eql(u8, level_str, "low")) return .low;
    if (std.mem.eql(u8, level_str, "medium")) return .medium;
    if (std.mem.eql(u8, level_str, "high")) return .high;
    return .off;  // ❌ 静默回退，用户不知道输入错误
}
```

**问题**:
1. 用户输入 "meduim"（拼写错误）会静默使用 .off
2. 用户输入 "max"（期望高级别）也会变成 .off
3. 没有任何提示或警告

**修复方案**:

**选项1**: 返回 error（推荐）
```zig
fn parseThinkingLevel(level_str: []const u8) !core.ThinkingLevel {
    if (std.mem.eql(u8, level_str, "off")) return .off;
    if (std.mem.eql(u8, level_str, "low")) return .low;
    if (std.mem.eql(u8, level_str, "medium")) return .medium;
    if (std.mem.eql(u8, level_str, "high")) return .high;
    
    log.err("Invalid thinking level: {s}. Valid options: off, low, medium, high", .{level_str});
    return error.InvalidThinkingLevel;
}
```

**选项2**: 记录警告但使用默认值
```zig
fn parseThinkingLevel(level_str: []const u8) core.ThinkingLevel {
    if (std.mem.eql(u8, level_str, "off")) return .off;
    if (std.mem.eql(u8, level_str, "low")) return .low;
    if (std.mem.eql(u8, level_str, "medium")) return .medium;
    if (std.mem.eql(u8, level_str, "high")) return .high;
    
    log.warn("Invalid thinking level '{s}', using 'off'. Valid: off, low, medium, high", .{level_str});
    return .off;
}
```

**选项3**: 支持更多别名
```zig
fn parseThinkingLevel(level_str: []const u8) core.ThinkingLevel {
    const lower = std.ascii.toLowerString(level_str);  // 不区分大小写
    
    if (std.mem.eql(u8, lower, "off") or 
        std.mem.eql(u8, lower, "none")) return .off;
    if (std.mem.eql(u8, lower, "low") or 
        std.mem.eql(u8, lower, "1")) return .low;
    if (std.mem.eql(u8, lower, "medium") or 
        std.mem.eql(u8, lower, "med") or 
        std.mem.eql(u8, lower, "2")) return .medium;
    if (std.mem.eql(u8, lower, "high") or 
        std.mem.eql(u8, lower, "max") or 
        std.mem.eql(u8, lower, "3")) return .high;
    
    log.warn("Invalid thinking level '{s}', using 'off'", .{level_str});
    return .off;
}
```

**验收标准**:
- [ ] 选择合适的方案
- [ ] 添加错误提示或警告
- [ ] 测试各种输入（有效、无效、边缘情况）
- [ ] 更新帮助文档

**依赖**: 
- T-008 (日志系统)

**相关文件**:
- src/cli/root.zig

**笔记**:
用户体验问题，推荐至少添加警告日志。
