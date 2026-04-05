# Zig 0.16 迁移任务清单

> 基于 Zig 0.16.0-dev.2261+d6b3dd25a 的破坏性变更整理
> 参考: `docs/11-zig-0.16-migration-guide.md` (详细指南)
> 参考: `docs/ZIG-0.16-BREAKING-CHANGES-SUMMARY.md` (速查表)

---

## 🔴 紧急: 当前编译错误 (立即修复)

### 错误 1: ArrayList.writer() API 变更

**文件**: `src/http.zig:91`

```zig
// ❌ 当前代码 (0.15)
.response_writer = body_list.writer(self.allocator),

// ✅ 修复 (0.16)
.response_writer = body_list.writer(), // 不再需要 allocator
```

**任务**:
- [ ] **TASK-0.1**: 修复 `src/http.zig:91` 的 ArrayList.writer() 调用

### 错误 2: 函数调用命名空间

**文件**: `src/utils/config.zig:250`

```zig
// ❌ 当前代码
const key = getApiKey(&config, "openai");

// ✅ 修复
const key = ConfigManager.getApiKey(&config, "openai");
```

**任务**:
- [ ] **TASK-0.2**: 修复 `src/utils/config.zig` 中的静态方法调用

---

## 🔴 阶段 1: Build 系统迁移 (30分钟)

### 1.1 build.zig 更新

**关键变更**:
- `exe.linkLibC()` → `mod.link_libc = true`
- `exe.addCSourceFiles()` → `exe.root_module.addCSourceFiles()`
- `mod.linkSystemLibrary()` → 需要空参数 `.{}`
- `run.captureStdOut()` → 需要空参数 `.{}`

**任务**:
- [ ] **TASK-1.1**: 更新 `build.zig` 中的 linkLibC 调用
- [ ] **TASK-1.2**: 更新 addCSourceFiles 调用
- [ ] **TASK-1.3**: 更新 linkSystemLibrary 调用（添加空参数）
- [ ] **TASK-1.4**: 更新 captureStdOut 调用（添加空参数）

**验证**:
```bash
zig build --help  # 应该正常显示帮助
```

---

## 🔴 阶段 2: main() 函数迁移 (30分钟)

### 2.1 签名变更

**文件**: `src/main.zig`

```zig
// ❌ 旧签名 (0.15)
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    // ...
}

// ✅ 新签名 (0.16)
pub fn main(init: std.process.Init) !u8 {
    const allocator = init.gpa;  // 直接使用提供的 GPA
    const io = init.io;          // I/O 实例
    const env_map = init.environ_map;  // 环境变量
    
    // 参数处理
    var argv = try init.minimal.args.toSlice(init.gpa);
    defer init.gpa.free(argv);
    
    // 业务逻辑
    try cli.run(allocator, io);
    
    return 0;  // 返回 exit code
}
```

**任务**:
- [ ] **TASK-2.1**: 修改 `src/main.zig` 的 main 函数签名
- [ ] **TASK-2.2**: 更新参数解析逻辑
- [ ] **TASK-2.3**: 确保返回 u8 exit code

### 2.2 CLI 入口更新

**文件**: `src/cli/root.zig`

```zig
// ❌ 旧签名
pub fn main() !void { }

// ✅ 新签名
pub fn run(allocator: std.mem.Allocator, io: std.Io) !void {
    // 使用传入的 io 实例
}
```

**任务**:
- [ ] **TASK-2.4**: 更新 `src/cli/root.zig` 的 run 函数签名
- [ ] **TASK-2.5**: 确保所有 I/O 操作使用传入的 io 实例

---

## 🔴 阶段 3: CLI I/O 修复 (1-2小时)

### 3.1 stdout/stdin API 修复

**当前问题**: `src/cli/root.zig` 中有 10+ 处使用了错误的 API

```zig
// ❌ 错误代码 (多处)
var stdout_buf: [4096]u8 = undefined;
var stdout_file = std.fs.File.stdout().writer(&stdout_buf);
const stdout = &stdout_file.interface;

// ✅ 正确代码 (0.16)
const stdout_file = std.io.getStdOut().writer();
// 或使用 buffered writer:
var stdout_buf = std.io.bufferedWriter(std.io.getStdOut().writer());
const stdout = stdout_buf.writer();
```

**受影响的函数**:
- `runRepl()` - 多处 stdout/stdin 使用
- `runTui()`
- `runOnce()`
- `runConfig()`
- `processInput()`
- `printHelp()`
- `printReplHelp()`
- `printVersion()`

