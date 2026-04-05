# TASK-INFRA-008: Zig 0.16 API 迁移跟踪

**状态**: in_progress  
**优先级**: P0  
**创建**: 2026-04-05  
**预计耗时**: 16h  
**类型**: Infrastructure  
**阻塞**: 所有开发工作

## 背景

项目当前使用 Zig 0.16.0-dev.2261，该版本引入了重大 API 变化：
- `std.fs` 模块被移除，文件系统操作移至 `std.Io.Dir`
- `std.io` 更名为 `std.Io`
- `std.http.Client` 需要 `io` 字段
- `std.time.milliTimestamp()` 被移除
- 所有 I/O 操作需要 `std.Io` 实例

## 当前编译错误统计

```
错误类型                          数量    状态
─────────────────────────────────────────────────
std.fs.cwd() 不存在                21      待修复
std.Io.init 不存在                  3      待修复
utils.milliTimestamp 未定义         17      待修复
std.io 重命名为 std.Io              5      待修复
JSON 类型不兼容                     4      已修复
其他                                2      待修复
```

## 已完成的修复

### 1. ✅ 添加 getModelById 函数
- **文件**: `src/ai/models.zig`
- **修改**: 添加 `getModelById(id: []const u8) ?Model` 函数
- **提交**: 15d5559

### 2. ✅ 创建兼容性层
- **文件**: `src/utils/fs_helper.zig` (新建)
- **功能**: 提供文件系统操作的兼容性包装
- **文件**: `src/utils/root.zig` (新建)
- **功能**: 组织工具模块，导出兼容性函数

### 3. ✅ 修复 skills 模块导入
- **文件**: `src/skills/builtin.zig`, `code_review.zig`, `debug.zig`, `doc_gen.zig`, `refactor.zig`, `test_gen.zig`
- **修改**: `@import("root.zig")` → `@import("./root.zig")`

### 4. ✅ 修复 agent.zig 错误处理
- **文件**: `src/agent/agent.zig`
- **修改**: `ai.Ai.init(allocator)` → `try ai.Ai.init(allocator)`

## 待修复任务清单

### 阶段 1: Io 系统初始化 (预计 4h)

#### TASK-1.1: 创建 IoManager 单例
- **文件**: `src/utils/io_manager.zig` (新建)
- **描述**: 创建全局 Io 实例管理器，因为 Zig 0.16 的 Io 需要通过 Threaded 或 Evented 创建
- **依赖**: 无
- **验收标准**:
  - [ ] 创建 `IoManager` 结构体
  - [ ] 实现 `init()` 和 `deinit()`
  - [ ] 提供全局 `io()` 访问函数
  - [ ] 线程安全

#### TASK-1.2: 更新 http.zig 使用 IoManager
- **文件**: `src/http.zig`
- **描述**: 修改 HttpClient 使用 IoManager 获取 Io 实例
- **依赖**: TASK-1.1
- **当前错误**:
  ```
  src/http.zig:39:37: error: missing struct field: io
  ```
- **验收标准**:
  - [ ] HttpClient.init 使用 IoManager
  - [ ] 所有 HTTP 请求正常工作

### 阶段 2: 文件系统 API 迁移 (预计 6h)

#### TASK-2.1: 更新 fs_helper.zig 使用 IoManager
- **文件**: `src/utils/fs_helper.zig`
- **描述**: 修改所有文件系统函数使用 IoManager 获取 Io 实例
- **依赖**: TASK-1.1
- **当前错误**:
  ```
  src/memory/root.zig:649:35: error: root source file struct 'fs' has no member named 'cwd'
  ```
- **需要更新的函数**:
  - [ ] `cwd()` - 使用 `std.Io.Dir.cwd()`
  - [ ] `readFileAlloc()` - 使用 Io 实例
  - [ ] `writeFile()` - 使用 Io 实例
  - [ ] `fileExists()` - 使用 Io 实例
  - [ ] `makeDir()` - 使用 Io 实例
  - [ ] `makeDirRecursive()` - 使用 Io 实例
  - [ ] `rename()` - 使用 Io 实例
  - [ ] `deleteFile()` - 使用 Io 实例
  - [ ] `realpath()` - 使用 Io 实例

#### TASK-2.2: 更新所有使用 std.fs.cwd() 的文件
- **文件列表** (21 个文件):
  - [ ] `src/memory/root.zig` (7 处)
  - [ ] `src/harness/parser.zig`
  - [ ] `src/harness/runtime.zig`
  - [ ] `src/harness/reasoning_trace.zig`
  - [ ] `src/harness/knowledge_base.zig`
  - [ ] `src/extension/wasm.zig`
  - [ ] `src/extension/root.zig`
  - [ ] `src/extension/package.zig`
  - [ ] `src/extension/loader.zig`
  - [ ] `src/extension/host.zig`
  - [ ] `src/workspace/context.zig`
  - [ ] `src/skills/code_review.zig`
  - [ ] `src/skills/debug.zig`
  - [ ] `src/agent/tools/edit.zig`
  - [ ] `src/agent/tools/grep.zig`
  - [ ] `src/agent/tools/read_file.zig`
  - [ ] `src/agent/tools/glob.zig`
  - [ ] `src/agent/tools/write_file.zig`
  - [ ] `src/core/session.zig`
  - [ ] `src/utils/log.zig`
  - [ ] `src/utils/session.zig`
  - [ ] `src/utils/config.zig`
  - [ ] `src/cli/root.zig`
