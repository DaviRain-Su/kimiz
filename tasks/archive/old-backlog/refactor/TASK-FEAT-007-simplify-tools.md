### Task-FEAT-007: 简化 Tools 系统
**状态**: completed
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 4h
**参考**: [Simplified Architecture Proposal](../../docs/design/simplified-architecture-proposal.md)

**描述**:
将当前 7 个内置工具简化为 5 个核心工具，移除复杂工具（web_search, url_summary），这些可以通过 Extensions 实现。

**当前工具** (7个):
1. read_file ✅ 保留
2. write_file ✅ 保留
3. bash ✅ 保留
4. glob ✅ 合并到 grep
5. grep ✅ 保留
6. web_search ❌ 移除 (Extension)
7. url_summary ❌ 移除 (Extension)

**简化后工具** (5个):
1. **read** - 读取文件内容
2. **write** - 写入文件
3. **edit** - 编辑文件（新增，替代部分 write 场景）
4. **bash** - 执行 shell 命令
5. **grep** - 搜索文件（增强版，包含 glob 功能）

**工具定义**:

```zig
// src/agent/tools.zig
pub const BuiltinTools = struct {
    pub const read = Tool{
        .name = "read",
        .description = "Read file contents",
        .parameters = &[_]Parameter{
            .{ .name = "path", .type = .filepath, .required = true },
            .{ .name = "offset", .type = .integer, .required = false },
            .{ .name = "limit", .type = .integer, .required = false },
        },
    };
    
    pub const write = Tool{
        .name = "write",
        .description = "Write content to a file",
        .parameters = &[_]Parameter{
            .{ .name = "path", .type = .filepath, .required = true },
            .{ .name = "content", .type = .string, .required = true },
        },
    };
    
    pub const edit = Tool{
        .name = "edit",
        .description = "Edit a file by replacing text",
        .parameters = &[_]Parameter{
            .{ .name = "path", .type = .filepath, .required = true },
            .{ .name = "old_string", .type = .string, .required = true },
            .{ .name = "new_string", .type = .string, .required = true },
        },
    };
    
    pub const bash = Tool{
        .name = "bash",
        .description = "Execute a bash command",
        .parameters = &[_]Parameter{
            .{ .name = "command", .type = .string, .required = true },
            .{ .name = "working_dir", .type = .directory, .required = false },
            .{ .name = "timeout_ms", .type = .integer, .required = false },
        },
    };
    
    pub const grep = Tool{
        .name = "grep",
        .description = "Search for patterns in files",
        .parameters = &[_]Parameter{
            .{ .name = "pattern", .type = .string, .required = true },
            .{ .name = "path", .type = .filepath, .required = false },
            .{ .name = "glob", .type = .string, .required = false },
            .{ .name = "case_sensitive", .type = .boolean, .required = false },
        },
    };
    
    pub const all = &[_]Tool{
        read, write, edit, bash, grep,
    };
};
```

**增强 grep 工具**:

```zig
// 合并 glob 功能到 grep
fn executeGrep(arena: std.mem.Allocator, args: GrepArgs) !ToolResult {
    // 1. 使用 glob 模式查找文件
    var files = std.ArrayList([]const u8).init(arena);
    
    if (args.glob) |pattern| {
        // 使用 glob 模式
        try globFiles(arena, args.path orelse ".", pattern, &files);
    } else {
        // 递归搜索所有文件
        try listAllFiles(arena, args.path orelse ".", &files);
    }
    
    // 2. 在每个文件中搜索
    var results = std.ArrayList(Match).init(arena);
    for (files.items) |file| {
        try searchInFile(arena, file, args.pattern, args.case_sensitive, &results);
    }
    
    // 3. 格式化输出
    return formatResults(arena, results);
}
```

**新增 edit 工具**:

```zig
// src/agent/tools/edit.zig
fn executeEdit(arena: std.mem.Allocator, args: EditArgs) !ToolResult {
    // 1. 读取原文件
    const content = try std.fs.cwd().readFileAlloc(arena, args.path, 10 * 1024 * 1024);
    
    // 2. 查找 old_string
    const idx = std.mem.indexOf(u8, content, args.old_string);
    if (idx == null) {
        return error.StringNotFound;
    }
    
    // 3. 替换
    const new_content = try std.mem.concat(arena, u8, &[_][]const u8{
        content[0..idx.?],
        args.new_string,
        content[idx.? + args.old_string.len ..],
    });
    
    // 4. 写回
    try std.fs.cwd().writeFile(.{
        .sub_path = args.path,
        .data = new_content,
    });
    
    return ToolResult{
        .content = "File edited successfully",
        .is_error = false,
    };
}
```

**需要修改的文件**:
- [x] 删除 `src/agent/tools/glob.zig` (合并到 grep)
- [x] 删除 `src/agent/tools/web_search.zig`
- [x] 删除 `src/agent/tools/url_summary.zig`
- [x] 创建 `src/agent/tools/edit.zig`
- [x] 修改 `src/agent/root.zig` (更新工具列表)

**验收标准**:
- [x] 5 个核心工具正常工作
- [x] edit 工具正常工作
- [x] web_search 和 url_summary 移除
- [x] 代码减少 30%+
- [x] 测试通过
- [x] 编译通过

**依赖**:
- 无

**阻塞**:
- 无

**笔记**:
2026-04-05: 任务完成

简化后的工具集 (5个核心工具):
1. read - 读取文件
2. write - 写入文件
3. edit - 编辑文件 (新增)
4. bash - 执行命令
5. grep - 搜索文件

删除的工具:
- glob (功能合并到 grep)
- web_search (将通过 Extension 实现)
- url_summary (将通过 Extension 实现)

code 统计:
- 删除: ~800 行 (3个工具文件)
- 新增: ~150 行 (edit 工具)
- 净减少: ~650 行

参考 Pi-Mono 的工具设计：read, write, edit, bash 是核心。其他功能通过 Extensions 添加。
