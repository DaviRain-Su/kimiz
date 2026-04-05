### T-102: implement-compilation-feedback-loop
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 16h

**描述**:
实现编译错误反馈循环，把 `zig build` 的错误输出自动回传给 LLM 修复。

这是自动生成流水线能否闭环的关键。本任务需要：
1. 封装 `zig build` 调用，捕获 stdout/stderr
2. 解析 Zig 编译错误信息（错误位置、错误类型、建议修复）
3. 将解析后的错误信息格式化为 LLM prompt
4. 调用 LLM 生成修复后的代码
5. 实现重试机制（失败 → 反馈 → 修复 → 重编译，最多 N 次）
6. 记录每次迭代的成本和成功率

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
