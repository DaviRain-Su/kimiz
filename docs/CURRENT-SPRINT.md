# Current Sprint: Sprint 2026-04

**Sprint 目标**: 让 KimiZ 在当前环境（Zig 0.15.2）下恢复可编译、可测试、可运行，并验证最近提交的子 Agent 功能。  
**详细看板**: `tasks/active/sprint-2026-04/README.md`

---

## 成功标准

1. `zig build` ✅ 编译成功
2. `zig build test` ✅ 所有测试通过
3. `zig build run -- repl` 可启动并对话 ✅
4. `delegate` subagent 工具验证通过 ✅
5. git worktree 隔离验证通过 ✅

---

## 任务看板

### P0 - 阻塞级

#### FIX-ZIG-015: 修复 Zig 0.15.2 编译兼容性
- **状态**: `cancelled`
- **说明**: 已确认项目目标版本为 Zig 0.16，此任务不再适用。之前为 0.15 做的兼容性修复已全部回滚。
- **影响文件**: `src/main.zig`, `src/http.zig`, `src/utils/io_manager.zig`, `src/cli/root.zig` 等

#### T-092-VERIFY: 验证 delegate subagent 注册
- **状态**: `todo`
- **Spec**: `docs/specs/T-092-verify-delegate-tool.md`
- **背景**: Commit `9a24161` 声称已完成注册，但编译阻塞导致无法验证
- **影响文件**: `src/agent/agent.zig`, `src/cli/root.zig`, `src/agent/subagent.zig`
- **验收**:
  - [ ] AI 可以在 REPL 中调用 `delegate` 工具
  - [ ] 子代理结果正确返回
  - [ ] 深度限制有效

#### T-119-VERIFY: 验证 git worktree 隔离
- **状态**: `todo`
- **Spec**: `docs/specs/T-119-verify-worktree.md` (待创建)
- **背景**: Commit `74c22ff` 实现了 worktree 隔离，但编译阻塞导致无法验证
- **影响文件**: `src/utils/worktree.zig`, `src/agent/subagent.zig`
- **验收**:
  - [ ] `WorktreeManager` 能正确创建/删除 worktree
  - [ ] Subagent 的文件操作默认发生在独立 worktree 中

### P1 - 高优先级

#### T-009-E2E: 补充端到端测试
- **状态**: `todo`
- **Spec**: `docs/specs/T-009-e2e-tests.md`
- **背景**: 项目目前测试覆盖率极低，需要至少覆盖核心路径
- **影响文件**: `tests/integration_tests.zig` 或新增 `tests/*.zig`
- **验收**:
  - [ ] Provider 解析测试（mock）
  - [ ] 工具调用测试（read_file, bash）
  - [ ] Agent Loop 基础测试
  - [ ] 所有测试通过

#### T-103-SPIKE: comptime Skill DSL 原型验证
- **状态**: `todo`
- **Spec**: `docs/specs/T-103-spike-comptime-skill-dsl.md`
- **背景**: KimiZ 核心差异化战略（ZIG-LLM-SELF-EVOLUTION-STRATEGY）的 Phase 3 起点。Scale / Metadata Programming 能力越早落地，后续所有开发都能自动加速。本任务是 go/no-go 的关键探针。
- **影响文件**: `src/skills/dsl.zig`, `src/skills/debug.zig` 或 `src/skills/refactor.zig`
- **验收**:
  - [ ] `defineSkill` comptime DSL 最小可行版本实现
  - [ ] 成功迁移 1 个现有 skill 并测试通过
  - [ ] 输出 Spike Report，决定 T-100/T-101 的架构方向

#### T-100: 建立 auto skill 自动生成流水线
- **状态**: `todo`
- **Spec**: `docs/specs/T-100-establish-auto-skill-generation-pipeline.md`
- **背景**: 让 LLM 能根据自然语言描述生成有效的 Zig skill 源码，是自我进化的第一步
- **影响文件**: `src/skills/auto/`, `scripts/generate-skill.zig`, `build.zig`
- **验收**:
  - [ ] `src/skills/auto/` 目录创建并纳入构建
  - [ ] LLM 成功生成第一个可编译的 auto skill
  - [ ] 编译失败时有结构化反馈机制

#### T-101: 设计 AutoRegistry 动态加载
- **状态**: `todo`
- **Spec**: `docs/specs/T-101-design-autoregistry-dynamic-loading.md`
- **背景**: 让 auto skill 无需修改 `builtin.zig` 即可被系统发现和调用
- **影响文件**: `src/skills/auto_registry.zig`, `src/skills/root.zig`, `build.zig`
- **验收**:
  - [ ] `AutoRegistry` 能在构建时自动发现 `src/skills/auto/` 下的 skill
  - [ ] 新增 auto skill 无需手动修改手写注册表
  - [ ] `zig build test` 全绿

