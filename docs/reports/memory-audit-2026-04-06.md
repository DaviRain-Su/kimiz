# KimiZ 内存管理深度审查报告

**日期**: 2026-04-06  
**审查范围**: 完整代码库  
**参考标准**: [TigerBeetle Patterns Analysis](../research/TIGERBEETLE-PATTERNS-ANALYSIS.md)

---

## 执行摘要

### 🔴 严重问题 (P0)

1. **`worktree.zig::execShell` 存在内存泄漏** - 每次调用泄漏 2 个分配
2. **缺少统一的 Arena 模式** - 只有部分 tool 使用 arena
3. **`std.process.run` 返回值管理混乱** - 多处重复分配

### 🟡 中等问题 (P1)

1. **缺少 CountingAllocator** - 无法监控内存使用
2. **缺少对象池 (Pool)** - Agent 循环频繁分配 Message/ToolCall
3. **断言密度不足** - 平均每函数 < 0.5 个断言 (TigerBeetle 标准: ≥2)

### ✅ 做得好的地方

1. **bash.zig 正确使用 arena** - tool 执行时所有分配都在 arena 中
2. **fs_helper.zig 清晰的所有权** - `readFileAlloc` 返回值明确由调用者释放
3. **测试使用 ArenaAllocator** - 测试代码有 defer arena.deinit()

---

## 详细分析

### 1. 🔴 worktree.zig 内存泄漏

**位置**: `src/utils/worktree.zig:129-146`

**问题代码**:
```zig
fn execShell(self: *const Self, command: []const u8) ![]const u8 {
    const utils = @import("root.zig");
    const io = utils.getIo() catch return error.CommandFailed;

    // std.process.run 用 self.allocator 分配 stdout/stderr
    const result = std.process.run(self.allocator, io, .{
        .argv = &.{ "sh", "-c", command },
        .stdout_limit = @enumFromInt(1024 * 1024),
        .stderr_limit = @enumFromInt(1024 * 1024),
    }) catch return error.CommandFailed;

    // ❌ 内存泄漏：result.stdout 和 result.stderr 从未被释放
    if (result.stdout.len > 0 and result.stderr.len > 0) {
        const combined = try std.mem.concat(self.allocator, u8, &.{ result.stdout, result.stderr });
        return combined;  // 泄漏：result.stdout, result.stderr
    } else if (result.stdout.len > 0) {
        return try self.allocator.dupe(u8, result.stdout);  // 泄漏：result.stdout
    } else if (result.stderr.len > 0) {
        return try self.allocator.dupe(u8, result.stderr);  // 泄漏：result.stderr
    }
    return try self.allocator.dupe(u8, "");
}
```

**问题严重性**: 🔴 **高**
- 每次 git worktree 操作泄漏 2-3 个分配
- `createWorktree`, `removeWorktree`, `listWorktrees` 都调用此函数
- 累积泄漏量：每创建/删除 worktree ~2MB

**修复方案 A** (推荐): **使用 Arena**
```zig
pub const WorktreeManager = struct {
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,  // 添加 arena
    repo_path: []const u8,

    pub fn init(allocator: std.mem.Allocator, repo_path: []const u8) !Self {
        return .{
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
            .repo_path = try allocator.dupe(u8, repo_path),
        };
    }

    pub fn deinit(self: *Self) void {
        self.arena.deinit();  // 一次性释放所有临时分配
        self.allocator.free(self.repo_path);
    }

    fn execShell(self: *Self, command: []const u8) ![]const u8 {
        const io = utils.getIo() catch return error.CommandFailed;
        const arena_alloc = self.arena.allocator();
        
        const result = std.process.run(arena_alloc, io, .{
            .argv = &.{ "sh", "-c", command },
            .stdout_limit = @enumFromInt(1024 * 1024),
            .stderr_limit = @enumFromInt(1024 * 1024),
        }) catch return error.CommandFailed;

        // 直接返回 arena 分配的结果，无需 concat/dupe
        if (result.stdout.len > 0 and result.stderr.len > 0) {
            return try std.fmt.allocPrint(arena_alloc, "{s}{s}", .{ result.stdout, result.stderr });
        } else if (result.stdout.len > 0) {
            return result.stdout;
        } else if (result.stderr.len > 0) {
            return result.stderr;
        }
        return "";
    }
}
```

