### T-003: 实现 HTTP 客户端封装
**状态**: blocked
**优先级**: P0
**创建**: 2026-04-05
**完成**: 2026-04-05
**预计耗时**: 3h
**实际耗时**: 4h

**描述**:
封装 std.http.Client，提供统一的 HTTP 请求接口，支持重试、超时、错误处理。

**文件**:
- `src/http.zig`

**功能**:
- [x] POST/GET 请求 (通过 fetch API)
- [x] 自动重试机制
- [x] 超时控制
- [x] 错误码映射
- [x] 流式响应支持

**验收标准**:
- [x] HTTP GET/POST 正常工作
- [x] 重试机制测试通过
- [x] 超时处理正确
- [x] 错误映射准确

**依赖**: T-001

**阻塞原因**:
- 编译错误: src/http.zig:91 - ArrayList.writer() API 使用错误
- 需要修复: URGENT-FIX-compilation-errors

**笔记**:
使用 std.http.Client.fetch API 实现，支持重试和流式响应。
