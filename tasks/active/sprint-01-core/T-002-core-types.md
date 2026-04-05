### T-002: 实现核心类型系统
**状态**: completed
**优先级**: P0
**创建**: 2026-04-05
**完成**: 2026-04-05
**预计耗时**: 4h
**实际耗时**: 4h

**描述**:
定义所有核心数据类型，包括 Message, Context, Tool, Skill 等。

**文件**:
- `src/core/root.zig` (合并了 types 和 errors)

**类型列表**:
- [x] Provider / KnownProvider
- [x] Message (UserMessage, AssistantMessage, ToolResultMessage)
- [x] Context
- [x] Tool / ToolCall
- [x] Model / ModelCost
- [x] Usage
- [x] StopReason
- [x] ThinkingLevel

**验收标准**:
- [x] 所有类型定义完成
- [x] 单元测试覆盖率 > 80%
- [x] 内存布局优化
- [x] 文档注释完整

**依赖**: T-001

**笔记**:
所有核心类型已在 src/core/root.zig 中定义完成。