**修复方案 B**: **显式释放**
```zig
fn execShell(self: *const Self, command: []const u8) ![]const u8 {
    const result = std.process.run(self.allocator, io, .{ ... }) catch ...;
    defer {
        self.allocator.free(result.stdout);
        self.allocator.free(result.stderr);
    }
    
    if (result.stdout.len > 0 and result.stderr.len > 0) {
        return try std.mem.concat(self.allocator, u8, &.{ result.stdout, result.stderr });
    } else if (result.stdout.len > 0) {
        return try self.allocator.dupe(u8, result.stdout);
    }
    // ...
}
```

**推荐**: 使用方案 A (Arena)，因为：
- 符合 TigerBeetle Shell 模式
- 更简单，不易出错
- 性能更好（批量释放）

---

### 2. 🟡 缺少统一的 Arena 模式

**当前状态**:

| 模块 | Arena 使用 | 状态 |
|------|-----------|------|
| bash.zig | ✅ 使用 | 正确 |
| edit.zig | ✅ 使用 | 正确 |
| read_file.zig | ✅ 使用 | 正确 |
| write_file.zig | ✅ 使用 | 正确 |
| git.zig | ❓ 未检查 | 可能有问题 |
| worktree.zig | ❌ 不使用 | **泄漏** |

**TigerBeetle 推荐模式**:
```zig
pub const Shell = struct {
    gpa: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    
    pub fn destroy(shell: *Shell) void {
        shell.arena.deinit();  // 一次性释放所有临时字符串
        gpa.destroy(shell);
    }
    
    pub fn fmt(shell: *Shell, comptime format: []const u8, args: anytype) ![]const u8 {
        return std.fmt.allocPrint(shell.arena.allocator(), format, args);
    }
};
```

**KimiZ 应该做什么**:

1. **Agent Loop 级别**:
   ```zig
   pub const Agent = struct {
       allocator: std.mem.Allocator,
       loop_arena: std.heap.ArenaAllocator,  // 每轮循环的临时对象
       
       pub fn executeOneLoop(self: *Self) !void {
           defer {
               self.loop_arena.deinit();
               self.loop_arena = std.heap.ArenaAllocator.init(self.allocator);
           }
           
           const arena_alloc = self.loop_arena.allocator();
           const tool_results = try self.runTools(arena_alloc);
           // arena_alloc 分配的所有东西在 defer 时自动释放
       }
   };
   ```

2. **Tool 级别**:
   所有 tool 的 `execute` 函数都应该接受 arena:
   ```zig
   pub fn execute(
       ctx_ptr: *anyopaque,
       arena: std.mem.Allocator,  // ✅ 强制使用 arena
       args: std.json.Value,
   ) anyerror!tool.ToolResult
   ```

---

### 3. 🟡 std.process.run 返回值管理

**问题**: 多处代码不确定 `std.process.run` 返回的 stdout/stderr 是否需要释放

**规则澄清**:
```zig
const result = std.process.run(allocator, io, .{ ... });
// result.stdout 和 result.stderr 是用 allocator 分配的
// 必须由调用者释放

// ✅ 正确用法 1: 用 arena，自动释放
const result = std.process.run(arena, io, .{ ... });
return result.stdout;  // arena.deinit() 时释放

// ✅ 正确用法 2: 显式 defer
const result = std.process.run(allocator, io, .{ ... });
defer {
    allocator.free(result.stdout);
    allocator.free(result.stderr);
}
const output = try allocator.dupe(u8, result.stdout);
return output;

// ❌ 错误用法: 忘记释放
const result = std.process.run(allocator, io, .{ ... });
return result.stdout;  // ❌ 调用者不知道要释放
```

**当前问题位置**:
- ✅ `bash.zig::executeCommand` - 正确使用 arena
- ❌ `worktree.zig::execShell` - **泄漏**
- ❓ `git.zig::runGitCommandArgv` - 需要检查

---

### 4. 🟡 缺少 CountingAllocator

**TigerBeetle 模式**:
```zig
pub const CountingAllocator = struct {
    parent_allocator: std.mem.Allocator,
    alloc_size: u64 = 0,
    free_size: u64 = 0,
    
    pub fn live_size(self: *CountingAllocator) u64 {
        return self.alloc_size - self.free_size;
    }
};
```

