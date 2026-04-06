# T-129-02: PluginLoader — 文件加载与 ABI 验证

**任务类型**: Implementation  
**优先级**: P0  
**预计耗时**: 3h  
**前置任务**: T-129-01

---

## 1. 背景与目标

在 T-129-01 定义了 `WasmSkill` 结构后，需要一个能从文件系统加载 `.wasm` 文件、实例化 `zwasm` module、验证 ABI 并提取元数据的生产级 `PluginLoader`。

## 2. Research

- [x] `docs/specs/T-129-design-and-implement-wasm-skill-plugin-system.md` — PluginLoader 设计规范
- [x] `src/extension/loader.zig` — 已有 `ExtensionInstance.init()` 流程，参考其 `zwasm.WasmModule.load()` 和 host context 链接方式
- [x] `src/extension/host.zig` — 已有 host function table 创建逻辑

## 3. Spec

**Spec 文件**: `docs/specs/T-129-design-and-implement-wasm-skill-plugin-system.md`

### 3.1 关键设计决策

- **复用 `zwasm.WasmModule.load()`**：和 `extension/loader.zig` 保持一致，先 load bytes 再实例化。
- **ABI 验证分两层**：
  1. 导出名称检查（`kimiz_skill_version`, `kimiz_skill_name` 等必须存在）
  2. 类型/签名检查（`kimiz_skill_execute` 必须是 function export）
- **元数据通过 WASM memory 读取**：name 和 desc 的实际内容由 WASM 模块内部的全局数据提供，宿主读取指针和长度后从 linear memory 提取字符串。
- **Host imports 先挂空 vtable**：本子任务仅验证加载流程，真实 host import 实现放在 T-129-03。

### 3.2 影响文件

| 文件 | 预期改动 |
|------|----------|
| `src/skills/plugin_loader.zig` | 新增：PluginLoader 结构、loadFromFile()、ABI 验证、元数据提取 |
| `src/skills/wasm_skill.zig` | 修改：为 PluginLoader 暴露必要的构造接口 |
| `tests/plugin_tests.zig` | 新增：加载有效 WASM、加载无效 WASM、ABI 验证失败的测试 |
| `tests/fixtures/` | 新增：测试用最小 WASM skill（echo 输入） |

## 4. 验收标准

- [ ] `PluginLoader.loadFromFile(path)` 能读取 `.wasm` 文件并返回 `WasmSkill`
- [ ] 成功加载后对 `wasm_bytes` 的内存能正确释放（无泄漏）
- [ ] 缺少 `kimiz_skill_execute` 导出时返回明确的 ABI 错误
- [ ] `kimiz_skill_version != 1` 时返回版本不匹配错误
- [ ] 能正确提取 name 和 description 字符串
- [ ] `PluginLoader` 实例持有 `allocator` 和可选的 `WasiConfig`
- [ ] 至少 3 个测试（加载成功 / 缺少 export / 版本错误）
- [ ] `zig build test` 通过

## 5. Log

- `2026-04-06` — 创建子任务文档，状态为 `todo`

## 6. Lessons Learned

（任务完成后填写）
