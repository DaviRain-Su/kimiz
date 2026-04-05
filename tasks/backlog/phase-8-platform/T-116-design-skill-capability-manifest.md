### T-116: design-skill-capability-manifest
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 12h

**描述**:
设计 Skill Capability Manifest，为每个 skill 声明权限清单，作为安全护栏的第一层。

这是 4 项技术中唯一 mandatory 的。需要：
1. 定义 Capability Manifest Schema：read_paths, write_paths, network_domains, max_memory_mb, forbidden_syscalls 等
2. 在 Skill / AutoRegistry 中强制要求每个 skill 附带 capabilities
3. AutoRegistry 加载时验证：请求的权限是否在系统白名单内
4. 编译通过但 capability 越界的 skill，拒绝注册并给出清晰错误
5. 为内置 skill 补写 capability manifest 做示范

参考文档: docs/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md, docs/NULLCLAW-ANALYSIS.md

**验收标准**:
- [ ] 核心设计/原型实现
- [ ] 集成测试或验证通过
- [ ] 文档更新
- [ ] 与现有任务（T-100 ~ T-111）的兼容性确认

**依赖**: 

**笔记**:
- 来自战略文档: docs/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md
- 这是构建 Hardness Engineer 多层防御系统的核心组成部分
