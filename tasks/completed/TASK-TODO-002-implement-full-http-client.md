# TASK-TODO-002: 实现完整 HTTP 客户端

**状态**: pending  
**优先级**: P0  
**类型**: Infrastructure  
**预计耗时**: 8小时  
**阻塞**: 所有外部 API 调用

## 描述

当前 HTTP 客户端是简化版，使用 POSIX sockets 直接实现。需要完整的 HTTP/HTTPS 客户端支持。

## 受影响的文件

- **src/http.zig**
  - `postJson()` (第 50 行) - TODO: Implement sleep for Zig 0.16
  - `postJsonOnce()` (第 76 行) - TODO: Implement actual HTTP request using POSIX sockets

## 当前问题

1. 重试逻辑中的 `std.time.sleep()` 被移除
2. HTTP 请求实现不完整
3. 缺少 HTTPS/TLS 支持
4. 缺少连接池和重用

## 实现方案

### 方案 1: 使用 std.http.Client (推荐)
```zig
var client = std.http.Client{
    .allocator = allocator,
    .io = io,  // 需要 std.Io 实例
};
```

### 方案 2: 使用外部 HTTP 库
- 调研 zig 生态中的 HTTP 客户端库
- 如: zig-network, zig-http 等

### 方案 3: 完善 POSIX 实现
- 实现完整的 HTTP/1.1 协议
- 添加 TLS 支持 (使用 bearssl 或 openssl)

## 验收标准

- [ ] 完整的 HTTP/1.1 支持
- [ ] HTTPS/TLS 支持
- [ ] 连接池和重用
- [ ] 请求/响应头处理
- [ ] Cookie 支持
- [ ] 重定向跟随
- [ ] 超时处理
- [ ] 流式响应支持 (SSE)

## 依赖

- TASK-INFRA-008 (IoManager 实现)
- Zig 0.16 std.http.Client 研究

## 相关任务

- TASK-INFRA-008
- TASK-BUG-018 (HTTP 流式处理)
