### Task-BUG-003: 修复 URL 分配错误路径内存泄漏
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**开始**: 
**完成**: 
**耗时**: 

**描述**:
在 OpenAI 和 Google provider 中，URL 字符串使用 `allocPrint` 分配，但 `defer` 释放语句放在 `try` 语句之后，导致如果 `http_client.postJson` 失败，URL 不会被释放。

**受影响的文件**:
1. `src/ai/providers/openai.zig` 第 98 行
2. `src/ai/providers/google.zig` 第 111 行

**问题代码**:
```zig
const url = try std.heap.page_allocator.allocPrint(...);
// defer 应该在这里
const response = try http_client.postJson(...); // 如果这里失败，url 泄漏
defer std.heap.page_allocator.free(url); // 但 defer 在这里
```

**修复方案**:
将 `defer` 语句移到 `try` 语句之前：
```zig
const url = try std.heap.page_allocator.allocPrint(...);
defer std.heap.page_allocator.free(url);
const response = try http_client.postJson(...);
```

**验收标准**:
- [ ] 修复 OpenAI provider 的 defer 位置
- [ ] 修复 Google provider 的 defer 位置
- [ ] 检查所有 provider 是否有同样模式
- [ ] 添加错误路径测试

**依赖**:
- 无

**相关文件**:
- `src/ai/providers/openai.zig`
- `src/ai/providers/google.zig`

**笔记**:
