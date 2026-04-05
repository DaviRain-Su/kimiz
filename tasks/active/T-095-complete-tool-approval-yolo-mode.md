### T-095: complete-tool-approval-yolo-mode
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 10h

**描述**:
完善工具审批和 YOLO 模式，实现三级审批策略并支持会话持久化。

kimi-cli 有完整的审批体系：Ask / Session / Always，且会随会话恢复。KimiZ 的 `src/harness/tool_approval.zig` 有基础代码但未完整集成。本任务需要：
1. 实现三级审批：每次询问 / 本会话允许 / 始终允许
2. 将审批决策持久化到 SQLite，随会话恢复
3. 在 Agent 循环的每个 tool 调用前执行审批检查
4. 支持 `/yolo` 命令快速切换 YOLO 模式
5. 提供清晰的审批提示 UI（工具名、参数预览、风险等级）
6. 支持按工具类型配置默认审批策略（如只读工具自动通过）

**TigerBeetle 借鉴**:
- 审批状态机增加高密度断言（如 `assert(approval_result.approved or approval_result.one_time)`）
- 使用 `CountingAllocator` 在测试模式下追踪审批管理器的内存（approved_tools / denied_tools 的 HashMap）
- 对 `getToolRisk` 返回值的边界做正向-负向断言（既 assert 是预期值，又 assert 不是非法值）
- 审批回调未设置时的 fallback 策略明确使用断言保护（`assert(callback != null)` 或 safe default）

参考: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md (GAP-7), docs/TIGERBEETLE-PATTERNS-ANALYSIS.md

**验收标准**:
- [ ] 核心功能实现
- [ ] 集成到主循环/CLI
- [ ] 基础测试覆盖
- [ ] 文档更新

**依赖**: 

**笔记**:
- 来自差距分析文档: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md
