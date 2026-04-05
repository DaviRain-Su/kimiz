# Swarm (penberg/swarm) 分析 — 多 Agent 工作区管理的 Rust 实现

**文档版本**: 1.0  
**日期**: 2026-04-05  
**分析对象**: [penberg/swarm](https://github.com/penberg/swarm) (45 stars, 极度活跃)  
**作者背景**: Pekka Enberg — Turso (SQLite 云服务) 创始人 & CTO，前 ScyllaDB、Linux Kernel 开发者  

> **注**: 仓库中没有发现与 Flox（开发环境管理工具）的直接关联。Swarm 使用的数据库是 **Turso**（SQLite 的分布式版本），这是作者的主业产品。

---

## 1. Swarm 是什么

**定位**: "Manage a swarm of coding agents" — 一个**工作区管理器（workspace manager）**，不是 agent 本身。

**核心解决的问题**:
> 当你同时运行 3 个 AI coding agent（比如一个修 bug、一个加 feature、一个写测试）时，它们会在同一个工作目录里互相踩脚、改同一个文件、污染 git 分支。很快你就会淹没在终端标签页里，分不清哪个 agent 在干什么。

**Swarm 的方案**: 用 **git worktree** 为每个 agent 创建物理隔离的工作区，并为每个工作区维护一个持久化的终端会话（session）。

---

## 2. 核心架构：三层抽象

```
Repository (git remote)  →  Workspace (git worktree)  →  Session (持久化终端)
     ↑                            ↑                           ↑
  github.com/                    feature-x/                    bash
  owner/repo                     bugfix-y/                     claude-code
                                 refactor-z/                   aider
```

### 2.1 Repository — 远程仓库的本地镜像

- Swarm 维护一个 **bare clone** 的本地缓存
-  canonical ID: `host/owner/name`（如 `github.com/penberg/swarm`）
- 所有 workspace 从这个 bare clone 创建 worktree，避免重复拉取完整历史

### 2.2 Workspace — 隔离的工作区

```sh
swarm workspace create swarm feature-x
# 创建: ~/.local/share/swarm/repos/github.com/penberg/swarm/workspaces/feature-x/
```

**关键设计**：
- 每个 workspace 是一个 **git worktree**，不是一个完整的 `git clone`
- 这意味着：文件系统隔离，但磁盘开销极小（共享 `.git` 对象）
- `swarm workspace clone` 可以从现有 workspace 再分叉出一个新 worktree + 新分支

### 2.3 Session — 持久化的终端环境

```sh
swarm session create swarm/feature-x -- claude-code
# 创建一个在 workspace 中运行的持久会话
```

**关键设计**：
- Session 是**守护进程化**的：即使 UI/CLI 退出，session 仍在后台运行
- 用 **Unix Domain Socket** 实现 attach/detach（类似 `tmux`/`screen`）
- `Ctrl-]` detach，`Ctrl-D` 传递给内部进程

---

## 3. 工程亮点分析

### 3.1 Supervisor Daemon 模式

Swarm 不是一个简单的 shell wrapper，而是一个**进程监督器（supervisor）**。

```
CLI/GUI 退出
    ↓
Supervisor Daemon 继续运行
    ↓
Agent Session 不受影响
    ↓
用户稍后重新 attach
```

**对 KimiZ 的价值**：
- T-094（后台任务）和 T-110（子代理）可以参考这个"supervisor + session"模型
- 子代理的任务不应该随主 CLI 的关闭而中断
- Unix Domain Socket 是轻量级的进程间通信方案，比 TCP localhost 更干净

### 3.2 git worktree 作为隔离机制 — 天才但简单

Swarm 没有使用：
- Docker 容器（太重）
- 文件系统 namespace（太复杂）
- 完整的 git clone（太占磁盘）

它只用了 **git worktree**：
```sh
git worktree add ../feature-x feature-branch
```

**优势**：
- **零额外依赖**：只要有 git 就行
- **磁盘效率**：所有 worktree 共享同一个 bare repo 的对象库
- **原生 git 体验**：每个 worktree 独立分支，天然支持并行开发
- **可审计**：workspace 本身就是标准 git 工作区，任何 diff 一目了然

**对 KimiZ 的价值**：
- 如果 KimiZ 的 auto skill 需要在不同分支/版本上并行工作，git worktree 是最佳轻量级隔离方案
- 比如：一个子代理在 `main` 分支跑测试，另一个在 `feature/auto-skill` 分支生成代码

### 3.3 Per-Repo Database 架构

Swarm 用 **Turso**（SQLite 的分布式版本）管理状态，但不是单一大库，而是：

```
~/.local/share/swarm/
├── index.db           ← 全局：只存 repo 列表
└── repos/
    └── github.com/
        └── penberg/
            └── swarm/
                ├── repo.db        ← 每个 repo 独立：workspaces, sessions, events
                └── workspaces/
                    └── feature-x/
```

**优势**：
- **故障隔离**：一个 repo 的数据库损坏，不影响其他 repo
- **可移植性**：把整个 `repos/.../swarm/` 目录搬走，所有 workspace 历史都保留
- **并发友好**：不同 repo 的数据库操作互不阻塞

**对 KimiZ 的价值**：
- KimiZ 的 session 持久化（T-086）和 auto skill 元数据如果按项目/仓库分库， resilience 会高很多
- 比把所有数据塞进一个 SQLite 文件更符合"Hardness"原则

### 3.4 GTK4 + Ghostty VT 的原生 UI

Swarm 有一个用 **Rust + GTK4** 写的桌面应用，而且大胆地把 **Ghostty** 的虚拟终端逻辑**vendoring**进来了（`vendor-libghostty-vt-sys/`）。

**效果**：
- 没有 Electron 的内存膨胀
- 可以在一个 dashboard 里同时渲染多个 agent 的终端输出
- 比 web-based terminal emulator（xterm.js 等）延迟更低

**对 KimiZ 的价值**：
- 短期不适用（KimiZ 是 CLI 优先）
- 如果未来 KimiZ 要做监控面板，这个"原生 + vendored VT"的路径比 Tauri/Electron 更硬核

### 3.5 磁盘布局设计

Swarm 的 on-disk format 非常清晰：

```
~/.local/share/swarm/
├── index.db
├── repos/<host>/<owner>/<name>/
│   ├── meta.toml
│   ├── repo.db
│   ├── workspaces/<name>/       ← git worktree checkout
│   └── sessions/<id>/
│       ├── meta.toml
│       └── log
```

所有状态都是：
- **文件系统可见的**（不是加密/序列化 blob）
- **文本+数据库混合**（toml 元数据 + sqlite 索引）
- **按 repo 分片**的

**对 KimiZ 的价值**：
- KimiZ 的 `~/.kimiz/` 目录结构可以直接参考这种分层分片设计
- 把 `sessions/`, `skills/auto/`, `repos/` 分开存储，便于备份和调试

---

## 4. Swarm 的局限性

### 4.1 它不是一个 Agent，只是一个容器/编排器

Swarm 本身**不运行 LLM**，它只是给 Claude Code、aider、OpenCode 等 agent 提供干净的工作区和会话管理。

### 4.2 没有自动任务分解

Swarm 不会帮你决定"这个 bug 该分配给哪个 agent"，它只是提供基础设施让你手动启动多个 agent。

### 4.3 没有安全沙箱

git worktree 提供了**文件系统隔离**，但不是**安全隔离**。一个恶意 agent 仍然可以：
- 读取其他 worktree 的文件
- 访问系统上的敏感文件
- 发起网络攻击

Swarm 的安全边界是"防意外冲突"，不是"防恶意代码"。

---

## 5. 对 KimiZ 的直接借鉴清单

| 借鉴点 | 落地方式 | 优先级 |
|--------|----------|--------|
| **git worktree 隔离** | 子代理/后台任务在独立 worktree 中运行 | P1 |
| **supervisor daemon + UDS attach/detach** | T-094 后台任务持久化机制 | P1 |
| **per-repo 数据分片** | `~/.kimiz/repos/<host>/<owner>/<name>/` 结构 | P2 |
| **session 元数据 + log 分离** | 每个 session 有自己的目录和日志 | P2 |
| **GTK4 + VT 原生 UI** | 远期监控面板参考 | P3 |

---

## 6. 结论

**Swarm 是一个非常有洞察力的基础设施项目。** 它没有追逐"更聪明的 LLM agent"，而是解决了 agent 并行化中最朴实但最致命的问题：**工作区冲突**。

它的核心哲学可以总结为：
> **"物理隔离优于共享内存中的上下文管理。"**

这对 KimiZ 的启示是深远的：
- **子代理不应该共享同一个文件系统视图**
- **持久化 session 是后台任务的必需品**
- **轻量级隔离（git worktree）比重型隔离（Docker）更适合日常开发**

但 Swarm 只走到了"基础设施"这一步。它没有利用 comptime、没有编译器约束、没有代码生成。这些正是 KimiZ 的机会。

---

## 7. 与 KimiZ 现有任务的关联

- **T-094**（后台任务）→ 参考 Swarm 的 session supervisor 模式
- **T-110**（OS 线程隔离）→ 可以和 git worktree 隔离结合使用
- **T-086**（会话持久化）→ 参考 Swarm 的 on-disk session 布局
- **T-115**（Nix 集成）→ 在 worktree 隔离的基础上再加一层 Nix 环境锁定

**终极组合**：
```
KimiZ Subagent
    ├── 文件系统隔离: git worktree
    ├── 环境隔离:     Nix shell
    ├── 运行隔离:     OS thread / WASM / namespace
    └── 能力隔离:     Capability manifest
```

这个四层隔离模型，才是 Hardness Engineer 的完整形态。
