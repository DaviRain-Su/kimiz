# T-129-03: Host Imports 实现（log, alloc, free）

**任务类型**: Implementation  
**优先级**: P0  
**预计耗时**: 3h  
**前置任务**: T-129-02

---

## 1. 背景与目标

WASM 插件默认没有任何权限。为了让 WASM skill 能运行，宿主必须提供一组受控的 Host Imports。本子任务实现最基础的三件套：`log`（打印日志）、`alloc`/`free`（WASM 内存分配）。这三个 import 是后续执行任何 skill 的前提。

## 2. Research

- [x] `docs/specs/T-129-design-and-implement-wasm-skill-plugin-system.md` — HostImports 设计规范
- [x] `src/extension/host.zig` — 已有 `HostFunctionTable` 和 `createStandardHostFunctions()`，判断复用程度
- [x] `src/utils/log.zig` — KimiZ 的日志系统接口
- [x] `zwasm` 文档/源码 — 如何向 `zwasm.WasmModule` 注册 host import 函数

## 3. Spec

**Spec 文件**: `docs/specs/T-129-design-and-implement-wasm-skill-plugin-system.md`

### 3.1 关键设计决策

- **复用 `extension/host.zig` 的基础设施**：如果 `zwasm` 的 host function API 与 `extension/host.zig` 兼容，优先复用。如果不兼容，新建 `src/skills/host_imports.zig`。
- **alloc/free 对接 WASM linear memory**：`zwasm` 的 module 实例化时会自动创建 memory。host `alloc` 不是请求宿主分配 OS 内存，而是请求在 WASM linear memory 中分配一块区域（由 host 侧维护一个简单 bump allocator 或记录空闲地址）。
- **log 级别映射**：WASM 传入的 `level: i32` 映射到 KimiZ 的 `std.log.err/warn/info/debug`。
- **错误处理**：host import 内部 panic 或 trap 会导致整个 module 执行失败，因此所有 host import 函数必须做边界检查。

### 3.2 影响文件

| 文件 | 预期改动 |
|------|----------|
| `src/skills/host_imports.zig` | 新增：HostImportVtable、log_alloc_free 的实现 |
| `src/skills/plugin_loader.zig` | 修改：加载时链接真实的 host imports（替代空 vtable） |
| `src/skills/wasm_skill.zig` | 修改：execute() 内部不再由宿主分配输入缓冲区，而是调用 WASM 的 `alloc` import |
| `tests/plugin_tests.zig` | 新增：host log / alloc / free 的集成测试 |

## 4. 验收标准

- [x] `PluginLoader` 加载 WASM 时成功链接 `kimiz_log`, `kimiz_alloc`, `kimiz_free`
- [x] WASM skill 调用 `kimiz_log` 后，日志正确输出到 KimiZ 日志系统
- [x] `kimiz_alloc` 返回的地址在 WASM linear memory 范围内
- [x] `kimiz_free` 能正确释放（bump rollback）
- [x] WASM skill 能够通过 `kimiz_alloc` 分配输入/输出缓冲区
- [x] `WasmSkill.execute()` 实现完整 JSON 输入/输出传输
- [x] 3 个测试（log 输出验证 / alloc-free 边界验证 / loadFromFile）
- [x] `zig build test` 通过

## 5. Log

- `2026-04-06` — 创建子任务文档，状态为 `todo`
- `2026-04-06` — 研究发现 `zwasm` 的 `types.zig` 已经导出了 `Vm`、`ImportEntry`、`HostFnEntry`、`loadWithImports`
- `2026-04-06` — 实现 `src/skills/plugin_loader.zig` 中的 host imports：
  - `hostLog`：通过 `vm.popOperand()` 读取栈参数，用 `module.memoryRead()` 读取字符串
  - `hostAlloc`：bump allocator 从 1024 开始，用 `memoryWrite(offset, "")` 探针检测越界
  - `hostFree`：bump rollback（仅释放顶部分配时回退）
  - `PluginLoader.loadFromFile` 接入 `loadWithImports()`
- `2026-04-06` — 完善 `WasmSkill.execute()`：宿主直接写 input JSON 到 linear memory offset 8192，调用 `kimiz_skill_execute`，读取 output JSON
- `2026-04-06` — WAT fixture 新增 `test_log` / `test_alloc` export，用于独立测试 host imports
- `2026-04-06` — 添加 `_ = skills; _ = extension;` 到 `src/root.zig` test 块，拉入大量 pre-existing tests，发现并修复 legacy bugs（`code_review_dsl` 签名、`dsl` 类型映射、`dsl` 测试泄漏）
- `2026-04-06` — `zig build test` 通过（92/92 tests passed）

## 6. Lessons Learned

**分类**: API 踩坑 / 架构决策 / 测试策略

**内容**:
- `zwasm` 的 `Vm` 类型虽然导出，但 `Vm.getMemory()` 返回的 `*WasmMemory` 类型未完全公开，无法直接操作 memory bytes。因此 host import 中读取/写入 memory 的最佳方式是让 `HostContext` 持有 `*WasmModule`，复用现有的 `memoryRead` / `memoryWrite` 封装
- `memoryWrite(probe_offset, "")` 是一个非常实用的边界探测技巧（利用 `end == offset` 的 bounds check）
- `src/root.zig` 的 `test {}` 块负责控制哪些模块的测试被编译运行。遗漏 `_ = skills;` 意味着大量测试长期未被 CI 覆盖，积累了多个 pre-existing bugs
- Zig 0.16 对 `*const [N]T` → `[]T` 的隐式转换更严格，需要在 API 签名中显式使用 `[]const T` 来兼容字面量传入
- `defineSkill` 的 `execute_fn` 设计意图是传入 `ArenaAllocator`。如果传入 GPA，内部多个 `arena.dupe` 会导致测试泄漏
- Host function 的栈参数弹出顺序与 WASM 的压栈顺序相反（最后压入的参数最先弹出）。`kimiz_log(level, ptr, len)` 弹出顺序是 `len` → `ptr` → `level`

**后续动作**:
- [ ] 继续执行 T-129-04 的 PluginRegistry 实现
