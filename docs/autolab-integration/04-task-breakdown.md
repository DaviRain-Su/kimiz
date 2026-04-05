# Phase 4: Task Breakdown — AutoLab Critic Integration

**项目**: KimiZ  
**模块**: AutoLab External Evaluator  
**版本**: 1.0.0  
**日期**: 2026-04-05  
**任务 ID**: TASK-FEATURE-AUTOLAB-001  
**依赖**: Phase 3 Technical Spec (approved)  

---

## 1. 任务拆分总览

整个集成工作拆分为 **4 个 Phase**，共 **14 个子任务**。每个子任务有明确的输入、输出、验收标准和预估工时。

| Phase | 名称 | 子任务数 | 目标 |
|-------|------|----------|------|
| Phase 1 | MVP Integration (最小可行集成) | 4 | 命令行跑通第一个 AutoLab 任务 |
| Phase 2 | Zig Skill 封装 | 4 | 把 Python 包装脚本迁移为编译型 skill |
| Phase 3 | 闭环优化 | 3 | 把 Critic 接入 Agent 迭代循环 |
| Phase 4 | 扩展与硬化 | 3 | 多任务支持、回归测试、文档完善 |

**总预估工时**: 32-40 小时  
**阻塞关系**: Phase 1 → Phase 2 → Phase 3 → Phase 4（可部分并行）

---

## 2. Phase 1: MVP Integration (最小可行集成)

**目标**: 不改动 KimiZ 核心代码，用外部脚本验证 AutoLab 可以运行并产出结构化反馈。

### 2.1 Task 1.1: Clone AutoLab 仓库

**输入**: Git URL  
**输出**: `third_party/autolab/` 目录  
**步骤**:
1. `git clone https://github.com/autolabhq/autolab.git third_party/autolab`
2. 确认 `tasks/` 目录包含 23 个任务
3. 确认 `main.py` 和 `harbor_patch.sh` 存在

**验收标准**:
- [ ] `third_party/autolab/tasks/discover_sorting/` 存在且结构完整
- [ ] `third_party/autolab/tasks/discover_sorting/task.toml` 可读

**工时**: 15 min  
**阻塞**: 无

---

### 2.2 Task 1.2: 安装 Harbor 与 Docker 环境检查

**输入**: Python `uv` / `pip` 环境  
**输出**: Harbor 可执行、Docker daemon 可用  
**步骤**:
1. `uv pip install harbor`（或 `pip install harbor`）
2. 运行 `docker ps` 确认 Docker daemon 可达
3. 运行 `docker info` 记录可用 CPU、内存、GPU 信息
4. 执行 `bash third_party/autolab/harbor_patch.sh`（按 README 说明）

**验收标准**:
- [ ] `harbor --version` 有输出
- [ ] `docker ps` 不报错
- [ ] `harbor_patch.sh` 执行成功

**工时**: 30 min  
**阻塞**: Task 1.1

---

### 2.3 Task 1.3: 编写 Python 包装脚本 `scripts/autolab_eval.py`

**输入**: AutoLab 任务结构、Docker CLI  
**输出**: `scripts/autolab_eval.py`  
**脚本功能**:
1. 接收 CLI 参数：`--task`, `--artifact`, `--autolab-root`
2. 读取 `task.toml` 获取资源限制
3. 构建并运行 Docker 容器
4. 执行 `tests/test.sh`
5. 读取 `reward.json`
6. 输出结构化的 JSON feedback

**伪代码**:
```python
def main():
    args = parse_args()
    task_dir = f"{args.autolab_root}/tasks/{args.task}"
    task_toml = parse_toml(f"{task_dir}/task.toml")
    
    # Build image if not exists
    image = f"autolab:{args.task}"
    if not image_exists(image):
        docker_build(f"{task_dir}/environment", image)
    
    # Run container
    result = docker_run(
        image=image,
        cpus=task_toml.environment.cpus,
        memory=task_toml.environment.memory_mb,
        mounts={args.artifact: "/app/solve.py"},
        cmd="bash /tests/test.sh"
    )
    
    # Parse reward.json from container output or mounted tmp dir
    feedback = assemble_feedback(result)
    print(json.dumps(feedback, indent=2))
```

