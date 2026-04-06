# T-129-01: WASM Skill ABI 设计与最小骨架

**任务类型**: Implementation  
**优先级**: P0  
**预计耗时**: 2h  
**前置任务**: T-128

---

## 1. 背景与目标

T-129 要求实现 WASM-based Skill Plugin 系统。子任务 01 是整个 T-129 的基础层，目标是定义宿主（KimiZ）与 WASM 插件之间的 ABI 契约，并搭建最小可运行的 `WasmSkill` 结构体。

## 2. Research

做这个任务前，必须阅读和参考的文档。

- [x] `docs/specs/T-129-design-and-implement-wasm-skill-plugin-system.md` — T-129 的整体设计、ABI 规范、通信协议
- [x] `src/extension/wasm.zig` — 已有 `WasmModule` 封装，判断如何复用
- [x] `src/extension/loader.zig` — 已有 `ExtensionInstance`，判断是否需要复用其 host context 链接逻辑

## 3. Spec

**Spec 文件**: `docs/specs/T-129-design-and-implement-wasm-skill-plugin-system.md`

### 3.1 关键设计决策

- **复用 `src/extension/wasm.zig` 的 `WasmModule`**：T-128 阶段已有的 `extension.wasm.WasmModule` 已经封装了 `zwasm.WasmModule`，直接复用可减少重复代码。
- **JSON 作为通信协议**：所有 Skill 输入输出统一使用 JSON，与现有 `defineSkill` DSL 的 JSON wrapper 保持一致。
- **execute 签名**：`(i32, i32, i32, i32) -> i32`，返回值 >=0 为输出长度，<0 为错误码。
- **内存读写**：宿主通过 `zwasm` 的 memory API 直接读写 WASM linear memory，而不是通过额外 import。

### 3.2 影响文件

| 文件 | 预期改动 |
|------|----------|
| `src/skills/wasm_skill.zig` | 新增：WasmSkill 结构、execute 方法、ABI 元数据读取接口 |
| `src/skills/root.zig` | 修改：导出 wasm_skill 模块 |
| `tests/plugin_tests.zig` | 新增：WasmSkill 的最小单元测试 |

## 4. 验收标准

- [ ] `WasmSkill` 结构能包装 `extension.wasm.WasmModule`
- [ ] 能从 WASM 导出中读取 `kimiz_skill_version`（=1）
- [ ] 能从 WASM 导出中读取 `kimiz_skill_name` / `kimiz_skill_desc`（通过 linear memory 指针）
- [ ] `execute()` 能正确传递 JSON 输入、调用 export `kimiz_skill_execute`、读取 JSON 输出
- [ ] 定义 `WasmSkillError` 错误枚举（覆盖版本不匹配、缺少 export、内存不足、执行返回负错误码等）
- [ ] 至少 1 个单元测试能通过硬编码最小 WASM 或 fixture 验证 execute 流程
- [ ] `zig build test` 通过

## 5. Log

- `2026-04-06` — 创建子任务文档，状态为 `todo`

## 6. Lessons Learned

（任务完成后填写）
