### TASK-P2-003: 完成 Learning learnFromCodeChange 实现
**状态**: pending
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 6h

**描述**:
LearningEngine.learnFromCodeChange() 是空实现，需要分析代码变更来学习用户风格偏好。

**位置**: `src/learning/root.zig:224-229`

**当前代码**:
```zig
pub fn learnFromCodeChange(
    self: *Self,
    filepath: []const u8,
    old_code: []const u8,
    new_code: []const u8,
) !void {
    // TODO: Analyze code changes to learn style preferences
    _ = self;
    _ = filepath;
    _ = old_code;
    _ = new_code;
}
```

**修复方案**:

```zig
pub fn learnFromCodeChange(
    self: *Self,
    filepath: []const u8,
    old_code: []const u8,
    new_code: []const u8,
) !void {
    // 1. 检测缩进风格变化
    const old_indent = detectIndentStyle(old_code);
    const new_indent = detectIndentStyle(new_code);
    if (old_indent != new_indent) {
        self.preferences.code_style.indentation = new_indent;
    }
    
    // 2. 检测命名风格变化
    const old_naming = detectNamingStyle(old_code);
    const new_naming = detectNamingStyle(new_code);
    if (new_naming != .unknown) {
        self.preferences.code_style.naming = new_naming;
    }
    
    // 3. 检测行长度偏好
    const old_avg_line_len = averageLineLength(old_code);
    const new_avg_line_len = averageLineLength(new_code);
    if (@abs(old_avg_line_len - new_avg_line_len) > 10) {
        self.preferences.code_style.max_line_length = @intFromFloat(new_avg_line_len);
    }
    
    // 4. 检测语言偏好
    if (std.mem.endsWith(u8, filepath, ".zig")) {
        self.preferences.code_style.language = .zig;
    } else if (std.mem.endsWith(u8, filepath, ".rs")) {
        self.preferences.code_style.language = .rust;
    }
    
    self.dirty = true;
}

fn detectIndentStyle(code: []const u8) IndentationStyle {
    var spaces_count: u32 = 0;
    var tabs_count: u32 = 0;
    
    var lines = std.mem.split(u8, code, "\n");
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "    ")) spaces_count += 1;
        else if (std.mem.startsWith(u8, line, "\t")) tabs_count += 1;
    }
    
    if (spaces_count > tabs_count * 2) return .spaces;
    if (tabs_count > spaces_count * 2) return .tabs;
    return .unknown;
}
```

**验收标准**:
- [ ] 从代码变更学习缩进风格
- [ ] 从代码变更学习命名风格
- [ ] 从代码变更学习行长度偏好
- [ ] 保存学习到的偏好

**依赖**:
- TASK-INTEG-002 (集成 Learning)

**阻塞**:
- 无

**笔记**:
这是一个高级功能，可以后续实现。
