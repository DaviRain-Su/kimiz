### T-101: design-autoregistry-dynamic-loading
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 10h

**描述**:
设计 AutoRegistry 动态加载机制，让运行时无需修改 builtin.zig 即可注册 auto skill。

当前 KimiZ 新增 skill 必须修改 `src/skills/builtin.zig` 并重新编译整个项目。本任务需要：
1. 设计 `AutoRegistry` 结构，能在启动时扫描 `src/skills/auto/` 目录
2. 或者设计运行时动态发现机制（如 comptime 枚举生成、或者 build.zig 生成注册表）
3. 确保 auto skill 和 builtin skill 在 `SkillEngine` 中统一调用
4. 保持类型安全：auto skill 仍然必须通过 Zig 编译器检查

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
