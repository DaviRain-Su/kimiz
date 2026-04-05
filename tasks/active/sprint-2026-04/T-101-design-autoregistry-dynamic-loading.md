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

- [ ] `AutoRegistry` 能在构建时自动发现 `src/skills/auto/` 下的所有 skill
- [ ] 新增一个 `.zig` 文件到 `src/skills/auto/` 后，无需修改 `builtin.zig` 即可被调用
- [ ] `SkillEngine` 统一处理 builtin 和 auto skill 的查询与调用
- [ ] 所有代码通过 `zig build test`
- [ ] `zig build` 零错误