**验收标准**:
- [ ] 脚本有 `--help`
- [ ] 脚本能成功构建 `autolab:discover_sorting` 镜像
- [ ] 脚本能运行并输出 JSON
- [ ] JSON 包含 `status`, `reward`, `raw_score`, `logs`

**工时**: 3-4 h  
**阻塞**: Task 1.2

---

### 2.4 Task 1.4: 端到端测试（MVP 验证）

**输入**: `scripts/autolab_eval.py`、discover_sorting 任务  
**输出**: MVP 验证报告  
**步骤**:
1. 复制原始 `solve.py` 作为 artifact
2. 运行 `python scripts/autolab_eval.py --task discover_sorting --artifact ...`
3. 验证返回的 JSON 中 `status` 为 `success` 或 `correctness_fail`
4. 验证 `reward` 和 `raw_score` 有数值
5. 修改 `solve.py` 引入一个编译错误，重新运行，验证 `status` 变为 `compile_error`

**验收标准**:
- [ ] 原始代码能跑完测试并产出 reward
- [ ] 引入编译错误后 status 正确识别
- [ ] 日志内容被完整捕获

**工时**: 1-2 h  
**阻塞**: Task 1.3

---

## 3. Phase 2: Zig Skill 封装

**目标**: 将 Python 包装脚本的功能迁移为 KimiZ 原生编译型 skill，并实现完整的 parser 和 formatter。

### 3.1 Task 2.1: 定义 Zig 数据模型

**输入**: Phase 3 Technical Spec 中的数据模型  
**输出**: `src/skills/autolab/autolab_types.zig`  
**内容**:
- `AutoLabTask` struct + 嵌套 struct
- `AutoLabFeedback` struct + `Status` enum
- `TaskTomlParser`（基础版，只解析关键字段）
- `RewardJsonParser`

**验收标准**:
- [ ] 文件能通过 `zig test`
- [ ] 能解析 `discover_sorting/task.toml` 的关键字段
- [ ] 能解析示例 `reward.json`

**工时**: 2-3 h  
**阻塞**: Phase 1 完成

---

### 3.2 Task 2.2: 实现 Docker 运行器 `autolab_runner.zig`

**输入**: `AutoLabTask`、artifact path  
**输出**: `src/skills/autolab/autolab_runner.zig`  
**功能**:
- `buildImage(task_name, env_dir)` → 调用 `docker build`
- `runContainer(image, task, artifact)` → 调用 `docker run`
- `killContainer(id)` → 超时后清理
- `captureOutput()` → 返回 stdout + stderr

**验收标准**:
- [ ] 能构建 `autolab:discover_sorting` 镜像
- [ ] 能运行容器并捕获输出
- [ ] 超时后能正确 kill 容器
- [ ] 资源限制（--cpus, --memory）正确传递

**工时**: 3-4 h  
**阻塞**: Task 2.1

---

### 3.3 Task 2.3: 实现 Feedback 组装器

**输入**: Docker 输出、reward.json 内容  
**输出**: `src/skills/autolab/feedback_assembler.zig`  
**功能**:
- 根据 docker 退出码推断 `Status`
- 解析 `reward.json`（如果存在）
- 填充 `AutoLabFeedback` 所有字段
- 格式化人类可读的输出文本

**状态推断规则**:
| 条件 | Status |
|------|--------|
| docker exit != 0 且 stdout 含 "error:" / "compile" | `compile_error` |
| docker exit != 0 且 stdout 含 "panic" / "segfault" | `runtime_error` |
| docker exit == 0 但 reward.json 中 correctness=false | `correctness_fail` |
| docker exit == 0 且 reward > 0 | `success` |
| 进程被 kill | `timeout` |
| 其他 | `unknown` |

**验收标准**:
- [ ] 各状态推断逻辑有单元测试覆盖
- [ ] 输出文本包含 P0/P1 风格的优先级标签
- [ ] 格式化输出能被现有 Agent 循环消费

**工时**: 2-3 h  
**阻塞**: Task 2.2

