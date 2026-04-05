### TASK-INFRA-009: 实现环境变量访问

**状态**: 已完成 ✅
**完成日期**: 2026-04-05
**实际耗时**: 1小时

**实现内容**:
1. ✅ 修改 `main.zig` 接收完整的 `std.process.Init` 参数
2. ✅ 提取 `environ_map` 并传递给 CLI
3. ✅ 在 `cli/root.zig` 中创建全局环境变量存储
4. ✅ 实现 `getEnvVar` 函数访问环境变量
5. ✅ 修改 `core/root.zig` 的 `getApiKey` 使用新的访问方式
6. ✅ 所有编译错误修复

**代码变更**:

### main.zig
```zig
pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    try cli.run(allocator, init.environ_map, init.minimal.args);
}
```

### cli/root.zig
```zig
// Global environment map storage
var g_environ_map: ?*std.process.Environ.Map = null;

pub fn initEnvVars(environ_map: *std.process.Environ.Map) void {
    g_environ_map = environ_map;
}

pub fn getEnvVar(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    const env_map = g_environ_map orelse return error.NotFound;
    const value = env_map.get(name) orelse return error.NotFound;
    return allocator.dupe(u8, value);
}
```

### core/root.zig
```zig
pub fn getApiKey(allocator: std.mem.Allocator, provider: KnownProvider) ?[]const u8 {
    const env_var = switch (provider) { ... };
    const cli = @import("../cli/root.zig");
    return cli.getEnvVar(allocator, env_var) catch null;
}
```

**使用方法**:
```bash
# 设置环境变量
export OPENAI_API_KEY="your-api-key"

# 运行 kimiz
./zig-out/bin/kimiz
```

**支持的变量**:
- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `GOOGLE_API_KEY`
- `KIMI_API_KEY`
- `FIREWORKS_API_KEY`
- `OPENROUTER_API_KEY`
- `KIMIZ_MODEL`

**编译状态**:
```bash
$ zig build
✅ 成功

$ ./zig-out/bin/kimiz --help
✅ 正常运行
```

**后续优化**:
- 添加环境变量验证
- 支持配置文件覆盖环境变量
- 添加调试日志显示使用了哪个 API Key
