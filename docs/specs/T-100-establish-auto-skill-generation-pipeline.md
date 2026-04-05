# T-100: 建立 auto skill 自动生成流水线

**任务类型**: Implementation  
**优先级**: P1  
**预计耗时**: 12h  
**前置任务**: T-103-SPIKE（comptime DSL 验证通过）

---

## 参考文档

- [ZIG-LLM-SELF-EVOLUTION-STRATEGY](../research/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md) - KimiZ 自我进化三阶段战略
- [TigerBeetle Patterns](../research/TIGERBEETLE-PATTERNS-ANALYSIS.md) - 零技术债务、编译时验证原则
- [Yoyo Evolve](../research/YOYO-EVOLVE-ANALYSIS.md) - 自进化循环与编译反馈

---

## 背景

这是 KimiZ 核心差异化战略（ZIG-LLM-SELF-EVOLUTION-STRATEGY）的 Phase 2 起点。当前 skill 必须手写并静态注册到 `builtin.zig`，新增一个 skill 的边际成本很高。本任务要建立一套流水线，让 LLM 能够根据自然语言描述生成有效的 Zig skill 源码，自动通过编译并注册到系统中。

---

## 目标

1. 创建 `src/skills/auto/` 目录作为自动生成 skill 的隔离区
2. 设计并实现 skill 生成模板（从 prompt/schema → Zig 源码）
3. 实现构建脚本或 CLI 工具触发 skill 生成
4. 让 LLM 能成功生成第一个有效的 `.zig` skill 文件
5. 生成的 skill 能够通过 `zig build test`

---

## 关键设计决策

### 1. 生成隔离原则
- 所有 auto-generated skill 必须放在 `src/skills/auto/` 下，与手写 skill 物理隔离
- 文件名规范：`auto_<kebab-case-name>.zig`

### 2. 模板驱动生成
- 提供标准模板，约束 LLM 的输出格式
- 模板必须基于 `T-103-SPIKE` 验证通过的 comptime DSL（或过渡用的 struct 模式）

### 3. 编译反馈闭环
- 生成后自动触发 `zig build test`
- 编译失败时，错误信息必须能被解析并回传给 LLM 进行修复
- 修复次数上限：5 次，超过则人工介入

---

## 影响文件

| 文件 | 预期改动 |
|------|----------|
| `src/skills/auto/` | 新增目录，存放所有 auto skill |
| `scripts/generate-skill.zig` 或 `src/cli/skill_generator.zig` | 生成器实现 |
| `src/skills/root.zig` | 集成 auto skill 加载逻辑 |
| `src/skills/builtin.zig` | 可能需要拆分出 `auto_registry.zig` |
| `build.zig` | 可能需增加生成步骤 |

---

## 验收标准

- [ ] `src/skills/auto/` 目录已创建并纳入构建系统
- [ ] 存在至少 1 个 skill 生成模板（JSON/YAML/Prompt）
- [ ] LLM 能根据自然语言生成第一个可编译的 auto skill（如 `auto-hello` 或 `auto-file-search`）
- [ ] `zig build test` 能自动编译并测试该 auto skill
- [ ] 编译失败时有结构化的错误反馈机制
- [ ] 文档已更新（至少更新 `docs/skills/README.md`）