---

### 3.4 Task 2.4: 组装 `autolab-eval` Skill

**输入**: runner + assembler + types  
**输出**: `src/skills/autolab/autolab_eval.zig`  
**功能**:
- 定义 `SKILL_ID = "autolab-eval"`
- 定义 `params`（4 个参数）
- 实现 `execute()` 函数
- 注册到 `src/skills/root.zig` 的 builtin skills 中

**验收标准**:
- [ ] `zig build test` 通过
- [ ] Skill 能被 `kimiz skill autolab-eval --task discover_sorting ...` 调用
- [ ] 调用结果与 Phase 1 的 Python 脚本等价

**工时**: 2 h  
**阻塞**: Task 2.3

---

## 4. Phase 3: 闭环优化

**目标**: 让 KimiZ Agent 能利用 `autolab-eval` 的反馈自动迭代。

### 4.1 Task 3.1: 设计 Orchestrator 反馈循环

**输入**: `AutoLabFeedback` 结构、现有 Agent 循环代码  
**输出**: Orchestrator 设计文档（嵌入 `docs/autolab-integration/`）  
**设计内容**:
1. 定义循环状态机：`GENERATE` → `EVALUATE` → `DECIDE` → `ACT` → (repeat)
2. 定义 `DECIDE` 逻辑：根据 `Status` 选择下一步 action
3. 定义最大迭代次数（如 10 次）
4. 定义终止条件：reward >= 0.8 或达到最大迭代次数

**验收标准**:
- [ ] 状态机图（文字版或 ASCII 图）写入文档
- [ ] DECIDE 逻辑表格化
- [ ] 与现有 `AgentLoop` 代码兼容

**工时**: 2 h  
**阻塞**: Phase 2 完成

---

### 4.2 Task 3.2: 实现 `autolab-orchestrator` Skill / 模块

**输入**: Orchestrator 设计文档  
**输出**: `src/skills/autolab/autolab_orchestrator.zig`（或集成到现有 orchestrator）  
**功能**:
- 接收初始 task_name 和 artifact
- 循环调用 `autolab-eval`
- 根据 feedback 调用对应子 skill（debug / optimize）
- 记录每次迭代的 feedback 历史
- 返回最终 best artifact 和迭代轨迹

**验收标准**:
- [ ] 能在 `discover_sorting` 上跑完 3-5 次迭代
- [ ] 编译错误时能触发 debug 分支
- [ ] 成功时能正确终止
- [ ] 历史记录可被读取和分析

**工时**: 4-6 h  
**阻塞**: Task 3.1

---

### 4.3 Task 3.3: 端到端闭环测试

**输入**: Orchestrator 模块、discover_sorting 任务  
**输出**: 闭环测试报告  
**测试场景**:
1. **场景 A**: 传入正确的初始代码，期望 1 次迭代后 success
2. **场景 B**: 传入有编译错误的代码，期望进入 debug 循环并修复
3. **场景 C**: 传入正确但性能差的代码，期望进入 optimize 循环并改进

**验收标准**:
- [ ] 场景 A 通过
- [ ] 场景 B 通过（或至少能识别并尝试修复）
- [ ] 场景 C 通过（或至少能识别性能差距）
- [ ] 测试报告记录每次迭代的 reward 变化

**工时**: 3-4 h  
**阻塞**: Task 3.2

---

## 5. Phase 4: 扩展与硬化

**目标**: 支持更多任务，提升鲁棒性，形成可维护的基准。

### 5.1 Task 4.1: 支持 3+ 个不同语言任务

**输入**: AutoLab 任务库  
**输出**: 扩展任务列表和兼容性报告  
**候选任务**:
1. `discover_sorting` (Python) — 已有
2. `aes128_ctr` (C) — 测试 C 编译链
3. `fft_rust` (Rust) — 测试 Rust 编译链
4. `bm25_search_go` (Go) — 测试 Go 编译链

**步骤**:
1. 对每个候选任务运行 `autolab-eval`
2. 记录 `task.toml` 解析是否成功
3. 记录 Docker 构建是否成功
4. 记录测试运行是否成功
5. 汇总兼容性矩阵

