# TASK-FEAT-024: Specialist Subagent System

**状态**: pending  
**优先级**: P0  
**预计工时**: 16小时  
**指派给**: TBD  
**标签**: agent, specialization, harness

---

## 背景

基于 Nyk 四大支柱和 Coda 研究，Agent Specialization 要求从通用 Subagent 转向专职 Expert。

> "不要一个万能 agent，要按领域拆成专职子 Agent" —— Nyk

Coda 案例: Explorer/Planner/Researcher/Triager/Coder 分工

---

## 目标

重构 Subagent 系统，实现 Specialist 专业化分工模式。

---

## 详细需求

### 1. Specialist Type Enum

```zig
// src/agent/specialist.zig
pub const SpecialistType = enum {
    explorer,      // 代码探索专家
    planner,       // 任务规划专家
    researcher,    // 调研专家
    coder,         // 代码实现专家
    reviewer,      // 代码审查专家
    debugger,      // 调试专家
    architect,     // 架构专家
};
```

### 2. Specialist Subagent 结构

```zig
pub const SpecialistSubAgent = struct {
    base: SubAgent,
    specialist_type: SpecialistType,
    
    // 专业领域配置
    prompt_template: []const u8,      // 专家领域提示词
    tool_set: []const Tool,           // 专业工具集（最小化）
    knowledge_base: ?KnowledgeBase,   // 专业知识库
    
    // 约束
    read_only_default: bool,          // 默认只读模式
    max_depth_override: ?u32,         // 深度限制覆盖
    
    pub fn execute(self: *SpecialistSubAgent, task: Task) !Result;
};
```

### 3. 各 Specialist 定义

#### Explorer (代码探索)
```zig
const EXPLORER_PROMPT = 
    \\You are a code exploration expert.
    \\Your job: understand codebase structure, trace call chains, analyze dependencies.
    \\Tools: read_file, glob, grep (read-only)
    \\Output: structured analysis report
;

const EXPLORER_TOOLS = &[_]Tool{ read_file, glob, grep };
```

#### Planner (任务规划)
```zig
const PLANNER_PROMPT =
    \\You are a task planning expert.
    \\Your job: break down vague requirements into verifiable subtasks.
    \\Tools: read_file (for context), write_file (for plan)
    \\Output: task breakdown with dependencies
;
```

#### Coder (代码实现)
```zig
const CODER_PROMPT =
    \\You are a coding expert.
    \\Your job: implement features following best practices.
    \\Tools: all file operations, code editing
    \\Constraints: must write tests, follow style guide
;
```

#### Reviewer (代码审查)
```zig
const REVIEWER_PROMPT =
    \\You are a code review expert.
    \\Your job: analyze code quality, security, performance.
    \\Tools: read-only tools only
    \\Output: review report with severity levels
;
```

### 4. Master Agent 协调器

```zig
pub const MasterAgent = struct {
    specialists: std.EnumMap(SpecialistType, SpecialistSubAgent),
    
    /// Analyze task and delegate to appropriate specialist
    pub fn delegate(self: *MasterAgent, task: Task) !Result {
        const specialist_type = self.selectSpecialist(task);
        var specialist = self.specialists.get(specialist_type);
        return specialist.execute(task);
    }
    
    /// Chain multiple specialists for complex tasks
    pub fn chainExecute(self: *MasterAgent, chain: []SpecialistType, task: Task) !Result;
};
```

### 5. Structured Handoff Protocol

```zig
pub const HandoffProtocol = struct {
    from: SpecialistType,
    to: SpecialistType,
    context: HandoffContext,
    deliverables: []const Deliverable,
    
    pub fn validate(self: *HandoffProtocol) !bool;
};
```

---

## 验收标准

- [ ] 实现 5 个核心 Specialist (Explorer, Planner, Coder, Reviewer, Researcher)
- [ ] 每个 Specialist 有独立的 prompt template 和 tool set
- [ ] Master Agent 能根据任务类型自动选择 Specialist
- [ ] 支持 Specialist chain (Explorer → Planner → Coder → Reviewer)
- [ ] Handoff Protocol 实现上下文传递
- [ ] 工具最小化原则：每个 Specialist 只能访问必要工具

---

## 相关文件

- `src/agent/subagent.zig` (需重构)
- `src/agent/agent.zig`
- `src/agent/tool.zig`
- `docs/research/coda-team-agent-analysis.md`

---

## 参考

- docs/research/harness-four-pillars-nyk-analysis.md
- docs/research/coda-team-agent-analysis.md
- Nyk: "按领域拆成专职子 Agent，每个只给它需要的工具"
