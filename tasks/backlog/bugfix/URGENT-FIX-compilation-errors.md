### URGENT-FIX: 修复项目编译错误
**状态**: pending
**优先级**: P0 - BLOCKING
**创建**: 2026-04-05
**预计耗时**: 30分钟

**描述**:
项目当前无法编译，存在2个致命编译错误，必须立即修复。

**错误列表**:

**错误1**: src/utils/config.zig:250
```
error: use of undeclared identifier 'getApiKey'
const key = getApiKey(&config, "openai");
```

**错误2**: src/http.zig:91
```
error: expected type '?*Io.Writer', found 'Io.GenericWriter(...)'
.response_writer = body_list.writer(self.allocator),
```

**修复方案**:

1. **config.zig:250** - 添加命名空间
```zig
// 修改前
const key = getApiKey(&config, "openai");
const new_key = getApiKey(&config, "openai");
const missing = getApiKey(&config, "unknown");

// 修改后
const key = ConfigManager.getApiKey(&config, "openai");
const new_key = ConfigManager.getApiKey(&config, "openai");
const missing = ConfigManager.getApiKey(&config, "unknown");
```

2. **http.zig:91** - 移除 allocator 参数
```zig
// 修改前
.response_writer = body_list.writer(self.allocator),

// 修改后
.response_writer = body_list.writer(),
```

**验收标准**:
- [ ] `zig build` 成功编译
- [ ] `zig build test` 测试通过
- [ ] 确认没有新的编译警告

**依赖**: 无

**阻塞**: 所有其他开发工作

**笔记**:
这是最高优先级任务，项目目前完全不可用。
