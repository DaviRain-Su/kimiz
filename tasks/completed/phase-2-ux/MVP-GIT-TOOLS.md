# MVP-GIT-TOOLS: 内置 Git 工具集

**目标**: 为 kimiz Agent 提供安全的 Git 操作工具，减少 token 消耗并避免 bash 注入风险。

**状态**: in_progress
**预计工时**: 4 小时
**指派给**: Droid

---

## 背景

当前 kimiz 的 bash 工具已经能执行 `git` 命令，但存在以下问题：
1. **安全性** — LLM 可能通过 bash 注入非 git 命令
2. **Token 浪费** — git 默认输出太长，LLM 上下文容易爆炸
3. **不可控** — 无法保证 AI 使用的是正确的 git 参数

Claude Code / Codex / Cursor 都内置了 Git 相关能力。kimiz 也需要专门的 Git 工具来补齐这块。

---

## 任务清单

### TOOL-001: git_status

**功能**: 获取工作区状态，返回简洁格式。

**实现**:
- 调用 `git status --porcelain -b`
- 解析输出：分支名、 ahead/behind、modified/untracked files
- 限制返回文件数量（最多 50 个），超出时显示 "... and X more files"

**输出格式示例**:
```
On branch main...origin/main [ahead 2]

Modified: 3
  src/agent/agent.zig
  src/core/root.zig
  src/http.zig

Untracked: 1
  tasks/active/MVP-GIT-TOOLS.md
```

---

### TOOL-002: git_diff

**功能**: 获取当前工作区变更（staged 或 unstaged）。

**实现**:
- 默认调用 `git diff`（unstaged）
- 支持 `staged=true` 参数调用 `git diff --cached`
- 支持 `path` 参数只 diff 特定文件
- 限制输出大小（最大 50KB），超出时截断并提示

**输出格式示例**:
```
--- src/agent/agent.zig
+++ src/agent/agent.zig
@@ -130,6 +130,9 @@
     pub fn deinit(self: *Self) void {
+        for (self.messages.items) |msg| {
+            msg.deinit(self.allocator);
+        }
```

---

### TOOL-003: git_log

**功能**: 获取最近提交历史。

**实现**:
- 调用 `git log --oneline -n {limit}`（默认 limit=10，最大 50）
- 支持 `path` 参数查看特定文件的 log
- 输出每行格式：`{hash} {subject}`

**输出格式示例**:
```
71cee33 fix: eliminate memory leaks
c540c22 feat: configure default model as k2p5
594db3a docs: rewrite README for MVP quickstart
```

---

## 统一实现原则

1. **使用 C `popen`** — 和 `bash.zig` 保持一致，兼容 Zig 0.16
2. **参数白名单** — 只接受已知参数，不拼接任意字符串
3. **错误处理** — 如果不在 git 仓库内，返回友好错误 "Not a git repository"
4. **Token 优化** — 所有输出默认截断/限制，避免 LLM 上下文爆炸
5. **注册到 Agent** — 在 `cli/root.zig` 中注册这三个工具

---

## 验收标准

- [ ] `git_status` 在非 git 仓库中返回友好错误
- [ ] `git_diff` 能正确显示 staged 和 unstaged 变更
- [ ] `git_log` 默认返回 10 条，支持 limit 参数
- [ ] 三个工具都通过 `zig build test`
- [ ] REPL 中 AI 能正确调用这些工具

---

**创建日期**: 2026-04-05
