### TASK-BUG-025: 清理 registry.zig 死代码
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 30分钟

**描述**:
`src/agent/registry.zig` 导入了 3 个已删除的文件，导致潜在的编译问题。

**位置**: `src/agent/registry.zig:12-15`

**当前代码**:
```zig
const glob = @import("tools/glob.zig");           // ❌ 文件不存在
const web_search = @import("tools/web_search.zig");  // ❌ 文件不存在
const url_summary = @import("tools/url_summary.zig"); // ❌ 文件不存在
```

**问题**:
- 这 3 个文件在 commit 17e9e00 中被删除
- 但 registry.zig 仍有这些导入
- registry.zig 当前未被任何模块使用（孤立文件）
- 如果将来被使用，会导致编译错误

**修复方案**:

方案 A: 如果 registry.zig 不需要，删除整个文件
```bash
rm src/agent/registry.zig
```

方案 B: 如果需要，清理导入
```zig
// 移除这 3 行导入
// 或者创建空壳模块
const glob = struct {};
const web_search = struct {};
const url_summary = struct {};
```

**验收标准**:
- [ ] registry.zig 或者被删除，或者干净无死代码
- [ ] `zig build` 编译通过

**依赖**:
- 无

**阻塞**:
- 无（当前未使用）

**笔记**:
检查是否真的不需要这个文件，如果是就删除。
