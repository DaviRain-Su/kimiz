# T-129: 设计并实现 WASM-based Skill Plugin 系统

**任务类型**: Implementation  
**优先级**: P0  
**预计耗时**: 16h  
**前置任务**: T-128（TaskEngine 运行时任务状态机）

---

## 参考文档

- [T-128 Technical Spec](T-128-design-and-implement-task-engine.md) — TaskEngine 与 7-phase 状态机
- [T-103 Spike Report](../reports/T-103-spike-comptime-skill-dsl-report.md) — comptime Skill DSL 验证
- [T-100 Spec](T-100-establish-auto-skill-generation-pipeline.md) — auto skill 自动生成流水线
- [zwasm 依赖](../) — `build.zig.zon` 中已引入 `zwasm`
- [WASI Preview 1](https://github.com/WebAssembly/WASI/blob/main/legacy/preview1/docs.md) — 文件系统沙箱标准

---

## 背景

T-128 的 TaskEngine 解决了"自动编排"的问题，但留下了一个**产品化的硬约束**：

> KimiZ 是 Zig 编译的二进制。`defineSkill` DSL 生成的是 comptime Zig 类型。
> 如果 KimiZ 作为产品只分发二进制（用户拿不到源码），用户就无法使用 `defineSkill` 自定义 Skill。

要让终端用户能够：
1. 下载 KimiZ 二进制
2. 写几句自然语言描述，或写一段 Rust/Go/AssemblyScript 代码
3. 让 KimiZ 自动识别并执行这个新 Skill

**唯一可行的技术路径是 WASM 运行时动态加载。**

WASM 提供了：
- **零编译**（对用户而言）
- **沙箱安全**（WASM 无法访问宿主，除非显式 import 接口）
- **跨语言**（任何能编译到 WASM 的语言都可以）
- **跨平台**（一份 `.wasm` 到处运行）
- **热加载**（运行时加载和卸载）

KimiZ 的 `build.zig.zon` 中已经引入了 `zwasm` 依赖，T-129 的目标是把 `zwasm` 从"依赖列表"变成"核心基础设施"。

---

## 目标

1. **定义 WASM Skill 的标准接口**：宿主（KimiZ）和插件（WASM）之间的 ABI 契约
2. **实现 PluginLoader**：运行时扫描、加载、执行 `.wasm` 文件
3. **实现 PluginRegistry**：管理 WASM Skill 的生命周期（注册、缓存、热重载、卸载）
4. **集成到 TaskEngine**：WASM Skill 可以和内置 Zig Skill 一样被 TaskEngine 自动调度
5. **实现 Prompt-to-WASM 自动生成**：用户输入自然语言描述 → LLM 生成 Zig 代码 → 编译为 `.wasm` → 自动注册
6. **建立安全模型**：WASM Skill 的资源限制、超时控制、权限白名单

---

## 关键设计决策

### 1. WASM Skill ABI 契约

每个 `.wasm` 文件必须导出以下函数：

```wat
(module
  ;; 必需导出
  (export "kimiz_skill_version" (global $version))
  (export "kimiz_skill_name" (global $name_ptr))
  (export "kimiz_skill_name_len" (global $name_len))
  (export "kimiz_skill_desc" (global $desc_ptr))
  (export "kimiz_skill_desc_len" (global $desc_len))
  (export "kimiz_skill_execute" (func $execute))

  ;; 函数签名
  (func $execute (param $input_ptr i32) (param $input_len i32) (param $output_ptr i32) (param $output_capacity i32) (result i32))
  ;; 返回值: >=0 表示输出长度, <0 表示错误码
)
```

对应的 Zig 结构：

```zig
pub const WasmSkillAbi = struct {
    pub const VERSION: u32 = 1;

    /// 输入输出通过 WASM linear memory 传递
    pub const execute_signature = "execute(i32, i32, i32, i32) -> i32";
};
```

宿主通过 import 提供给 WASM 的 API（受控能力）：

```zig
pub const HostImports = struct {
    /// 打印日志到宿主
    pub fn log(level: i32, ptr: i32, len: i32) void;
    
    /// 获取环境变量（只允许读取白名单中的变量）
    pub fn env_get(name_ptr: i32, name_len: i32, buf_ptr: i32, buf_cap: i32) i32;
    
    /// 发起 HTTP 请求（受速率限制和域名白名单控制）
    pub fn http_request(req_ptr: i32, req_len: i32, resp_ptr: i32, resp_cap: i32) i32;
    
    /// 文件系统访问（WASI Preview 1 风格，只暴露特定目录）
    pub fn fs_read(path_ptr: i32, path_len: i32, buf_ptr: i32, buf_cap: i32) i32;
    pub fn fs_write(path_ptr: i32, path_len: i32, data_ptr: i32, data_len: i32) i32;
    
    /// 分配/释放 WASM 内存（由宿主管理 allocator）
    pub fn alloc(size: i32) i32;
    pub fn free(ptr: i32, size: i32) void;
};
```

### 2. 宿主-插件通信协议

所有 Skill 的输入输出统一使用 **JSON**。

```zig
pub const WasmSkill = struct {
    module: zwasm.Module,
    name: []const u8,
    description: []const u8,
    
    pub fn execute(self: *WasmSkill, input_json: []const u8) ![]const u8 {
        // 1. 在 WASM memory 中分配输入缓冲区
        const input_ptr = try self.callAlloc(@intCast(input_json.len));
        defer self.callFree(input_ptr, @intCast(input_json.len));
        try self.writeMemory(input_ptr, input_json);
        
        // 2. 分配输出缓冲区
        const output_cap = 64 * 1024; // 64KB max initial
        const output_ptr = try self.callAlloc(output_cap);
        defer self.callFree(output_ptr, output_cap);
        
        // 3. 调用 execute
        const result_len = try self.callExecute(input_ptr, input_json.len, output_ptr, output_cap);
        if (result_len < 0) {
            return try self.mapError(@intCast(-result_len));
        }
        
        // 4. 读取输出
        return try self.readMemoryAlloc(output_ptr, @intCast(result_len));
    }
};
```

**为什么用 JSON**：
- 跨语言通用（WASM 插件可以用 Rust/Go/TS 写，JSON 是通用语）
- 和 KimiZ 现有的 `defineSkill` JSON wrapper 一致
- 不需要复杂的序列化协议

### 3. PluginLoader 和 PluginRegistry

#### PluginLoader

```zig
pub const PluginLoader = struct {
    allocator: std.mem.Allocator,
    wasi_config: WasiConfig,
    
    pub fn loadFromFile(self: *PluginLoader, path: []const u8) !WasmSkill {
        // 1. 读取 .wasm 文件
        const wasm_bytes = try std.fs.cwd().readFileAlloc(self.allocator, path, 10 * 1024 * 1024);
        defer self.allocator.free(wasm_bytes);
        
        // 2. 实例化 zwasm module
        var module = try zwasm.Module.init(self.allocator, wasm_bytes);
        
        // 3. 链接 host imports
        try module.linkImports(HostImportVtable.get());
        
        // 4. 验证 ABI
        try self.validateAbi(&module);
        
        // 5. 读取元数据（name, description, version）
        const meta = try self.extractMetadata(&module);
        
        return WasmSkill{
            .module = module,
            .name = meta.name,
            .description = meta.description,
        };
    }
};
```

#### PluginRegistry

```zig
pub const PluginRegistry = struct {
    allocator: std.mem.Allocator,
    skills: std.StringHashMap(*WasmSkill),
    watch_dirs: []const []const u8,
    last_checksums: std.StringHashMap(u64),
    
    pub fn init(allocator: std.mem.Allocator) PluginRegistry {
        return .{
            .allocator = allocator,
            .skills = std.StringHashMap(*WasmSkill).init(allocator),
            .watch_dirs = &[_][]const u8{
                "~/.kimiz/skills/wasm",      // 用户级
                ".kimiz/skills/wasm",          // 项目级
            },
            .last_checksums = std.StringHashMap(u64).init(allocator),
        };
    }
    
    /// 扫描 watch_dirs，加载/重载/卸载 WASM 文件
    pub fn scanAndReload(self: *PluginRegistry) !void {
        // 1. 收集当前目录下所有 .wasm 文件
        // 2. 计算 checksum，与 last_checksums 比较
        // 3. 新增 → 加载
        // 4. 变更 → 卸载旧实例，加载新实例
        // 5. 删除 → 卸载
    }
    
    pub fn get(self: *PluginRegistry, name: []const u8) ?*WasmSkill {
        return self.skills.get(name);
    }
};
```

### 4. 与 TaskEngine 和 SkillRegistry 的集成

KimiZ 现有的 `SkillRegistry` 已经通过 `execute_fn` 支持动态调用。WASM Skill 的集成方式是：

```zig
pub fn wasmSkillToSkill(wasm_skill: *WasmSkill) Skill {
    return .{
        .name = wasm_skill.name,
        .description = wasm_skill.description,
        .params = &[_]SkillParam{}, // WASM skill 自行解析 JSON schema
        .execute_fn = struct {
            fn execute(input_json: []const u8, allocator: std.mem.Allocator) ![]const u8 {
                return wasm_skill.execute(input_json);
            }
        }.execute,
    };
}
```

PluginRegistry 在扫描到 `.wasm` 文件后，自动将其转换为 `Skill` 并注册到全局 `SkillRegistry`。这样 TaskEngine 不需要知道一个 Skill 是 Zig 编译的还是 WASM 加载的。

### 5. Prompt-to-WASM 自动生成流水线

这是降低用户门槛的关键能力：

```
用户输入自然语言描述
    ↓
KimiZ 使用 T-100 的 generator 生成 Zig 代码
    ↓
调用 `zig build-lib -target wasm32-freestanding` 编译为 .wasm
    ↓
PluginLoader 验证并加载
    ↓
注册到 SkillRegistry
    ↓
立即可用
```

对应的 CLI：

```bash
# 用户只用写一句话
kimiz skill create "fetch weather from OpenWeatherMap and return temperature"

# KimiZ 内部行为：
# 1. 生成 src/skills/wasm_gen/weather_skill.zig
# 2. 编译为 ~/.kimiz/skills/wasm/weather_skill.wasm
# 3. 加载并注册
```

生成的 WASM Skill Zig 模板：

```zig
const std = @import("std");

// WASM 内存由宿主管理
extern fn kimiz_alloc(size: usize) usize;
extern fn kimiz_free(ptr: usize, size: usize) void;
extern fn kimiz_log(level: i32, ptr: usize, len: usize) void;

export const kimiz_skill_version: u32 = 1;
export const kimiz_skill_name: [*:0]const u8 = "weather_fetcher";
export const kimiz_skill_desc: [*:0]const u8 = "Fetch weather from OpenWeatherMap";

export fn execute(input_ptr: i32, input_len: i32, output_ptr: i32, output_cap: i32) i32 {
    // 1. 读取 input JSON
    // 2. 调用 host http_request import
    // 3. 写入 output JSON
    // 4. 返回 output_len 或负错误码
}
```

**编译命令**：
```bash
zig build-lib weather_skill.zig \
  -target wasm32-freestanding \
  -dynamic \
  -O ReleaseSmall \
  -femit-bin=~/.kimiz/skills/wasm/weather_skill.wasm
```

### 6. 安全模型

#### 沙箱边界

WASM 插件默认**没有任何权限**。所有能力通过 Host Imports 显式授予。

#### 资源限制

```zig
pub const WasmSandbox = struct {
    max_memory: usize = 16 * 1024 * 1024,     // 16MB linear memory
    max_execution_time_ms: u64 = 30_000,      // 30s timeout
    max_http_requests_per_minute: u32 = 60,
    allowed_env_vars: []const []const u8 = &.{"KIMIZ_API_KEY"},
    allowed_http_hosts: []const []const u8 = &.{"api.openweathermap.org"},
    allowed_fs_paths: []const []const u8 = &.{"~/.kimiz/data/"},
};
```

#### 超时控制

```zig
pub fn executeWithTimeout(skill: *WasmSkill, input: []const u8, timeout_ms: u64) ![]const u8 {
    // 使用 async/子线程 + 定时器中断 WASM 执行
    // 超时返回 error.SkillTimeout
}
```

#### 错误隔离

单个 WASM Skill 的崩溃（trap）不会导致 KimiZ 进程崩溃。PluginLoader 捕获 trap 并返回 `error.SkillCrashed`。

---

## 影响文件

| 文件 | 预期改动 |
|------|----------|
| `src/plugin/wasm_skill.zig` | 新增：WASM Skill 核心结构体（内存读写、execute 调用） |
| `src/plugin/loader.zig` | 新增：PluginLoader（文件加载、ABI 验证、zwasm 集成） |
| `src/plugin/registry.zig` | 新增：PluginRegistry（扫描目录、热重载、生命周期管理） |
| `src/plugin/host_imports.zig` | 新增：Host Imports 的 vtable 实现（log, env, http, fs） |
| `src/plugin/sandbox.zig` | 新增：资源限制、超时、权限白名单 |
| `src/skills/generator.zig` | 扩展：支持生成 WASM-target Zig 代码并编译为 .wasm |
| `src/skills/root.zig` | 修改：PluginRegistry 加载的 WASM skills 自动注册到 SkillRegistry |
| `src/cli/root.zig` | 新增：`kimiz skill create <desc> --wasm` 命令 |
| `src/engine/task.zig` | 修改：TaskEngine 对 WASM 和 Zig skills 无差别调度 |
| `tests/plugin_tests.zig` | 新增：WASM 加载、执行、超时、沙箱单元测试 |
| `tests/fixtures/skill_echo.wasm` | 新增：测试用的最小 WASM skill（echo 输入） |
| `examples/wasm-skill/` | 新增：用户手写 WASM skill 的示例目录 |

---

## 验收标准

### 核心加载与执行

- [ ] `PluginLoader.loadFromFile("~/.kimiz/skills/wasm/echo.wasm")` 能成功加载并实例化一个有效的 WASM module
- [ ] `WasmSkill.execute("{\"msg\":\"hello\"}")` 能正确向 WASM 传递输入并读取输出
- [ ] 加载失败时（无效 WASM / 缺少 export ABI）返回明确的错误信息
- [ ] WASM skill 的崩溃被捕获，不会导致 KimiZ 进程退出

### 注册与集成

- [ ] `PluginRegistry.scanAndReload()` 能自动发现 `~/.kimiz/skills/wasm/` 下的新 `.wasm` 文件
- [ ] 新加载的 WASM skill 自动出现在 `SkillRegistry` 中，可被 `TaskEngine` 调用
- [ ] 修改 `.wasm` 文件后重新扫描，能热重载新版本的 skill
- [ ] 删除 `.wasm` 文件后重新扫描，能卸载对应的 skill

### 自动生成流水线

- [ ] CLI `kimiz skill create "return the input reversed" --wasm` 能生成并编译出一个可工作的 `.wasm`
- [ ] 生成的 WASM skill 能通过 `PluginLoader` 的 ABI 验证
- [ ] 自动生成失败时（编译错误），错误信息能反馈给用户

### 安全与沙箱

- [ ] WASM skill 调用 `host log` 能正常打印到 KimiZ 日志
- [ ] WASM skill 访问未授权的环境变量时返回 permission denied
- [ ] WASM skill 执行超过 30 秒时自动中断并返回 timeout 错误
- [ ] WASM skill 内存使用超过 16MB 时返回 out_of_memory 错误

### 端到端

- [ ] 一个 WASM skill 能被 TaskEngine 作为普通任务步骤调用（从 JSON 输入到 JSON 输出）
- [ ] `zig build test` 全部通过，包括新的 `tests/plugin_tests.zig`
- [ ] 更新 `AGENT-ENTRYPOINT.md` 和 `docs/FEATURES.md`，记录 WASM Plugin 能力

---

## 子任务拆解

T-129 已拆分为以下 6 个顺序执行的子任务：

1. **T-129-01** [`wasm-skill-abi-and-skeleton`](T-129-01-wasm-skill-abi-and-skeleton.md) — WASM Skill ABI 设计与最小骨架 (2h)
2. **T-129-02** [`plugin-loader`](T-129-02-plugin-loader.md) — PluginLoader 文件加载与 ABI 验证 (3h)
3. **T-129-03** [`host-imports`](T-129-03-host-imports.md) — Host Imports 实现（log, alloc, free）(3h)
4. **T-129-04** [`plugin-registry`](T-129-04-plugin-registry.md) — PluginRegistry 扫描、注册与热重载 (3h)
5. **T-129-05** [`skillregistry-integration`](T-129-05-skillregistry-integration.md) — 与 SkillRegistry / TaskEngine 集成 (2h)
6. **T-129-06** [`prompt-to-wasm-autogen`](T-129-06-prompt-to-wasm-autogen.md) — Prompt-to-WASM 自动生成 + CLI (3h)

> **执行顺序**：严格 01 → 02 → 03 → 04 → 05 → 06，后面的依赖前面的。