- **修改方式**: 将 `std.fs.cwd()` 替换为 `utils.fs.cwd()`

### 阶段 3: 时间 API 迁移 (预计 2h)

#### TASK-3.1: 添加 milliTimestamp 兼容性函数
- **文件**: `src/utils/root.zig`
- **描述**: 添加 `milliTimestamp()` 函数，使用 Zig 0.16 的 Clock API
- **当前错误**:
  ```
  src/agent/agent.zig:335:28: error: use of undeclared identifier 'utils'
  src/agent/tools/bash.zig:142:24: error: use of undeclared identifier 'utils'
  src/core/session.zig:29:27: error: use of undeclared identifier 'utils'
  ... (17 处)
  ```
- **实现方案**:
  ```zig
  pub fn milliTimestamp() i64 {
      // 使用 std.time.nanoTimestamp 或 std.Io.Clock
      return @intCast(@divTrunc(std.time.nanoTimestamp(), std.time.ns_per_ms));
  }
  ```

#### TASK-3.2: 更新所有使用 utils.milliTimestamp 的文件
- **文件列表**:
  - [ ] `src/agent/agent.zig`
  - [ ] `src/agent/tools/bash.zig`
  - [ ] `src/core/session.zig`
  - [ ] `src/extension/host.zig`
  - [ ] `src/harness/resource_limits.zig` (2 处)
  - [ ] `src/learning/root.zig`
  - [ ] `src/memory/root.zig` (5 处)
  - [ ] `src/utils/session.zig` (5 处)

### 阶段 4: I/O 重命名修复 (预计 2h)

#### TASK-4.1: 修复 std.io 重命名为 std.Io
- **文件列表**:
  - [ ] `src/skills/code_review.zig`
  - [ ] `src/skills/test_gen.zig`
  - [ ] `src/skills/debug.zig`
  - [ ] `src/skills/doc_gen.zig`
  - [ ] `src/skills/refactor.zig`
  - [ ] `src/tui/terminal.zig`
  - [ ] `src/tui/root.zig`
  - [ ] `src/memory/root.zig`
  - [ ] `src/utils/config.zig`
  - [ ] `src/utils/log.zig`
  - [ ] `src/utils/io_helper.zig`
- **修改方式**: 将 `std.io` 替换为 `std.Io`

### 阶段 5: 测试和验证 (预计 2h)

#### TASK-5.1: 编译验证
- [ ] `zig build` 成功
- [ ] `zig build test` 成功
- [ ] 无编译警告

#### TASK-5.2: 功能验证
- [ ] REPL 模式正常工作
- [ ] 文件操作正常工作
- [ ] HTTP 请求正常工作
- [ ] 技能系统正常工作

## 关键 API 变化对照表

| Zig 0.13-0.15 | Zig 0.16 | 备注 |
|--------------|----------|------|
| `std.fs.cwd()` | `std.Io.Dir.cwd()` | 需要 Io 实例进行实际操作 |
| `std.io` | `std.Io` | 模块重命名 |
| `std.time.milliTimestamp()` | `std.time.nanoTimestamp() / ns_per_ms` | 函数移除 |
| `std.http.Client{ .allocator = a }` | `std.http.Client{ .allocator = a, .io = io }` | 需要 io 字段 |
| `std.ArrayList(T).init(allocator)` | `var list: std.ArrayList(T) = .empty` | API 变化 |
| `std.fs.cwd().readFileAlloc()` | `dir.openFile(&io.interface, path, .{})` | 需要 Io 实例 |

## 参考资料

- [Zig 0.16 Release Notes](https://ziglang.org/download/0.16.0/release-notes.html)
- [std.Io 文档](https://ziglang.org/documentation/0.16.0/std/Io/)
- [Migration Guide](https://ziglang.org/learn/migration-guides/0.16/)

## 相关任务

- TASK-INFRA-007-create-compilation-fix-batch.md
- URGENT-FIX-compilation-errors.md

## 进度跟踪

| 阶段 | 任务数 | 已完成 | 进度 |
|------|--------|--------|------|
| 阶段 1: Io 系统 | 2 | 0 | 0% |
| 阶段 2: 文件系统 | 2 | 0 | 0% |
| 阶段 3: 时间 API | 2 | 0 | 0% |
| 阶段 4: I/O 重命名 | 1 | 0 | 0% |
| 阶段 5: 测试验证 | 2 | 0 | 0% |
| **总计** | **9** | **0** | **0%** |

## 下一步行动

1. 立即开始 TASK-1.1: 创建 IoManager 单例
2. 并行开始 TASK-3.1: 添加 milliTimestamp 兼容性函数
3. 然后按顺序完成其他任务

## 验收标准

- [ ] `zig build` 编译成功，无错误
- [ ] `zig build test` 所有测试通过
- [ ] `kimiz repl` 可以正常启动
- [ ] 文件读写操作正常工作
- [ ] HTTP 请求正常工作
- [ ] 技能系统正常工作