**任务**:
- [ ] **TASK-3.1**: 修复 `runRepl()` 中的 stdout 初始化
- [ ] **TASK-3.2**: 修复 `runRepl()` 中的 stdin 读取逻辑
- [ ] **TASK-3.3**: 修复 `runTui()` 中的 stdout
- [ ] **TASK-3.4**: 修复 `runOnce()` 中的 stdout
- [ ] **TASK-3.5**: 修复 `runConfig()` 中的 stdout
- [ ] **TASK-3.6**: 修复 `processInput()` 中的 stdout
- [ ] **TASK-3.7**: 修复 `printHelp()` 中的 stdout
- [ ] **TASK-3.8**: 修复 `printReplHelp()` 中的 stdout
- [ ] **TASK-3.9**: 修复 `printVersion()` 中的 stdout

### 3.2 stdin 读取优化

```zig
// ❌ 当前: 逐字节读取
var line_buf: std.ArrayList(u8) = .empty;
while (true) {
    const byte = in_reader.readByte() catch break;
    if (byte == '\n') break;
    try line_buf.append(allocator, byte);
}

// ✅ 优化: 使用 bufferedReader
var stdin_buf = std.io.bufferedReader(std.io.getStdIn().reader());
const stdin = stdin_buf.reader();
var line_buf: [1024]u8 = undefined;
const line = try stdin.readUntilDelimiterOrEof(&line_buf, '\n');
```

**任务**:
- [ ] **TASK-3.10**: 优化 `runRepl()` 的输入读取逻辑

---

## 🔴 阶段 4: HTTP 客户端迁移 (1-2小时)

### 4.1 ArrayList 初始化

**文件**: `src/http.zig`

```zig
// ❌ 旧代码
var body_list: std.ArrayList(u8) = .empty;

// ✅ 新代码 (0.16)
var body_list: std.ArrayList(u8) = .empty;  // 相同，但确保理解语义
```

### 4.2 HTTP Client 更新

```zig
pub const HttpClient = struct {
    allocator: std.mem.Allocator,
    client: std.http.Client,
    // 可能需要 io 实例
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .client = .{ .allocator = allocator },
        };
    }
    
    pub fn postJson(
        self: *Self,
        url: []const u8,
        headers: []const std.http.Header,
        body: []const u8,
    ) !Response {
        // ... 更新 fetch 调用
        const fetch_result = self.client.fetch(.{
            .location = .{ .uri = uri },
            .method = .POST,
            .extra_headers = headers,
            .payload = body,
            .response_writer = body_list.writer(),  // ✅ 无需 allocator
        }) catch return AiError.HttpRequestFailed;
    }
};
```

**任务**:
- [ ] **TASK-4.1**: 修复 `src/http.zig:91` 的 writer 调用
- [ ] **TASK-4.2**: 检查 `std.http.Client` API 是否有变化
- [ ] **TASK-4.3**: 测试 HTTP 请求功能

---

## 🔴 阶段 5: 文件 I/O 迁移 (1-2小时)

### 5.1 配置文件操作

**文件**: `src/utils/config.zig`

```zig
// ❌ 旧代码 (0.15)
const content = std.fs.cwd().readFileAlloc(
    self.allocator,
    self.config_path,
    1024 * 1024,
);

// ✅ 新代码 (0.16)
pub fn load(self: *ConfigManager, io: std.Io) !Config {
    const dir = std.Io.Dir.cwd();
    const content = try dir.readFileAlloc(
        io,
        self.allocator,
        self.config_path,
        1024 * 1024,
    );
    // ...
}
```

**任务**:
- [ ] **TASK-5.1**: 更新 `ConfigManager.load()` 添加 io 参数
- [ ] **TASK-5.2**: 更新 `ConfigManager.save()` 添加 io 参数
- [ ] **TASK-5.3**: 更新文件路径处理

### 5.2 其他文件操作

**文件**:
- `src/utils/session.zig`
- `src/utils/log.zig`

**任务**:
- [ ] **TASK-5.4**: 更新 `session.zig` 的文件操作
- [ ] **TASK-5.5**: 更新 `log.zig` 的文件操作

---

## 🟡 阶段 6: 网络 I/O 迁移 (可选, 1-2小时)

### 6.1 DNS 查询

如果需要直接使用网络 API：