**验收标准**:
- [ ] 至少 3 个任务的 `task.toml` 能被正确解析
- [ ] 至少 3 个任务能成功构建 Docker 镜像
- [ ] 至少 3 个任务能运行测试并返回 feedback

**工时**: 3-4 h  
**阻塞**: Phase 3 完成

---

### 5.2 Task 4.2: 实现 AutoLab 回归测试套件

**输入**: 兼容的任务列表  
**输出**: `tests/autolab_integration_tests.zig`  
**测试内容**:
- TOML parser 测试（5+ 个不同结构的 task.toml）
- Docker runner mock 测试（不依赖真实 Docker）
- Feedback assembler 测试（覆盖所有 Status）
- 端到端 smoke 测试（可选，标记为 slow）

**验收标准**:
- [ ] `zig build test` 中新增测试全部通过
- [ ] 有 mock 避免 CI 环境无 Docker 时失败
- [ ] 慢测试可以用 `-Dskip-slow-tests` 跳过

**工时**: 3-4 h  
**阻塞**: Task 4.1

---

### 5.3 Task 4.3: 完善文档与使用指南

**输入**: 所有前述实现  
**输出**:  
- `docs/autolab-integration/06-implementation-log.md`
- `docs/autolab-integration/07-review-report.md`
- `docs/autolab-integration/USAGE.md`
- 更新 KimiZ 根 README 的相关章节

**验收标准**:
- [ ] 新用户能根据 USAGE.md 在 30 分钟内跑通第一个任务
- [ ] USAGE.md 包含常见问题排查
- [ ] Implementation Log 记录了所有关键决策和已知限制

**工时**: 2 h  
**阻塞**: Task 4.2

---

## 6. 任务依赖图

```
Phase 1 ──► Phase 2 ──► Phase 3 ──► Phase 4

1.1 clone   ─┐
1.2 env     ─┼──► 2.1 types ──► 2.2 runner ──► 2.3 assembler ──► 2.4 skill
1.3 script  ─┤                                                     │
1.4 e2e     ─┘                                                     ▼
                                                            3.1 design
                                                               │
                                                               ▼
                                                            3.2 orchestrator
                                                               │
                                                               ▼
                                                            3.3 e2e loop
                                                               │
                                                               ▼
                                                            4.1 multi-task
                                                               │
                                                               ▼
                                                            4.2 test suite
                                                               │
                                                               ▼
                                                            4.3 docs
```

---

## 7. 风险与应对

| 风险 | 影响 | 概率 | 应对策略 |
|------|------|------|----------|
| Docker 环境不可用 | Phase 1 阻塞 | 中 | 提供 Podman 替代方案；CI 用 mock |
| Harbor 安装失败 | Phase 1 阻塞 | 低 | Python 包装脚本阶段可跳过 Harbor，直接用 docker build |
| AutoLab task.toml 格式变更 | Phase 2 阻塞 | 低 | parser 只做最小化解析，遇到未知字段忽略 |
| GPU 任务无法测试 | Phase 4 延迟 | 高 | GPU 任务放到最后，先用 CPU-only 任务验证 |
| Agent 无法修复某些错误 | Phase 3 效果差 | 中 | 明确这是已知限制，记录到文档；不追求 100% 解决率 |

---

## 8. 资源需求

| 资源 | 数量 | 说明 |
|------|------|------|
| 开发机器 | 1台 | 有 Docker 的 macOS/Linux |
| CPU 时间 | ~10h | 用于运行 AutoLab 测试任务 |
| GPU 时间 | 可选 | 仅 Phase 4 的 GPU 任务需要 |
| 存储空间 | ~20GB | Docker 镜像 + AutoLab 环境 |

---

## 9. 下一步行动

1. **立即**: 审批本 Task Breakdown 和 Technical Spec
2. **今天**: 开始 Task 1.1（Clone AutoLab）
3. **本周**: 完成 Phase 1（MVP Integration）
4. **下周**: 完成 Phase 2（Zig Skill）并开始 Phase 3

---

**状态**: Ready for review  
**审批人**: (待用户确认)
