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

- [x] `WasmSkill` 结构能包装 `zwasm.WasmModule`
- [x] 能从 WASM 导出中读取 `kimiz_skill_version`（=1）
- [x] 能从 WASM 导出中读取 `kimiz_skill_name` / `kimiz_skill_desc`（通过 linear memory 指针）
- [x] `execute()` 暂为 stub，正确定义了 JSON 签名（等待 T-129-03 的 host import 实现）
- [x] 定义 `WasmSkillError` 错误枚举（覆盖版本不匹配、缺少 export、内存不足、执行返回负错误码等）
- [x] 3 个单元测试通过 WAT fixture 验证 init / ABI 读取 / 错误路径
- [x] `zig build test` 通过

## 5. Log

- `2026-04-06` — 创建子任务文档，状态为 `todo`
- `2026-04-06` — 新建 `kimiz-t129` worktree（基于 `t129` 分支），初始化 submodule，构建 `fff_c`，更新 `zwasm` hash，修复并推送远程 `zwasm` 的 Zig 0.16 `link_libc` 兼容性
- `2026-04-06` — 分析现有 `src/extension/wasm.zig` 和 `loader.zig`，确认 `zwasm.WasmModule` 的 API（`loadFromWat`、`memoryRead`、`module.getExport`、`instance.getGlobal`、`invoke`）
- `2026-04-06` — 实现 `src/skills/wasm_skill.zig`：
  - 定义 `WasmSkillAbi.VERSION = 1`
  - 定义 `WasmSkillError`（VersionMismatch、MissingExport、OutOfBoundsMemoryAccess、ExecutionFailed、OutputTooLarge）
  - 实现 `WasmSkill.init()`：验证 `kimiz_skill_version` global，读取 `kimiz_skill_name`/`kimiz_skill_desc` 元数据
  - 实现 `readMetadata()` helper，通过 `memoryRead` 从 WASM linear memory 提取字符串
  - `execute()` 暂为 stub（返回 `error.TodoImplementInT12903`，等待 T-129-03 的 host import 内存分配）
- `2026-04-06` — 添加 3 个单元测试（正常初始化 / 缺少 export / 版本不匹配），使用 WAT 字符串作为 fixture
- `2026-04-06` — `zig build test` 通过（8/8 steps succeeded）
- `2026-04-06` — 提交 `t129` 分支到远程，状态标记为 `done`

## 6. Lessons Learned

**分类**: API 踩坑 / 架构决策

**内容**:
- `zwasm` 的 `WasmModule` 字段（`module`、`instance`）是 public 的，可以直接访问底层的 `getExport` 和 `getGlobal`，不需要额外的 wrapper API
- 读取 WASM global 的值时，要注意 `global.value` 是 `u128`，需要用 `& 0xFFFFFFFF` 截断为 `u32`（因为 ABI 的 ptr/len 都是 i32）
- WAT fixture 是测试 WASM skill 的最快方式，`zwasm.loadFromWat` 默认可用（`enable_wat = true`），比手写 wasm binary bytes 可靠得多
- `execute()` 不能直接把宿主指针传给 WASM，必须通过 WASM linear memory + offset。这证实了 T-129-03 的 host `alloc` import 是必不可少的