#### T-120-DESIGN: 设计文档驱动的 Agent 工作流
- **状态**: `todo`
- **Spec**: `docs/specs/T-120-design-document-driven-loop.md`
- **背景**: 根据 yage.ai《从上下文失忆到文档驱动开发》，Agentic AI 在大型项目失效的根因是缺乏长期记忆。需要将文档驱动开发作为 KimiZ 的核心机制。
- **影响文件**: `docs/design/document-driven-agent-loop.md`（新增）
- **验收**:
  - [ ] 设计文档完成并通过 review
  - [ ] 明确 3 个新工具接口和 System Prompt 改造方案

#### T-121-IMPLEMENT: 实现 Agent 长期记忆工具
- **状态**: `todo`
- **Spec**: `docs/specs/T-121-implement-memory-tools.md`
- **背景**: 将 T-120 的设计落地为可执行工具
- **影响文件**: `src/agent/tools/document_tools.zig`, `src/agent/registry.zig`
- **验收**:
  - [ ] `read_active_task` 实现并测试通过
  - [ ] `update_task_log` 实现并测试通过
  - [ ] `sync_spec_with_code` 实现并测试通过

#### T-122-PROMPT: 改造 System Prompt 强制文档前置读取
- **状态**: `todo`
- **Spec**: `docs/specs/T-122-prompt-document-driven-loop.md`
- **背景**: 仅有工具不够，必须让 Agent 在每次行动前自动读取文档、行动后自动更新日志
- **影响文件**: `src/agent/agent.zig`, `src/cli/root.zig`
- **验收**:
  - [ ] System Prompt 注入 Document-Driven Protocol
  - [ ] REPL 支持 `/resync` 指令

#### T-123-LESSONS: 建立 lessons-learned 和多 Agent 一致性
- **状态**: `todo`
- **Spec**: `docs/specs/T-123-lessons-learned-and-consistency.md`
- **背景**: 长期记忆不仅是单 Agent 的笔记，也是 Multi-Agent 的共享通信渠道
- **影响文件**: `docs/lessons-learned.md`, `src/utils/document_lock.zig`, `src/agent/tools/lesson_tools.zig`
- **验收**:
  - [ ] `lessons-learned.md` 创建并包含初始记录
  - [ ] `DocumentLock` 通过并发测试
  - [ ] Agent 启动时自动读取最新 lessons

#### T-127: 将 zig-to-yul 集成为 KimiZ 的合约生成 skill
- **状态**: `todo`
- **Spec**: `docs/specs/T-127-integrate-zig-to-yul-as-contract-skill.md`
- **背景**: 创始人已有 `zig-to-yul` 编译器，可将 Zig 直接编译为 Yul → EVM Bytecode。T-103 验证 comptime DSL 可行后，下一个战略里程碑是将该编译器与 KimiZ Agent 整合，实现"需求 → Zig 合约 → 字节码 → 部署"的完整 Hardness Engineering 闭环。
- **影响文件**: `src/skills/contract.zig`, `src/skills/dsl.zig`, `tests/contract_skill_e2e.zig`
- **验收**:
  - [ ] Agent 能根据自然语言生成有效的 Zig 合约文件
  - [ ] `defineContract` comptime DSL 能验证至少 3 条安全规则
  - [ ] 自动调用 `zig-to-yul` 生成 EVM Bytecode
  - [ ] 通过 `forge test` 端到端验证

---

## 执行顺序

```
FIX-ZIG-015(cancelled) → T-092-VERIFY → T-119-VERIFY → T-009-E2E
→ T-103-SPIKE → (go/no-go decision)
    ├── go  → T-100 → T-101 → T-124-METRICS → T-127 (zig-to-yul integration)
    └── parallel → T-120-DESIGN → T-121-IMPLEMENT → T-122-PROMPT → T-123-LESSONS
```

---

## 已完成（归档在 `tasks/completed/`）

### Phase 0: 基础
- 项目结构、构建系统

### Phase 1: 核心 Agent
- Agent Loop、事件系统、5 Providers、7 工具、Skills 框架、RTK 优化

### Phase 2: 用户体验
- T-086 Session Persistence (`f7ee56a`)
- T-087 Shell Mode (`0edec45`)
- T-088 Plan Mode (`a371fc5`)
- T-095 YOLO Tool Approval (`0edec45`)
- MVP-GIT-TOOLS (`88c0af4`)

### Phase 3: 子 Agent（部分代码已提交）
- T-092 delegate 注册 (`9a24161`)
- T-119 git worktree 隔离 (`74c22ff`)

---

## 归档说明

本 Sprint 完成后，下一个 Sprint 的目标将从 `backlog/phase-3-subagent/` 中取任务：
- Named Sub-agents（YAML 角色配置）
- Coordinator Mode MVP
- 安全分类器
- 工具调用摘要机制

**这些任务目前不在 Sprint 范围内，不要提前做。**

**最后更新**: 2026-04-06
