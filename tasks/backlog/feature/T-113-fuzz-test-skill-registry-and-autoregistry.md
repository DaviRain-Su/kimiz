### T-113: fuzz-test-skill-registry-and-autoregistry
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 16h

**描述**:
为 SkillRegistry 和 AutoRegistry 引入高强度 Fuzz / Property-based 测试，捕获边界条件和并发缺陷。

形式化验证的实用级切入点。需要：
1. 建立基于 TigerBeetle 风格的 Fuzz 测试框架（随机序列生成）
2. 对 SkillRegistry 进行 Fuzz：随机注册/注销/查找/搜索 100万+ 次
3. 对 AutoRegistry 进行 Fuzz：随机加载/卸载/版本切换
4. 检测内存泄漏、use-after-free、竞争条件、HashMap 不一致
5. 把 Fuzz 测试集成到 CI（每次 PR 自动跑）

参考文档: docs/TIGERBEETLE-PATTERNS-ANALYSIS.md

**验收标准**:
- [ ] 核心设计/原型实现
- [ ] 集成测试或验证通过
- [ ] 文档更新
- [ ] 与现有任务（T-100 ~ T-111）的兼容性确认

**依赖**: 

**笔记**:
- 来自战略文档: docs/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md
- 这是构建 Hardness Engineer 多层防御系统的核心组成部分
