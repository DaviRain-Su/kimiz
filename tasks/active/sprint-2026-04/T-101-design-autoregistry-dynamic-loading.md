# T-101: 设计 AutoRegistry 动态加载机制

**任务类型**: Design / Implementation  
**优先级**: P1  
**预计耗时**: 10h  
**前置任务**: T-103-SPIKE

---

## 参考文档

- [ZIG-LLM-SELF-EVOLUTION-STRATEGY](../research/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md) - 自我进化战略
- [TigerBeetle Patterns](../research/TIGERBEETLE-PATTERNS-ANALYSIS.md) - 侵入式数据结构、零隐藏分配
- [Zig gRPC Analysis](../research/grpc-zig-analysis.md) - comptime 枚举生成模式参考
- [OpenCLI Analysis](../research/OPENCLI-ANALYSIS.md) - 外部自动注册机制参考、自我修复触发模式

---

## 背景

当前 KimiZ 新增 skill 必须手动修改 `src/skills/builtin.zig` 并重新编译整个项目。对于 auto skill 的自我进化流水线，这种静态注册方式是不可接受的。本任务需要设计并实现 `AutoRegistry`，让系统在启动时能够自动发现 `src/skills/auto/` 目录下的 skill，无需修改手写注册表。

---

## 目标

1. 设计 `AutoRegistry` 的数据结构和接口
2. 实现启动时自动扫描 `src/skills/auto/` 目录的 mechanism
3. 确保 auto skill 与 builtin skill 在 `SkillEngine` 中统一调用
4. 保持 Zig 的类型安全：auto skill 仍然必须通过编译器检查
5. 支持 auto skill 的版本追踪和基本元数据

---

## 关键设计决策

### 方案 A：comptime 枚举生成（推荐）

在 `build.zig` 或编译步骤中扫描 `src/skills/auto/`，生成一个 `auto_registry_generated.zig`：

```zig
pub const auto_skills = &[_]type{
    @import("auto/hello-skill.zig").HelloSkill,
    @import("auto/file-search-skill.zig").FileSearchSkill,
};
```

优点：
- 纯编译时，零运行时开销
- 保持完整的类型安全
- 不需要动态加载或 DLL

缺点：
- 新增/删除 skill 后必须重新触发构建

### 方案 B：运行时函数指针表

将 auto skill 编译为独立的 `.o` 文件或 WASM 模块，运行时通过统一 C ABI 调用。

优点：
- 真正的运行时热加载

缺点：
- 失去 Zig 的类型安全
- 实现复杂度高
- 与 KimiZ 的强类型哲学冲突

**决策：采用方案 A（comptime 枚举生成）**。KimiZ 的核心优势是编译时安全网，不能因为追求热加载而放弃这个护城河。

---

## 影响文件

| 文件 | 预期改动 |
|------|----------|
| `src/skills/auto_registry.zig` | 新增：AutoRegistry 核心实现 |
| `src/skills/root.zig` | 修改：SkillEngine 同时查询 builtin 和 auto registry |
| `build.zig` | 新增：编译前扫描 `src/skills/auto/` 并生成注册表 |
| `src/skills/builtin.zig` | 可能修改：拆分手写和自动注册表 |

---

## 验收标准

- [x] `AutoRegistry` 能在构建时自动发现 `src/skills/auto/` 下的所有 skill
- [x] 新增一个 `.zig` 文件到 `src/skills/auto/` 后，无需修改 `builtin.zig` 即可被调用
- [x] `SkillEngine` 统一处理 builtin 和 auto skill 的查询与调用
- [x] 所有代码通过 `zig build test`
- [x] `zig build` 零错误

---

## 5. Log

> 执行任务的过程中，每做一步都要在这里追加记录。这是 Agent 的自我修正历史。

- `2026-04-06` — 开始实现 T-101，状态从 `todo` 改为 `implement`
- `2026-04-06` — 选择了方案 A（构建时 comptime 生成）。尝试在 build.zig 中直接扫描目录，但 Zig 0.16 的 `std.fs.openDirAbsolute`、`std.fs.cwd()` 等在 build.zig 中不可用
- `2026-04-06` — 改用 Makefile 预处理方案：`tools/gen_auto_registry.sh` 在 `make build` 前自动扫描并生成 `registry.zig`
- `2026-04-06` — 验证通过：添加测试文件 `auto_echo_test.zig` 后 `make build` 自动检测到 2 个技能
- `2026-04-06` — 在 `src/skills/root.zig` 添加集成测试 `Auto-registry integrates auto skills`
- `2026-04-06` — 修复了两个无关的编译错误：`src/core/session.zig` 和 `src/utils/session.zig`
- `2026-04-06` — `make build` 和 `make test` 全部通过，状态改为 `verify`

## 6. Lessons Learned

> 任务完成后，填写此章节。这是把个人任务经验升级为项目级长期记忆的关键步骤。

**分类**: 架构决策 / API 选择

**内容**:
- **Zig 0.16 build.zig 的文件系统限制**: `std.fs.cwd()`、`std.fs.openDirAbsolute()` 和 `b.io` 在 build.zig 配置阶段均不可用。构建时文件系统操作需要通过 `RunArtifact` 执行独立程序，或通过外部脚本（Makefile）预处理
- **采用 Makefile 预处理**: 使用 shell 脚本扫描目录并生成 `registry.zig` 是最可靠的方案。脚本只在内容变化时更新文件，保留 Zig 构建缓存
- **统一注册路径**: `SkillEngine` 通过 `registerBuiltinSkills()` 同时注册 builtin 和 auto skills，对调用者完全透明

**后续动作**:
- [x] 更新 `docs/DESIGN-REFERENCES.md`
- [ ] 考虑是否需要更新 `docs/lessons-learned.md`
