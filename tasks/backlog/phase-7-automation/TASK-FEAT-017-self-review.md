### Task-FEAT-017: 实现 Agent Self-Review 系统
**状态**: pending
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 8h

**描述**:
参考 OpenAI 的 harness engineering 实践，实现 Agent Self-Review 系统。核心洞察：**Agent review 可以替代大部分人类 review，人类角色转向定义审查标准。**

**背景**:
OpenAI 发现：
- 让 Codex 先自我审查，再请求其他 agent 审查
- 在循环中迭代直到所有 agent reviewer 满意
- 人类角色从逐行审查转向定义审查标准、在 AGENTS.md 中编码品味偏好
- 80% 以上的评论反应是正面的

**目标功能**:

1. **ReviewCriteria 结构**
```zig
pub const ReviewCriteria = struct {
    correctness: bool = true,
    performance: bool = true,
    style: bool = true,
    security: bool = true,
    tests: bool = true,
    documentation: bool = true,
};

pub const ReviewResult = struct {
    passed: bool,
    criteria: ReviewCriteria,
    issues: []const ReviewIssue,
    suggestions: []const []const u8,
    score: f64,  // 0.0 - 1.0
};

pub const ReviewIssue = struct {
    severity: enum { critical, major, minor, suggestion },
    category: []const u8,
    description: []const u8,
    location: ?SourceLocation,
    fix_suggestion: ?[]const u8,
};
```

2. **SelfReviewer**
```zig
pub const SelfReviewer = struct {
    criteria: ReviewCriteria,
    max_iterations: u32 = 3,
    llm: *Llama,
    
    pub fn review(
        self: *SelfReviewer,
        code: []const u8,
        context: *const AgentContext,
    ) !ReviewResult {
        var current_code = code;
        var iteration: u32 = 0;
        
        while (iteration < self.max_iterations) : (iteration += 1) {
            const issues = try self.performReview(current_code, context);
            
            if (issues.len == 0) {
                return ReviewResult{
                    .passed = true,
                    .criteria = self.criteria,
                    .issues = &.{},
                    .suggestions = &.{},
                    .score = 1.0,
                };
            }
            
            // 尝试自动修复
            const fixed = try self.autoFix(current_code, issues);
            if (std.mem.eql(u8, fixed, current_code)) {
                // 无法继续修复
                break;
            }
            current_code = fixed;
        }
        
        return ReviewResult{
            .passed = false,
            .criteria = self.criteria,
            .issues = try self.performReview(current_code, context),
            .suggestions = try self.generateSuggestions(current_code),
            .score = 0.5,
        };
    }
    
    fn performReview(self: *SelfReviewer, code: []const u8, context: *const AgentContext) ![]const ReviewIssue {
        // 构建 review prompt
        const prompt = try std.fmt.allocPrint(self.allocator,
            \\Review the following code for:
            \\{s}
            \\
            \\Code:
            \\{s}
        , .{ self.criteriaToString(), code });
        
        // 调用 LLM 进行审查
        const response = try self.llm.complete(prompt);
        return try self.parseReviewResponse(response);
    }
};
```

3. **多 Agent 审查循环**
```zig
// 参考 OpenAI 的 agent review 循环
pub const ReviewLoop = struct {
    author: *Agent,          // 代码作者
    reviewers: []*Agent,     // 审查 agents
    max_rounds: u32 = 3,

    pub fn run(self: *ReviewLoop, code: []const u8) !ReviewResult {
        var current_code = code;
        
        for (0..self.max_rounds) |round| {
            // 每个 reviewer 审查
            var all_issues: std.ArrayList(ReviewIssue) = .empty;
            
            for (self.reviewers) |reviewer| {
                const issues = try reviewer.review(current_code);
                try all_issues.appendSlice(issues);
            }
            
            if (all_issues.items.len == 0) {
                return ReviewResult{ .passed = true, .final_code = current_code };
            }
            
            // 作者根据反馈修复
            current_code = try self.author.fixIssues(current_code, all_issues.items);
        }
        
        return ReviewResult{ .passed = false, .final_code = current_code };
    }
};
```

4. **与 CI 集成**
```zig
// 在 PR 时自动运行 self-review
pub fn runPReview(pr: *const PullRequest) !void {
    const code = try pr.getDiff();
    const context = try buildAgentContext(pr.repo);
    
    var reviewer = SelfReviewer{
        .criteria = ReviewCriteria{
            .correctness = true,
            .style = true,
            .tests = true,
        },
        .max_iterations = 3,
        .llm = try createLlama(),
    };
    
    const result = try reviewer.review(code, context);
    
    if (!result.passed) {
        try pr.postComment(result.summary());
    }
}
```

5. **质量评分卡**
```zig
// 生成质量评分卡
pub const Scorecard = struct {
    file_path: []const u8,
    scores: std.StringHashMap(f64),  // criterion -> score
    
    pub fn toMarkdown(self: *const Scorecard) []const u8 {
        // 生成 Markdown 格式的评分卡
        return std.fmt.allocPrint(allocator,
            \\## Quality Scorecard: {s}
            \\
            \\| Criterion | Score |
            \\|------------|-------|
            \\| Correctness | {d:.1}/10 |
            \\| Performance | {d:.1}/10 |
            \\| Style | {d:.1}/10 |
            \\
        , .{
            self.file_path,
            self.scores.get("correctness").?,
            self.scores.get("performance").?,
            self.scores.get("style").?,
        });
    }
};
```

**验收标准**:
- [ ] Self-review 能检测常见问题
- [ ] 自动修复可修复的问题
- [ ] 质量评分卡生成正确
- [ ] 与 Agent 生成流程集成
- [ ] CLI 命令可用

**依赖**:
- Task-FEAT-014 (Knowledge Base)
- Task-FEAT-015 (Agent Linter)

**阻塞**:
- 无

**笔记**:
这是 OpenAI 实践中证明有效的核心机制。
