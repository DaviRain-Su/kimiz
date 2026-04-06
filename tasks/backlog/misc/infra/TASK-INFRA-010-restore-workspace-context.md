### TASK-INFRA-010: 恢复 Workspace 上下文收集

**状态**: done
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 4小时
**阻塞**: Workspace 感知功能

**描述**:
Workspace 上下文收集被暂时禁用，因为 Zig 0.16 的文件系统 API 需要 `std.Io` 实例。需要恢复此功能。

**背景**:
`src/workspace/context.zig` 中的功能被禁用，因为：
- `std.fs.cwd()` 不再可用
- 文件操作需要通过 `std.Io` 进行

**实现方案**:
Use `std.process.run()` with `utils.getIo()` to execute git commands (rev-parse, branch, status, log) and `utils.readFileAlloc()` for file reading. All git commands run from current working directory without explicit cwd parameter.

**验收标准**:
- [x] 可以收集 Git 信息 (分支、状态、最近提交)
- [x] 可以读取项目文档 (README.md, AGENTS.md 等)
- [x] 可以检测项目类型 (通过 pyproject.toml, package.json 等)
- [x] 错误处理完善
- [x] 性能良好 (不阻塞主线程)
- [x] 单元测试通过

**Log**:
- 2026-04-06: 重写 `src/workspace/context.zig`，完整实现 `findGitRoot`, `getGitBranch`, `getGitDefaultBranch`, `getGitStatus`, `getRecentCommits`, `collectProjectDocs`, `formatContext`
- 2026-04-06: 使用 `std.process.run` + `utils.getIo()` 执行 git 命令
- 2026-04-06: 使用 `utils.readFileAlloc` 读取项目文档
- 2026-04-06: 修复 Zig 0.16 `appendPrint` → `std.fmt.allocPrint` + `appendSlice`
- 2026-04-06: `make build` 和 `make test` 全部通过
- 2026-04-06: 标记为 done

**依赖**:
- TASK-INFRA-008 (实现完整的 HTTP Client) - 共享 IoManager

**阻塞**:
- Workspace 感知功能
- AGENTS.md 解析

**参考**:
- Zig 0.16 std.Io 文档
- Zig 0.16 std.Io.File 文档
- Zig 0.16 std.Io.Dir 文档
- 原始 `src/workspace/context.zig` 实现
