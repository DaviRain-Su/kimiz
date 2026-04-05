### TASK-BUG-021: 创建缺失的工具文件
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 2h

**描述**:
`src/agent/root.zig` 导入了 3 个不存在的工具文件，导致项目无法编译。

**错误信息**:
```
error: unable to load 'glob.zig': FileNotFound
error: unable to load 'url_summary.zig': FileNotFound
error: unable to load 'web_search.zig': FileNotFound
```

**位置**:
- `src/agent/root.zig:8` - `url_summary`
- `src/agent/root.zig:11` - `glob`
- `src/agent/root.zig:14` - `web_search`

**修复方案**:

方案 A: 创建缺失的工具文件 (如果需要这些功能)
- `src/agent/tools/glob.zig` - 文件模式匹配工具
- `src/agent/tools/web_search.zig` - 网页搜索工具
- `src/agent/tools/url_summary.zig` - URL 内容摘要工具

方案 B: 移除导入 (如果不急需这些功能)
- 从 `src/agent/root.zig` 移除这 3 个导入
- 从 `createDefaultRegistry()` 移除这些工具的注册

**验收标准**:
- [ ] `zig build` 编译成功
- [ ] Agent 可以正常初始化
- [ ] 至少 5 个核心工具可用 (bash, read_file, write_file, edit, grep)

**依赖**:
- 无

**阻塞**:
- 所有开发和测试

**笔记**:
这是当前阻塞项目的最大问题。
