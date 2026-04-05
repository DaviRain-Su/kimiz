### T-103: establish-comptime-skill-dsl-prototype
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 20h

**描述**:
建立 comptime Skill DSL 原型，让 skill 定义在编译时就被类型系统验证。

这是 Phase 3 的核心基础。本任务需要：
1. 设计 `defineSkill(comptime config: anytype)` 宏/函数
2. 在 comptime 验证：input 必须是 struct、handler 签名匹配、output 含必需字段
3. 利用 ZML 的 `MapType`/`mapAlloc` 思想做类型变换
4. 把现有 2-3 个 builtin skill 迁移为 DSL 形式做验证
5. 确保 DSL 生成的高质量编译错误信息（方便 LLM 自我修正）

参考文档: docs/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md, docs/ZML-PATTERNS-ANALYSIS.md

**验收标准**:
- [ ] 核心功能实现
- [ ] 集成到主循环/CLI/构建系统
- [ ] 基础测试覆盖
- [ ] 文档更新

**依赖**: 

**笔记**:
- 来自战略文档: docs/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md
- 这是 KimiZ 的核心差异化战略
