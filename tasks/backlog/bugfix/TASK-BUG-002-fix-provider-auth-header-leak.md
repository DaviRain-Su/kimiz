### Task-BUG-002: 修复 AI Provider 内存泄漏 (Authorization Header)
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**开始**: 
**完成**: 
**耗时**: 

**描述**:
多个 AI Provider 中，Authorization header 使用 `allocPrint` 分配内存但从未释放，导致每次请求都会泄漏内存。

**受影响的文件**:
1. `src/ai/providers/openai.zig` 第 75 行
2. `src/ai/providers/kimi.zig` 第 131 行

**问题代码模式**:
```zig
const auth_header = try std.heap.page_allocator.allocPrint(
    "Bearer {s}",
    .{api_key},
);
// 从未释放 auth_header
```

**修复方案**:
1. 使用请求级别的 arena allocator
2. 或者在请求完成后统一释放 headers
3. 或者改用栈上分配的缓冲区（如果 key 长度有限）

**验收标准**:
- [ ] 修复 OpenAI provider 内存泄漏
- [ ] 修复 Kimi provider 内存泄漏
- [ ] 检查其他 providers 是否有同样问题
- [ ] 添加内存使用测试

**依赖**:
- 无

**相关文件**:
- `src/ai/providers/openai.zig`
- `src/ai/providers/kimi.zig`

**笔记**:
