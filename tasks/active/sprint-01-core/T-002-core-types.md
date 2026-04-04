### T-002: 实现核心类型系统
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 4h

**描述**:
定义所有核心数据类型，包括 Message, Context, Tool, Skill 等。

**文件**:
- `src/core/types.zig`
- `src/core/errors.zig`

**类型列表**:
- Provider / KnownProvider
- Message (UserMessage, AssistantMessage, ToolResultMessage)
- Context
- Tool / ToolCall
- Skill / SkillMetadata
- Usage
- StopReason

**验收标准**:
- [ ] 所有类型定义完成
- [ ] 单元测试覆盖率 > 80%
- [ ] 内存布局优化
- [ ] 文档注释完整

**依赖**: T-001

**笔记**:
