### TASK-TOOL-002: 集成 fff C FFI 作为原生 Zig 模块
**状态**: pending
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 8h

**描述**:
将 fff 的 C FFI 库 (`libfff-c`) 编译为共享库，从 Zig 直接调用，实现零 subprocess 开销的极速搜索。

**背景**:
MCP Server 方案有 ~50-100ms 的进程间通信开销。对于需要极低延迟的场景，可以直接链接 C 库。

**架构**:
```
kimiz (Zig)
    ↓ @cImport("fff.h")
libfff-c (C FFI wrapper)
    ↓
libfff_core (Rust static lib)
    ↓
搜索结果 (< 5ms)
```

**前提条件**:
1. 克隆 fff.nvim 仓库
2. 构建 libfff_c.a (静态库)
3. 生成 fff.h 头文件

**实施步骤**:

1. **获取 fff C FFI**
```bash
git clone https://github.com/dmtrKovalenko/fff.nvim
cd fff.nvim
# 构建 C 库
cargo build --release -p fff-c
```

2. **创建 Zig 绑定**
```zig
// src/db/fff.zig
const std = @import("std");

// 加载 C 库
pub const ffi = @cImport(@cInclude("fff.h"));

// 实例句柄
pub const FFFHandle = opaque {
    // Opaque pointer to internal state
};

// 结果结构
pub const FFFFileResult = extern struct {
    path: [*]const u8,
    score: f64,
    is_dir: bool,
};

pub const FFFGrepResult = extern struct {
    path: [*]const u8,
    line_number: u32,
    line_content: [*]const u8,
    score: f64,
};

// 核心 API
pub const fff = struct {
    pub fn create(path: [*]const u8) ?*FFFHandle {
        return ffi.fff_create_instance(path);
    }

    pub fn search(
        handle: *FFFHandle,
        query: [*]const u8,
        max_results: u32,
    ) ?[]FFFFileResult {
        const result = ffi.fff_search(handle, query, max_results);
        // 转换并返回切片
    }

    pub fn grep(
        handle: *FFFHandle,
        query: [*]const u8,
        path_filter: ?[*]const u8,
        max_results: u32,
    ) ?[]FFFGrepResult { ... }

    pub fn destroy(handle: *FFFHandle) void {
        ffi.fff_destroy(handle);
    }

    pub fn freeResult(result: *anyopaque) void {
        ffi.fff_free_result(result);
    }
};
```

3. **创建 FFFStore 封装**
```zig
// src/db/fff_store.zig
pub const FFFStore = struct {
    allocator: std.mem.Allocator,
    handle: *fff.FFFHandle,
    base_path: []const u8,

    pub fn init(allocator: std.mem.Allocator, base_path: []const u8) !Self {
        const handle = fff.create(base_path) orelse {
            return error.FFFInitFailed;
        };
        return .{
            .allocator = allocator,
            .handle = handle,
            .base_path = try allocator.dupe(u8, base_path),
        };
    }

    pub fn deinit(self: *Self) void {
        fff.destroy(self.handle);
        self.allocator.free(self.base_path);
    }

    pub fn findFiles(self: *Self, query: []const u8, limit: u32) ![]FFFFileResult {
        const results = fff.search(self.handle, query, limit) orelse {
            return error.SearchFailed;
        };
        // 转换为 Zig 切片并复制到 allocator
        return self.copyFileResults(results);
    }

    pub fn grep(self: *Self, query: []const u8, limit: u32) ![]FFFGrepResult { ... }
};
```

4. **修改 build.zig 链接**
```zig
// build.zig
const fff_mcp = b.dependency("fff_mcp", .{
    .target = target,
    .optimize = optimize,
});

// 添加 C 库和头文件路径
exe.linkSystemLibrary("c");
exe.addIncludePath(fff_mcp.path("crates/fff-c/src"));
exe.addLibPath(fff_mcp.path("target/release"));
exe.linkSystemLibrary("fff_c");  // libfff_c.a
```

**性能对比目标**:
| 操作 | MCP Server | C FFI |
|------|------------|--------|
| find_files | ~100ms | **< 5ms** |
| grep | ~150ms | **< 10ms** |
| 模糊搜索 | ~100ms | **< 5ms** |

**验收标准**:
- [ ] `zig build` 编译通过
- [ ] 链接 libfff_c.a 成功
- [ ] find_files < 5ms (10k 文件)
- [ ] grep < 10ms (10k 文件)
- [ ] 内存占用 < 50MB (10k 文件索引)

**依赖**:
- TASK-TOOL-001 (了解 FFI 接口)

**阻塞**:
- 需要 fff 仓库源码

**笔记**:
- C FFI 方案复杂度高，需要处理内存分配边界
- 建议先用 MCP 方案验证功能，再考虑 C FFI
- LMDB 依赖 (heed) 可能需要额外配置
