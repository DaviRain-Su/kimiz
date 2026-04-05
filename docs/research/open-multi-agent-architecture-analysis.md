# Open-Multi-Agent 架构层级分析与 Kimiz 定位研究

**研究日期**: 2026-04-05  
**来源**: @ivanburazin (Daytona.io 创始人) Twitter/X 帖子  
**项目链接**: https://github.com/JackChen-me/open-multi-agent  
**背景**: Claude Code 源码泄露后，多 Agent 编排系统的开源复刻

---

## 1. 执行摘要

Open-Multi-Agent 是一个基于 Claude Code 多 Agent 编排架构的**开源复刻项目**，采用 TypeScript 实现，具有以下核心特征：

- **模型无关** (Model-Agnostic): 不绑定特定 LLM
- **进程内执行** (In-Process): 全程 in-process，非 CLI spawn 模式
- **生产级部署**: 支持 Serverless、Docker、CI/CD 多种部署方式
- **核心组件**: 目标拆分、团队组建、消息总线、带依赖解析的任务调度器

**关键洞察**: Open-Multi-Agent 与 Kimiz **不是竞争关系**，而是**上下层架构关系**。

---

## 2. 三层架构模型

```
┌─────────────────────────────────────────────────────────────────┐
│  Layer 3: Multi-Agent Orchestration (编排层)                      │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  open-multi-agent / CrewAI / LangGraph / AutoGen        │    │
│  │  ├── 目标拆分 (Goal Decomposition)                       │    │
│  │  ├── 团队组建 (Team Assembly)                           │    │
│  │  ├── 消息总线 (Message Bus)                             │    │
│  │  ├── 任务调度器 (Task Scheduler with DAG)               │    │
│  │  └── 依赖解析 (Dependency Resolution)                   │    │
│  │                                                         │    │
│  │  职能: 协调多个 Agent 实例协作完成复杂任务                  │    │
│  └─────────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────────┤
│  Layer 2: Individual Agent (执行层)                             │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Kimiz / Claude Code / OpenCode / Codex / etc           │    │
│  │  ├── 自有工具集 (Tools)                                  │    │
│  │  ├── 自有 Memory 系统 (Short/Working/Long Term)         │    │
│  │  ├── 自有 Learning 系统                                 │    │
│  │  ├── 内部 Subagent 委派                                 │    │
│  │  └── 通过 MCP / Stdio / API 与上层通信                   │    │
│  │                                                         │    │
│  │  职能: 作为被编排的执行单元，专注特定领域任务              │    │
│  └─────────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────────┤
│  Layer 1: AI Provider (模型层)                                  │
│  ├── OpenAI (GPT-4o, o1, o3)                                   │
│  ├── Anthropic (Claude 3.5 Sonnet)                             │
│  ├── Google (Gemini 2.0 Flash)                                 │
│  ├── Kimi (Moonshot k1)                                        │
│  └── Fireworks (Open Source Models)                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Open-Multi-Agent 核心特性详解

### 3.1 架构特点

| 特性 | 说明 | 优势 |
|------|------|------|
| **In-Process** | 所有 Agent 在同一个进程内运行 | 共享内存、零延迟通信、无冷启动 |
| **CLI Spawn 对比** | claude-agent-sdk 每个 Agent 都 spawn 新进程 | 后者上下文隔离但资源开销大 |
| **Message Bus** | 中央消息总线协调 Agent 间通信 | 解耦、支持 pub/sub、易于扩展 |
| **DAG Scheduler** | 任务依赖图 + 拓扑排序调度 | 自动处理任务依赖、支持并行执行 |
| **Team Assembly** | 根据任务动态组建 Agent 团队 | 灵活应对不同场景需求 |

### 3.2 与 Kimiz Subagent 的区别

| 维度 | Open-Multi-Agent | Kimiz Subagent |
|------|------------------|----------------|
| **层级** | Layer 3 (编排) | Layer 2 (执行) |
| **作用域** | 跨 Agent 实例协调 | Agent 内部委派 |
| **通信** | 消息总线 (pub/sub) | 直接函数调用 |
| **生命周期** | 动态创建/销毁 Agent | 固定父子链 |
| **部署** | Serverless/Docker/CI | 本地二进制 |
| **粒度** | 粗粒度 (Agent 级) | 细粒度 (工具级) |

---

## 4. Kimiz 的定位校准

### 4.1 当前定位

Kimiz 目前是一个**独立的、端到端的 Coding Agent**：

```
用户 <-> Kimiz (直接交互)
       ├── 工具执行
       ├── Memory 管理
       ├── Learning 适应
       └── Subagent 委派 (内部)
