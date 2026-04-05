# Zig 0.16 不兼容变更速查表

**快速参考** - 5 分钟了解关键变更

---

## 🔴 核心变更（必须处理）

### 1. std.Io 接口

```zig
// ❌ 0.15.2
std.fs.cwd()
std.fs.File
std.net.getAddressList()

// ✅ 0.16
std.Io.Dir.cwd()
std.Io.File
std.Io.net.HostName.lookup()
```

**关键**: 所有 I/O 操作现在需要一个 `io: *std.Io` 参数！

### 2. main() 函数

```zig
// ❌ 0.15.2
pub fn main() !void { }

// ✅ 0.16
pub fn main(init: std.process.Init) !u8 {
    const allocator = init.gpa;
    const io = init.io;
    return 0;
}
```

### 3. ArrayList.writer()

```zig
// ❌ 0.15.2
var list = std.ArrayList(u8).init(allocator);
const writer = list.writer(allocator);

// ✅ 0.16
var list: std.ArrayList(u8) = .empty;
const writer = list.writer(); // 无需 allocator!
```

### 4. Build 系统

```zig
// ❌ 0.15.2
exe.linkLibC();
exe.addCSourceFiles(.{ ... });

// ✅ 0.16
const mod = b.addModule(..., .{ .link_libc = true });
exe.root_module.addCSourceFiles(.{ ... });
```

---

## 📊 项目影响评估

| 文件 | 影响 | 工作量 |
|------|------|-------|
| `src/main.zig` | 🔴 main 签名 | 30min |
| `src/cli/root.zig` | 🔴 stdout API (10+处) | 1h |
| `src/http.zig` | 🔴 ArrayList + 网络 | 1h |
| `src/utils/*.zig` | 🔴 文件 I/O | 1-2h |
| `build.zig` | 🔴 Build API | 30min |
| **总计** | - | **4-6 小时** |

---

## 🚨 当前编译错误映射

### 错误 1: src/http.zig:91
```zig
- .response_writer = body_list.writer(self.allocator),
+ .response_writer = body_list.writer(),
```
**原因**: ArrayList.writer() 不再接受 allocator (0.16 变更)

### 错误 2: src/utils/config.zig:250  
```zig
- const key = getApiKey(&config, "openai");
+ const key = ConfigManager.getApiKey(&config, "openai");
```
**原因**: 函数调用缺少命名空间 (0.15 问题)

---

## 📋 迁移清单

### 立即 (P0)
- [ ] 修复 2 个编译错误
- [ ] 升级 Zig 到 0.16
- [ ] 更新 build.zig
- [ ] 更新 main() 签名

### 本周 (P1)
- [ ] 修复 CLI stdout/stdin API
- [ ] 更新所有文件 I/O 调用
- [ ] 迁移网络调用到 std.Io.net

### 可选 (P2)
- [ ] 利用 io_uring 优化性能
- [ ] 添加条件编译支持多版本

---

## 🔗 完整文档

详见: `docs/11-zig-0.16-migration-guide.md`

---

**结论**: Zig 0.16 是重大升级，但迁移路径清晰，预计 4-6 小时完成。
