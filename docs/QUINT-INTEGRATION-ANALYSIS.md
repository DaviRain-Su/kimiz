# Quint 集成分析 — 可执行规范语言能否增强 KimiZ 的验证能力

**文档版本**: 1.0  
**日期**: 2026-04-05  
**分析对象**: [informalsystems/quint](https://github.com/informalsystems/quint)  
**分析结论**: Quint 是一个高质量的可执行规范语言和模型检查工具，但**与 KimiZ 的直接编译集成并不合适**。更实际的价值在于：作为 KimiZ Agent 的**外部规范验证器**和**测试用例生成器**，用于验证分布式系统、协议和状态机的正确性。

---

## 1. Quint 是什么

**定位**: "An executable specification language with delightful tooling based on the temporal logic of actions (TLA)."

Quint 是一个现代版的 TLA+ 替代方案，由 Informal Systems 开发（1.3k stars）。它的核心能力包括：

1. **可执行规范（Executable Specs）**
   - 用类 TypeScript 的语法描述系统状态机
   - 定义状态变量（`var`）、动作（`action`）、纯值（`pure val`）

2. **属性声明（Properties）**
   - 不变量（invariants）：如 `balances >= 0`
   - 时序属性（temporal properties）：如 "最终一定会提交"

3. **模型检查（Model Checking）**
   - 自动穷举状态空间
   - 验证属性是否在所有可能执行路径上成立

4. **模拟器（Simulator）**
   - 生成交互式执行 trace
   - 支持随机或引导式探索

5. **基于模型的测试（Model-based Testing）**
   - 从规范模型生成测试 trace
   - 在真实代码实现中重放这些 trace 进行验证

6. **反例生成（Counter-examples）**
   - 当属性被违反时，输出具体的步骤序列
   - 展示系统如何从初始状态一步步走到违规状态

### 1.1 代码示例

```quint
/// 状态变量：每个账户的余额
var balances: str -> int

pure val ADDRESSES = Set("alice", "bob", "charlie")

action withdraw(account, amount) = {
  balances' = balances.setBy(account, curr => curr - amount)
}

/// 不变量：余额永远不应为负
val no_negatives = ADDRESSES.forall(addr => balances.get(addr) >= 0)
```

运行模型检查：
```bash
$ quint run bank.qnt --invariant=no_negatives

[State 0] { balances: Map("alice" -> 0, "bob" -> 0, "charlie" -> 0) }
[State 1] { balances: Map("alice" -> -63, "bob" -> 0, "charlie" -> 0) }
[violation] Found an issue (44ms).
error: Invariant violated
```

### 1.2 实际应用项目

Quint 已被多个知名项目使用：
- **CometBFT** / **Tendermint** (Cosmos 共识)
- **Malachite** (Circle 的 BFT 共识)
- **MonadBFT** (Monad 链)
- **Mysticeti-C** (Sui 的共识)
- **HotShot** (Espresso)
- **Interchain Security** (Cosmos)
- **Jellyfish Merkle Tree** (Left Curve)
- **各种智能合约** (CosmWasm, Solidity)

---

## 2. Quint 与 KimiZ 的集成可能性分析

### 2.1 直接编译集成？❌ 不合适

**原因**:
- Quint 本身是 **TypeScript/Scala**（Apalache 后端）实现的
- 它的运行时依赖 Node.js/npm 和 JVM（可选）
- 将 Quint 编译进 KimiZ 的二进制需要引入庞大的外部运行时
- 这与 KimiZ "编译型、零依赖、高性能" 的设计哲学冲突

**结论**: 不要试图把 Quint 编译进 KimiZ。

### 2.2 作为外部工具调用？✅ 有价值

Quint 可以作为 KimiZ 的**外部验证工具**，通过 `std.process.Child` 调用 CLI（`quint run`、`quint test`、`quint verify`）。

这和 AutoLab 的集成模式类似：
```
KimiZ Agent ──► 生成协议/状态机代码
                     │
                     ▼
              Quint Model / Spec
                     │
                     ▼
              quint run / quint verify
                     │
                     ▼
              Counter-example or Success
                     │
                     ▼
              反馈给 Agent 修复或确认正确
```

---

## 3. 最值得探索的 3 个集成场景

### 场景 1: Agent 生成代码 + Quint 规范验证（Protocol Verification）

**适用对象**: 分布式系统、共识协议、状态机、智能合约

**工作流程**:
1. 用户要求 KimiZ Agent 实现一个 Raft 共识模块
2. Agent 生成 Zig/Rust/Go 实现代码
3. 同时（或在人类协助下），为该系统编写 Quint 规范
4. KimiZ 调用 `quint run` / `quint verify` 验证规范
5. 如果 Quint 发现反例（如 leader 选举死锁），将 counter-example 反馈给 Agent
6. Agent 根据 counter-example 修改实现代码

**价值**:
- 用形式化方法验证协议正确性，远超单元测试的覆盖率
- Counter-example 提供了具体的修复线索
- 特别适合 KimiZ 未来要支持的 "Hardness Engineering" 场景

**挑战**:
- 要求 Agent（或用户）会写 Quint 规范
- 状态空间爆炸问题（需要合理限制模型参数）
- 从 Quint counter-example 到实现代码修复的映射不是自动的

### 场景 2: Quint 生成测试 Trace，用于测试 Agent 的实现（Model-based Testing）

这是 Quint 官方明确支持的能力：Model-based Testing (MBT)。

**工作流程**:
1. 用 Quint 描述系统的抽象模型
2. 运行 `quint run --out-format=json` 生成大量随机 trace
3. 将这些 trace 转换为具体的测试输入
4. 在 Agent 生成的实现代码上重放这些 trace
5. 如果实现行为和模型不一致，报告错误

**价值**:
- 自动生成复杂的、覆盖边界条件的测试场景
- 测试数据有形式化语义保证，不是随机 fuzz
- 可以覆盖单元测试难以触发的并发/时序问题

**示例**:
```bash
# 1. Quint 生成 1000 个 trace
quint run raft.qnt --max-samples=1000 --out-format=json > traces.json

# 2. KimiZ 测试转换器将 trace 转为单元测试
# 3. 运行测试套件验证 Agent 生成的 raft 实现
```

### 场景 3: 用 Quint 验证 KimiZ 自己的 Agent 协议设计

**元应用**: 不帮用户验证外部代码，而是验证 KimiZ 自身的系统设计。

KimiZ 的自我进化涉及很多状态机和协议：
- Agent 循环状态机（idle → planning → executing → reviewing → learning）
- Skill registry 的并发访问
- AutoRegistry 的更新协议
- Subagent 委派和结果收集协议

**工作流程**:
1. 用 Quint 为 KimiZ 的 Agent Loop 写规范
2. 声明不变量（如 "任何时刻最多只有一个 LLM 调用在进行"）
3. 用 Quint 模型检查器验证这些不变量
4. 在修改 KimiZ 核心逻辑前，先更新 Quint 规范并验证

**价值**:
- 在 KimiZ 自身变得复杂时，用形式化方法避免设计缺陷
- 特别适合验证并发和时序相关的协议
- 作为架构审查的一部分

---

## 4. 具体集成方案设计

### 4.1 推荐的集成形式：Zig Skill + Quint CLI

类似 AutoLab 的 `autolab-eval` skill，可以设计一个 `quint-verify` skill：

```zig
pub const SKILL_ID = "quint-verify";
pub const SKILL_NAME = "Quint Protocol Verification";

pub const params = &[_]SkillParam{
    .{
        .name = "spec_path",
        .description = "Path to the .qnt specification file",
        .param_type = .filepath,
        .required = true,
    },
    .{
        .name = "main_module",
        .description = "Main module name to verify",
        .param_type = .string,
        .required = true,
    },
    .{
        .name = "invariants",
        .description = "Comma-separated list of invariants to check",
        .param_type = .string,
        .required = false,
    },
    .{
        .name = "max_steps",
        .description = "Maximum number of steps for the model checker",
        .param_type = .integer,
        .required = false,
        .default_value = "100",
    },
};
```

### 4.2 Skill 执行流程

```
1. 验证 spec_path 指向的 .qnt 文件存在
2. 调用 `quint typecheck <spec_path>` 确保规范语法正确
3. 调用 `quint run <spec_path> --main=<module> --invariant=<invs> --max-steps=<n>`
4. 捕获 stdout/stderr
5. 解析输出：
   - 若包含 "[violation]" → 提取 counter-example trace
   - 若包含 "No violation" / "all OK" → 成功
   - 其他 → 未知错误
6. 组装 `QuintFeedback` 返回
```

### 4.3 数据模型

```zig
pub const QuintFeedback = struct {
    success: bool,
    status: Status,
    checked_invariants: [][]const u8,
    violated_invariant: ?[]const u8,
    counter_example: ?CounterExample,
    logs: []const u8,
    elapsed_ms: u32,

    pub const Status = enum {
        all_invariants_hold,
        invariant_violated,
        type_error,
        runtime_error,
        timeout,
        unknown,
    };

    pub const CounterExample = struct {
        initial_state: []const u8,
        steps: []Step,

        pub const Step = struct {
            action: []const u8,
            state: []const u8,
        };
    };
};
```

---

## 5. 与 AutoLab 集成的对比

| 维度 | AutoLab | Quint |
|------|---------|-------|
| **评估类型** | 性能/正确性基准测试 | 形式化规范验证 |
| **输出** | reward.json（数值分数） | Counter-example（具体反例 trace） |
| **适用域** | 算法优化、ML 训练、系统工程 | 分布式协议、状态机、并发系统 |
| **外部依赖** | Docker + Harbor | Node.js + `quint` CLI |
| **Agent 能力要求** | 优化代码、调试错误 | 理解/编写规范、从反例修复实现 |
| **集成复杂度** | 中等 | 较低（纯 CLI 调用） |
| **即时价值** | 高（可直接跑真实代码） | 中（需要先有规范） |

**关系**: AutoLab 和 Quint 是**互补**的。
- AutoLab 回答 "代码跑得快不快、对不对？"
- Quint 回答 "协议在所有可能场景下是否都正确？"

---

## 6. 建议的实施路径

### 阶段 0: 探索（1-2 天）
1. 安装 Quint CLI：`npm install -g @informalsystems/quint`
2. 跑通官方 tutorial（coin、bank 等示例）
3. 选一个 KimiZ 内部的小状态机，尝试用 Quint 写规范
4. 评估：从 counter-example 到代码修复的映射是否自然

### 阶段 1: Skill 原型（2-3 天）
1. 实现 `quint-verify` Zig skill（CLI 包装）
2. 支持 `quint run` 和 `quint typecheck`
3. 解析 "[violation]" 和基本 counter-example
4. 在 1-2 个 Quint 官方示例上测试

### 阶段 2: Agent 集成（3-5 天）
1. 设计 "spec-driven development" workflow
2. 当 Agent 生成协议代码时，自动触发 `quint-verify`
3. 将 counter-example 转化为 LLM 可理解的反馈 prompt
4. 在一个真实的 KimiZ 子系统（如 subagent orchestration）上验证

### 阶段 3: MBT 扩展（长期）
1. 从 Quint 模型批量生成 JSON trace
2. 将 trace 转为目标语言的单元测试
3. 作为 CI 回归测试的一部分运行

---

## 7. 风险与限制

### 7.1 状态空间爆炸
Quint/TLA+ 的模型检查在大状态空间下会超时或耗尽内存。
- **应对**: 限制参数规模（如节点数 ≤ 3），使用抽象模型而非 1:1 映射

### 7.2 规范和实现之间的语义鸿沟
Quint 规范是抽象模型，实现代码是具体细节。两者的差异可能导致：
- 规范通过了，但实现仍有 bug（因为规范遗漏了某些细节）
- 规范失败，但实现是对的（因为规范过于严格）
- **应对**: 明确 Quint 是辅助工具，不是绝对保证

### 7.3 Agent 写 Quint 规范的能力
当前 LLM 对 Quint/TLA+ 的掌握程度远低于 Python/Zig。
- **应对**: 短期内由人类提供规范，Agent 负责根据反馈修复实现
- 长期可收集 Quint 规范数据集，训练 Agent 写规范

### 7.4 Node.js 依赖
Quint CLI 需要 Node.js 环境。
- **应对**: 在 KimiZ 运行环境中预装 Node.js；或将 Quint 运行在独立容器中

---

## 8. 结论

### 是否推荐集成 Quint？

**推荐，但要有明确的定位和边界：**

1. **不把 Quint 编译进 KimiZ** —— 作为外部 CLI 工具调用
2. **不期望 Agent 自动生成 Quint 规范**（短期内）—— 由人类写规范，Agent 根据验证反馈修复实现
3. **最适合的场景**:
   - 验证分布式协议和状态机设计（场景 3：验证 KimiZ 自身）
   - 从规范生成测试 trace（场景 2：MBT）
   - 辅助 Hardness Engineering 任务中的协议实现（场景 1）

### 优先级建议

在当前 KimiZ 的 MVP 阶段，**Quint 的优先级应低于 AutoLab**：
- AutoLab 可以直接评估代码实现，无需人类写额外规范
- Quint 的价值在 KimiZ 进入 "复杂协议/分布式系统" 领域后才会充分显现

**建议时机**: 
- **短期（1-2 月）**: 保持关注，做阶段 0 的探索
- **中期（3-6 月）**: 当 KimiZ 开始处理子代理编排、状态机协议时，引入 Quint 验证
- **长期**: 把 Quint 作为 Agent 工具链的一部分，与 AutoLab 互补

---

## 9. 下一步行动

如果决定推进，建议只做**最小可行探索**：

```bash
# 1. 安装 Quint
npm install -g @informalsystems/quint

# 2. 克隆示例
git clone https://github.com/informalsystems/quint.git /tmp/quint

# 3. 跑一个经典示例
cd /tmp/quint/examples/classic/dining-philosophers
quint run philosophers.qnt --invariant=no_deadlock --max-steps=50

# 4. 观察输出格式，评估解析难度
```

同时，我可以为 KimiZ 的 **Agent Loop 状态机**草拟一个 Quint 规范，作为概念验证。如果你同意，我可以继续做这个探索。
