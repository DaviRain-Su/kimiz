# KimiZ 任务拆解 — 基于 OpenCLI / Pay-as-you-go / Claude Code 架构分析

**拆解日期**: 2026-04-05  
**前置分析文档**:
- `docs/OPENCLI-ANALYSIS.md`
- `docs/PAY-AS-YOU-GO-AI-ANALYSIS.md`
- `docs/CLAUDE-CODE-PROMPT-ANALYSIS.md`

---

## 执行优先级总览

```
P0 (立即做): Claude Code 架构优化 — 直接影响 KimiZ 核心体验和输出质量
P1 (近期做): OpenCLI Skill 集成 — 低成本快速扩展 79+ 网站适配能力
P2 (中期做): Pay-as-you-go 付费系统 — 商业化方向，但需要更多前期调研
```

---

## P0: Claude Code Prompt 架构升级

**战略价值**: 这是三个方向中对 KimiZ 核心体验提升最大的。Claude Code 的 prompt 架构代表了当前工业级 Agentic Coding Assistant 的最高水平。

**目标**: 把验证过的模式逐步引入 KimiZ 的 system prompt 和 orchestration 层。

### P0-1: System Prompt 代码规范优化
**任务 ID**: `cc-1`  
**状态**: 待开始  
**预估工时**: 2-4 小时  
**所需技能**: Prompt Engineering

**具体内容**:
- 从 `CLAUDE-CODE-PROMPT-ANALYSIS.md` 中提取 "Doing tasks" 章节的核心规则
- 整合进 KimiZ 的 system prompt（`PERSONA.md` 或对应的 prompt 注入点）
- 关键规则包括：
  - "Don't add features beyond what was asked"
  - "Avoid premature abstraction — three similar lines is better than a helper"
  - "Report outcomes faithfully: if tests fail, say so"
  - "Never claim 'all tests pass' when output shows failures"
  - "Verify it actually works before reporting complete"

**验收标准**:
- [ ] 新 system prompt 文本写入对应配置文件
- [ ] 选取 3-5 个历史 bad case（过度工程、隐瞒测试失败、 premature abstraction）进行回测
- [ ] 回测结果显示改进明显

**依赖**: 无

---

### P0-2: delegate_task 预设角色模板
**任务 ID**: `cc-2`  
**状态**: 待开始  
**预估工时**: 1-2 天  
**所需技能**: Zig / TypeScript（取决于 delegate_task 的实现语言）, Prompt Engineering

**具体内容**:
为 `delegate_task` 设计 3 个预设角色，每个角色有专门的 system prompt 注入：

1. **researcher**: 只读、深入、不修改任何文件
2. **implementer**: 专注实现和修改，必须有明确 spec 才开工
3. **verifier**: 对抗性验证，必须运行测试/类型检查，不能 rubber-stamp

**验收标准**:
- [ ] `delegate_task` 调用支持 `persona` 参数（如 `"researcher"`, `"implementer"`, `"verifier"`）
- [ ] 每个 persona 有独立的 system prompt prefix
- [ ] verifier persona 的输出必须包含："Tests run: yes/no", "Type check: yes/no", "Verdict: pass/fail"

**依赖**: 无

---

### P0-3: 结构化子 Agent 返回格式
**任务 ID**: `cc-3`  
**状态**: 待开始  
**预估工时**: 1 天  
**所需技能**: 后端开发

**具体内容**:
当前 `delegate_task` 的结果是纯文本摘要塞回主上下文。参考 Claude Code 的 `<task-notification>`，改为结构化格式：

```json
{
  "task_id": "agent-1",
  "status": "completed",
  "summary": "Found the auth bug in src/auth/validate.ts:42",
  "result": "...",
  "usage": {
    "total_tokens": 15000,
    "tool_uses": 12,
    "duration_ms": 45000
  }
}
```

**验收标准**:
- [ ] `delegate_task` 返回格式统一为上述 JSON Schema
- [ ] 主 Agent 解析 JSON 后能准确提取 `summary` 和 `result`
- [ ] 失败任务有明确的 `error` 字段和原因

**依赖**: 无（可与 P0-2 并行）

---

### P0-4: Coordinator Mode MVP 技术 Spec
**任务 ID**: `cc-4`  
**状态**: 待开始  
**预估工时**: 2-3 天（设计）+ 3-5 天（实现）  
**所需技能**: 架构设计, LLM Orchestration, Zig/Node.js

**具体内容**:
设计一个可选的 Coordinator Mode。当任务复杂度超过阈值时，主 Agent 切换为 Coordinator 角色，执行四阶段工作流：

