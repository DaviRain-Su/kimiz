### T-112: tla-plus-verify-agent-loop-state-machine
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 20h

**描述**:
用 TLA+ 验证 KimiZ Agent Loop 核心状态机的正确性，确保系统不会死锁或陷入无限循环。

作为 Hardness Engineer 的元级验证层，TLA+ 不是用来验证单个 skill 的，而是验证 Agent Loop 这个"心脏"。需要：
1. 为 Agent Loop 建立 TLA+ 形式化模型（状态、转换、不变量）
2. 验证：Agent 在任何状态下都能继续推进（无死锁）
3. 验证：spawn → running → completed 的状态转换是良基的（无活锁）
4. 验证：工具调用链不会无限递归
5. 将 TLA+ 模型和验证结果文档化，作为 KimiZ 可信基座的一部分

参考文档: docs/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md

**验收标准**:
- [ ] 核心设计/原型实现
- [ ] 集成测试或验证通过
- [ ] 文档更新
- [ ] 与现有任务（T-100 ~ T-111）的兼容性确认

**依赖**: 

**笔记**:
- 来自战略文档: docs/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md
- 这是构建 Hardness Engineer 多层防御系统的核心组成部分
