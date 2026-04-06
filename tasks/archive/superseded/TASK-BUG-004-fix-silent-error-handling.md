### TASK-BUG-004: 修复静默错误处理问题
**状态**: pending
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 2h

**描述**:
多个文件中使用 `catch {}` 或 `catch break` 静默吞掉错误，导致问题难以调试。

**受影响的文件**:

1. **src/http.zig:98** - postJsonOnce
```zig
// 问题代码
const n = reader.read(buffer) catch break;
// 如果 read 失败，会返回不完整的 JSON
```

2. **src/http.zig:165** - postStream
```zig
// 问题代码
const n = reader.read(line_buf[line_len..]) catch break;
// SSE 流中断但不报错
```

3. **src/agent/agent.zig:264** - getToolDefinitions
```zig
// 问题代码
tools.append(self.allocator, core_tool) catch {};
// 内存分配失败被忽略
```

4. **所有 Provider 的 SSE 处理**
   - src/ai/providers/openai.zig:225
   - src/ai/providers/anthropic.zig:252
   - src/ai/providers/google.zig:145
   - src/ai/providers/kimi.zig:162
```zig
// 问题模式
processLine(...) catch {};
// JSON 解析错误被忽略
```

**修复方案**:

1. **HTTP 客户端** - 返回错误而不是静默中断
```zig
// 修改后
const n = reader.read(buffer) catch |err| {
    log.err("Failed to read response: {}", .{err});
    return AiError.HttpRequestFailed;
};
```

2. **Agent 工具** - 至少记录错误
```zig
// 修改后
tools.append(self.allocator, core_tool) catch |err| {
    log.warn("Failed to append tool {s}: {}", .{core_tool.name, err});
    continue;
};
```

3. **Provider SSE** - 记录解析错误
```zig
// 修改后
processLine(...) catch |err| {
    log.warn("SSE parse error: {}", .{err});
};
```

**验收标准**:
- [ ] 移除所有 `catch {}` 空处理
- [ ] 关键错误路径返回错误或记录日志
- [ ] 添加错误处理测试
- [ ] 更新错误处理文档

**依赖**: 
- T-008 (日志系统已完成)

**相关文件**:
- src/http.zig
- src/agent/agent.zig
- src/ai/providers/*.zig

**笔记**:
这是代码质量问题，会影响调试和问题诊断。
