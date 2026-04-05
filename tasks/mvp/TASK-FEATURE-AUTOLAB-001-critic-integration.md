### TASK-FEATURE-AUTOLAB-001: Integrate AutoLab as external Critic for KimiZ Agent

**状态**: todo  
**优先级**: P1  
**创建**: 2026-04-05  
**预计耗时**: 32-40 小时  
**阻塞**: 无  

**描述**:
将 AutoLab 基准测试集成到 KimiZ 中作为外部评估器（Critic），构建 Generator-Critic 对抗反馈循环。Agent 生成代码/配置 → AutoLab 运行评估 → 返回结构化反馈 → Agent 迭代优化。

**7-Phase 文档**:
- Phase 3 Technical Spec: `docs/autolab-integration/03-technical-spec.md`
- Phase 4 Task Breakdown: `docs/autolab-integration/04-task-breakdown.md`
- Phase 5 Test Spec: `docs/autolab-integration/05-test-spec.md`

**Phase 拆分**:
| Phase | 内容 | 工时 |
|-------|------|------|
| Phase 1 | MVP Integration: clone AutoLab, 写 Python 包装脚本, 端到端验证 | 6h |
| Phase 2 | Zig Skill 封装: parser, Docker runner, feedback assembler, skill 注册 | 10h |
| Phase 3 | 闭环优化: orchestrator 设计, 接入 Agent 迭代循环, 端到端闭环测试 | 10h |
| Phase 4 | 扩展与硬化: 多语言任务支持, 回归测试套件, 文档完善 | 8h |

**关键子任务**:
1. Task 1.1: Clone AutoLab 仓库 (15 min)
2. Task 1.2: 安装 Harbor & Docker 环境检查 (30 min)
3. Task 1.3: 编写 `scripts/autolab_eval.py` (3-4h)
4. Task 1.4: 端到端 MVP 测试 (1-2h)
5. Task 2.1: Zig 数据模型与 TOML/JSON parser (2-3h)
6. Task 2.2: Docker runner 实现 (3-4h)
7. Task 2.3: Feedback assembler 实现 (2-3h)
8. Task 2.4: 组装 `autolab-eval` skill (2h)
9. Task 3.1: Orchestrator 反馈循环设计 (2h)
10. Task 3.2: 实现 `autolab-orchestrator` (4-6h)
11. Task 3.3: 端到端闭环测试 (3-4h)
12. Task 4.1: 支持 3+ 个不同语言任务 (3-4h)
13. Task 4.2: 回归测试套件 (3-4h)
14. Task 4.3: 文档完善 (2h)

**验收标准**:
- [ ] 能解析至少 3 个 AutoLab 任务的 `task.toml`
- [ ] 能对 `discover_sorting` 完成端到端评估
- [ ] Docker 资源限制正确传递
- [ ] 能区分 compile_error / runtime_error / correctness_fail / success / timeout
- [ ] `reward.json` 数值正确映射到 feedback
- [ ] Skill 输出能被 Agent 循环消费
- [ ] 15+ 单元测试通过
- [ ] 3 个 E2E 测试通过（需 Docker）

**依赖**:
- Docker Engine
- AutoLab 仓库 (github.com/autolabhq/autolab)
- KimiZ Skill Framework (`src/skills/root.zig`)

**阻塞**:
- 无

**参考**:
- `docs/AUTOLAB-INTEGRATION-ANALYSIS.md`
- `docs/FACTORY-PLUGINS-ANALYSIS.md`