```
Phase 1: Research（并行 researcher workers）
Phase 2: Synthesis（Coordinator 自己完成）
Phase 3: Implementation（implementer worker）
Phase 4: Verification（verifier worker）
```

**复杂度判定启发规则**:
- 涉及 3+ 个文件的修改
- 用户请求包含 "重构"、"重新设计"、"添加新模块"
- 需要跨代码库搜索和理解

**验收标准**:
- [ ] 输出 `docs/COORDINATOR-MODE-SPEC.md`
- [ ] 定义复杂度判定算法
- [ ] 定义每个 Phase 的输入输出和角色分工
- [ ] 包含一个端到端的流程图和示例

**依赖**: P0-2, P0-3 完成后才能进入实现阶段

---

### P0-5: 轻量级安全分类器
**任务 ID**: `cc-5`  
**状态**: 待开始  
**预估工时**: 2-3 天  
**所需技能**: LLM Engineering, 安全设计

**具体内容**:
对于高危操作（`terminal(background=true)`、`write_file` 覆写配置文件、敏感路径操作等），在真正执行前增加一次轻量级分类器调用。

分类器设计：
- 只接收 **tool_use 意图**（排除 assistant 自然语言文本，防止 prompt injection）
- 强制 JSON 输出：`{ "thinking": "...", "should_block": true/false, "reason": "..." }`
- 用户可在 `~/.hermes/config.yaml` 中配置 `allow_rules` 和 `deny_rules`

**验收标准**:
- [ ] 定义高危操作列表
- [ ] 分类器 JSON schema 设计完成
- [ ] 集成到 tool 执行 pipeline 中（block 时向用户解释原因）
- [ ] 3 个安全场景测试通过（恶意命令、敏感文件覆写、可疑网络请求）

**依赖**: 无

---

### P0-6: 工具调用摘要机制
**任务 ID**: `cc-6`  
**状态**: 待开始  
**预估工时**: 1-2 天  
**所需技能**: 后端开发, Prompt Engineering

**具体内容**:
当主 Agent 在一次 assistant message 中连续调用 3+ 个工具后，在下一次回复前自动触发一次摘要：把这 3+ 个工具的结果总结成 1-2 句话，替换原来冗长的工具结果上下文。

**验收标准**:
- [ ] 连续工具调用检测逻辑
- [ ] 摘要生成 prompt 设计
- [ ] 上下文替换机制（不丢失关键信息）
- [ ] 长会话测试：上下文增长曲线明显变缓

**依赖**: 无

---

## P1: OpenCLI Skill 集成

**战略价值**: 低成本、高杠杆。让 KimiZ 瞬间获得 79+ 网站的 CLI 适配能力和本地 Chrome 登录态复用。

### P1-1: opencli Zig skill 设计
**任务 ID**: `opencli-1`  
**状态**: 待开始  
**预估工时**: 1 天  
**所需技能**: Zig, Skill 系统设计

**具体内容**:
设计 `opencli` skill 的参数和返回结构：

```zig
pub const SKILL_ID = "opencli";
pub const params = &[_]SkillParam{
    .{ .name = "site_command", .param_type = .string, .required = true },
    .{ .name = "args", .param_type = .string, .required = false },
    .{ .name = "format", .param_type = .string, .default_value = "json" },
};
```

**验收标准**:
- [ ] 参数设计文档
- [ ] 返回格式定义（JSON / Table / Raw）
- [ ] 错误处理策略（opencli 未安装时的 fallback）

**依赖**: 无

---

### P1-2: opencli skill 核心实现
**任务 ID**: `opencli-2`  
**状态**: 待开始  
**预估工时**: 2-3 天  
**所需技能**: Zig, 外部进程调用

**具体内容**:
- 检测 `opencli` 是否安装（`which opencli`）
- 未安装时提示用户 `npm install -g @jackwener/opencli`
- 构建并执行命令：`opencli {site_command} {args} --format {format}`
- 解析 JSON 输出并返回

**验收标准**:
- [ ] `terminal("which opencli")` 检测逻辑
- [ ] 命令构建和解析逻辑
- [ ] JSON parse 失败时的 raw output fallback

**依赖**: P1-1

---

### P1-3: opencli skill 测试验证
**任务 ID**: `opencli-3`  
**状态**: 待开始  
**预估工时**: 半天  
**所需技能**: 手动测试

**具体内容**:
用实际场景测试 opencli skill：
- `opencli hackernews/top --limit 10`
- `opencli bilibili/hot --limit 5`（测试本地 Chrome 登录态复用）
- `opencli twitter trending --limit 10`

