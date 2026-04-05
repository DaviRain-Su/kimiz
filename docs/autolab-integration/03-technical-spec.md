# Phase 3: Technical Spec — AutoLab Critic Integration

**项目**: KimiZ  
**模块**: AutoLab External Evaluator (Critic)  
**版本**: 1.0.0  
**日期**: 2026-04-05  
**任务 ID**: TASK-FEATURE-AUTOLAB-001  
**作者**: Agent  

---

## 1. 背景与目标

### 1.1 背景
KimiZ 是一个编译型 AI Agent 框架，核心能力包括代码生成、调试、和 skill 自动演化。当前评估 Agent 输出主要依赖：
- 编译器反馈（compile success/failure）
- 单元测试结果
- LLM-as-judge 的主观评估

这些评估方式存在明显局限：
- **编译器反馈**只能验证语法正确性，无法评估语义正确性和性能
- **单元测试**需要预先编写，对开放性问题覆盖不足
- **LLM-as-judge**主观性强，缺乏可量化的客观标准

### 1.2 目标
将 [AutoLab](https://github.com/autolabhq/autolab) 集成到 KimiZ 中作为**外部评估器（External Critic）**，构建一个对抗式反馈循环：

```
Agent 生成代码/配置 ──► AutoLab Critic 运行评估 ──► 返回结构化反馈 ──► Agent 迭代优化
```

通过这个闭环，KimiZ Agent 可以：
1. 在**真实工程任务**上获得**客观、可量化的性能反馈**
2. 自动诊断编译错误、运行时错误、正确性错误
3. 在性能达标任务上进行瓶颈分析和优化迭代
4. 从成功经验中提取可复用的 skill 模式

---

## 2. 设计原则

### 2.1 编译型优先 (Compiled-First)
- 核心 evaluator skill 必须是 Zig 编译型代码
- 避免把评估逻辑放在 prompt 中
- 与 KimiZ 的 skill 系统原生集成

### 2.2 渐进式集成 (Incremental Integration)
- Phase 1 从最简单的 Python-only 任务开始验证概念
- 逐步扩展到 C/Rust/Go 和 GPU 任务
- 不追求一次性覆盖全部 23 个任务

### 2.3 安全隔离 (Sandboxed Execution)
- 所有 AutoLab 任务在 Docker 容器中运行
- Agent 的代码修改不会直接影响主机
- 通过资源限制（CPU、内存、GPU）控制成本

### 2.4 反馈即信号 (Feedback as Signal)
- AutoLab 的输出必须被解析成 Agent 可直接消费的结构化数据
- 不同错误类型（compile / runtime / correctness / performance）触发不同的 Agent 策略

---

## 3. 系统架构

### 3.1 整体架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                         KimiZ Agent                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │  Generator   │  │  Orchestrator│  │  Debug / Optimize Skills │  │
│  │  (Agent core)│◄─┤  (Loop ctrl) │◄─┤  (systematic-debugging)  │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────────────────────┘  │
│         │                 ▲                                        │
│         │ generate        │ feedback                               │
│         ▼                 │                                        │
│  ┌────────────────────────┴────────────────────────┐               │
│  │         autolab-eval Skill (Zig)               │               │
│  │  - parse task.toml                              │               │
│  │  - prepare artifact                             │               │
│  │  - spawn Docker container                       │               │
│  │  - run tests/test.sh                            │               │
│  │  - parse reward.json + logs                     │               │
│  │  - return AutoLabFeedback struct                │               │
│  └─────────────────────────────────────────────────┘               │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼ Docker API / CLI
┌─────────────────────────────────────────────────────────────────────┐
│                     AutoLab Task Container                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐  │
│  │  task.toml  │  │ instruction │  │ environment │  │ tests/    │  │
│  │  (config)   │  │     .md     │  │  (codebase) │  │ test.sh   │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────┬─────┘  │
│                                                           │        │
│                              Agent artifact (mounted)     ▼        │
│                                    /app/solve.py  ──►  run & score │
│                                                           │        │
│                                                     reward.json      │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 核心组件

| 组件 | 语言 | 职责 |
|------|------|------|
| `autolab-eval` skill | Zig | KimiZ skill，暴露评估接口 |
| `autolab-runner` | Zig + Shell | 管理 Docker 生命周期，挂载代码，运行测试 |
| `task.toml` parser | Zig | 解析 AutoLab 任务配置 |
| `reward.json` parser | Zig | 解析评估结果 |
| `feedback-formatter` | Zig | 将原始输出格式化为 Agent 可读的报告 |

---

## 4. 数据模型

### 4.1 AutoLabTask（任务配置）

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
        difficulty: []const u8,
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

### 4.2 AutoLabFeedback（评估反馈）

```zig
pub const AutoLabFeedback = struct {
    success: bool,
    reward: f64,
    raw_score: f64,
    baseline_score: f64,
    reference_score: f64,
    elapsed_sec: f32,
    status: Status,
    logs: []const u8,
    errors: ?[]const u8,

    pub const Status = enum {
        success,
        correctness_fail,
        compile_error,
        runtime_error,
        timeout,
        unknown,
    };
};
```

### 4.3 状态到 Agent 行动的映射

| Status | Agent 行动 | 对应 Skill |
|--------|------------|------------|
| `compile_error` | 解析编译错误，定位源码，修复 | `systematic-debugging` |
| `runtime_error` | 分析崩溃日志，检查边界/资源 | `systematic-debugging` |
| `correctness_fail` | 对比预期输出和实际输出，修复逻辑 | `code-review` + debugging |
| `success` (reward < 0.5) | 性能分析，提出优化假设 | optimization orchestrator |
| `success` (reward >= 0.8) | 记录成功，提取模式 | `auto-skill-generation` |
| `timeout` | 分析算法复杂度，减少计算量 | optimization orchestrator |

---

## 5. Skill 接口

### 5.1 参数定义

```zig
pub const SKILL_ID = "autolab-eval";
pub const SKILL_NAME = "AutoLab Evaluation";
pub const SKILL_DESCRIPTION = "Evaluate agent-generated code using AutoLab benchmark tasks";

pub const params = &[_]SkillParam{
    .{
        .name = "task_name",
        .description = "AutoLab task name (e.g., 'discover_sorting')",
        .param_type = .string,
        .required = true,
    },
    .{
        .name = "artifact_path",
        .description = "Path to agent-modified code or project directory",
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

### 5.2 执行流程

```
1. 验证输入参数
2. 读取并解析 task.toml
3. 验证 artifact_path 存在且包含可编辑文件
4. 构建 Docker 运行命令（或调用 Docker API）
5. 挂载 artifact 到容器内的 /app/
6. 在容器内执行 tests/test.sh
7. 捕获 stdout/stderr
8. 读取 reward.json（如果存在）
9. 根据退出码和输出内容推断 Status
10. 组装 AutoLabFeedback
11. 格式化输出并返回
```

---

## 6. Docker 运行策略

### 6.1 容器镜像
AutoLab 每个任务自带 `environment/Dockerfile`。集成策略：
- **预先构建**：第一次运行时 `docker build -t autolab:<task_name>`
- **缓存复用**：后续运行直接使用已构建镜像
- **增量挂载**：Agent 的修改通过 `-v` 挂载到 `/app/`，不重新构建镜像

### 6.2 运行命令示例

```bash
# 构建（首次）
docker build -t autolab:discover_sorting \
  /path/to/autolab/tasks/discover_sorting/environment/

# 运行评估
docker run --rm \
  --cpus=2 \
  --memory=2048m \
  -v /path/to/agent/solve.py:/app/solve.py:ro \
  -v /path/to/autolab/tasks/discover_sorting/tests:/tests:ro \
  autolab:discover_sorting \
  bash /tests/test.sh
```

### 6.3 资源限制
直接从 `task.toml` 的 `[environment]` 段读取并映射到 Docker flags：
- `cpus` → `--cpus`
- `memory_mb` → `--memory`
- `gpus` → `--gpus` (if > 0)
- `allow_internet=false` → `--network none`

---

## 7. 错误处理与边界情况

### 7.1 容器构建失败
- **表现**：`docker build` 非零退出
- **处理**：返回 `Status.unknown`，错误信息包含 build log
- **Agent 行动**：报告环境不可用，可能需要检查 AutoLab 安装

### 7.2 测试脚本不存在
- **表现**：`tests/test.sh` 缺失
- **处理**：返回 `Status.unknown`，错误信息明确指出文件缺失
- **Agent 行动**：跳过此任务

### 7.3 reward.json 解析失败
- **表现**：`test.sh` 成功运行但 `reward.json` 格式异常
- **处理**：返回 `Status.unknown`，附带原始 JSON 内容
- **Agent 行动**：人工检查 AutoLab 版本兼容性

### 7.4 超时
- **表现**：Docker 进程在 `timeout_sec` 内未结束
- **处理**：发送 `docker kill`，返回 `Status.timeout`
- **Agent 行动**：优化算法复杂度或并行度

### 7.5 Agent 产物文件缺失
- **表现**：`artifact_path` 不存在或为空目录
- **处理**：在 skill 执行早期失败，返回 `error.MissingArtifact`

---

## 8. 与现有模块的交互

### 8.1 与 Skill System 集成
- `autolab-eval` 是一个标准 Skill，注册在 SkillRegistry 中
- 通过 `execute_fn` 接收参数，返回 `SkillResult`
- `SkillResult.output` 包含格式化的 `AutoLabFeedback` 文本

### 8.2 与 Provider / LLM 集成
- 当前 `autolab-eval` **不直接调用 LLM**
- 它只提供**结构化反馈文本**
- 是否调用 LLM 分析反馈由上层 Orchestrator 决定

### 8.3 与 Subagent / Delegate 集成
- 可以把每个 AutoLab 任务作为一个独立的子代理作业
- 并行运行多个任务的探索，提高搜索效率

---

## 9. 安全考虑

1. **Docker 隔离**：Agent 代码在容器内运行，无主机写权限（除明确挂载点）
2. **网络隔离**：`allow_internet=false` 时加 `--network none`
3. **资源上限**：CPU、内存、GPU 严格按 `task.toml` 限制
4. **只读挂载**：Agent artifact 和 tests 目录以只读方式挂载，防止测试脚本被篡改

---

## 10. 依赖清单

### 10.1 外部依赖
- Docker Engine（本地或远程 daemon）
- AutoLab 仓库克隆（`git clone https://github.com/autolabhq/autolab.git`）
- Harbor Python 包（`uv pip install harbor`，仅用于 Harbor 原生任务运行，可选）

### 10.2 KimiZ 内部依赖
- `std.process.Child`（执行 Docker CLI）
- `std.json`（解析 `reward.json`）
- `std.fs`（文件路径操作）
- Skill framework (`Skill`, `SkillContext`, `SkillResult`, `SkillParam`)

### 10.3 无新增运行时依赖
- 不引入 Python runtime 到 KimiZ 二进制
- 不引入 HTTP client 到 evaluator（除非未来走 Docker API）

---

## 11. 验收标准

- [ ] 能成功解析至少 3 个 AutoLab 任务的 `task.toml`
- [ ] 能对 `discover_sorting` 任务完成端到端评估（从传入 solve.py 到返回 feedback）
- [ ] Docker 容器正确限制资源（CPU、内存）
- [ ] 能区分 compile_error / runtime_error / correctness_fail / success / timeout
- [ ] `reward.json` 的数值能正确映射到 `AutoLabFeedback.reward`
- [ ] Skill 输出格式能被现有 Agent 循环直接消费
- [ ] 有至少 6 个单元测试覆盖 parser 和 feedback formatter
- [ ] 集成文档完整（含本 Technical Spec + Task Breakdown + Test Spec）

---

## 12. 参考文档

- [AutoLab GitHub](https://github.com/autolabhq/autolab)
- [AutoLab Integration Analysis](../../docs/AUTOLAB-INTEGRATION-ANALYSIS.md)
- [Factory Plugins Analysis](../../docs/FACTORY-PLUGINS-ANALYSIS.md)
- KimiZ Skill System: `src/skills/root.zig`
