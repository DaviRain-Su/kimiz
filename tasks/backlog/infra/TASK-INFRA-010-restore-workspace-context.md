### TASK-INFRA-010: 恢复 Workspace 上下文收集

**状态**: pending
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

**解决方案**:

### 方案 1: 使用 std.Io 进行文件操作 (推荐)

1. **修改 WorkspaceContext 接收 Io 实例**
```zig
pub const WorkspaceContext = struct {
    allocator: std.mem.Allocator,
    io: std.Io,  // 添加 Io 实例
    cwd: []const u8,
    // ... 其他字段
    
    pub fn collect(
        allocator: std.mem.Allocator,
        io: std.Io,
        cwd: []const u8,
    ) !WorkspaceContext {
        // ... 实现
    }
    
    fn readFileLimited(
        self: *WorkspaceContext,
        path: []const u8,
        max_bytes: usize,
    ) !?[]const u8 {
        // 使用 self.io 进行文件操作
        const file = try std.Io.Dir.openFile(self.io, path, .{});
        defer file.close(self.io);
        
        // ... 读取文件
    }
};
```

2. **修改调用方传递 Io 实例**
```zig
// src/cli/root.zig
fn runInteractive(allocator: std.mem.Allocator, io: std.Io) !void {
    // ...
    const workspace_ctx = workspace.WorkspaceContext.collect(
        allocator,
        io,
        cwd,
    ) catch |err| {
        // ...
    };
}
```

### 方案 2: 使用 POSIX 文件操作 (备选)

直接使用 POSIX 函数，绕过 `std.fs` 和 `std.Io`：

```zig
const posix = std.posix;

fn readFileLimited(
    allocator: std.mem.Allocator,
    path: []const u8,
    max_bytes: usize,
) !?[]const u8 {
    const fd = try posix.open(path, .{ .ACCMODE = .RDONLY }, 0);
    defer posix.close(fd);
    
    // ... 读取文件
}
```

**缺点**: 不够跨平台，代码不够 Zig 风格。

**推荐方案**: 方案 1

**实现步骤**:

1. **修改 WorkspaceContext 结构**
   - 添加 `io: std.Io` 字段
   - 修改 `init` 和 `collect` 方法

2. **修改文件操作方法**
   - `readFileLimited` - 使用 `std.Io.File`
   - `findGitRoot` - 使用 `std.Io.Dir`
   - `collectProjectDocs` - 遍历目录

3. **修改调用方**
   - `src/cli/root.zig` - 传递 Io 实例
   - `src/agent/agent.zig` - 如果需要

4. **添加错误处理**
   - 文件不存在
   - 权限不足
   - 读取超时

**验收标准**:
- [ ] 可以收集 Git 信息 (分支、状态、最近提交)
- [ ] 可以读取项目文档 (README.md, AGENTS.md 等)
- [ ] 可以检测项目类型 (通过 pyproject.toml, package.json 等)
- [ ] 错误处理完善
- [ ] 性能良好 (不阻塞主线程)
- [ ] 单元测试通过

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