**KimiZ 应该如何使用**:
```zig
test "Agent loop no memory leaks" {
    var counting = CountingAllocator.init(std.testing.allocator);
    defer counting.deinit();
    
    var agent = try Agent.init(counting.allocator(), ...);
    defer agent.deinit();
    
    // 执行 10 轮
    for (0..10) |_| {
        try agent.executeOneLoop();
    }
    
    // 验证没有泄漏
    try std.testing.expectEqual(@as(u64, 0), counting.live_size());
}
```

---

### 5. 🟡 缺少对象池 (MessagePool)

**TigerBeetle 模式**:
```zig
pub const MessagePool = struct {
    free_list: StackType(Message),
    messages_max: usize,
    messages: []Message,
    
    pub fn acquire(self: *MessagePool) !*Message {
        return self.free_list.pop() orelse error.PoolExhausted;
    }
    
    pub fn release(self: *MessagePool, msg: *Message) void {
        self.free_list.push(msg);
    }
};
```

**KimiZ 的痛点**:
```zig
// ❌ 当前：每个 message 都动态分配
const msg = Message{
    .assistant = response,  // response.content 也是动态分配的数组
};
try self.messages.append(self.allocator, msg);

// Agent 循环 100 次 → 创建 ~300 个 Message 对象
// → 大量内存碎片
```

**推荐方案**:
```zig
pub const Agent = struct {
    message_pool: MessagePool,
    
    pub fn init(allocator: Allocator, options: Options) !Agent {
        return .{
            .message_pool = try MessagePool.init(allocator, 100),  // 预分配 100 个
            // ...
        };
    }
    
    pub fn addMessage(self: *Self, role: Role, content: []const u8) !void {
        const msg = try self.message_pool.acquire();
        msg.* = .{ .role = role, .content = content };
        try self.messages.append(msg);
    }
};
```

---

## 行动计划

### Phase 1: 修复 P0 内存泄漏 (1-2 天)

1. ✅ **worktree.zig 添加 Arena**
   - [ ] 添加 `arena: std.heap.ArenaAllocator` 字段
   - [ ] 实现 `deinit()`
   - [ ] 修复 `execShell` 使用 arena
   - [ ] 运行测试确认无泄漏

2. ✅ **添加 CountingAllocator 测试**
   - [ ] 实现 `utils/counting_allocator.zig`
   - [ ] 为 worktree 添加泄漏测试
   - [ ] 确认泄漏已修复

### Phase 2: 统一 Arena 模式 (3-5 天)

1. ✅ **Agent Loop Arena**
   - [ ] Agent 添加 `loop_arena` 字段
   - [ ] executeOneLoop 使用 arena + defer
   - [ ] 验证性能和内存使用

2. ✅ **检查所有 tool**
   - [ ] 审查 git.zig
   - [ ] 审查其他 tool (grep, ls, etc.)
   - [ ] 统一使用 arena 参数

### Phase 3: 性能优化 (1-2 周)

1. ✅ **MessagePool**
   - [ ] 实现 `agent/message_pool.zig`
   - [ ] Agent 集成 pool
   - [ ] Benchmark 对比

2. ✅ **ToolCallPool**
   - [ ] 实现对象池
   - [ ] 集成到 Agent
   - [ ] 测试高频场景

### Phase 4: 断言密度提升 (持续)

目标：从当前 < 0.5/函数 提升到 ≥ 1.5/函数

---

## 参考资料

1. [TigerBeetle Patterns Analysis](../research/TIGERBEETLE-PATTERNS-ANALYSIS.md)
2. [Zig 0.16 Memory Management Best Practices](https://ziglang.org/documentation/master/)
3. [Arena Allocator Pattern](https://www.rfleury.com/p/untangling-lifetimes-the-arena-allocator)

---

## 附录：检测到的所有内存泄漏点

| 文件 | 函数 | 风险等级 | 描述 |
|------|------|---------|------|
| utils/worktree.zig | execShell | 🔴 高 | std.process.run 返回值未释放 |
| utils/worktree.zig | createWorktree | 🔴 高 | execShell 返回值未释放 |
| utils/worktree.zig | removeWorktree | 🔴 高 | execShell 返回值未释放 |
| utils/worktree.zig | listWorktrees | 🔴 高 | execShell 返回值未释放 |
| agent/agent.zig | Agent 循环 | 🟡 中 | 每轮累积临时对象，无 arena |
| agent/tools/git.zig | runGitCommandArgv | 🟡 中 | 需要检查 |

---

**报告完成日期**: 2026-04-06  
**下次审查**: 2026-04-13 (修复后验证)
