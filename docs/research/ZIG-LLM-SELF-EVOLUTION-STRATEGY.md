# Zig + LLM 自我进化战略 — KimiZ 的核心护城河

**文档版本**: 1.0  
**日期**: 2026-04-05  
**状态**: 战略级设计文档  
**关联分析**: [TIGERBEETLE-PATTERNS-ANALYSIS.md](TIGERBEETLE-PATTERNS-ANALYSIS.md), [ZML-PATTERNS-ANALYSIS.md](ZML-PATTERNS-ANALYSIS.md)  

---

## 1. 核心命题

> **KimiZ 的最大差异化不是"更快的 CLI 代理"，而是"一个能利用 Zig 的编译时安全网实现自我进化的 Hardness Engineer"。**

当前所有 AutoAgent（OpenHands、SWE-agent、Devin）都基于 Python/JS，它们的根本缺陷是：
- LLM 生成的代码是**弱类型的字符串**
- 验证只能靠运行时测试，**测试不到的就是定时炸弹**
- 技术债务会随自我迭代**指数级累积**

**Zig 改变了游戏规则。**

---

## 2. 为什么只有 Zig 能支撑真正的自我进化

### 2.1 三支柱理论

| 支柱 | Zig 的能力 | 对自我进化的意义 |
|------|-----------|-----------------|
| **Comptime 类型安全网** | `@TypeInfo` + `@Struct`/`@Union` 实现编译时元编程 | LLM 生成的代码在**编译阶段**就被验证结构正确性 |
| **自举编译** | `build.zig` 可执行任意构建脚本，`std.process.Child` 可调自身编译器 | Agent 可以**生成代码→编译自己→测试→重启** |
| **零技术债务文化** | 强类型 + 高密度断言 + 无隐式分配 | 不正确就不编译，**债务在产生前就被阻止** |

### 2.2 与其他语言的对比

```
Python AutoAgent: 生成 → 运行 → 也许报错 → 债务积累 →  humans clean up
Zig AutoAgent:   生成 → 编译(第一道防线) → 测试(第二道) → 才运行
                 └─ 编译不过 = 直接打回重写，不产生债务
```

Python 的验证是**后验的**（run and see），Zig 的验证是**先验的**（compile and prove）。对于自我进化的系统，先验验证是生存的必需品。

---

## 3. KimiZ 自我进化的三阶段路线图

### Phase 1：运行时 Skill（✅ 已具备基础）

**状态**: `src/skills/root.zig` 已实现 SkillRegistry + SkillEngine

- Skill 是编译进二进制的函数指针
- 通过 JSON `ObjectMap` 传递参数
- 新增 skill = 手写 `.zig` + 修改 `builtin.zig` + 重新编译

**这是地基，但不是进化的终点。**

---

### Phase 2：代码生成-编译-验证闭环（6 个月内）

**核心机制**：

```
Agent 识别重复任务/能力缺口
        ↓
LLM 生成 skill Zig 源码
        ↓
写入 src/skills/auto/{name}.zig
        ↓
自动修改注册表（builtin.zig / auto_registry.zig）
        ↓
触发 zig build test
        ├── 编译失败 → 错误反馈给 LLM → 修复 → 重试
        └── 编译通过 + 测试通过 → 注册生效
        ↓
热重载或自动重启
```

**这是 KimiZ 自我进化的第一步**，让 Agent 从"每次调用 LLM"升级为"学会后固化成本地 skill"。

**关键技术点**：
1. `scripts/generate-skill.zig` — 生成 skill 脚手架的构建脚本
2. `src/skills/auto/` — 自动生成的 skill 隔离目录
3. `AutoRegistry` — 运行时加载 auto skill 的注册表（无需每次改 builtin.zig）
4. `CompilationFeedbackLoop` — 把 zig build 的错误输出解析后回传给 LLM

---

### Phase 3：编译时自我进化（12 个月内）

**终极目标**：Skill 不再只是"运行时被调用的函数"，而是"编译时生成并验证的代码片段"。

#### 模式 A：Comptime Skill DSL

```zig
pub const MySkill = defineSkill(.{
    .name = "analyze-zig-deps",
    .input = struct { path: []const u8 },
    .output = struct { unused: []const []const u8 },
    .handler = myHandler,
});

fn myHandler(input: MySkill.Input) MySkill.Output {
    // 实现...
}
```

`defineSkill` 在 `comptime` 验证：
- `input` 必须是 struct
- `handler` 签名严格匹配 `fn(Input) Output`
- `output` 必须包含 `success` 字段
- 任何违规都是 `@compileError`

