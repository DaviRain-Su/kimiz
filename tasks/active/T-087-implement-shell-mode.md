### T-087: implement-shell-mode
**状态**: active
**优先级**: P1
**创建**: 2026-04-05
**更新**: 2026-04-05
**预计耗时**: 6h

**描述**:
实现 Shell 模式，允许用户在 REPL 中直接执行 shell 命令而无需通过 AI agent。

这是与官方 kimi-cli 的核心差距之一（GAP-4）。kimi-cli 按 Ctrl-X 可在 Agent 模式和 Shell 模式间切换。本任务需要：
1. 在 REPL 中检测模式切换（Ctrl-X 或 `$` 前缀）
2. Shell 模式下直接调用系统 shell 执行命令
3. 将命令输出反馈到当前会话上下文（可选）
4. 状态栏显示当前模式（Agent / Shell）

**TigerBeetle 借鉴**:
- 直接参考 `shell.zig` 的设计：用 `ArenaAllocator` 统一管理 Shell 模式下的所有临时字符串和命令输出
- 命令执行后用 `arena.deinit()` 一次性释放，避免逐个 free
- `pushd` / `popd` 配对使用 `defer` 管理目录切换，确保 cwd 始终正确
- 命令参数插值避免字符串拼接（类似 TigerBeetle 的 `exec_` 方法族）

参考文档: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md, docs/TIGERBEETLE-PATTERNS-ANALYSIS.md

**验收标准**:
- [ ] 核心功能实现
- [ ] 集成到主循环/CLI
- [ ] 基础测试覆盖
- [ ] 文档更新

**依赖**: 

**笔记**:
- 来自差距分析文档: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md
