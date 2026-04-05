### T-106: port-zml-flags-to-kimiz
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 8h

**描述**:
移植 ZML 的 `stdx/flags.zig` 到 KimiZ，建立声明式 CLI 参数解析能力。

这是支撑自我进化的基础设施：LLM 生成的代码需要简洁、可维护的 CLI 接口。本任务需要：
1. 把 ZML/TigerBeetle 的 `flags.zig` 适配到 KimiZ 的 Zig 版本
2. 用 struct/union 声明式定义当前所有 CLI 参数
3. 替换手动字符串解析逻辑
4. 为新参数（如 `--auto-generate-skill`）预留扩展点

参考文档: docs/ZML-PATTERNS-ANALYSIS.md

**验收标准**:
- [ ] 核心功能实现
- [ ] 集成到主循环/CLI/构建系统
- [ ] 基础测试覆盖
- [ ] 文档更新

**依赖**: 

**笔记**:
- 来自战略文档: docs/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md
- 这是 KimiZ 的核心差异化战略
