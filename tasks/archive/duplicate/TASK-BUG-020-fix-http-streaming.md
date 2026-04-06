### Task-BUG-020: 修复 HTTP postStream 未实现真正流式处理
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 3h

**描述**:
`src/http.zig` 中的 `postStream` 函数名为"流式"但实际是先收集完整响应再处理，无法实现真正的 SSE 流式响应。这会导致：

1. 延迟问题 - 必须等待完整响应才能开始处理
2. 内存问题 - 大响应会占用大量内存
3. 实时性丧失 - 无法实现真正的流式输出

**当前代码** (http.zig:109-177):
```zig
pub fn postStream(...) !void {
    // 先收集完整 body
    const fetch_result = self.client.fetch(.{
        .response_writer = body_list.writer(),  // 收集到 ArrayList
    });
    
    // 然后才逐行处理
    for (body_list.items) |byte| {
        // 处理每一行...
    }
}
```

**问题**:
真正的 SSE 流式处理应该是边接收边处理，而非先完整 buffer。

**验收标准**:
- [ ] postStream 真正实现边接收边处理
- [ ] 无需完整 body buffer
- [ ] SSE 事件能实时回调

**依赖**:
- Zig 0.16 迁移完成

**阻塞**:
- 实时流式输出体验

**笔记**:
这是体验关键问题。发现于 2026-04-05 代码审查。
