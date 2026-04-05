# Sub-agent 四阶段落地路线图

**文档版本**: 1.0  
**日期**: 2026-04-05  
**状态**: active  

---

## 目标

把 KimiZ 的 sub-agent 从一个"已写好的死代码模块"变成真正可用、可扩展、可隔离的生产级能力。

分层递进：先让功能能用，再逐步加隔离层，最终形成与 kimi-cli `Agent` 工具等价甚至在隔离性上超越的方案。

---

## 架构大图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           KimiZ Sub-agent Stack                             │
├─────────────────────────────────────────────────────────────────────────────┤
│  Layer 4: Orchestration    │  内置 delegate 工具 → named sub-agents YAML   │
│  Layer 3: File Isolation   │  git worktree (每个子代理独立工作区)           │
│  Layer 2: Env Isolation    │  Nix shell (依赖可复现、行为一致)              │
│  Layer 1: Runtime Isolation│  OS namespace / WASM / seccomp (安全沙箱)      │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Stage 1: 内置 delegate 工具 MVP

**状态**: 准备就绪，可立即执行  
**预计耗时**: 2-4h  
**对应backlog任务**: T-092 (enable-subagent-tool)  

### 目标
让主 Agent 能识别并执行 `delegate` tool call。这是让 sub-agent"跑起来"的最后一环。

### 为什么先做这个
- KimiZ 的 `src/agent/subagent.zig` 已经有 90% 的实现
- 与 kimi-cli 官方架构一致（`Agent` 工具 = 我们的 `delegate`）
- 不需要任何系统级依赖，macOS/Linux/Windows 都能跑
- sub-agent 在主进程同一个线程里同步执行，启动成本为零

### 具体工作
1. 修改 `src/cli/root.zig`
   - 在 `runInteractive()` 中 `ai_agent` 初始化后，创建 `subagent.DelegateContext`
   - 把 `subagent.createAgentTool(&delegate_ctx)` 加入 REPL 的 tools 数组
2. 修改 `src/agent/agent.zig`
   - 确保 `Agent` struct 的 `subagent_delegate_ctx` 生命周期不会悬空
   - 如有必要，微调 event callback 兼容性
3. 验证
   - 在 REPL 中让 AI 使用 `delegate` 工具执行子任务
   - 测试递归深度限制（当 depth > 3 时应返回错误）
   - 测试 read-only 模式（只读模式下不能调用 write_file）
4. 更新文档
   - `docs/design/SUBAGENT-ARCHITECTURE-AND-IMPLEMENTATION-PLAN.md`

### 验收标准
- [x] `delegate` 工具出现在主 Agent 的可用工具列表中
- [x] AI 可以通过 `delegate` 调用子代理完成任务
- [x] 子代理结果正确返回到父代理上下文
- [x] 递归深度超出限制时返回错误（不崩溃）
- [x] `zig build test` 通过

---

## Stage 2: git worktree 隔离

**状态**: 设计完成，待开发  
**预计耗时**: 12h  
**对应backlog任务**: T-119 (integrate-git-worktree-for-subagent-isolation)  

### 目标
当子代理/后台任务需要执行文件操作时，不再与主 agent 共享同一个 git working tree，而是运行在独立的 git worktree 中，避免文件冲突。

### 为什么在此阶段引入
- 这是性价比最高的"物理隔离"
- macOS 和 Linux 都原生支持 `git worktree`
- 不需要 root、不需要 Docker、不需要 namespace
- 直接解决"多个 agent 同时改同一个文件"的问题（Swarm 验证过的模式）

### 具体工作
1. 实现 `WorktreeManager`
   - `create(repo_path, branch_or_name)` → 返回 worktree 路径
   - `list(repo_path)` → 列出该 repo 下所有 worktree
   - `remove(worktree_path)` → 清理 worktree
2. 在 REPL/subagent 启动时
   - 如果当前目录是 git repo，自动为 subagent 创建临时 worktree
   - worktree 基于 bare clone 缓存或当前 repo 直接创建（根据配置）
3. 将 worktree 路径注入 subagent 的上下文
   - subagent 的所有文件操作工具默认使用该 worktree 作为 CWD
4. subagent 结束后
   - 默认清理 worktree（可配置保留）
   - 如果子代理生成了有效改动，可以通过 `git diff` 提取 patch 后应用到主分支

### 验收标准
- [ ] `WorktreeManager` 能正确创建/删除 worktree
- [ ] Subagent 的文件操作默认发生在独立 worktree 中
- [ ] 多个 subagent 同时运行不会互相覆盖文件
- [ ] Subagent 退出后 worktree 能被正常清理
- [ ] 集成测试通过

### 依赖
- Stage 1 完成（delegate 工具可用）

---

## Stage 3: Nix 环境隔离

**状态**: backlog，依赖 T-115  
**预计耗时**: 14h  
**对应backlog任务**: T-115 (integrate-nix-into-auto-skill-pipeline)  

### 目标
为 sub-agent / auto-skill / 后台任务提供可复现的运行环境。不是安全沙箱，而是"环境锁定"，确保"在我机器上能跑"的问题不会出现。

### 为什么在此阶段引入
- 当 sub-agent 需要执行编译、构建、测试时，环境一致性至关重要
- Nix 能精确锁定 zig 版本、系统库、第三方工具链
- 这是 Hardness Engineer "免疫系统" 的核心组成部分

### 具体工作
1. 为 KimiZ 项目建立 `flake.nix`
   - 锁定 zig 版本、libcurl、openssl 等依赖
