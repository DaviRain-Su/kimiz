# T-129-05: 与 SkillRegistry / TaskEngine 集成

**任务类型**: Implementation  
**优先级**: P0  
**预计耗时**: 2h  
**前置任务**: T-129-04

---

## 1. 背景与目标

PluginRegistry 已经能独立管理 WASM skills。本子任务的目标是让这些 WASM skills 和内置 Zig skills 一样，能被 `SkillRegistry` 识别，并被 `TaskEngine` 无差别调度。

## 2. Research

- [x] `docs/specs/T-129-design-and-implement-wasm-skill-plugin-system.md` — 集成方式章节（wasmSkillToSkill）
- [x] `src/skills/root.zig` — 现有 `SkillRegistry` 的结构和 `register()` 接口
- [x] `src/engine/task.zig` — TaskEngine 如何调用 `Skill.execute()`

## 3. Spec

**Spec 文件**: `docs/specs/T-129-design-and-implement-wasm-skill-plugin-system.md`

### 3.1 关键设计决策

- **统一接口**：WASM skill 通过 `wasmSkillToSkill()` 包装成现有的 `Skill` 类型。TaskEngine 不需要知道底层是 WASM 还是 Zig。
- **自动注册**：`PluginRegistry.scanAndReload()` 在加载每个 WASM skill 后，自动调用 `SkillRegistry.register(wasmSkillToSkill(skill))`。
- **自动注销**：WASM skill 被卸载时，需要从 `SkillRegistry` 中移除。这要求 `SkillRegistry` 支持 `unregister(name)`，或者 `PluginRegistry` 在重载前主动注销旧 skill。
- **Allocator 传递**：WASM skill 的 `execute()` 内部已经持有 module 的 allocator，包装层的 `execute_fn` 签名可能需要适配。

### 3.2 影响文件

| 文件 | 预期改动 |
|------|----------|
| `src/skills/wasm_skill.zig` | 修改/新增：`wasmSkillToSkill()` 转换函数 |
| `src/skills/plugin_registry.zig` | 修改：加载后自动注册到 SkillRegistry；卸载前自动注销 |
| `src/skills/root.zig` | 修改：SkillRegistry 可能需要 `unregister(name)` |
| `src/engine/task.zig` | 修改/确认：TaskEngine 对 WASM skill 无差别调度（通常无需改动，验证即可） |
| `tests/plugin_tests.zig` | 新增：端到端测试——TaskEngine 执行 WASM echo skill |

## 4. 验收标准

- [ ] `wasmSkillToSkill(wasm_skill)` 返回有效的 `Skill` 实例
- [ ] `PluginRegistry` 加载 WASM 后，新 skill 出现在 `SkillRegistry` 中
- [ ] `PluginRegistry` 卸载 WASM 前，先从 `SkillRegistry` 中移除
- [ ] `TaskEngine` 能成功调度 WASM skill 并获取 JSON 输出
- [ ] 端到端测试：放置 echo.wasm → 扫描 → TaskEngine 执行 → 输出与输入一致
- [ ] `zig build test` 通过

## 5. Log

- `2026-04-06` — 创建子任务文档，状态为 `todo`

## 6. Lessons Learned

（任务完成后填写）
