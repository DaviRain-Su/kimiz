# TASK-TODO-001: 实现 AI Provider JSON 序列化

**状态**: pending  
**优先级**: P0  
**类型**: Bugfix  
**预计耗时**: 6小时  
**阻塞**: AI API 调用

## 描述

所有 AI Provider (Google, Kimi, Anthropic) 的 JSON 序列化当前使用占位符实现，需要完整的 JSON 序列化功能。

## 受影响的文件

1. **src/ai/providers/google.zig**
   - `serializeRequest()` (第 188 行) - TODO: Implement proper JSON serialization
   - `parseResponse()` (第 267 行) - TODO: Fix JSON serialization

2. **src/ai/providers/kimi.zig**
   - `serializeCodeRequest()` (第 206 行) - TODO: Implement proper JSON serialization

3. **src/ai/providers/anthropic.zig**
   - `serializeRequest()` (第 268 行) - TODO: Implement proper JSON serialization
   - `parseResponse()` (第 324 行) - TODO: Fix JSON serialization

## 当前问题

当前实现使用手动字符串拼接或返回占位符：
```zig
// 当前占位符实现
try buf.appendSlice(allocator, "{\"placeholder\":true}");
return try buf.toOwnedSlice(allocator);
```

## 实现方案

### 方案 1: 使用 std.json 标准库 (推荐)
```zig
const request = GoogleRequest{
    .contents = contents,
    .generationConfig = .{...},
};
return try std.json.stringifyAlloc(allocator, request, .{});
```

### 方案 2: 使用 zig-json 库
- 添加 zig-json 依赖
- 使用更灵活的序列化 API

## 验收标准

- [ ] Google provider 完整的请求/响应 JSON 序列化
- [ ] Kimi provider 完整的请求/响应 JSON 序列化
- [ ] Anthropic provider 完整的请求/响应 JSON 序列化
- [ ] 所有序列化/反序列化测试通过
- [ ] 与真实 API 测试验证

## 依赖

- Zig 0.16 std.json 兼容性研究

## 相关任务

- TASK-INFRA-008 (Zig 0.16 迁移)
