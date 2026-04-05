# AutoLab 集成分析 — 把前沿研究基准变成 Agent 的对抗反馈源

**文档版本**: 1.0  
**日期**: 2026-04-05  
**分析对象**: [autolabhq/autolab](https://github.com/autolabhq/autolab)  
**分析结论**: AutoLab 是评估 AI Agent 在工程和研究任务上能力的优秀基准。将其集成到 KimiZ 中作为**外部评估器（Critic/Evaluator）**，可以构建一个类似 GAN 的对抗反馈循环：Agent 生成代码 → AutoLab 评估 → 反馈驱动 Agent 迭代优化。

---

## 1. AutoLab 是什么

**定位**: "A benchmark for evaluating AI agents on frontier research tasks."

AutoLab 提供 **23 个开放式任务**，覆盖两大领域：
- **Model Development (5 个)**: scaling law、GRPO fine-tuning、data selection、OCR、LLM serving
- **System Optimization (18 个)**: AES-128、SHA-256、Gaussian blur、Flash Attention、hash join、radix sort、regex engine、sorting network 等

**关键特点**:
- 每个任务提供一个**能运行但未经优化的初始代码**
- 有明确的**计算预算和超时限制**（1-12 小时）
- 有**可量化的目标指标**（throughput、latency、perplexity、accuracy、parameter count）
- 在 **Docker sandbox** 中运行（基于 Harbor 框架），支持 GPU
- 评分基于与人类参考解的对比

---

## 2. AutoLab 的任务结构

每个任务目录标准化：

```
tasks/<task_name>/
├── task.toml              # 元数据、评分规则、资源限制
├── instruction.md         # Agent 可读的问题描述
├── environment/
│   ├── Dockerfile         # 可复现环境
│   └── <editable files>   # 需要优化的代码
├── solution/              # 私有 — 对 Agent 不可见
│   ├── solve.sh           # 参考解法
│   └── reference.md       # 优化机会说明
└── tests/
    ├── test.sh            # 运行 benchmark，计算 reward
    └── <verifier scripts> # 正确性检查
```

### task.toml 示例

```toml
version = "1.0"

[metadata]
author = "SOTAGYM"
difficulty = "hard"
domain = "optimization"
tags = ["python", "sorting-network", "search"]

[agent]
timeout_sec = 7200  # 2 hours

[environment]
cpus = 2
memory_mb = 2048
gpus = 0
allow_internet = false

[optimization]
metric = "comparator_count"
direction = "lower"

[optimization.baseline]
score = 80
method = "Batcher bitonic sort for 16 inputs"

[optimization.reference]
score = 60
method = "Known optimal 16-input sorting network"
```

---

## 3. 为什么 AutoLab 适合作为 KimiZ 的 Critic

用户的直觉非常正确：AutoLab 可以充当 **GAN 中的 Discriminator / Critic**。

```
┌─────────────────┐      generate       ┌─────────────────┐
│   KimiZ Agent   │ ──────────────────► │   Code/Config   │
│   (Generator)   │                     │   (Artifact)    │
└─────────────────┘                     └────────┬────────┘
         ▲                                       │
         │         feedback (score + logs)       │
         │◄──────────────────────────────────────┘
         │
┌────────┴────────┐
│   AutoLab Task  │
│   (Critic)      │
│  - run tests/   │
│  - compute      │
│    reward       │
│  - return       │
│    structured   │
│    feedback     │
└─────────────────┘
```

### 3.1 AutoLab 提供的是**客观、可量化的反馈**

不像 LLM-as-judge 那样主观，AutoLab 的反馈是：
- `reward.json` 中的数值分数
- `test.sh` 的 stdout/stderr（编译错误、运行时错误、性能数据）
- 通过/失败的明确边界

这完美契合 KimiZ "编译型 + 反馈驱动" 的哲学。

### 3.2 AutoLab 的任务覆盖 KimiZ 关心的能力

KimiZ 的自我进化需要 Agent 擅长：
1. **写代码** → AutoLab 的系统优化任务直接测试代码优化能力
2. **训练/调优 ML 模型** → AutoLab 的 model development 任务覆盖
3. **在约束下迭代** → 每个任务都有时间/计算预算限制
4. **诊断和修复错误** → 编译失败、测试失败、性能不达标的反馈循环

### 3.3 Harbor 的 Sandbox 机制天然安全

AutoLab 基于 [Harbor](https://github.com/harbor-framework/harbor) 运行：
- 每个任务在自己的 Docker 容器中执行
- 可以限制 CPU、内存、GPU、网络访问
- Agent 的代码不会破坏主机环境

这意味着 KimiZ 可以**大规模、自动地**让 Agent 尝试各种解法，即使代码有 bug 也不会影响主系统。

---

## 4. 集成方案设计

### 4.1 架构概览

```
KimiZ Agent
    │
    ├──► AutoLab Evaluator (Zig skill or Python wrapper)
    │       │
    │       ├──► Harbor / Docker
    │       │       │
    │       │       ├──► Run task environment
    │       │       ├──► Execute tests/test.sh
    │       │       └──► Write reward.json
    │       │
    │       └──► Parse reward.json + logs
    │               │
    │               └──► Return structured Feedback
    │
    └──► Agent uses feedback to iterate
```

### 4.2 集成层级选择

有三种集成深度，推荐**方案 B（中等深度）**作为起点：

#### 方案 A: 浅层集成 — 外部脚本调用
KimiZ 通过 `std.process.Child` 调用一个 Python 包装脚本，由脚本管理 Harbor 生命周期。

**优点**: 实现快，不需要改 AutoLab 源码  
**缺点**: 依赖 Python/Harbor 环境，调用链长  
**适用**: 快速验证概念

#### 方案 B: 中等深度 — Zig skill + Docker API
在 KimiZ 中新增一个 `autolab-eval` skill。该 skill：
1. 接收 `task_name` 和 `agent_artifact`（代码/配置）
2. 用 Docker API（或 `docker` CLI）启动 AutoLab 任务容器
3. 挂载 agent 的修改到 `/app/`
4. 执行 `tests/test.sh`
5. 读取 `reward.json` 和日志
6. 返回结构化的 `AutoLabFeedback`

**优点**: 编译型、可控、可以嵌入 KimiZ 的反馈循环  
**缺点**: 需要实现 Docker 生命周期管理  
**适用**: **推荐方案**

#### 方案 C: 深度集成 — 重写 AutoLab 运行时
用 Zig 重写 Harbor 的 sandbox 层，或用现有容器运行时（如 containerd）直接跑 AutoLab 任务。

**优点**: 零 Python 依赖，完全编译型  
**缺点**: 工程量大，Harbor 和 AutoLab 还在快速迭代  
**适用**: 长期目标，当前不推荐

---

## 5. 核心数据类型设计（Zig）

### 5.1 AutoLab Task Config

```zig
pub const AutoLabTask = struct {
    name: []const u8,
    version: []const u8,
    metadata: Metadata,
    agent: AgentConfig,
    environment: EnvConfig,
    optimization: OptimizationConfig,

    pub const Metadata = struct {
        author: []const u8,
        difficulty: []const u8,  // "easy", "medium", "hard"
        domain: []const u8,
        tags: [][]const u8,
    };

    pub const AgentConfig = struct {
        timeout_sec: u32,
    };

    pub const EnvConfig = struct {
        cpus: u32,
        memory_mb: u32,
        storage_mb: u32,
        gpus: u32,
        allow_internet: bool,
    };

    pub const OptimizationConfig = struct {
        metric: []const u8,
        direction: enum { lower, higher },
        baseline: ScorePoint,
        reference: ScorePoint,

        pub const ScorePoint = struct {
            score: f64,
            method: []const u8,
        };
    };
};
```

### 5.2 Evaluation Feedback

```zig
pub const AutoLabFeedback = struct {
    success: bool,
    reward: f64,           // 0.0 - 1.0+ (can exceed 1.0 for ML tasks)
    raw_score: f64,        // actual metric value
    baseline_score: f64,
    reference_score: f64,
    elapsed_sec: f32,
    status: Status,
    logs: []const u8,      // stdout + stderr from test.sh
    errors: ?[]const u8,   // structured error info

    pub const Status = enum {
        success,            // passed correctness + got reward
        correctness_fail,   // code runs but produces wrong result
        compile_error,      // build failed
        runtime_error,      // crashed during execution
        timeout,            // exceeded time limit
        unknown,            // unexpected failure
    };
};
```

---

## 6. Skill 接口设计

```zig
pub const SKILL_ID = "autolab-eval";
pub const SKILL_NAME = "AutoLab Evaluation";
pub const SKILL_DESCRIPTION = "Evaluate agent-generated code using AutoLab benchmark tasks as an external critic";

pub const params = &[_]SkillParam{
    .{
        .name = "task_name",
        .description = "Name of the AutoLab task (e.g., 'discover_sorting', 'flash_attention')",
        .param_type = .string,
        .required = true,
    },
    .{
        .name = "artifact_path",
        .description = "Path to the agent's modified code or project directory",
        .param_type = .filepath,
        .required = true,
    },
    .{
        .name = "autolab_tasks_root",
        .description = "Root directory containing AutoLab tasks/ folder",
        .param_type = .filepath,
        .required = true,
    },
    .{
        .name = "timeout_override",
        .description = "Optional timeout override in seconds",
        .param_type = .integer,
        .required = false,
    },
};
```

---

## 7. 反馈循环：如何把 Critic 输出变成 Agent 的改进行动

这是集成的核心价值。AutoLab 不只是打分，它的输出应该被解析成 Agent 可消费的**结构化反馈**。

### 7.1 反馈分类与对应的 Agent 策略

| AutoLab 状态 | 反馈内容 | Agent 行动 |
|--------------|----------|------------|
| `compile_error` | 编译器错误信息 | 调用 `systematic-debugging` skill，定位并修复编译错误 |
| `correctness_fail` | 测试失败、assertion 错误 | 分析测试输出，理解预期行为 vs 实际行为，修复逻辑 bug |
| `runtime_error` | Segfault、panic、exception | 添加错误处理、检查边界条件、修复内存问题 |
| `success` (reward < 0.5) | 代码正确但性能差 | 诊断瓶颈、提出优化假设、运行 profiler、迭代改进 |
| `success` (reward >= 0.8) | 接近或超过参考解 | 记录成功方案，提取为 skill 或 pattern |
| `timeout` | 运行时间太长 | 分析算法复杂度、减少不必要的计算、并行化 |

### 7.2 两阶段优化循环（Recommended）

```
Loop:
  1. Agent 生成代码修改
  2. AutoLab Critic 运行评估 → Feedback
  3. Agent 解析 Feedback
  4. If compile/correctness/runtime error:
        → Debug skill → fix → goto 1
     Else if reward < target:
        → Optimization skill → hypothesize & experiment → goto 1
     Else:
        → Success, extract learnings
```

这和 AutoLab 自己的任务设计哲学是一致的：*"diagnose bottlenecks, formulate hypotheses, run experiments, and iteratively improve."*

---

## 8. 与现有 KimiZ 工作的关联

| KimiZ 组件 | AutoLab 集成后如何增强 |
|------------|------------------------|
| `code-review` skill | Critic 的输出可以作为 code review 的额外输入（"AutoLab found a correctness issue here"） |
| `systematic-debugging` skill | AutoLab 的 compile/runtime 错误可以直接触发 debug 流程 |
| `auto-skill-generation` (T-100) | 成功的 AutoLab 解法可以被提取为新 skill |
| `hermes-atropos-environments` | 如果 KimiZ 未来做 RL training，AutoLab 任务就是天然的 reward environment |
| Subagent / delegate_task | 可以把每个 AutoLab 任务作为一个子代理作业，并行探索 |

---

## 9. 实施路线图

### Phase 1: 最小可行集成（1-2 天）
1. Clone `autolabhq/autolab` 到本地
2. 挑选 1-2 个 Python-only 的任务（如 `discover_sorting`）
3. 写一个 Python 包装脚本，接收 agent 修改并运行 Harbor
4. 在 KimiZ 中通过 `std.process.Child` 调用脚本
5. 解析 `reward.json`，返回简单的 success/reward 信息

### Phase 2: Zig Skill 化（2-3 天）
1. 实现 `autolab-eval` Zig skill
2. 用 Docker CLI 直接管理容器生命周期（替代 Python 脚本）
3. 解析 `task.toml` 为 Zig struct
4. 实现 `AutoLabFeedback` 的完整格式化输出

### Phase 3: 闭环优化（1 周）
1. 把 `autolab-eval` 接入 Agent 的迭代循环
2. 设计 "Evaluate → Debug → Optimize" 的 orchestration skill
3. 在 2-3 个任务上跑通完整的端到端优化
4. 记录成功/失败模式，提取为技能库

### Phase 4: 扩展覆盖（长期）
1. 逐步覆盖更多 AutoLab 任务
2. 对需要 GPU 的任务配置 GPU sandbox
3. 把 AutoLab 分数作为 Agent 版本迭代的回归测试基准

---

## 10. 风险与注意事项

### 10.1 计算成本
AutoLab 任务可能需要：
- CPU-intensive 任务：几分钟到几小时
- GPU-intensive 任务：需要 L40S / H100

**建议**:
- 从廉价的 CPU 任务开始验证集成
- GPU 任务只在有算力资源时运行
- 设置严格的 timeout

### 10.2 Harbor 依赖
Harbor 需要 Docker + Python `uv` 环境。

**建议**:
- KimiZ 主机上预装 Docker
- 用 `uv` 管理 Harbor 依赖
- 考虑用 `docker-in-docker` 或远程 Docker daemon

### 10.3 任务不可解性
有些任务（如 `discover_sorting`）是 NP-hard / 组合优化问题，Agent 可能无法在预算内找到优解。

**建议**:
- 不要以"满分"作为唯一成功标准
- 关注 **relative improvement**（从 baseline 提升了多少）
- 把过程数据（尝试次数、错误类型分布）也作为评估维度

---

## 11. 结论

AutoLab 是一个非常高质量的**外部评估基准**，把它集成到 KimiZ 中作为 Critic 有巨大价值：

1. **客观的数值反馈**替代主观的 LLM 评判
2. **真实的工程和研究任务**测试 Agent 的端到端能力
3. **安全的 sandbox 环境**支持自动化的大规模实验
4. **天然的两阶段循环**（正确性 → 性能）与 KimiZ 方法论高度契合

用户提出的 "GAN 式评论员" 概念非常准确：
- **Generator** = KimiZ Agent（生成代码/配置）
- **Discriminator** = AutoLab Critic（运行测试、打分、给反馈）
- **Loss signal** = `reward.json` + 日志中的结构化错误信息

这是 KimiZ 从"能编译通过的代码生成"进化到"能解决真实工程问题"的关键一步。

---

## 12. 下一步行动建议

建议立即执行 **Phase 1**（最小可行集成）：

```bash
# 1. 克隆 AutoLab
cd /Users/davirian/dev/active/kimiz
git clone https://github.com/autolabhq/autolab.git third_party/autolab

# 2. 安装 Harbor
uv pip install harbor

# 3. 选一个简单任务做端到端测试
cd third_party/autolab
harbor run -p tasks/discover_sorting -a terminus-2 -m gpt-4o
```

同时，我可以开始写一个**Python 包装脚本**（`scripts/autolab_eval.py`），让 KimiZ 能通过命令行快速调用 AutoLab 评估。

要我直接开始做 Phase 1 的实现吗？
