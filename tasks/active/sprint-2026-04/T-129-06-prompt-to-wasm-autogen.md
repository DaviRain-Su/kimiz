# T-129-06: Prompt-to-WASM 自动生成 + CLI

**任务类型**: Implementation  
**优先级**: P1  
**预计耗时**: 3h  
**前置任务**: T-129-05

---

## 1. 背景与目标

T-129 的产品化价值在于降低终端用户创建自定义 Skill 的门槛。本子任务实现"一句话生成 WASM skill"的完整流水线：自然语言描述 → Zig 代码生成 → 编译为 `.wasm` → 自动注册。

## 2. Research

- [x] `docs/specs/T-129-design-and-implement-wasm-skill-plugin-system.md` — Prompt-to-WASM 章节
- [x] `src/skills/generator.zig` — 现有 auto skill 生成器的模板和结构
- [x] `T-100 Spec` — auto skill 自动生成流水线的已有基础设施

## 3. Spec

**Spec 文件**: `docs/specs/T-129-design-and-implement-wasm-skill-plugin-system.md`

### 3.1 关键设计决策

- **复用 T-100 的 generator 框架**：如果有现成的 `generator.zig` 和 prompt 模板，优先扩展以支持 `wasm32-freestanding` 目标。
- **生成最小可行的 Zig WASM skill**：模板包含 `kimiz_alloc` / `kimiz_free` / `kimiz_log` 的 extern 声明，以及 `kimiz_skill_version` / `kimiz_skill_name` / `kimiz_skill_desc` / `execute` 的导出。
- **编译命令**：调用系统 `zig build-lib <file> -target wasm32-freestanding -dynamic -O ReleaseSmall -femit-bin=<output>`。
- **错误反馈**：如果 zig 编译失败，捕获 stderr，提取前 20 行返回给用户。
- **自动注册**：编译成功后，将 `.wasm` 复制到 `~/.kimiz/skills/wasm/` 并触发 `PluginRegistry.scanAndReload()`。

### 3.2 影响文件

| 文件 | 预期改动 |
|------|----------|
| `src/skills/generator.zig` | 扩展：新增 `generateWasmSkill()`，输出 wasm-target Zig 代码 |
| `src/skills/wasm_compiler.zig` | 新增：封装 `zig build-lib` 子进程调用 |
| `src/cli/root.zig` | 新增：`kimiz skill create <desc> --wasm` 子命令 |
| `src/skills/plugin_registry.zig` | 修改：编译成功后触发扫描重载 |
| `examples/wasm-skill/` | 新增：手写 WASM skill 的示例目录和模板 |

## 4. 验收标准

- [ ] `generator.zig` 能根据描述生成合法的 `wasm32-freestanding` Zig 代码
- [ ] `wasm_compiler.zig` 能调用 `zig build-lib` 编译出 `.wasm`
- [ ] 编译失败时返回清晰的错误信息（包含 zig stderr 摘要）
- [ ] 编译成功后 `.wasm` 被复制到 `~/.kimiz/skills/wasm/` 并自动加载
- [ ] CLI `kimiz skill create "return the input reversed" --wasm` 端到端可用
- [ ] 生成的 WASM skill 能通过 `PluginLoader` 的 ABI 验证
- [ ] `zig build test` 通过

## 5. Log

- `2026-04-06` — 创建子任务文档，状态为 `todo`

## 6. Lessons Learned

（任务完成后填写）
