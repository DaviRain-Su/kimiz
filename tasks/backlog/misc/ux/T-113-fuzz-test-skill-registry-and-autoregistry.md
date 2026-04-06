### T-113: fuzz-test-skill-registry-and-autoregistry
**状态**: done
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 16h

**描述**:
为 SkillRegistry 和 AutoRegistry 引入高强度 Fuzz / Property-based 测试，捕获边界条件和并发缺陷。

**实现内容**:
创建 `src/skills/fuzz_tests.zig` — 8 组高强度 fuzz 测试:
1. `fuzz: SkillRegistry random operations (100k iterations)` — 随机注册/注销/查找/搜索，带属性验证
2. `fuzz: same ID rapid register/unregister (10k iterations)` — 极速注册/注销相同 ID
3. `fuzz: register same ID twice does not corrupt state` — 双重注册一致性
4. `fuzz: listByCategory stays consistent (50k iterations)` — 分类计数一致性
5. `fuzz: listAll returns correct count (10k iterations)` — listAll 计数验证
6. `fuzz: search with overlapping patterns` — 搜索模式重叠验证
7. `fuzz: SkillEngine executes skills safely (50k iterations)` — 安全执行验证
8. `fuzz: registerBuiltinSkills idempotent + search after builtin registration` — 幂等性验证

使用 TigerBeetle 风格的随机序列生成器，所有测试都通过 property verification（注册后必可查、注销后必消失、分类计数一致等）。

参考文档: docs/TIGERBEETLE-PATTERNS-ANALYSIS.md

**验收标准**:
- [x] 核心设计/原型实现 — `src/skills/fuzz_tests.zig` with 8 fuzz test groups
- [x] 集成测试通过 — all fuzz tests pass with `make test`
- [x] 与现有任务兼容性确认 — integrated with root.zig tests

**Log**:
- 2026-04-06: 创建 `src/skills/fuzz_tests.zig` — 8 组 fuzz 测试
- 2026-04-06: TigerBeetle 风格随机序列生成器 (deterministic seed)
- 2026-04-06: Property-based 验证: register→get→search→unregister→get==null
- 2026-04-06: 100k 次随机操作测试无内存泄漏
- 2026-04-06: 集成到 `src/skills/root.zig` 编译链
- 2026-04-06: `make build` 和 `make test` 全部通过
- 2026-04-06: 标记为 done