#### 模式 B：自举编译循环

Agent 可以直接触发 Zig 编译器重新编译 KimiZ 本身：

```zig
// Agent 生成一个优化后的新模块
// 调用 zig build 生成新版本二进制
// 如果测试全过，替换当前进程或优雅重启
```

这就是 **Hardness Engineer** —— 一个被 Zig 编译器持续约束在正确性边界内的、自我改进的工程系统。

---

## 4. 直接借鉴的代码资产

### 从 TigerBeetle 学习
- **断言密度**: 把 LLM 生成的不变量用 assert 固化
- **零技术债务**: 编译不过的生成代码不允许进入系统
- **侵入式数据结构**: AutoRegistry 用零分配的侵入式队列管理

### 从 ZML 学习
- **`stdx/flags.zig`**: CLI 参数声明式解析，让生成代码更易维护
- **`stdx/bounded_array.zig`**: 固定上限的数组，防止 LLM 生成的循环/列表无限膨胀
- **`MapType`/`mapAlloc`**: comptime 类型变换，可用于 "Skill Schema → Zig Type" 的自动生成
- **Scope + Arena 栈**: 每个生成的 skill 执行都有自己的内存上下文

---

## 5. KimiZ 的护城河构建路径

### 5.1 短期（1-2 个月）：跑通第一个自动生成的 skill

**里程碑**：
- [ ] Agent 能根据自然语言描述生成一个有效的 `.zig` skill 文件
- [ ] `zig build` 能自动编译这个 skill
- [ ] 编译错误能自动回传给 LLM 并修复
- [ ] 测试通过后，skill 能被 Agent 在后续对话中调用

**首个示例**：`auto-generated-hello-skill` → `auto-generated-file-search-skill` → `auto-generated-refactor-skill`

### 5.2 中期（3-6 个月）：建立 AutoRegistry 和生成模板库

**里程碑**：
- [ ] `AutoRegistry` 能动态发现和注册 `src/skills/auto/` 下的所有 skill
- [ ] 建立 10+ 个 skill 生成模板（code, test, doc, refactor, debug...）
- [ ] LLM 能根据模板约束生成高质量代码（减少编译失败率到 <20%）
- [ ] 实现 skill 版本管理和回滚机制

### 5.3 长期（6-12 个月）：自举式系统改进

**里程碑**：
- [ ] Agent 能分析 KimiZ 自己的代码库，发现缺失的抽象
- [ ] 生成新的 Zig 模块（不限于 skill）
- [ ] 自动编译、测试、并提交 PR/补丁
- [ ] 人类从"写代码"退化为"Review 并批准进化"

---

## 6. 风险与护栏

| 风险 | 护栏机制 |
|------|----------|
| LLM 生成垃圾代码 | **Zig 编译器**是第一道防线；测试是第二道；人类 review 是第三道 |
| 无限自我迭代烧钱 | 单次生成本上限；只有 P0/P1 能力缺口才触发 |
| 安全漏洞 | Auto skill 只能访问白名单 API；禁止直接 `execve` 任意命令 |
| 二进制膨胀 | 定期清理未引用的 auto skill；comptime 条件编译控制体积 |
| 回滚困难 | 每个生成的 skill 必须有版本号；保留最近 50 个生成快照 |

---

## 7. 为什么这是 KimiZ 的"唯一核心"

市场上已有：
- **更快的 CLI**: `aider`, `claude-code`, `codex`
- **更强的模型**: OpenAI, Anthropic, Google
- **更全的工具链**: OpenHands, Devin

但**没有任何一个**基于强类型编译语言构建了自我进化的闭环。Python 生态在这一点上有一个**结构性天花板**。

KimiZ 如果能在 Zig 上跑通 "LLM 生成 → 编译器验证 → 自动注册 → 持续迭代"，我们将拥有一个**其他项目无法复制的护城河**。

因为这不是模型能力的比拼，这是**工程范式的代差**。

---

## 8. 下一步行动

1. **立即启动 `T-100`**: 建立 `src/skills/auto/` 目录和自动生成流水线原型
2. **并行启动 `T-101`**: 设计 `AutoRegistry` 动态加载机制
3. **2 周内目标**: 让 KimiZ 能成功生成并编译第一个 auto skill

**参考文档**: 
- [TIGERBEETLE-PATTERNS-ANALYSIS.md](TIGERBEETLE-PATTERNS-ANALYSIS.md)
- [ZML-PATTERNS-ANALYSIS.md](ZML-PATTERNS-ANALYSIS.md)
