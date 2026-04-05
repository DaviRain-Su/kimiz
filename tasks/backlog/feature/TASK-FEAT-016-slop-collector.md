### Task-FEAT-016: 实现 AI Slop 垃圾回收系统
**状态**: pending
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 6h

**描述**:
参考 OpenAI 的 harness engineering 实践，实现 AI Slop 垃圾回收系统。核心洞察：**熵会积累，需要"垃圾回收"**。Agent 会复制已有的模式，包括不理想的模式。

**背景**:
OpenAI 发现：
- Codex 会复制 repo 中已有的模式，包括不理想的
- 起初每周五花 20% 时间手动清理"AI slop"
- 很快意识到不可持续
- 转向自动化：把"黄金原则"编码进 repo，定期扫描

**目标功能**:

1. **SlopPattern 结构**
```zig
pub const SlopPattern = struct {
    name: []const u8,
    description: []const u8,
    pattern: []const u8,           // 检测 pattern
    replacement: ?[]const u8,       // 可选的替换
    severity: enum { warning, error },
};

pub const QualityScore = struct {
    overall: f64,                  // 0.0 - 1.0
    specificity: f64,             // 具体性评分
    consistency: f64,             // 与项目一致性
    completeness: f64,            // 完整性
};
```

2. **Slop 检测模式**
```zig
pub const SLOP_PATTERNS = &[_]SlopPattern{
    .{
        .name = "generic-comments",
        .description = "过于通用的注释",
        .pattern = "(?:This (?:function|class|module)|The following|The code)",
        .severity = .warning,
    },
    .{
        .name = "verbose-error",
        .description = "冗长的错误信息",
        .pattern = "An error occurred while (?:processing|handling)",
        .severity = .warning,
    },
    .{
        .name = "boilerplate-heavy",
        .description = "过多的模板代码",
        .pattern = "(?:TODO: Add|This should be extended in the future)",
        .severity = .warning,
    },
    .{
        .name = "magic-numbers",
        .description = "魔数应该用常量替代",
        .pattern = "\\b(?:100|1000|86400)\\b",
        .severity = .warning,
    },
};
```

3. **QualityScorer**
```zig
pub const QualityScorer = struct {
    patterns: []const SlopPattern,
    
    pub fn score(self: *const QualityScorer, content: []const u8) !QualityScore {
        var specificity: f64 = 0.8;
        var consistency: f64 = 0.9;
        var completeness: f64 = 0.7;
        
        // 检测 slop patterns
        for (self.patterns) |pattern| {
            if (containsPattern(content, pattern.pattern)) {
                completeness -= 0.1;
            }
        }
        
        // 检查具体性：是否有具体命名
        if (containsPattern(content, "\\b(?:foo|bar|baz|item|data)\\b")) {
            specificity -= 0.2;
        }
        
        return QualityScore{
            .overall = (specificity + consistency + completeness) / 3.0,
            .specificity = specificity,
            .consistency = consistency,
            .completeness = completeness,
        };
    }
};
```

4. **GarbageCollector**
```zig
pub const GarbageCollector = struct {
    scorer: QualityScorer,
    threshold: f64 = 0.7,  // 低于此分数需要清理
    dry_run: bool = true,

    pub fn scan(self: *GarbageCollector, repo_root: []const u8) !ScanResult {
        var issues: std.ArrayList(SlopIssue) = .empty;
        
        // 扫描所有代码文件
        var walker = try std.fs.walkDir(std.fs.cwd(), repo_root);
        while (try walker.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!isCodeFile(entry.path)) continue;
            
            const content = try readFile(entry.path);
            const score = try self.scorer.score(content);
            
            if (score.overall < self.threshold) {
                try issues.append(.{
                    .path = entry.path,
                    .score = score,
                    .issues = try self.findIssues(content),
                });
            }
        }
        
        return ScanResult{ .issues = issues.toOwnedSlice() };
    }

    pub fn autoFix(self: *GarbageCollector, issue: *const SlopIssue) !void {
        // 生成修复 PR
        // 或者直接应用修复
    }
};
```

5. **定期清理任务**
```zig
// 每周运行一次的清理任务
pub fn weeklyCleanup() !void {
    var gc = GarbageCollector{
        .scorer = QualityScorer{ .patterns = SLOP_PATTERNS },
        .dry_run = false,
    };
    
    const result = try gc.scan(".");
    
    if (result.issues.len > 0) {
        // 创建修复 PR
        const pr = try createCleanupPR(result);
        try std.debug.print("Created cleanup PR: {s}\n", .{ pr.url });
    }
}
```

**验收标准**:
- [ ] Slop pattern 检测完整
- [ ] Quality scoring 正确
- [ ] 自动生成修复建议
- [ ] 可配置的阈值
- [ ] CLI 命令集成

**依赖**:
- Task-FEAT-014 (Knowledge Base)

**阻塞**:
- 无

**笔记**:
这是保持代码库长期健康的关键机制。
