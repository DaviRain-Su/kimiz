# TASK-TOOL-002: 集成 fff C FFI (高性能搜索)

**状态**: in_progress  
**优先级**: P1  
**预计工时**: 8 小时  
**分配**: Claude Code  
**创建**: 2026-04-05

---

## 目标

通过 C FFI 直接链接 libfff_core，实现零开销 (< 5ms) 的高性能模糊搜索。

---

## 背景

fff (Fuzzy File Finder) 是比 ripgrep 快 100 倍的模糊搜索引擎：
- 无索引架构
- SIMD 加速 (AVX2/NEON)
- 支持 50万文件实时搜索 (< 100ms)
- 模糊匹配 + Typo 纠错 + Frecency 排名

---

## 技术架构

```
kimiz (Zig)
    ↓ @cImport
libfff_c (C FFI Wrapper - 需自行实现)
    ↓
libfff_core (Rust, SIMD)
```

---

## 实施步骤

### Phase 1: C FFI 绑定层 (3h)

**1.1 创建 fff C FFI 包装器**

文件: `ffi/fff-wrapper/Cargo.toml`
```toml
[package]
name = "fff-c"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib", "staticlib"]

[dependencies]
fff-core = { git = "https://github.com/dmtrKovalenko/fff.nvim" }
```

文件: `ffi/fff-wrapper/src/lib.rs`
```rust
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};

/// C FFI wrapper for fff search
#[no_mangle]
pub extern "C" fn fff_search(
    query: *const c_char,
    path: *const c_char,
    results: *mut FFFResult,
    max_results: c_int,
) -> c_int {
    let query = unsafe { CStr::from_ptr(query) }.to_string_lossy();
    let path = unsafe { CStr::from_ptr(path) }.to_string_lossy();
    
    // Call fff core
    let matches = fff_core::search(&query, &path);
    
    // Convert to C format
    let count = matches.len().min(max_results as usize);
    for (i, m) in matches.iter().take(count).enumerate() {
        unsafe {
            (*results.add(i)).path = CString::new(m.path.clone()).unwrap().into_raw();
            (*results.add(i)).score = m.score;
            (*results.add(i)).line_num = m.line_num as c_int;
        }
    }
    
    count as c_int
}

#[repr(C)]
pub struct FFFResult {
    path: *mut c_char,
    score: f64,
    line_num: c_int,
}
```

**1.2 Zig FFI 绑定**

文件: `src/ffi/fff.zig`
```zig
const c = @cImport({
    @cInclude("fff.h");
});

pub const FFFMatch = struct {
    path: []const u8,
    score: f64,
    line_num: usize,
};

pub fn search(
    allocator: std.mem.Allocator,
    query: []const u8,
    path: []const u8,
    max_results: usize,
) ![]FFFMatch {
    const query_c = try allocator.dupeZ(u8, query);
    defer allocator.free(query_c);
    
    const path_c = try allocator.dupeZ(u8, path);
    defer allocator.free(path_c);
    
    var results: [100]c.FFFResult = undefined;
    
    const count = c.fff_search(
        query_c.ptr,
        path_c.ptr,
        &results[0],
        @intCast(max_results),
    );
    
    var matches = try allocator.alloc(FFFMatch, @intCast(count));
    for (0..@intCast(count)) |i| {
        const r = results[i];
        matches[i] = .{
            .path = try allocator.dupe(u8, std.mem.span(r.path)),
            .score = r.score,
            .line_num = @intCast(r.line_num),
        };
    }
    
    return matches;
}
```

### Phase 2: FFFTool 实现 (2h)

文件: `src/agent/tools/fff.zig`
```zig
const std = @import("std");
const tool = @import("../tool.zig");
const fff = @import("../../ffi/fff.zig");

pub const FFFTool = struct {
    pub fn execute(arena: std.mem.Allocator, args: std.json.Value) !tool.ToolResult {
        const parsed = try tool.parseArguments(arena, args, struct {
            query: []const u8,
            path: ?[]const u8 = null,
            max_results: ?usize = 20,
        });
        
        const matches = try fff.search(
            arena,
            parsed.query,
            parsed.path orelse ".",
            parsed.max_results orelse 20,
        );
        
        // Format results
        var result_text = std.ArrayList(u8).init(arena);
        for (matches, 0..) |m, i| {
            if (i > 0) try result_text.append('\n');
            try std.fmt.format(result_text.writer(), "{s}:{d} (score: {d:.2})", .{
                m.path, m.line_num, m.score,
            });
        }
        
        return tool.textContent(arena, result_text.items);
    }
};

pub const definition = tool.Tool{
    .name = "fff",
    .description = "Fast fuzzy file/code search with typo correction and smart ranking",
    .parameters_json =
        \\{"type":"object","properties":{"query":{"type":"string","description":"Search query (fuzzy, supports typos)"},"path":{"type":"string","description":"Directory to search in"},"max_results":{"type":"number","description":"Maximum results to return"}},"required":["query"]}
    ,
};
```

### Phase 3: build.zig 配置 (1h)

```zig
// Add fff C library
const fff_lib = b.addStaticLibrary(.{
    .name = "fff-c",
    .root_source_file = b.path("ffi/fff-wrapper/src/lib.rs"),
    .target = target,
    .optimize = optimize,
});

// Link to kimiz
exe.addObjectFile(fff_lib.getEmittedBin());
exe.linkLibC();
exe.addIncludePath(b.path("ffi/fff-wrapper/include"));
```

### Phase 4: 替换 grep (2h)

1. 更新 `src/agent/root.zig`，添加 fff 工具
2. 更新 `src/agent/tools/grep.zig`，标记为 deprecated
3. 更新默认工具集，fff 替代 grep

---

## 验收标准

- [ ] fff 搜索延迟 < 5ms (10k 文件)
- [ ] 模糊匹配正常工作 ("mtxlk" → "mutex_lock")
- [ ] Typo 纠错正常工作 ("serach" → "search")
- [ ] Git 感知优先级正常
- [ ] 编译通过 `zig build`
- [ ] 所有测试通过 `zig build test`

---

## 风险评估

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| fff 无现成 C FFI | 高 | 高 | 需自行编写 Rust wrapper |
| 内存边界问题 | 中 | 高 | 仔细测试，使用 Arena |
| 编译复杂度 | 中 | 中 | 提供一键构建脚本 |

---

## 参考

- fff: https://github.com/dmtrKovalenko/fff.nvim
- Pi + fff: https://github.com/SamuelLHuber/pi-fff
- Zig FFI: https://ziglang.org/documentation/master/#C-Import

---

**下一步**: Phase 1 - 创建 C FFI 绑定层
