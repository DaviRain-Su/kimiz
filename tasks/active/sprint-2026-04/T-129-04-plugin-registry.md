# T-129-04: PluginRegistry — 扫描、注册与热重载

**任务类型**: Implementation  
**优先级**: P0  
**预计耗时**: 3h  
**前置任务**: T-129-03

---

## 1. 背景与目标

有了 `PluginLoader` 后，需要一个能管理多个 WASM skill 生命周期的 `PluginRegistry`。它需要自动扫描用户目录、检测文件变更、热重载，让终端用户只需将 `.wasm` 文件放入目录即可生效。

## 2. Research

- [x] `docs/specs/T-129-design-and-implement-wasm-skill-plugin-system.md` — PluginRegistry 设计规范
- [x] `src/skills/root.zig` — 现有 `SkillRegistry` 的注册接口

## 3. Spec

**Spec 文件**: `docs/specs/T-129-design-and-implement-wasm-skill-plugin-system.md`

### 3.1 关键设计决策

- **扫描目录**：默认两个路径：`~/.kimiz/skills/wasm/`（用户级）和 `.kimiz/skills/wasm/`（项目级）。项目级优先级高于用户级（同名 skill 覆盖）。
- **变更检测策略**：使用文件 mtime 或 CRC32 作为轻量级 checksum，避免每次扫描都重新实例化 module。
- **热重载语义**：文件 mtime 变化 → 卸载旧 `WasmSkill`（调用 `deinit()`）→ 用 `PluginLoader` 重新加载 → 更新 registry。
- **卸载语义**：`.wasm` 文件被删除 → 从 registry 移除并释放内存。
- **内存安全**：`PluginRegistry` 持有 `WasmSkill` 的 `*WasmSkill` 指针，卸载时必须用 `allocator.destroy()` 释放。

### 3.2 影响文件

| 文件 | 预期改动 |
|------|----------|
| `src/skills/plugin_registry.zig` | 新增：PluginRegistry 结构、scanAndReload()、get()、卸载逻辑 |
| `src/skills/root.zig` | 修改：应用启动时初始化 PluginRegistry 并执行首次扫描 |
| `tests/plugin_tests.zig` | 新增：扫描新增 / 扫描变更 / 扫描删除 / 优先级覆盖 的测试 |

## 4. 验收标准

- [ ] `PluginRegistry.init(allocator)` 正确初始化，默认 watch_dirs 包含用户级和项目级路径
- [ ] `scanAndReload()` 能递归扫描指定目录下所有 `.wasm` 文件
- [ ] 新增 `.wasm` 文件后扫描，能加载并注册新 skill
- [ ] 修改 `.wasm` 文件后扫描，能热重载新版本
- [ ] 删除 `.wasm` 文件后扫描，能从 registry 移除并释放内存
- [ ] 同名 skill 在项目级和用户级同时存在时，项目级优先
- [ ] `get(skill_name)` 能返回已注册的 skill 指针
- [ ] `PluginRegistry.deinit()` 能安全释放所有持有的 skill 和内部 HashMap
- [ ] 至少 4 个测试（新增/变更/删除/优先级）
- [ ] `zig build test` 通过

## 5. Log

- `2026-04-06` — 创建子任务文档，状态为 `todo`

## 6. Lessons Learned

（任务完成后填写）
