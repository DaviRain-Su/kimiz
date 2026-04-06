# KimiZ Lessons Learned

> 这是项目的长期记忆库。所有 Agent 和人类开发者共享此文档。
> 新增记录请追加到最前面（逆时序）。
> 模板定义在 `docs/lessons-learned-template.md`。

---

## 2026-04-06 | 构建时文件系统操作在 build.zig 中不可用

**分类**: 踩坑记录  
**来源**: T-101 AutoRegistry 实现事件  
**教训**: Zig 0.16 的 `std.fs.cwd()`、`std.fs.openDirAbsolute()`、`std.Io.Dir.openDir` 在 build.zig 配置阶段均不可用。构建时的文件系统扫描必须通过外部脚本（Makefile）或独立程序（RunArtifact）完成。改用 `tools/gen_auto_registry.sh` 在 make build 前预处理。

---

## 2026-04-06 | Zig 0.16 API 迁移关键差异

**分类**: API 选择  
**来源**: T-121/T-122/T-123 多任务积累  
**教训**: 从 Zig 0.15 迁移到 0.16 的关键 API 变化：
- `std.ArrayList(T).init(alloc)` → `.empty`，方法需传 allocator
- `std.json.stringifyAlloc` → `std.json.Stringify.valueAlloc`
- `std.time.milliTimestamp()` → C `clock_gettime()` wrapper (`utils.milliTimestamp()`)
- `std.fs.cwd()` → `std.Io.Dir.cwd()` + Io 实例
- `dir.close()` → `dir.close(io)`
- `std.mem.trimLeft` → `std.mem.trim(u8, s, "set")`

---

## 2026-04-06 | 项目必须使用 Zig 0.16 API

**分类**: 架构决策  
**来源**: FIX-ZIG-015 回滚事件  
**教训**: 项目统一使用 Zig 0.16。Makefile 已固定 `$(HOME)/zig-0.16.0-dev/zig`。不要尝试向后兼容 0.15。

---
