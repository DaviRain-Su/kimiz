# TASK-TODO-004: 实现 Extension 系统核心功能

**状态**: pending  
**优先级**: P1  
**类型**: Feature  
**预计耗时**: 8小时  
**阻塞**: Extension 加载和管理

## 描述

Extension 系统的核心功能尚未实现，包括 manifest 解析、安装/卸载、WASM 运行时清理等。

## 受影响的文件

- **src/extension/root.zig**
  - `unload()` (第 163 行) - TODO: Cleanup WASM runtime
  - `loadFromManifest()` (第 202 行) - TODO: Parse TOML manifest
  - `install()` (第 210 行) - TODO: Download and install extension
  - `uninstall()` (第 218 行) - TODO: Remove extension files

## 当前问题

1. WASM 运行时清理未实现
2. TOML manifest 解析未实现
3. Extension 安装/卸载流程未实现

## 实现方案

### Manifest 解析
```zig
const Manifest = struct {
    name: []const u8,
    version: []const u8,
    description: []const u8,
    entry: []const u8,  // WASM 文件路径
};

fn loadFromManifest(...) !void {
    const content = try utils.fs.readFileAlloc(allocator, manifest_path, 1024 * 1024);
    // 解析 TOML
}
```

### Extension 安装
```zig
fn install(...) !void {
    // 1. 下载 extension 包
    // 2. 解压到 extensions 目录
    // 3. 验证 manifest
    // 4. 加载 extension
}
```

## 验收标准

- [ ] TOML manifest 解析
- [ ] Extension 安装流程
- [ ] Extension 卸载流程
- [ ] WASM 运行时正确清理
- [ ] Extension 版本管理
- [ ] Extension 依赖解析

## 依赖

- TOML 解析库 (需要调研)
- TASK-TODO-002 (HTTP Client) - 用于下载

## 相关任务

- TASK-FEAT-006 (Extension 系统)
