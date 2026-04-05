### Task-REF-004: 移除 Learning 系统
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 2h
**参考**: [Simplified Architecture Proposal](../../docs/design/simplified-architecture-proposal.md)

**描述**:
移除当前复杂的自适应 Learning 系统，改为简单的用户配置。Learning 系统的价值 unclear，且增加大量代码复杂度。

**当前代码**:
```zig
// src/learning/root.zig (~400 行)
pub const LearningEngine = struct {
    user_preferences: UserPreferences,
    tool_patterns: std.StringHashMap(ToolUsagePattern),
    model_metrics: std.StringHashMap(ModelMetrics),
    
    pub fn learnFromCodeChange(...) !void;
    pub fn recordToolUsage(...) !void;
    pub fn recordModelPerformance(...) !void;
    pub fn recommendModel(...) ?[]const u8;
    pub fn shouldAutoApprove(...) bool;
};
```

**移除内容**:
1. 删除 `src/learning/root.zig`
2. 删除所有 Learning 相关引用
3. 将用户偏好移至简单配置

**替代方案**:

```json
// ~/.kimiz/config.json
{
  "default_model": "claude-sonnet-4",
  "thinking_level": "medium",
  "auto_approve_tools": ["read", "grep", "find"],
  "theme": "dark",
  "code_style": {
    "indent": "spaces",
    "indent_size": 4
  }
}
```

```zig
// src/utils/config.zig (简化)
pub const Config = struct {
    default_model: []const u8,
    thinking_level: ThinkingLevel,
    auto_approve_tools: []const []const u8,
    theme: Theme,
    code_style: CodeStyle,
    
    // 简单的加载/保存
    pub fn load(allocator: std.mem.Allocator) !Config;
    pub fn save(self: Config) !void;
};
```

**需要修改的文件**:
- [ ] 删除 `src/learning/root.zig`
- [ ] 修改 `src/utils/config.zig` (简化)
- [ ] 删除 `src/agent/agent.zig` 中的 Learning 引用
- [ ] 删除 `src/ai/routing.zig` (Smart Routing 也移除)
- [ ] 更新所有相关测试

**验收标准**:
- [ ] Learning 系统完全移除
- [ ] 配置系统正常工作
- [ ] 代码减少 400+ 行
- [ ] 编译通过
- [ ] 测试通过

**依赖**:
- 无

**阻塞**:
- 无

**笔记**:
Learning 系统虽然听起来很酷，但实际效果难以量化。简单配置更可靠。
