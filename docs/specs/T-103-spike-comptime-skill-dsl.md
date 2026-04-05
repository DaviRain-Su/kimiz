# T-103-SPIKE: comptime Skill DSL 原型验证

**任务类型**: Spike / Research  
**优先级**: P0  
**预计耗时**: 4h  
**前置任务**: T-009-E2E（E2E 测试通过，确保现有 skill 系统稳定）

---

## 参考文档

- [ZIG-LLM-SELF-EVOLUTION-STRATEGY](../research/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md) - Phase 3 编译时自我进化战略
- [TigerBeetle Patterns](../research/TIGERBEETLE-PATTERNS-ANALYSIS.md) - comptime 元编程与类型安全
- [ZML Patterns Analysis](../research/zml-patterns-analysis.md) - `MapType`/`mapAlloc` comptime 类型变换（如有）
- [OpenCLI Analysis](../research/OPENCLI-ANALYSIS.md) - 外部验证：自我进化的市场需求和 Token 经济性

---

## 背景

KimiZ 的自我进化终极目标是让 LLM 生成的代码在**编译阶段**就被验证。`defineSkill` comptime DSL 是这一目标的核心基础设施。如果 DSL 设计成功，后续 `T-100`（自动生成流水线）和 `T-101`（AutoRegistry）都将建立在它之上；如果失败，整个 Phase 3 战略需要重新设计。

本任务是一个 **Spike**（探针任务），目标是在最短时间内验证 `defineSkill` 的可行性，而不追求生产级完整度。

---

## 目标

1. 设计并实现 `defineSkill(comptime config: anytype)` 的最小可行版本
2. 在 `comptime` 验证以下约束：
   - `config.input` 必须是 `struct`
   - `config.handler` 的签名严格匹配 `fn(Input) Output`
   - `config.output` 必须包含 `success: bool` 字段
3. 将现有 1-2 个 builtin skill（如 `debug` 或 `refactor`）迁移为 DSL 形式，验证可用性
4. 评估编译错误信息的可读性（这对 LLM 自我修正至关重要）
5. 输出 go/no-go 决策和后续设计调整建议

---

## 关键设计决策

### 1. DSL 形态

采用 Zig 原生的 `comptime` struct literal：

```zig
pub const MySkill = defineSkill(.{
    .name = "debug",
    .description = "Analyze code and suggest fixes",
    .input = struct {
        code: []const u8,
        language: ?[]const u8 = null,
    },
    .output = struct {
        success: bool,
        suggestions: []const []const u8,
    },
    .handler = myHandler,
});
```

### 2. 验证规则（comptime 强制）

`defineSkill` 内部使用 `@TypeInfo` 检查：
- `input` 和 `output` 都必须是 `.Struct`
- `handler` 必须是 `.Fn`
- `handler` 的参数数量和类型严格匹配 `input`
- `handler` 的返回类型严格匹配 `output`
- `output` 的字段中必须包含 `success: bool`

任何违规触发 `@compileError("readable message")`

### 3. 输出产物

`defineSkill` 返回一个 comptime-known 的 `type`，该 type 自动实现：
- `.id` 字段
- `.metadata` 字段（名称、描述、参数 schema）
- `.execute(context, input_json)` 方法（JSON → Zig struct → handler → JSON）

---

## 影响文件

| 文件 | 预期改动 |
|------|----------|
| `src/skills/dsl.zig` | 新增：defineSkill 核心实现 |
| `src/skills/debug.zig` 或 `src/skills/refactor.zig` | 修改：作为 DSL 迁移的试点 |
| `src/skills/root.zig` | 修改：SkillEngine 支持 DSL 生成的 skill type |
| `tests/skill_dsl_test.zig` | 新增：comptime 验证测试 |

---

## 验收标准

- [x] `defineSkill` 能在 comptime 成功验证合法的 skill 定义
- [x] `defineSkill` 对非法定义（如 handler 签名不匹配）能给出清晰的 `@compileError`
- [x] 至少有 1 个现有 builtin skill 被成功迁移为 DSL 形式
- [x] 迁移后的 skill 能通过 `zig build test`
- [x] 输出 **Spike Report**：记录设计优缺点、编译错误示例、LLM 可读性评估、对 T-100/T-101 的影响
- [x] 基于报告，团队决定 go（继续推进 T-100/T-101）或 no-go（调整架构方向）

## Spike Report

- **Report**: [`docs/reports/T-103-spike-comptime-skill-dsl-report.md`](../../reports/T-103-spike-comptime-skill-dsl-report.md)
- **Decision**: **GO** — proceed with T-100 and T-101.
- **Key artifacts**:
  - `src/skills/dsl.zig` — `defineSkill` core implementation
  - `src/skills/debug_dsl.zig` — migrated `debug` skill
  - `src/skills/doc_gen_dsl.zig` — migrated `doc-gen` skill
  - `tests/integration_tests.zig` — E2E tests for DSL validation, execution, and registry integration
