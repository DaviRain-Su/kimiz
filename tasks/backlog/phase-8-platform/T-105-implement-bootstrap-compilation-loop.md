### T-105: implement-bootstrap-compilation-loop
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 30h

**描述**:
实现自举编译循环，让 Agent 能触发 `zig build` 生成新的 KimiZ 二进制。

这是 Hardness Engineer 的终极形态。本任务需要：
1. 实现一个安全沙箱内的构建触发器（调用 `zig build`）
2. 测试通过后，实现优雅重启或热替换
3. 在 CI/CD 流程中集成自动 skill 生成和验证
4. 设计人类审批节点（Agent 生成补丁 → 人类 Review → 自动合并）
5. 记录完整的进化历史（what changed, why, test results）

参考文档: docs/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md

**验收标准**:
- [ ] 核心功能实现
- [ ] 集成到主循环/CLI/构建系统
- [ ] 基础测试覆盖
- [ ] 文档更新

**依赖**: 

**笔记**:
- 来自战略文档: docs/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md
- 这是 KimiZ 的核心差异化战略
