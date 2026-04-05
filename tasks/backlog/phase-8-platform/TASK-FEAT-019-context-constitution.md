### TASK-FEAT-019: 实现 Context Constitution (上下文宪法)
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 4h
**参考**: Sarah Wooders (Letta CTO) 关于"记忆是 Harness 核心"的观点

**描述**:
创建 Context Constitution (上下文宪法)，定义 Agent 管理上下文的通用原则，让 Agent 的上下文管理行为可预测、可审计、可优化。

**背景**:
Sarah Wooders 强调：真正的记忆是 Harness 里一系列"看不见"的决策决定的，比如：
- 系统提示怎么加载？
- 技能信息怎么展示给模型？
- Agent 能不能自己改系统指令？
- 压缩上下文时什么该留、什么该丢？

这些东西**只能由 Harness 自己决定**。Context Constitution 就是把这些决策显式化、文档化。

**Context Constitution 结构**:
```markdown
# Kimiz Context Constitution

## 1. 上下文分层策略

### 1.1 消息保留优先级
| 优先级 | 类型 | 保留策略 |
|--------|------|----------|
| 最高 | 系统指令 | 永不删除 |
| 高 | 技能定义 | 压缩但不删除 |
| 中 | 用户偏好 | 定期巩固到记忆 |
| 低 | 中间结果 | 超过阈值删除 |
| 最低 | 工具输出 | 立即压缩或删除 |

### 1.2 上下文压缩触发条件
- 触发时机: context 使用率 > 80%
- 压缩策略: oldest_first (默认)
- 保留底线: 最近 10 条对话 + 系统提示

## 2. 记忆固化规则

### 2.1 什么时候固化
- 用户明确表达偏好时 → 立即固化到 WorkingMemory
- 同一信息出现 3 次 → 自动固化
- 会话结束时 → 总结固化

### 2.2 固化质量标准
- 内容精简: 原始 > 512 tokens → 摘要到 < 128 tokens
- 保留关键: 保留实体、动作、结果
- 保留上下文: 保留关联的记忆链接

## 3. 上下文完整性保障

### 3.1 必保留元素
- 当前任务目标
- 已完成的步骤
- 遇到的问题及解决方案
- 用户明确偏好

### 3.2 可压缩元素
- 详细错误堆栈 (保留摘要)
- 重复的工具调用
- 中间推导过程

## 4. Agent 自我修改边界

### 4.1 Agent 可以修改
- 工作记忆内容
- 会话内的偏好设置
- 任务优先级

### 4.2 Agent 不可以修改
- 系统级提示词
- 安全策略
- 核心工具定义

### 4.3 修改需要确认
- 用户偏好变更
- 记忆固化策略
- 新技能添加
```

**Zig 实现**:
```zig
// src/harness/context_constitution.zig
pub const ContextConstitution = struct {
    allocator: std.mem.Allocator,
    
    /// 上下文分层策略
    pub const LayerPriority = enum(u8) {
        system = 1,     // 系统指令
        skill = 2,      // 技能定义
        preference = 3,  // 用户偏好
        result = 4,     // 中间结果
        tool_output = 5,// 工具输出
    };
    
    /// 压缩触发条件
    pub const Triggers = struct {
        threshold: f32 = 0.8,      // 80% 使用率
        min_messages: usize = 10,  // 最少保留消息
        max_message_age: i64 = 3600, // 1小时前的可压缩
    };
    
    /// 固化规则
    pub const ConsolidationRules = struct {
        explicit_preference: bool = true,      // 明确偏好立即固化
        repetition_threshold: u32 = 3,          // 重复 3 次自动固化
        session_end: bool = true,             // 会话结束固化
        max_age_seconds: i64 = 86400,         // 24小时旧内容固化
    };
    
    /// 必保留元素
    pub const RequiredElements = struct {
        current_goal: bool = true,
        completed_steps: bool = true,
        problems_solved: bool = true,
        explicit_preferences: bool = true,
    };
    
    /// 可压缩元素
    pub const CompressibleElements = struct {
        error_stack: bool = true,        // 保留摘要
        repeated_calls: bool = true,      // 合并重复
        derivation_steps: bool = false,   // 不压缩推导
    };
    
    /// Agent 可修改的边界
    pub const AgentModifiable = struct {
        working_memory: bool = true,
        session_preferences: bool = true,
        task_priority: bool = true,
        // 不可修改
        system_prompt: bool = false,
        safety_policy: bool = false,
        core_tools: bool = false,
    };
    
    /// 检查元素是否可压缩
    pub fn canCompress(self: *ContextConstitution, element: LayerPriority) bool {
        return @intFromEnum(element) >= 3;
    }
    
    /// 检查元素是否必保留
    pub fn mustRetain(self: *ContextConstitution, element: LayerPriority) bool {
        return @intFromEnum(element) <= 2;
    }
    
    /// 评估压缩质量
    pub fn compressionQuality(
        self: *ContextConstitution,
        original: []const u8,
        compressed: []const u8,
    ) f64 {
        const ratio = @as(f64, @intCast(compressed.len)) / @as(f64, @intCast(original.len));
        // 质量 = 保留关键信息量 / 压缩比
        const retention = if (ratio < 0.5) 0.8 else 1.0 - ratio;
        return retention;
    }
};
```

**ContextTruncator 集成**:
```zig
// src/harness/context_truncation.zig
pub const ContextTruncator = struct {
    // ... existing fields ...
    constitution: *const ContextConstitution,  // 新增
    
    pub fn truncateWithConstitution(self: *Self, messages: *std.ArrayList(core.Message)) !void {
        // 使用 Constitution 指导压缩决策
        var i: usize = 0;
        while (i < messages.items.len) {
            const priority = self.classifyMessage(messages.items[i]);
            
            if (self.constitution.canCompress(priority)) {
                // 检查是否必保留
                if (self.constitution.mustRetain(priority)) {
                    i += 1;
                    continue;
                }
                
                // 检查年龄
                const age = self.getMessageAge(messages.items[i]);
                if (age < self.constitution.Triggers.max_age_seconds) {
                    i += 1;
                    continue;
                }
                
                // 可以压缩
                self.compressMessage(messages.items[i]);
                i += 1;
            } else {
                i += 1;
            }
        }
    }
};
```

**验收标准**:
- [ ] ContextConstitution 结构定义完整
- [ ] 压缩决策遵循 Constitution
- [ ] 必保留元素不被压缩
- [ ] 文档完整 (CONSTS.md)
- [ ] 测试覆盖关键路径

**依赖**:
- TASK-FEAT-008 (Context Truncation)

**阻塞**:
- 无
