# TASK-TODO-003: 恢复 Workspace Git 上下文功能

**状态**: pending  
**优先级**: P1  
**类型**: Feature  
**预计耗时**: 4小时  
**阻塞**: Workspace 上下文收集

## 描述

Workspace 上下文收集功能被简化，Git 相关功能需要完整实现。

## 受影响的文件

- **src/workspace/context.zig**
  - `formatContext()` (第 95 行) - TODO: Full implementation for Zig 0.16
  - `findGitRoot()` (第 117 行) - TODO: Full implementation in TASK-INFRA-010
  - `getGitBranch()` (第 124 行) - TODO: Full implementation in TASK-INFRA-010
  - `getGitDefaultBranch()` (第 131 行) - TODO: Full implementation in TASK-INFRA-010
  - `getGitStatus()` (第 138 行) - TODO: Full implementation in TASK-INFRA-010
  - `runGitCommand()` (第 151 行) - TODO: Full implementation in TASK-INFRA-010
  - `readFileLimited()` (第 159 行) - TODO: Full implementation in TASK-INFRA-010

## 当前问题

所有 Git 相关函数返回 `null` 或空值：
```zig
fn findGitRoot(...) !?[]const u8 {
    return null;  // 简化实现
}
```

## 实现方案

### Git 命令执行
```zig
fn runGitCommand(allocator: std.mem.Allocator, cwd: []const u8, argv: []const []const u8) !?[]const u8 {
    // 使用 std.process.Child 执行 git 命令
    var child = try std.process.Child.init(argv, allocator);
    child.cwd = cwd;
    // ... 执行并获取输出
}
```

### 文件读取
```zig
fn readFileLimited(allocator: std.mem.Allocator, path: []const u8, max_bytes: usize) !?[]const u8 {
    // 使用 utils.fs.readFileAlloc 读取文件
    return try utils.fs.readFileAlloc(allocator, path, max_bytes);
}
```

## 验收标准

- [ ] 自动检测 Git 仓库根目录
- [ ] 获取当前分支信息
- [ ] 获取默认分支信息
- [ ] 获取 Git 状态 (modified/staged 文件)
- [ ] 获取最近提交历史
- [ ] 读取项目文档 (README, AGENTS.md 等)
- [ ] 完整的 Workspace 上下文格式化

## 依赖

- TASK-INFRA-008 (IoManager)
- TASK-TODO-002 (HTTP Client) - 用于文件操作

## 相关任务

- TASK-INFRA-010
