# Phase 5: Test Spec — AutoLab Critic Integration

**项目**: KimiZ  
**模块**: AutoLab External Evaluator  
**版本**: 1.0.0  
**日期**: 2026-04-05  
**任务 ID**: TASK-FEATURE-AUTOLAB-001  

---

## 1. 测试策略总览

### 1.1 测试层级

| 层级 | 类型 | 数量目标 | 依赖 |
|------|------|----------|------|
| L1 | 单元测试 (Unit) | 15+ | 无外部依赖，纯 Zig stdlib |
| L2 | 集成测试 (Integration) | 6+ | 需要真实 AutoLab `tasks/` 目录 |
| L3 | 端到端测试 (E2E) | 3 | 需要 Docker daemon |
| L4 | 回归测试 (Regression) | 2 | 需要兼容的任务列表 |

### 1.2 测试原则

1. **Mock 优先**：Docker runner 的单元测试使用 mock 进程，避免 CI 失败
2. ** fixture 驱动**：TOML/JSON 测试数据放在 `tests/fixtures/autolab/` 下
3. **确定性**：每个测试有明确的输入和期望输出，不依赖随机性
4. **分层隔离**：L1 测试在任何环境都能跑，L3 只在有 Docker 时跑

---

## 2. L1 单元测试

### 2.1 TaskTomlParser Tests

**文件**: `src/skills/autolab/autolab_types.zig` 内嵌 `test` 块  
**fixture 目录**: `tests/fixtures/autolab/toml/`  

#### TEST-TOML-001: 解析 discover_sorting task.toml

**输入**: `tests/fixtures/autolab/toml/discover_sorting.toml`（复制自 AutoLab）  
**断言**:
- `task.version == "1.0"`
- `task.metadata.difficulty == "hard"`
- `task.agent.timeout_sec == 7200`
- `task.environment.cpus == 2`
- `task.environment.memory_mb == 2048`
- `task.environment.gpus == 0`
- `task.optimization.metric == "comparator_count"`
- `task.optimization.direction == .lower`
- `task.optimization.baseline.score == 80.0`
- `task.optimization.reference.score == 60.0`

#### TEST-TOML-002: 解析缺失可选字段

**输入**: 一个最小化 TOML（只有 `version` 和 `[metadata]`）  
**断言**:
- 解析不 panic
- 缺失的数值字段有合理的默认值（0 / false / empty string）

#### TEST-TOML-003: 解析 direction 枚举

**输入**: `direction = "higher"` 和 `direction = "lower"`  
**断言**:
- 分别映射到正确的 enum 变体
- 遇到非法值时返回可预期的错误

---

### 2.2 RewardJsonParser Tests

**文件**: `src/skills/autolab/autolab_types.zig` 内嵌 `test` 块  
**fixture 目录**: `tests/fixtures/autolab/json/`  

#### TEST-JSON-001: 解析标准 reward.json

**输入**:
```json
{
  "reward": 0.75,
  "raw_score": 65.0,
  "baseline_score": 80.0,
  "reference_score": 60.0,
  "correctness": true
}
```

**断言**:
- `feedback.reward == 0.75`
- `feedback.raw_score == 65.0`
- `feedback.success == true`

#### TEST-JSON-002: 解析 correctness_fail 的 reward.json

**输入**:
```json
{
  "reward": 0.0,
  "raw_score": 999.0,
  "correctness": false
}
```

**断言**:
- `feedback.reward == 0.0`
- `feedback.success == false`

#### TEST-JSON-003: 处理缺失字段

**输入**: `{}`  
**断言**:
- 返回错误（reward.json 必须包含 `reward`）

---

### 2.3 FeedbackAssembler Tests

**文件**: `src/skills/autolab/feedback_assembler.zig` 内嵌 `test` 块  

#### TEST-ASM-001: 从编译错误日志推断 compile_error

**输入**:
- docker exit code: 1
- stdout: `"error: use of undeclared identifier 'x'"`

**断言**:
- `status == .compile_error`
- `success == false`

#### TEST-ASM-002: 从 panic 日志推断 runtime_error