**验收标准**:
- [ ] 3 个 adapter 调用测试通过
- [ ] bilibili 场景验证是否成功复用登录态
- [ ] 文档记录测试结果和已知限制

**依赖**: P1-2

---

## P2: Pay-as-you-go AI 付费系统

**战略价值**: 商业模式差异化。但涉及合规、支付网关、智能合约，周期较长。

### P2-1: 余额策略引擎设计
**任务 ID**: `paygo-1`  
**状态**: 待开始  
**预估工时**: 1-2 天  
**所需技能**: 后端架构, 安全设计

**具体内容**:
设计轻量级的 "pre-spending policy engine"，在用户每次调用 AI 前执行：

```json
{
  "user_id": "u_123",
  "rules": [
    { "type": "balance_positive", "min_balance": "0.10" },
    { "type": "daily_spend_cap", "max_usd": "10.00" },
    { "type": "single_request_cap", "max_usd": "0.50" },
    { "type": "model_allowlist", "models": ["gpt-4o", "claude-3-haiku"] }
  ],
  "action": "deny"
}
```

**验收标准**:
- [ ] Policy JSON Schema 定义
- [ ] `evaluate_policy(policy, context)` 伪代码/实现
- [ ] 与 AI 调用 pipeline 的集成点设计

**依赖**: 无

---

### P2-2: 充值入口架构设计
**任务 ID**: `paygo-2`  
**状态**: 待开始  
**预估工时**: 2-3 天  
**所需技能**: 支付产品, 合规基础

**具体内容**:
设计 "法币为主 + crypto 为辅" 的混合充值架构：

```
用户登录
  ├── Stripe / 支付宝 / 微信（主入口，法币 → USD 余额）
  ├── MoonPay / Coinbase Commerce（crypto 新手入口）
  └── Temple Wallet / MetaMask（资深 Web3 用户入口）
```

**验收标准**:
- [ ] 各充值入口的 UX 流程图
- [ ] 到账确认机制（webhook / 链上事件监听）
- [ ] 汇率处理策略（crypto → USD 余额的实时折算）
- [ ] 合规风险评估初稿

**依赖**: 无

---

### P2-3: Tezos 智能合约方案评估
**任务 ID**: `paygo-3`  
**状态**: 待开始  
**预估工时**: 2-3 天  
**所需技能**: Smart Contract, Tezos

**具体内容**:
- 评估 Tezos 上 USDC/wrapped stablecoin 的可用性
- 设计存款/提现合约的初步逻辑
- 评估 gas 费和最低充值金额
- 输出是否建议用 Tezos 的结论

**验收标准**:
- [ ] Tezos 生态稳定币调研报告
- [ ] 存款合约伪代码
- [ ] 明确建议：继续用 Tezos vs 切换到 EVM 链

**依赖**: 无（可与 P2-2 并行）

---

## 依赖关系图

```
P0 系列（核心优化，互相依赖较少）:
cc-1  ─────────────────────────────────────┐
cc-2  ──┐                                    │
cc-3  ──┼──→ cc-4 (Coordinator Mode)        │
cc-5  ──┤                                    │
cc-6  ──┘                                    │
                                             │
P1 系列（OpenCLI，线性依赖）:                │
opencli-1 → opencli-2 → opencli-3          │
                                             │
P2 系列（付费系统，可并行）:                 │
paygo-1                                   │
paygo-2 ──┬──→ [后续: 完整付费系统实现]     │
paygo-3 ──┘                                │
```

**推荐执行顺序**:
1. **Week 1**: P0-1 (system prompt 优化) → 立即见效
2. **Week 1-2**: P0-2 + P0-3 (delegate_task 角色 + 结构化返回) → 并行
3. **Week 2**: P0-5 (安全分类器) → 提升安全感
4. **Week 2-3**: P0-6 (工具摘要) → 并行
5. **Week 3-4**: P0-4 (Coordinator Mode spec) → 依赖 P0-2/3
6. **Week 3-4**: P1-1 → P1-2 → P1-3 (OpenCLI skill) → 并行于 P0
7. **Month 2+**: P2-1/2/3 (付费系统调研) → 作为中长期背景任务

---

## 资源投入建议

| 方向 | 建议投入 | 原因 |
|------|----------|------|
| P0 Claude Code 架构升级 | **60%** | 核心体验，ROI 最高 |
| P1 OpenCLI Skill | **25%** | 快速扩展能力，实施成本低 |
| P2 Pay-as-you-go | **15%** | 商业化重要，但周期长、合规重 |

---

## 下一步

请确认：
1. 这个任务拆解是否符合你的预期？
2. 优先级是否需要调整？
3. 你想先从哪个任务开始？我可以立即开始执行。
