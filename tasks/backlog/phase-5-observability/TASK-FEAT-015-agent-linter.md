### Task-FEAT-015: 实现 Agent Linter 约束系统
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 6h

**描述**:
参考 OpenAI 的 harness engineering 实践，实现 Agent Linter 约束系统。核心洞察：**约束优于指令**。用 linter、架构规则强制约束，比用自然语言描述"应该怎么做"更有效。

**背景**:
OpenAI 发现：
- "不要留 TODO" 比 "记得完成实现" 更有效
- "no TODOs, no partial implementations" 是更好的指令
- 自定义 linter 强制执行架构约束

**目标功能**:

1. **LinterRule 结构**
```zig
pub const RuleSeverity = enum {
    warning,
    error,
    fatal,
};

pub const LinterRule = struct {
    name: []const u8,
    description: []const u8,
    severity: RuleSeverity,
    pattern: ?[]const u8,  // regex pattern
    check_fn: ?*const fn ([]const u8) bool,
};

pub const LintResult = struct {
    rule_name: []const u8,
    severity: RuleSeverity,
    message: []const u8,
    location: ?SourceLocation,
};
```

2. **默认规则集**
```zig
pub const DEFAULT_RULES = &[_]LinterRule{
    .{
        .name = "no-todos",
        .description = "TODO comments indicate incomplete work",
        .severity = .error,
        .pattern = "TODO|FIXME|HACK|XXX",
    },
    .{
        .name = "no-partial-impl",
        .description = "Partial implementations should be completed",
        .severity = .error,
        .pattern = "\\.\\.\\.\\s*$",  // trailing ...
    },
    .{
        .name = "no-print-debug",
        .description = "Debug prints should be removed",
        .severity = .warning,
        .pattern = "std\\.debug\\.print|console\\.log|println!",
    },
    .{
        .name = "max-file-size",
        .description = "Files should be <100KB",
        .severity = .warning,
        .check_fn = struct {
            fn check(content: []const u8) bool {
                return content.len < 100 * 1024;
            }
        }.check,
    },
};
```

3. **AgentLinter 引擎**
```zig
pub const AgentLinter = struct {
    rules: []const LinterRule,
    enabled_rules: std.StringHashMap(bool),

    pub fn check(self: *const AgentLinter, content: []const u8) ![]LintResult {
        var results: std.ArrayList(LintResult) = .empty;
        for (self.rules) |rule| {
            if (!self.isEnabled(rule.name)) continue;
            if (try self.applyRule(rule, content)) |result| {
                try results.append(result);
            }
        }
        return results.toOwnedSlice();
    }

    pub fn applyRule(self: *const AgentLinter, rule: LinterRule, content: []const u8) !?LintResult {
        if (rule.pattern) |pat| {
            if (containsPattern(content, pat)) {
                return LintResult{
                    .rule_name = rule.name,
                    .severity = rule.severity,
                    .message = rule.description,
                };
            }
        }
        return null;
    }
};
```

4. **与 Agent 集成**
```zig
// 在 Agent 生成代码后、提交前运行 linter
pub fn validateBeforeCommit(agent: *Agent, code: []const u8) !void {
    const results = try agent.linter.check(code);
    
    var errors: u32 = 0;
    for (results) |result| {
        if (result.severity == .error or result.severity == .fatal) {
            errors += 1;
            try agent.appendMessage(.{
                .role = "system",
                .content = try std.fmt.allocPrint(agent.allocator, 
                    "Linter error: {s} - {s}", .{ result.rule_name, result.message }),
            });
        }
    }
    
    if (errors > 0) {
        return error.LinterErrorsFound;
    }
}
```

5. **架构约束**
```zig
// 分层架构约束
pub const ARCHITECTURE_RULES = &[_]LinterRule{
    .{
        .name = "no-ui-in-core",
        .description = "Core layer cannot depend on UI",
        .severity = .error,
        .check_fn = struct {
            fn check(content: []const u8) bool {
                // 检查 import 语句
                // core 不能 import ui
            }
        }.check,
    },
    .{
        .name = "no-circular-deps",
        .description = "No circular dependencies allowed",
        .severity = .error,
        .check_fn = struct {
            fn check(content: []const u8) bool {
                // 分析依赖图
            }
        }.check,
    },
};
```

**验收标准**:
- [ ] 默认规则集完整
- [ ] 可配置的规则启用/禁用
- [ ] 与 Agent 生成流程集成
- [ ] 提供清晰的错误信息
- [ ] 支持自定义规则

**依赖**:
- Task-FEAT-006 (WorkspaceContext)

**阻塞**:
- 无

**笔记**:
这是让 Agent 行为符合预期的关键机制。
