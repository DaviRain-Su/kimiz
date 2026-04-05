### TASK-INFRA-008: 实现完整的 HTTP Client

**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 8小时
**阻塞**: 外部 API 调用功能

**描述**:
当前使用的是简化版 HTTP Client，只返回占位响应。需要实现完整的 HTTP Client 来支持实际的 AI API 调用。

**方案研究**:

### 方案 1: 使用 std.http.Client (推荐)
Zig 0.16 的 `std.http.Client` 需要 `std.Io` 实例。需要：
1. 创建 `std.Io.IoUring` 实例
2. 正确初始化并管理生命周期
3. 处理异步 I/O

**优点**:
- 标准库，无需外部依赖
- 功能完整，支持 HTTPS
- 性能良好

**缺点**:
- 需要复杂的异步 I/O 设置
- API 较新，文档较少

### 方案 2: 使用第三方 HTTP Client 库
搜索社区维护的 HTTP Client 库：
- `zig-fetch` - 简单的 HTTP 客户端
- `zig-network` - 网络库
- `http-client-zig` - 其他实现

**优点**:
- 可能更简单易用
- 可能有更好的文档

**缺点**:
- 需要添加依赖
- 可能不支持 Zig 0.16
- 维护状态不确定

### 方案 3: 自己实现简单的 HTTP Client
基于 POSIX socket 实现基本的 HTTP/1.1 客户端。

**优点**:
- 完全控制实现
- 无外部依赖
- 可以针对需求优化

**缺点**:
- 工作量大
- 需要处理 TLS (HTTPS)
- 需要处理很多边缘情况

**推荐方案**: 方案 1 (std.http.Client)

**实现步骤**:

1. **创建 IoUring 管理器**
```zig
// src/utils/io_manager.zig
pub const IoManager = struct {
    io_uring: std.Io.IoUring,
    
    pub fn init(allocator: std.mem.Allocator) !IoManager {
        var io_uring: std.Io.IoUring = undefined;
        try io_uring.init(allocator);
        return .{ .io_uring = io_uring };
    }
    
    pub fn deinit(self: *IoManager) void {
        self.io_uring.deinit();
    }
    
    pub fn io(self: *IoManager) std.Io {
        return self.io_uring.io();
    }
};
```

2. **重构 HttpClient 使用 std.http.Client**
```zig
// src/http.zig
pub const HttpClient = struct {
    allocator: std.mem.Allocator,
    client: std.http.Client,
    io_manager: *IoManager,
    
    pub fn init(allocator: std.mem.Allocator, io_manager: *IoManager) !HttpClient {
        const io = io_manager.io();
        var client = std.http.Client{
            .allocator = allocator,
            .io = io,
        };
        
        return .{
            .allocator = allocator,
            .client = client,
            .io_manager = io_manager,
        };
    }
    
    // ... 实现 postJson, postStream 等方法
};
```

3. **在 main 中初始化 IoManager**
```zig
// src/main.zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    
    // 初始化 IoManager
    var io_manager = try IoManager.init(allocator);
    defer io_manager.deinit();
    
    // 初始化 HttpClient
    var http_client = try HttpClient.init(allocator, &io_manager);
    defer http_client.deinit();
    
    // ... 其余代码
}
```

**验收标准**:
- [ ] 可以发送 HTTP POST 请求
- [ ] 可以处理 HTTPS (TLS)
- [ ] 支持流式响应 (SSE)
- [ ] 支持自定义 Headers
- [ ] 支持请求超时
- [ ] 错误处理完善
- [ ] 单元测试覆盖 >80%

**依赖**:
- 无

**阻塞**:
- 所有需要调用外部 API 的功能

**参考**:
- Zig 0.16 std.http.Client 源码
- Zig 0.16 std.Io.IoUring 文档
- RFC 7231 (HTTP/1.1)
