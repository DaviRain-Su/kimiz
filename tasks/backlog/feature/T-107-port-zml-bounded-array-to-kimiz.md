### T-107: port-zml-bounded-array-to-kimiz
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 10h

**描述**:
移植 ZML 的 `stdx/bounded_array.zig` 到 KimiZ，替换大量 ArrayList 使用场景。

固定上限的数组是防止 LLM 生成代码产生资源泄漏和无限膨胀的关键。本任务需要：
1. 移植 `BoundedArray` 到 KimiZ 的公共工具库
2. 识别并替换 SkillRegistry、Message 列表、Tool 参数列表等场景
3. 和 TigerBeetle 的 `stack.zig`/`queue.zig` 组合使用

参考文档: docs/ZML-PATTERNS-ANALYSIS.md, docs/TIGERBEETLE-PATTERNS-ANALYSIS.md

**验收标准**:
- [ ] 核心功能实现
- [ ] 集成到主循环/CLI/构建系统
- [ ] 基础测试覆盖
- [ ] 文档更新

**依赖**: 

**笔记**:
- 来自战略文档: docs/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md
- 这是 KimiZ 的核心差异化战略