```zig
// ❌ 旧代码
const result = try std.net.getAddressList(allocator, "example.com", 80);

// ✅ 新代码
const hostname: std.Io.net.HostName = try .init("example.com");
var elem_buf: [16]std.Io.net.HostName.LookupResult = undefined;
var queue: std.Io.Queue(std.Io.net.HostName.LookupResult) = .init(&elem_buf);
// ... 异步查询
```

**注意**: 如果只用 `std.http.Client`，可能不需要直接修改网络代码。

**任务**:
- [ ] **TASK-6.1**: 评估是否需要直接网络 API
- [ ] **TASK-6.2**: 如有需要，迁移 DNS 查询代码
- [ ] **TASK-6.3**: 如有需要，迁移 TCP 连接代码

---

## 🟡 阶段 7: AI Provider 更新 (30分钟)

### 7.1 API Key 管理

**文件**: `src/ai/providers/*.zig`

当前已经添加了 `defer std.heap.page_allocator.free(api_key)`，但需要确保：

```zig
const api_key = core.getApiKey(.openai) orelse return core.AiError.ApiKeyNotFound;
defer std.heap.page_allocator.free(api_key);  // ✅ 已添加
```

**任务**:
- [ ] **TASK-7.1**: 检查所有 provider 的 API key 内存管理
- [ ] **TASK-7.2**: 测试 provider 初始化

---

## 🟢 阶段 8: 测试和验证 (1-2小时)

### 8.1 编译测试

**任务**:
- [ ] **TASK-8.1**: 运行 `zig build` 确保编译通过
- [ ] **TASK-8.2**: 运行 `zig build test` 确保测试通过

### 8.2 功能测试

**任务**:
- [ ] **TASK-8.3**: 测试 CLI help 命令
- [ ] **TASK-8.4**: 测试 REPL 模式启动
- [ ] **TASK-8.5**: 测试配置文件读写
- [ ] **TASK-8.6**: 测试 HTTP 请求（如有网络）

### 8.3 回归测试

**任务**:
- [ ] **TASK-8.7**: 对比 0.15 和 0.16 版本的行为一致性
- [ ] **TASK-8.8**: 性能基准测试（可选）

---

## 📋 快速检查清单

### 编译前检查
- [ ] 所有 `ArrayList.writer(allocator)` 已改为 `ArrayList.writer()`
- [ ] 所有 `std.fs.File` 已改为 `std.Io.File`
- [ ] 所有文件操作已添加 `io` 参数
- [ ] `main()` 函数签名已更新
- [ ] `build.zig` 已更新

### 编译后检查
- [ ] `zig build` 成功
- [ ] `zig build test` 成功
- [ ] CLI 可以启动
- [ ] REPL 模式可以进入
- [ ] 配置文件可以读写

---

## 🔗 相关文档

- **详细迁移指南**: `docs/11-zig-0.16-migration-guide.md`
- **速查表**: `docs/ZIG-0.16-BREAKING-CHANGES-SUMMARY.md`
- **迁移示例**: `docs/migration-examples.md`
- **I/O Helper**: `src/utils/io_helper.zig` (我创建的辅助模块)

---

## ⏱️ 时间估算

| 阶段 | 预计时间 | 优先级 |
|------|---------|--------|
| 阶段 0: 修复编译错误 | 15分钟 | 🔴 P0 |
| 阶段 1: Build 系统 | 30分钟 | 🔴 P0 |
| 阶段 2: main() 迁移 | 30分钟 | 🔴 P0 |
| 阶段 3: CLI I/O | 1-2小时 | 🔴 P0 |
| 阶段 4: HTTP 客户端 | 1小时 | 🔴 P0 |
| 阶段 5: 文件 I/O | 1-2小时 | 🔴 P0 |
| 阶段 6: 网络 I/O | 1-2小时 | 🟡 P1 |
| 阶段 7: Provider 更新 | 30分钟 | 🟡 P1 |
| 阶段 8: 测试验证 | 1-2小时 | 🟢 P2 |
| **总计** | **6-10小时** | - |

---

## 🎯 下一步行动

1. **立即**: 修复 2 个编译错误（TASK-0.1, TASK-0.2）
2. **今天**: 完成阶段 1-3（Build + main + CLI）
3. **本周**: 完成阶段 4-5（HTTP + 文件 I/O）
4. **下周**: 完成测试验证

---

**当前状态**: 🔴 阻塞 - 有 2 个编译错误需要立即修复
**当前 Zig 版本**: 0.16.0-dev.2261+d6b3dd25a
**目标**: 在 Zig 0.16 上成功编译和运行
