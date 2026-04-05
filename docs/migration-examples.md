# Zig 0.16 迁移示例

本文档展示如何将现有代码从 Zig 0.15 迁移到 0.16。

## 示例 1: CLI 文件 I/O

### 旧代码 (0.15)

```zig
// src/cli/root.zig - 旧版本
const std = @import("std");

fn runRepl(allocator: std.mem.Allocator, options: CliOptions) !void {
    const stdout_file = std.fs.File{ .handle = std.fs.File.STDOUT_FILENO };
    const stdout = stdout_file.writer();
    const stdin_file = std.fs.File{ .handle = std.fs.File.STDIN_FILENO };
    const stdin = stdin_file.reader();

    try stdout.print("kimiz v0.1.0 - AI Coding Agent\n", .{});
    try stdout.print("Type 'exit' or 'quit' to exit, 'help' for commands.\n\n", .{});

    while (true) {
        try stdout.print("> ", .{});

        // Read line using buffered reader
        var line_buf: std.ArrayList(u8) = .empty;
        defer line_buf.deinit(allocator);

        var in_reader = stdin;
        while (true) {
            const byte = in_reader.readByte() catch break;
            if (byte == '\n') break;
            try line_buf.append(allocator, byte);
        }

        const input = std.mem.trim(u8, line_buf.items, " \t\r\n");
        // ... 处理输入
    }
}
```

### 新代码 (0.16)

```zig
// src/cli/root.zig - 新版本
const std = @import("std");
const io_helper = @import("../utils/io_helper.zig");

fn runRepl(allocator: std.mem.Allocator, io: std.Io, options: CliOptions) !void {
    // 创建缓冲 stdout
    var stdout_buf: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &stdout_buf);
    
    // 创建缓冲 stdin
    var stdin_buf: [4096]u8 = undefined;
    var stdin = std.Io.File.stdin().reader(io, &stdin_buf);

    // 使用 interface 进行打印
    try stdout.interface.print("kimiz v0.1.0 - AI Coding Agent\n", .{});
    try stdout.interface.print("Type 'exit' or 'quit' to exit, 'help' for commands.\n\n", .{});
    try stdout.flush();

    while (true) {
        try stdout.interface.print("> ", .{});
        try stdout.flush();

        // 读取行
        var line_buf = std.ArrayList.Managed(u8).init(allocator);
        defer line_buf.deinit();

        while (true) {
            const byte = stdin.interface.readByte() catch |err| switch (err) {
                error.EndOfStream => break,
                else => return err,
            };
            if (byte == '\n') break;
            try line_buf.append(byte);
        }

        const input = std.mem.trim(u8, line_buf.items, " \t\r\n");
        // ... 处理输入
    }
}
```

### 使用 Io Helper 模块的简化版本

```zig
// src/cli/root.zig - 使用 helper 模块
const std = @import("std");
const io_helper = @import("../utils/io_helper.zig");

fn runRepl(allocator: std.mem.Allocator, io: std.Io, options: CliOptions) !void {
    var stdout = io_helper.BufferedStdout.init(io);
    var stdin = io_helper.BufferedStdin.init(io);

    try stdout.print("kimiz v0.1.0 - AI Coding Agent\n", .{});
    try stdout.print("Type 'exit' or 'quit' to exit, 'help' for commands.\n\n", .{});
    try stdout.flush();

    while (true) {
        try stdout.print("> ", .{});
        try stdout.flush();

        if (try stdin.readLine(allocator)) |line| {
            defer allocator.free(line);
            const input = std.mem.trim(u8, line, " \t\r\n");
            // ... 处理输入
        } else {
            break; // EOF
        }
    }
}
```

---

## 示例 2: HTTP 客户端

### 旧代码 (0.15)

```zig
// src/http.zig - 旧版本
pub const HttpClient = struct {
    allocator: std.mem.Allocator,
    client: std.http.Client,
    retry_count: u3 = 3,
    timeout_ms: u32 = 30000,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .client = .{ .allocator = allocator },
        };
    }

    pub fn deinit(self: *Self) void {
        self.client.deinit();
    }

    pub fn postJson(
        self: *Self,
        url: []const u8,
        headers: []const std.http.Header,
        body: []const u8,
    ) !Response {
        const uri = std.Uri.parse(url) catch return AiError.HttpRequestFailed;

        var body_list: std.ArrayList(u8) = .empty;
        errdefer body_list.deinit(self.allocator);

        const fetch_result = self.client.fetch(.{
            .location = .{ .uri = uri },
            .method = .POST,
            .extra_headers = headers,
            .payload = body,
            .response_writer = body_list.writer(self.allocator),
        }) catch return AiError.HttpRequestFailed;

        // ...
    }
};
```

### 新代码 (0.16)

