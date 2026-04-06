# Lessons Learned Template — KimiZ 经验教训模板

> **本模板定义了一个标准的 Lessons Learned 文档格式。**  
> 每个 P0/P1 任务完成后，必须在任务文件或独立文档中至少写一条符合此格式的经验教训。  
> 目的：把个人任务经验升级为项目级长期记忆。

---

## 文件头

```markdown
# Lessons Learned — {任务标题或服务模块}

**来源任务**: T-XXX  
**日期**: YYYY-MM-DD  
**分类**: (见下方分类列表)
```

---

## 记录格式

每条经验教训必须包含以下四个字段：

```markdown
### {简短标题：一句话概括教训}

**分类**: 架构决策 / 踩坑记录 / 性能优化 / API 选择

**问题**: {你遇到了什么问题？当时的场景是什么？}

**发现**: {你是怎么发现这个问题的？什么触发了你对它的理解？}

**教训**: {你从中学到了什么？如果重来一次你会怎么做不同？}

**影响范围**: {这条教训影响哪些代码/模块/未来任务？}
```

---

## 分类定义

| 分类 | 何时使用 | 示例 |
|------|----------|------|
| **架构决策** | 选择了一种设计方向、放弃了另一种 | "选择方案 A 因为保持类型安全比热加载更重要" |
| **踩坑记录** | 遇到了非明显的错误、API 陷阱、环境问题 | "Zig 0.16 的 `std.fs.cwd()` 在 build.zig 配置阶段不可用" |
| **性能优化** | 发现并消除了性能瓶颈、减少了分配 | "用 ArenaAllocator 替代逐条 free，减少 60% 分配" |
| **API 选择** | Zig API 有两种以上用法、选择了其中一种 | "用 `parseFromSliceLeaky` 配合 Arena 而非 `parseFromSlice`" |
| **工具使用** | 发现某个工具/库的特殊用法或限制 | "ripgrep 的 `--glob` 比 `find` 快 10 倍" |
| **安全护栏** | 发现并修复了安全风险 | "LLM 生成的文件路径必须做沙箱限制" |
| **测试策略** | 关于如何写测试、什么值得测试的经验 | "comptime 函数的测试必须在 `test` block 中触发编译" |

---

## 示例条目

### Zig 0.16 build.zig 中无法使用 std.fs.cwd()

**分类**: 踩坑记录

**问题**: 在 `build.zig` 中尝试扫描 `src/skills/auto/` 目录以自动生成注册表，但 `std.fs.cwd()`、`std.fs.openDirAbsolute()` 和 `b.io` 在 build 配置阶段均不可用。

**发现**: 编译时 Zig 报错 `root source file struct 'fs' has no member named 'cwd'`。查阅 Zig 0.16 标准库后发现 build.zig 运行在受限上下文中，不提供完整的文件系统 API。

**教训**: 构建时的文件系统操作必须通过外部脚本（Makefile）或 `RunArtifact` 执行独立程序来完成。不能假设 build.zig 有完整 std 访问权限。

**影响范围**: 所有需要在 build.zig 中扫描目录、读取文件、生成代码的任务（T-101 及未来类似需求）。

---

### 统一注册路径：builtin + auto skills 透明集成

**分类**: 架构决策

**问题**: Auto skill 如何与 builtin skill 统一注册？是让它们走不同的代码路径，还是统一到一个入口？

**发现**: `SkillEngine.execute()` 只接受一个 `SkillRegistry` 指针。如果分开注册，执行层不需要知道 skill 的来源。

**教训**: 通过 `registerBuiltinSkills()` 函数同时注册 builtin 和 auto skills，对调用者完全透明。新增 auto skill 只需放在 `src/skills/auto/` 目录，构建时自动发现并注册。

**影响范围**: T-100 (auto skill 生成流水线)、T-101 (AutoRegistry)，以及所有 skill 相关未来任务。

---

## 维护建议

1. **每条教训必须是具体的**，不要写 "Zig 很难用" 这种无意义的总结
2. **每条教训必须包含可行动的建议**，读者应该能根据教训直接修改代码
3. **定期回顾**: 每个 Sprint 结束时，回顾 Lessons Learned 并更新 `DESIGN-REFERENCES.md`
4. **删除过时的**: 如果某个教训因为 API 升级不再适用，标记为 `[过时 - YYYY-MM-DD]`

---

## 自动化收集

未来（T-123）可以实现自动从 Git commit、编译错误日志、测试报告中提取 Lessons Learned 草稿，人工审核后固化。