**输入**:
- docker exit code: 134
- stdout: `"thread panicked at 'index out of bounds'"`

**断言**:
- `status == .runtime_error`
- `success == false`

#### TEST-ASM-003: 从正确性测试失败推断 correctness_fail

**输入**:
- docker exit code: 0
- reward.json: `{ "correctness": false, "reward": 0.0 }`

**断言**:
- `status == .correctness_fail`
- `success == false`

#### TEST-ASM-004: 从成功结果推断 success

**输入**:
- docker exit code: 0
- reward.json: `{ "correctness": true, "reward": 0.85 }`

**断言**:
- `status == .success`
- `success == true`
- `reward == 0.85`

#### TEST-ASM-005: 从 kill 信号推断 timeout

**输入**:
- docker exit code: 137 (SIGKILL)
- stdout: `"Killed"`

**断言**:
- `status == .timeout`
- `success == false`

#### TEST-ASM-006: 格式化输出包含 P0/P1 标签

**输入**: `AutoLabFeedback{ .status = .compile_error, .reward = 0.0 }`  
**断言**:
- 格式化字符串中包含 `"[P0]"`
- 包含 `"Compile Error"`

---

### 2.4 DockerRunner Mock Tests

**文件**: `src/skills/autolab/autolab_runner.zig` 内嵌 `test` 块  

#### TEST-RUN-001: Build 命令生成正确

**输入**: task_name="discover_sorting", env_dir="/tmp/env"  
**断言**:
- 生成的命令字符串包含 `"docker build -t autolab:discover_sorting /tmp/env"`

#### TEST-RUN-002: Run 命令包含资源限制

**输入**: task with cpus=2, memory_mb=2048, allow_internet=false  
**断言**:
- 生成的命令包含 `"--cpus=2"`
- 生成的命令包含 `"--memory=2048m"`
- 生成的命令包含 `"--network none"`

#### TEST-RUN-003: Run 命令包含挂载点

**输入**: artifact="/agent/solve.py", target="/app/solve.py"  
**断言**:
- 生成的命令包含 `"-v /agent/solve.py:/app/solve.py:ro"`

---

## 3. L2 集成测试

### 3.1 AutoLab 文件系统交互

**文件**: `tests/autolab_fs_integration.zig`  
**依赖**: `third_party/autolab/` 已克隆  

#### TEST-FS-001: 发现所有任务目录

**输入**: `third_party/autolab/tasks/`  
**断言**:
- 至少能发现 20 个任务目录
- 每个目录包含 `task.toml`

#### TEST-FS-002: 批量解析 task.toml

**输入**: 前 5 个任务的 `task.toml`  
**断言**:
- 5 个都能成功解析（不 panic）
- 每个解析结果包含非空的 `metric` 和 `direction`

#### TEST-FS-003: 读取 instruction.md

**输入**: `discover_sorting/instruction.md`  
**断言**:
- 文件内容非空
- 包含字符串 `"sorting network"`

---

## 4. L3 端到端测试

### 4.1 E2E with Docker

**文件**: `tests/autolab_e2e.zig`  
**依赖**: Docker daemon 可用  
**标记**: `slow`（可用 `-Dskip-slow-tests` 跳过）  

#### TEST-E2E-001: discover_sorting 原始代码能跑出 reward

**前置条件**:
- Docker daemon 运行中
- `autolab:discover_sorting` 镜像未构建或已构建

**步骤**:
1. 复制原始 `solve.py` 到临时目录
2. 调用 `autolab-eval` skill（或通过 runner 直接运行）
3. 等待执行完成

**断言**:
- `feedback.status == .success` 或 `.correctness_fail`
- `feedback.reward` 是有限数值
- `feedback.logs.len > 0`
- 执行时间 `elapsed_sec > 0`

#### TEST-E2E-002: 编译错误被正确识别

**前置条件**: 同上  
**步骤**:
1. 修改 `solve.py`，在函数开头加入非法语法 `!!!`
2. 运行评估

