### Task-BUG-015: 修复静默错误处理问题
**状态**: completed
**优先级**: P1
**创建**: 2026-04-05
**完成**: 2026-04-05
**预计耗时**: 3h
**实际耗时**: 1h

**描述**:
代码中多处使用 `catch {}` 或 `catch null` 静默忽略错误，这会导致问题难以调试，系统行为不可预测。

**问题位置**:

1. **src/ai/providers/anthropic.zig:125**
```zig
try http_client.postStream(url, headers.items, request_body, struct {
    fn onLine(line: []const u8, ctx_ptr: *StreamContext) void {
        ctx_ptr.processLine(line) catch {};  // ❌ 错误被静默忽略
    }
}.onLine);
```

2. **src/ai/providers/google.zig:73**
```zig
fn processLine(line: []const u8, callback: *const fn (event: ai.SseEvent) void) !void {
    // ...
    const parsed = try std.json.parseFromSlice(GoogleStreamChunk, std.heap.page_allocator, line, .{});
    defer parsed.deinit(std.heap.page_allocator);
    // 解析错误被忽略
}
```

3. **src/ai/providers/kimi.zig:148**
```zig
try http_client.postStream(url, headers.items, request_body, struct {
    fn onLine(line: []const u8) void {
        processLine(line, callback) catch {};  // ❌ 静默忽略
    }
}.onLine);
```

4. **src/agent/agent.zig:166**
```zig
const result = agent_tool.execute(arena.allocator(), parsed.value) catch |err| {
    return ToolResult{
        .content = &[_]tool_mod.UserContentBlock{.{ .text = @errorName(err) }},
        .is_error = true,
    };
};
```

5. **src/memory/root.zig** (多处)
```zig
// 文件操作错误被忽略
std.fs.cwd().makeDir(dir) catch |err| switch (err) {
    error.PathAlreadyExists => {},
    error.FileNotFound => {}, // ❌ 其他错误被忽略
    else => return err,  // 只有 else 分支返回错误
};
```

**修复方案**:

1. **添加错误日志**
```zig
// 修改前
ctx_ptr.processLine(line) catch {};

// 修改后
ctx_ptr.processLine(line) catch |err| {
    log.err("Failed to process SSE line: {s}", .{@errorName(err)});
};
```

2. **使用 try 传播错误**
```zig
// 修改前
const parsed = std.json.parseFromSlice(...) catch null;
if (parsed) |p| { ... }

// 修改后
const parsed = try std.json.parseFromSlice(...);
defer parsed.deinit();
```

3. **区分可忽略和不可忽略的错误**
```zig
std.fs.cwd().makeDir(dir) catch |err| switch (err) {
    error.PathAlreadyExists => {}, // 可忽略
    error.FileNotFound => return error.ParentDirNotFound, // 不可忽略
    else => return err, // 其他错误传播
};
```

**需要修改的文件**:
- [ ] src/ai/providers/anthropic.zig
- [ ] src/ai/providers/google.zig
- [ ] src/ai/providers/kimi.zig
- [ ] src/ai/providers/openai.zig
- [ ] src/agent/agent.zig
- [ ] src/memory/root.zig
- [ ] src/learning/root.zig

**验收标准**:
- [ ] 所有 `catch {}` 被替换为带日志的版本
- [ ] 关键错误正确传播
- [ ] 添加适当的错误日志
- [ ] 编译通过，测试通过

**依赖**:
- URGENT-FIX-compilation-errors
- TASK-BUG-013-fix-page-allocator-abuse (可选，建议先完成)

**阻塞**:
- 无直接阻塞，但影响调试效率

**笔记**:
这是一个代码质量改进任务。虽然不会立即导致功能问题，但对长期维护至关重要。
