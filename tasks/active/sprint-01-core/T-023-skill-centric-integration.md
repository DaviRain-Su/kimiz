### T-023: 实现 Skill-Centric 架构核心
**状态**: completed
**优先级**: P0
**创建**: 2026-04-05
**完成**: 2026-04-05
**预计耗时**: 4h
**实际耗时**: 3h

**描述**:
根据 PRD 要求，实现 Skill-Centric 架构 - 这是 kimiz 的核心差异化特性。

**验收标准**:
- [x] 创建 `src/skills/` 模块目录
- [x] 实现 Skill 注册表 (SkillRegistry)
- [x] 实现 Skill 执行引擎 (SkillEngine)
- [x] 定义 Skill 接口和基础类型
- [x] 支持 Skill 的热加载/注册
- [x] **5个内置 Skills 实现** (code_review, refactor, test_gen, doc_gen, debug)
- [x] **内置 Skills 自动注册**

**核心组件**:

| 组件 | 文件 | 功能 |
|------|------|------|
| Skill | `root.zig` | Skill 元数据定义 |
| SkillContext | `root.zig` | 执行上下文 |
| SkillResult | `root.zig` | 执行结果 |
| SkillParam | `root.zig` | 参数定义 |
| SkillRegistry | `root.zig` | Skill 注册表 |
| SkillEngine | `root.zig` | Skill 执行引擎 |
| Builtin Skills | `builtin.zig` | 内置技能集合 |

**内置 Skills**:
- `code-review` - 代码审查
- `refactor` - 代码重构
- `test-gen` - 测试生成
- `doc-gen` - 文档生成
- `debug` - 调试辅助

**使用示例**:
```zig
var registry = SkillRegistry.init(allocator);
defer registry.deinit();

// 注册内置 Skills
try skills.registerBuiltinSkills(&registry);

// 创建执行引擎
var engine = SkillEngine.init(allocator, &registry);

// 执行 Skill
var args = std.json.ObjectMap.init(allocator);
try args.put("filepath", .{ .string = "src/main.zig" });
const result = try engine.execute("code-review", args, ctx);
```

**依赖**: 

**笔记**:
Skill-Centric 架构已完成，包含：
- 完整的 Skill 类型系统
- 注册表支持增删改查
- 执行引擎支持参数验证和错误处理
- 5 个实用的内置 Skills