**断言**:
- `feedback.status == .compile_error`
- `feedback.logs` 包含 `"SyntaxError"` 或 `"error:"`
- `feedback.reward == 0.0`

#### TEST-E2E-003: 超时机制有效

**前置条件**: 同上  
**步骤**:
1. 修改 `solve.py` 加入死循环（如 `while True: pass`）
2. 用 `timeout_override=5` 运行评估

**断言**:
- `feedback.status == .timeout`
- 总耗时不超过 10 秒

---

## 5. L4 回归测试

### 5.1 多任务 Smoke Test

**文件**: `tests/autolab_regression.zig`  
**依赖**: Docker + 3+ 个任务  
**标记**: `slow`  

#### TEST-REG-001: 多任务构建测试

**输入**: `["discover_sorting", "aes128_ctr", "fft_rust"]`  
**步骤**:
1. 对每个任务构建 Docker 镜像
2. 运行 `tests/test.sh`（使用原始代码）

**断言**:
- 3 个镜像都构建成功
- 每个任务都返回有效的 `AutoLabFeedback`

---

## 6. CI / CD 测试策略

### 6.1 本地开发
- 运行全部测试：`zig build test`
- 跳过慢测试：`zig build test -Dskip-slow-tests`
- 只运行单元测试：`zig build test --test-filter "TEST-TOML|TEST-JSON|TEST-ASM|TEST-RUN"`

### 6.2 CI 环境（无 Docker）
- 只运行 L1 单元测试
- L2 测试使用 mock fixture，不依赖真实 AutoLab 仓库（ fixture 随仓库提交）
- L3/L4 标记为 `skip` 或 `allow_failure`

### 6.3 CI 环境（有 Docker）
- 运行全部测试
- 定期（如 nightly）运行 L4 回归测试

---

## 7. Fixture 清单

```
tests/fixtures/autolab/
├── toml/
│   ├── discover_sorting.toml
│   ├── aes128_ctr.toml
│   └── minimal.toml
├── json/
│   ├── reward_success.json
│   ├── reward_fail.json
│   └── reward_malformed.json
└── logs/
    ├── compile_error.log
    ├── runtime_error.log
    ├── correctness_fail.log
    ├── success.log
    └── timeout.log
```

---

## 8. 测试覆盖率目标

| 模块 | 目标覆盖率 | 说明 |
|------|------------|------|
| `autolab_types.zig` (parser) | 90%+ | 核心解析逻辑必须高覆盖 |
| `feedback_assembler.zig` | 85%+ | 状态推断分支多，需充分覆盖 |
| `autolab_runner.zig` | 60%+ | Docker CLI 生成可 mock 测试，真实运行走 E2E |
| `autolab_eval.zig` (skill) | 70%+ | execute 路径部分依赖外部进程 |

---

## 9. 测试工具与辅助函数

### 9.1 共享测试辅助函数

放在 `tests/helpers/autolab_test_utils.zig`：

```zig
pub fn loadFixture(allocator: Allocator, subpath: []const u8) ![]u8;
pub fn createTempArtifact(allocator: Allocator, content: []const u8) ![]u8;
pub fn assertStatus(feedback: AutoLabFeedback, expected: Status) !void;
pub fn skipIfNoDocker() !void;
```

### 9.2 Docker 可用性检查

```zig
fn skipIfNoDocker() !void {
    const result = try std.process.Child.run(.{
        .allocator = std.testing.allocator,
        .argv = &.{"docker", "info"},
    });
    if (result.term.Exited != 0) {
        return error.SkipZigTest;
    }
}
```

---

## 10. 验收标准汇总

- [ ] L1: 15+ 单元测试全部通过
- [ ] L2: 3+ 集成测试全部通过
- [ ] L3: 3 个 E2E 测试在有 Docker 时全部通过
- [ ] L4: 1 个回归测试在有 Docker 时通过
- [ ] Fixture 文件完整且版本化
- [ ] CI 策略文档化（本地 / 无 Docker / 有 Docker）
- [ ] 测试辅助函数库可用

---

**状态**: Ready for implementation  
**下一步**: 开始 Phase 6 Implementation (Task 1.1)
