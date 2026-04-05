### TASK-INFRA-010: 恢复 Workspace 上下文收集

**状态**: 已完成 ✅
**完成日期**: 2026-04-05
**实际耗时**: 2小时

**实现内容**:
1. ✅ 修改 `workspace/context.zig` 使用 POSIX 文件操作
2. ✅ 重写 `findGitRoot` 函数 - 使用 `std.posix.getcwd` 和路径拼接
3. ✅ 重写 `readFileLimited` 函数 - 使用 `std.posix.open/read/fstat`
4. ✅ 重写 `runGitCommand` 函数 - 使用 `std.posix.fork/pipe/execvpe`
5. ✅ 在 `cli/root.zig` 中启用 workspace 上下文收集
6. ✅ 所有编译错误修复

**代码变更**:

### workspace/context.zig
```zig
/// Find git repository root from a starting directory
fn findGitRoot(allocator: std.mem.Allocator, start_dir: []const u8) !?[]const u8 {
    // Use POSIX getcwd and path operations
    var cwd_buf: [std.fs.max_path_bytes]u8 = undefined;
    // ... implementation
}

/// Read file with size limit using POSIX
fn readFileLimited(allocator: std.mem.Allocator, path: []const u8, max_bytes: usize) !?[]const u8 {
    const fd = std.posix.open(path, .{ .ACCMODE = .RDONLY }, 0) catch ...;
    // ... implementation
}

/// Run a git command and return output using POSIX
fn runGitCommand(allocator: std.mem.Allocator, cwd: []const u8, argv: []const []const u8) !?[]const u8 {
    var pipe_fds: [2]i32 = undefined;
    std.posix.pipe(&pipe_fds) catch return null;
    const pid = std.posix.fork() catch ...;
    // ... implementation
}
```

### cli/root.zig
```zig
// Collect workspace context
print("📁 Collecting workspace context...\n");
var workspace_ctx = workspace.WorkspaceInfo.init(allocator, cwd) catch ...;
defer workspace_ctx.deinit();

try workspace_ctx.collect();
```

**功能特性**:
- ✅ Git 仓库根目录检测
- ✅ 当前分支获取
- ✅ 默认分支获取
- ✅ Git 状态获取
- ✅ 最近提交历史获取
- ✅ 项目文档读取 (README.md, AGENTS.md, 等)
- ✅ 项目类型检测 (pyproject.toml, package.json, 等)

**使用方法**:
```bash
# 在 Git 仓库中运行
./zig-out/bin/kimiz
# 输出: ✅ Workspace context collected
```

**编译状态**:
```bash
$ zig build
✅ 成功

$ ./zig-out/bin/kimiz --help
✅ 正常运行
```

**后续优化**:
- 添加更多项目类型检测
- 实现文件内容缓存
- 添加异步收集支持
- 添加更多 Git 信息 (远程 URL, 标签等)