```

### 4.2 建议定位

Kimiz 应该成为**可被编排的专业 Coding Agent**：

```
用户 <-> 编排器 (Open-Multi-Agent) <-> Kimiz (MCP Server)
                                    <-> Claude Code
                                    <-> OpenCode
                                    <-> 其他 Agent
```

### 4.3 类比理解

| 类比 | 编排层 | 执行层 | 接口 |
|------|--------|--------|------|
| **容器生态** | Kubernetes | Container | CRI |
| **Agent 生态** | Open-Multi-Agent | Kimiz | MCP |
| **函数计算** | AWS Step Functions | Lambda Functions | API Gateway |

---

## 5. 对 Kimiz 的启示与建议

### 5.1 不应该做的事 ❌

| 不建议 | 原因 |
|--------|------|
| 复制消息总线 | 这是编排层的职责 |
| 实现 DAG 调度器 | 与 Kimiz 定位冲突 |
| 动态团队组建 | 属于上层编排功能 |
| 跨进程 Agent 协调 | 违背高性能设计原则 |

### 5.2 应该做的事 ✅

#### P0 - 核心能力

1. **MCP Server 接口**
   - 提供标准化的被编排接口
   - 支持 Stdio / HTTP 两种传输模式
   - 暴露工具集、状态、能力元数据

2. **配置化身份 (Idea File)**
   ```yaml
   identity: "code-reviewer"  # 或 "test-writer", "refactor-specialist"
   skills: ["code_review", "refactor"]
   read_only: true
   model_preference: "claude-3.5-sonnet"
   ```

3. **清晰的能力边界**
   - 专注 Coding 领域
   - 强化工具执行质量
   - 优化 Memory 系统

#### P1 - 增强能力

4. **Subagent 增强**
   - 任务依赖图 (轻量级 DAG)
   - 并发 Subagent 执行
   - 结果合并策略

5. **状态报告**
   - 实时进度反馈
   - 执行状态查询
   - 资源使用统计

---

## 6. 交互模式设计

### 6.1 编排器 → Kimiz 的请求

```json
{
  "task_id": "analyze-code-001",
  "goal": "分析 src/auth.zig 的安全漏洞",
  "context": {
    "files": ["src/auth.zig", "src/crypto.zig"],
    "identity": "security-auditor",
    "constraints": {
      "read_only": true,
      "max_steps": 30,
      "max_depth": 2
    }
  },
  "callback": "http://orchestrator/events"
}
```

### 6.2 Kimiz → 编排器的响应

```json
{
  "task_id": "analyze-code-001",
  "status": "completed",
  "result": {
    "findings": [
      {"severity": "high", "line": 45, "issue": "..."}
    ],
    "suggestions": ["..."]
  },
  "metrics": {
    "steps": 15,
    "tokens_used": 2048,
    "execution_time_ms": 3200
  }
}
```

---

## 7. 与现有 Roadmap 的整合

| Kimiz Phase | 新增内容 | 优先级 | 关联性 |
|-------------|----------|--------|--------|
| Phase 0 | 修复编译错误 | P0 | 基础 |
| Phase 1 | **MCP Server 模式** | P1 | 🔥 新增 |
| Phase 1 | **Idea File 配置系统** | P1 | 🔥 新增 |
| Phase 1 | TaskGraph (轻量依赖) | P2 | 增强 |
| Phase 2 | Harness 功能完善 | P1 | 已有 |
| Phase 3 | TUI 完善 | P2 | 已有 |

---

## 8. 参考资源

- **Open-Multi-Agent**: https://github.com/JackChen-me/open-multi-agent
- **MCP Specification**: https://modelcontextprotocol.io/
- **Claude Code 泄露分析**: `docs/claude-code-architecture-analysis.md`
- **Agent Harness 升级**: `docs/06-agent-harness-upgrade.md`
- **Kimiz 架构愿景**: `docs/07-kimiz-vision-b.md`

---

## 9. 关键结论

> **"吸收思想，精简实现；做好执行层，不争编排层"**

1. Open-Multi-Agent 是 Kimiz 的**潜在调用方**，不是竞品
2. Kimiz 应该成为**优秀的、可被编排的 Coding Agent**
3. 提供 **MCP Server 接口** 是与编排层集成的关键
4. 保持 **高性能、单二进制** 的核心优势
5. 专注 **Coding 领域深度**，而非通用编排广度

---

*文档版本: 1.0*  
*最后更新: 2026-04-05*  
*维护者: kimiz-core-team*