```zig
// src/http.zig - 新版本
pub const HttpClient = struct {
    allocator: std.mem.Allocator,
    client: std.http.Client,
    io: std.Io,  // 需要 Io 实例
    retry_count: u3 = 3,
    timeout_ms: u32 = 30000,

    pub fn init(allocator: std.mem.Allocator, io: std.Io) Self {
        return .{
            .allocator = allocator,
            .client = .{ .allocator = allocator },
            .io = io,
        };
    }

    pub fn deinit(self: *Self) void {
        self.client.deinit();
    }

    pub fn postJson(
        self: *Self,
        url: []const u8,
        headers: []const std.http.Header,
        body: []const u8,
    ) !Response {
        const uri = std.Uri.parse(url) catch return AiError.HttpRequestFailed;

        // ArrayList 初始化变化
        var body_list = std.ArrayList.Managed(u8).init(self.allocator);
        errdefer body_list.deinit();

        // 注意: response_writer 的 API 可能也有变化
        // 需要检查 std.http.Client.fetch 的新签名
        const fetch_result = self.client.fetch(.{
            .location = .{ .uri = uri },
            .method = .POST,
            .extra_headers = headers,
            .payload = body,
            // .response_writer 可能需要调整
        }) catch return AiError.HttpRequestFailed;

        // ...
    }
};
```

---

## 示例 3: 配置文件读写

### 旧代码 (0.15)

```zig
// src/utils/config.zig - 旧版本
pub fn save(self: *ConfigManager, config: *const Config) !void {
    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    var writer = fbs.writer();
    
    try writer.print("{{\n", .{});
    try writer.print("  \"default_model\": \"{s}\",\n", .{config.default_model});
    // ...
    
    const file = try std.fs.cwd().createFile(self.config_path, .{});
    defer file.close();
    try file.writeAll(fbs.getWritten());
}
```

### 新代码 (0.16)

```zig
// src/utils/config.zig - 新版本
pub fn save(self: *ConfigManager, io: std.Io, config: *const Config) !void {
    // 使用 Io.Writer.fixed 替代 fixedBufferStream
    var buf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    
    // 通过 interface 访问 print
    try writer.interface.print("{{\n", .{});
    try writer.interface.print("  \"default_model\": \"{s}\",\n", .{config.default_model});
    // ...
    
    // 文件操作需要 Io 实例
    var file = try std.Io.File.create(io, self.config_path, .{});
    defer file.close(io);
    
    // 写入文件
    var file_buf: [4096]u8 = undefined;
    var file_writer = file.writer(io, &file_buf);
    
    // 将缓冲区的内容写入文件
    const content = writer.buffered();
    try file_writer.interface.writeAll(content);
    try file_writer.flush();
}
```

---

## 示例 4: 主函数初始化

### 旧代码 (0.15)

```zig
// src/main.zig - 旧版本
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    try cli.run(allocator);
}
```

### 新代码 (0.16)

```zig
// src/main.zig - 新版本
const std = @import("std");
const cli = @import("cli/root.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // 初始化 I/O 系统
    var threaded = std.Io.Threaded.init(allocator, .{
        .argv0 = .init(std.os.argv),
        .environ = std.os.environ,
    });
    defer threaded.deinit();
    const io = threaded.io();
    
    // 传递 Io 实例
    try cli.run(allocator, io);
}
```

---

## 关键变化总结

### 1. I/O 初始化

每个需要 I/O 的程序都需要创建一个 `std.Io` 实例：

```zig
// 选项 1: Threaded I/O (默认)
var threaded = std.Io.Threaded.init(allocator, .{
    .argv0 = .init(argv),
    .environ = environ,
});
defer threaded.deinit();
const io = threaded.io();

// 选项 2: Evented I/O (io_uring/GCD - 实验性)
var evented: std.Io.Evented = undefined;
try evented.init(allocator, .{
    .argv0 = .init(argv),
    .environ = environ,
    .backing_allocator_needs_mutex = false,
});
defer evented.deinit();
const io = evented.io();
```

### 2. 文件操作

```zig
// 获取标准流
const stdout_file = std.Io.File.stdout();
const stderr_file = std.Io.File.stderr();
const stdin_file = std.Io.File.stdin();

// 创建 writer/reader
var buf: [4096]u8 = undefined;
var writer = stdout_file.writer(io, &buf);
var reader = stdin_file.reader(io, &buf);

// 使用 interface 进行 I/O
try writer.interface.print("Hello {s}\n", .{"world"});
try writer.flush();
```

### 3. ArrayList 变化

```zig
// Managed (拥有分配器)
var list = std.ArrayList.Managed(u8).init(allocator);
defer list.deinit();
try list.append(item);

// Unmanaged (需要传递分配器)
var list = std.ArrayList.Unmanaged(u8).init(allocator);
defer list.deinit(allocator);
try list.append(allocator, item);
```

### 4. 错误处理

新的 I/O 系统引入了取消机制：

```zig
// 某些 I/O 操作可能返回 Cancelable 错误
const result = someIoOperation() catch |err| switch (err) {
    error.Canceled => // 操作被取消
    error.Timeout => // 操作超时
    else => // 其他错误
};
```

---

## 迁移检查清单

- [ ] 确定 I/O 策略（Threaded vs Evented）
- [ ] 在主函数中初始化 Io 实例
- [ ] 将 Io 实例传递给所有需要 I/O 的函数
- [ ] 更新所有文件操作代码
- [ ] 更新 ArrayList 初始化
- [ ] 更新 writer/reader 使用方式
- [ ] 测试所有 I/O 路径
- [ ] 处理新的错误类型（Canceled, Timeout 等）
