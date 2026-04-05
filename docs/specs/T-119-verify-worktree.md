# T-119-VERIFY: 验证 git worktree 隔离

**任务类型**: Verification / Bugfix  
**优先级**: P0  
**阻塞**: 依赖于 FIX-ZIG-015（必须先能编译）和 T-092-VERIFY（delegate 工具可用）  
**预计耗时**: 1h

---

## 参考文档

- [SUBAGENT-ARCHITECTURE-AND-IMPLEMENTATION-PLAN](../design/SUBAGENT-ARCHITECTURE-AND-IMPLEMENTATION-PLAN.md) - Worktree 隔离架构设计
- [TigerBeetle Patterns](../TIGERBEETLE-PATTERNS-ANALYSIS.md) - Zig 资源管理原则

---

## 背景

Commit `74c22ff` (`feat: implement git worktree isolation for subagents (T-119)`) 实现了子 Agent 的 git worktree 隔离功能。这一功能让子 Agent 在执行文件操作时，不再与主 Agent 共享同一个 git working tree，而是运行在独立的 git worktree 中，避免文件冲突。

但由于后续代码改用了 Zig 0.16 API，导致项目无法编译，**这一功能从未被实际验证过**。

本任务的目标是：在编译恢复且 delegate 工具可用后，**验证 worktree 隔离确实工作正常**，并修复任何集成问题。

---

## 相关代码

| 文件 | 作用 |
|------|------|
| `src/utils/worktree.zig` | WorktreeManager 实现 |
| `src/agent/subagent.zig` | SubAgent 核心，可能已集成 worktree |
| `src/agent/agent.zig` | Agent Loop |
| `src/cli/root.zig` | REPL 初始化 |

---

## 验证步骤

### Step 1: 确认代码集成

1. 打开 `src/utils/worktree.zig`
2. 确认是否有以下功能：
   - `create(repo_path, branch_or_name)` → 返回 worktree 路径
   - `list(repo_path)` → 列出 worktree
   - `remove(worktree_path)` → 清理 worktree
3. 打开 `src/agent/subagent.zig`
4. 检查 `SubAgentConfig` 或 `SubAgent.init()` 是否包含 `worktree_path` 相关字段
5. 检查 `SubAgent.run()` 是否在启动时切换到 worktree 目录

### Step 2: 编译并运行测试

```bash
zig build test
```

确保 `worktree.zig` 和 `subagent.zig` 中的现有测试通过。

### Step 3: REPL 功能验证

1. 启动 REPL：
   ```bash
   zig build run -- repl
   ```
2. 进入一个 git 仓库目录（确保当前目录是 git repo）
3. 输入一个会触发子代理进行文件操作的任务：
   > "使用 delegate 工具让子代理读取 src/main.zig 的内容，然后在 worktree 中创建一个新文件 test_worktree.txt，内容为 'hello from subagent'。"
4. 验证：
   - 子代理执行期间，worktree 是否被创建（可以通过另一个终端观察 `.git/worktrees/` 或 `git worktree list`）
   - 子代理创建的文件是否**不在**主 working tree 中
   - 子代理返回后，worktree 是否被清理

### Step 4: 边界条件测试

1. **非 git 目录**
   - 如果当前目录不是 git repo，子代理应该 gracefully fallback 到普通执行（不崩溃）

2. **多个并发子代理**
   - 快速连续触发两个 `delegate` 调用
   - 验证两个 worktree 互不干扰

3. **清理验证**
   - 子代理退出后，运行 `git worktree list`
   - 确认临时 worktree 已被删除

---

## 可能的修复

### 修复 A: worktree 创建失败未处理

如果 `subagent.zig` 在创建 worktree 失败时 panic 或返回晦涩错误，需要添加友好的错误处理：

```zig
const worktree_path = worktree_manager.create(cwd, subagent_name) catch |err| {
    std.log.warn("Failed to create worktree for subagent: {s}, fallback to main tree", .{@errorName(err)});
    return self.runInMainTree(task);
};
```

### 修复 B: 子代理工具的 CWD 未正确切换

检查子代理内部的文件操作工具（如 `read_file`, `write_file`）是否使用了 worktree 路径作为基准。可能需要：
- 在 `SubAgent` struct 中存储 `cwd: []const u8`
- 修改工具执行时传入的路径解析逻辑

### 修复 C: worktree 路径泄漏

检查 `worktree.zig` 中返回的路径字符串是否被正确释放。

---

## 验收标准

- [ ] `zig build test` 通过
- [ ] `src/utils/worktree.zig` 存在且编译通过
- [ ] REPL 中触发 `delegate` 时，git worktree 被自动创建
- [ ] 子代理的文件操作发生在独立 worktree 中（不影响主 tree）
- [ ] 子代理退出后，临时 worktree 被清理
- [ ] 非 git 目录下能 graceful fallback

---

## 参考

- `tasks/active/SUBAGENT-ROLLING-ROADMAP.md` - Stage 2 详细设计
- `src/utils/worktree.zig` - WorktreeManager 实现
- `src/agent/subagent.zig` - SubAgent 核心
