# NullClaw 可直接借鉴清单 — KimiZ 快速参考

**来源**: [nullclaw/nullclaw](https://github.com/nullclaw/nullclaw) (7.1k stars)  
**核心原则**: 借鉴工程实现，不借鉴 Prompt-based skill 模式  

---

## 1. JSON Mini Parser — 最值得立刻移植

**文件**: `src/json_miniparse.zig`

**作用**: 从大块 JSON 中**零分配**地快速提取单个字段。

```zig
// 不需要解析整个 JSON 树，直接定位和提取
pub fn parseStringField(json: []const u8, key: []const u8) ?[]const u8;
pub fn parseUintField(json: []const u8, key: []const u8) ?u64;
pub fn parseBoolField(json: []const u8, key: []const u8) ?bool;
```

**对 KimiZ 的价值**:
- LLM 返回的 tool_call JSON 通常很大，但只需要提取 `name` 和 `arguments`
- 比 `std.json.parseFromSlice` 快数倍，且零堆分配
- 适合高频调用的热路径

**建议**: **T-108: 移植 json_miniparse**（4h，立刻做）

---

## 2. Bootstrap Provider 模式 — 存储抽象的模板

**文件**: `src/bootstrap/provider.zig`

**作用**: 用 vtable 统一抽象多种后端存储。

```zig
pub const BootstrapProvider = struct {
    load:   *const fn (ctx: *anyopaque, allocator: Allocator, filename: []const u8) error{...}!?[]u8,
    store:  *const fn (ctx: *anyopaque, filename: []const u8, content: []const u8) error{...}!void,
    deinit: *const fn (ctx: *anyopaque) void,
    // ...
};

// 实现：FileBootstrapProvider / MemoryBootstrapProvider / NullBootstrapProvider
```

**对 KimiZ 的价值**:
- `SessionStore`（会话持久化）可以抽象为 `SessionProvider`
- `SkillStore`（skill 存储）可以抽象为 `SkillProvider`
- `ConfigStore` 也可以走同样模式
- 一份接口，支持磁盘/SQLite/Redis/内存多种后端

**建议**: **T-109: 设计 Provider 抽象用于 Session 和 Skill 存储**（8h）

---

## 3. Memory 引擎注册表 — 工厂模式的标准写法

**文件**: `src/memory/engines/registry.zig`

**作用**: 编译时注册所有后端，运行时按名字查找。

```zig
pub const known_backend_names = [_][]const u8{
    "none", "hybrid", "markdown", "sqlite", "postgres", "redis"
};

pub fn findBackend(name: []const u8) ?BackendCtor {
    inline for (known_backends) |backend| {
        if (std.mem.eql(u8, backend.name, name)) return backend.ctor;
    }
    return null;
}
```

**对 KimiZ 的价值**:
- 如果 KimiZ 未来支持多种 LLM provider 后端或多种 memory 后端，这是最佳模板
- 比 `switch` 字符串匹配更优雅，新增后端只需改数组

**建议**: 在 T-101 `AutoRegistry` 和 T-109 `Provider` 中参考使用

---

## 4. Subagent 系统 — 后台任务的线程隔离

**文件**: `src/subagent.zig`, `src/subagent_runner.zig`

**作用**: 用独立的 OS 线程运行后台 agent，避免阻塞主循环。

```zig
pub const SubagentManager = struct {
    pub fn spawn(self: *SubagentManager, task: []const u8, ...) !u64 {
        // 在独立 OS 线程中运行
        state.thread = try std.Thread.spawn(
            .{ .stack_size = thread_stacks.HEAVY_RUNTIME_STACK_SIZE },
            subagentThreadFn,
            .{ctx}
        );
    }
};
```

**关键安全设计**:
- 子代理禁止 `message`, `spawn`, `delegate` 工具，防止无限递归
- 结果通过事件总线异步回传

**对 KimiZ 的价值**:
- T-094 后台任务可以直接参考这个线程模型
- 工具白名单机制必须引入，防止生成的 auto skill 递归失控

**建议**: **T-110: 后台任务采用 OS 线程隔离 + 工具白名单**（参考 subagent.zig）

---

## 5. Channel 目录 — 多平台接入的扩展点

**文件**: `src/channel_catalog.zig`, `src/channels/`

**作用**: 用 comptime 数组管理所有通信渠道，统一的生命周期和配置接口。

```zig
pub const known_channels = [_]ChannelMeta{
    .{ .id = .telegram, .key = "telegram", .label = "Telegram" },
    .{ .id = .discord,  .key = "discord",  .label = "Discord" },
    .{ .id = .web,      .key = "web",      .label = "Web" },
    // ...
};
```

**对 KimiZ 的价值**:
- 如果 KimiZ 未来做 Web UI、Discord Bot、或 Telegram Bot，这是现成的架构模板
- 统一配置模型，新增 channel 只需添加一条元数据

**建议**: 先不做（当前 KimiZ 专注 CLI），但 T-086 之后如果要扩展多平台，直接参考

---

## 6. Config Mutator — 运行时安全自修改

**文件**: `src/config_mutator.zig`

**作用**: 允许 agent 在运行时安全地修改 `config.json`，支持白名单路径、备份、回滚。

```zig
pub const MutationResult = struct {
    path: []const u8,
    changed: bool,
    applied: bool,
    requires_restart: bool,
    old_value_json: []const u8,
    new_value_json: []const u8,
    backup_path: ?[]const u8 = null,
};
```

**关键设计**:
- `allowed_exact_paths` + `allowed_prefix_paths`：只有白名单中的配置项允许修改
- `pathRequiresRestart()`：修改某些路径后需要重启才能生效
- 修改前自动创建 `.bak` 备份

**对 KimiZ 的价值**:
- T-104（skill 版本管理）可以参考它的备份/回滚机制
- 如果 KimiZ 允许用户通过自然语言修改配置（如"把模型换成 Claude"），这是安全实现模板

**建议**: 在 T-104 中借鉴备份和回滚设计

---

## 7. 安全模型 — 风险命令分级拦截

**文件**: `src/security/`, `src/net_security.zig`

**作用**: 多层安全护栏：
- **域名白名单**: `http_request` 只能访问允许的域名
- **命令分级**: `block_high_risk_commands` + `require_approval_for_medium_risk`
- **路径隔离**: `workspace_only` 限制只能操作工作区文件
- **TLS 验证**: 网络请求的证书校验

**对 KimiZ 的价值**:
- T-100~T-105 的 auto skill 生成 pipeline 必须有这些护栏
- LLM 生成的代码应该被限制在白名单 API 和允许的路径内
- 子代理/后台任务尤其需要 `workspace_only` 和命令分级

**建议**: 在 T-110 和 T-105 中强制引入这些安全机制

---

## 8. Capabilities 清单 — 运行时能力自检

**文件**: `src/capabilities.zig`

**作用**: 生成一个 JSON manifest，列出当前构建启用的所有能力：
- 哪些 channels 编译进去了
- 哪些 memory engines 可用
- 哪些 tools 被配置启用

```zig
pub fn buildManifestJson(allocator: Allocator, cfg_opt: ?*const Config, runtime_tools: ?[]const Tool) ![]u8 {
    // 输出完整的 capabilities JSON
}
```

**对 KimiZ 的价值**:
- Agent 可以动态读取自身能力清单，避免调用未启用的 tool/skill
- 对 LLM 生成 skill 很有用：生成前先看当前系统有哪些能力可用
- 便于调试和用户支持（`kimiz --capabilities` 命令）

**建议**: **T-111: 实现 `kimiz --capabilities` 自检命令**（6h）

---

## 优先级建议

| 优先级 | 任务 | 价值 | 工作量 |
|--------|------|------|--------|
| **P0** | 移植 `json_miniparse.zig` | 高频性能提升 | 4h |
| **P0** | 设计 Provider 抽象 | 架构基础 | 8h |
| **P0** | 后台任务线程隔离 + 白名单 | T-094 核心 | 10h |
| **P1** | 配置修改备份/回滚 | T-104 借鉴 | 4h |
| **P1** | `--capabilities` 自检 | 实用 + LLM 友好 | 6h |
| **P2** | Channel 扩展架构 | 远期多平台 | - |

---

## 一句话总结

> **NullClaw 的工程实现非常扎实，但它的 Prompt-based skill 模式没有未来。KimiZ 应该像抢滩登陆一样，把 NullClaw 的工程资产（解析器、Provider、子代理、安全模型）快速吸收过来，然后用 Zig 的 comptime + 自举编译走出一条它永远追不上的路。**