2. 扩展 `SubAgentConfig`
   - 增加可选字段 `nix_shell: ?[]const u8`（指向 nix 描述的路径）
3. 在启动 sub-agent 前
   - 如果指定了 nix 环境，先进入 `nix develop` / `nix-shell` 再执行 agent loop
   - 或者通过 `nix run` 启动子进程（如果 Stage 4 已经部分实现）
4. 文档化
   - 开发者如何在 Nix 环境下运行 KimiZ
   - auto skill 如何自动生成 `shell.nix`

### 验收标准
- [ ] KimiZ 项目有 `flake.nix`，新开发者 `nix develop` 即可入环境
- [ ] Sub-agent 可以在指定的 nix 环境中运行
- [ ] auto skill 编译前自动进入 nix shell
- [ ] 与现有任务（T-100 ~ T-111）兼容

### 依赖
- Stage 2 完成（文件系统隔离稳定）

---

## Stage 4: Linux 进程级安全沙箱

**状态**: 远期 backlog  
**预计耗时**: 24h+  
**对应backlog任务**: T-117 (WASM WASI sandbox) + T-118 (OS-level namespace isolation)  

### 目标
为高风险 sub-agent / auto-skill 提供真正的安全边界，即使 agent 的代码生成带有恶意意图，也能被限制在最小权限范围内。

### 为什么放在最后
- macOS 下几乎没有轻量级沙箱方案（`sandbox-exec` 已废弃，bubblewrap 不支持）
- 这一层需要 Linux 专属技术（namespaces, seccomp-bpf, cgroup）
- 对 MVP 价值不大，但在 auto-skill 自动化程度越来越高时是安全刚需

### 方案对比

| 方案 | 隔离级别 | 跨平台 | 复杂度 | 适用场景 |
|------|----------|--------|--------|----------|
| **WASM/WASI** | Capability-based | 理论跨平台 | 中等 | 纯计算、无重型 IO 的 skill |
| **Linux namespaces + bubblewrap** | OS 进程级 | Linux only | 中高 | 通用 sub-agent，需要完整 shell |
| **systemd-nspawn / Docker** | 容器级 | Linux only | 高 | 最高风险场景，但太重 |

### 推荐策略
- **WASM**：用于`纯 Zig` auto skill（编译成 wasm32-wasi，通过 manifest 声明 cap）
- **bubblewrap**：用于需要 shell 的一般 sub-agent（Linux VM / CI 环境）
- **macOS 降级**：在 macOS 上回退到 Stage 2+3（worktree + nix），沙箱通过 Docker/Lima 可选支持

### 具体工作
1. T-117: WASM/WASI 原型
   - 调研 Zig 友好的 WASM runtime（wasmtime / wasmer / wazero）
   - 把一个简单 auto skill 编译为 `.wasm`
   - 实现 capability manifest 注入
2. T-118: OS namespace 隔离
   - 在 Linux 下 fork 隔离进程
   - 限制 FS 视图（只暴露 workspace）
   - seccomp-bpf 过滤 syscall
3. 跨平台抽象层
   - 定义 `SandboxProvider` 接口
   - macOS 用 noop/limited 实现，Linux 用 full 实现

### 验收标准
- [ ] WASM skill 无法访问未授权的文件
- [ ] Linux 下 bubblewrap 子进程无法突破 worktree 边界
- [ ] 沙箱崩溃/异常不影响主进程
- [ ] 有明确的 fallback 策略（macOS 降级到 worktree+nix）

### 依赖
- Stage 3 完成（环境稳定后再加沙箱）

---

## 任务状态总览

| Stage | 任务编号 | 任务名 | 状态 | 预计工时 |
|-------|----------|--------|------|----------|
| 1 | T-092 | Enable subagent tool | active | 2-4h |
| 2 | T-119 | git worktree 隔离 | pending | 12h |
| 3 | T-115 | Nix 集成 | pending | 14h |
| 4 | T-117/T-118 | WASM / OS namespace 沙箱 | pending | 24h+ |

---

## 决策建议

### 如果你现在有时间（比如接下来 1-2 小时）
**执行 Stage 1**。这是唯一一个"今天就能让它跑起来"的任务。

### 如果你接下来有半天的块时间
**执行 Stage 1 + Stage 2 设计**。先让 delegate 能工作，再设计 worktree manager 的 API。

### 如果你要规划季度 roadmap
- Q1: Stage 1 + 2（功能可用 + 文件系统隔离）
- Q2: Stage 3（Nix 环境锁定，服务 auto skill 可复现性）
- Q3-Q4: Stage 4（Linux 沙箱，Hardness 最终形态）

---

## 相关文档与源码

- `src/agent/subagent.zig` — SubAgent 核心实现
- `src/agent/agent.zig` — Agent loop，delegate 注册点
- `src/cli/root.zig` — REPL 生命周期，tools 数组
- `docs/design/SUBAGENT-ARCHITECTURE-AND-IMPLEMENTATION-PLAN.md` — 架构分析
- `docs/SWARM-PENBERG-ANALYSIS.md` — git worktree 隔离参考
- `tasks/backlog/feature/T-092-enable-subagent-tool.md`
- `tasks/backlog/feature/T-119-integrate-git-worktree-for-subagent-isolation.md`
- `tasks/backlog/feature/T-115-integrate-nix-into-auto-skill-pipeline.md`
- `tasks/backlog/feature/T-117-wasm-wasi-sandbox-prototype.md`
- `tasks/backlog/feature/T-118-os-level-namespace-isolation.md`
