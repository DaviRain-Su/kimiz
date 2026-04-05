### Task-BUG-013: 修复 page_allocator 滥用问题
**状态**: completed
**优先级**: P0
**创建**: 2026-04-05
**完成**: 2026-04-05
**预计耗时**: 4h
**实际耗时**: 2h

**描述**:
代码中多处滥用 `std.heap.page_allocator` 进行临时小内存分配，导致内存碎片和性能问题。`page_allocator` 每次分配至少 4KB，不适合频繁的小对象分配。

**修复内容**:

### 修改的文件

1. **src/core/root.zig**
   - `getApiKey()` 函数添加 `allocator` 参数
   - 调用者负责释放返回的内存

2. **src/ai/models.zig**
   - `getApiKey()` 函数添加 `allocator` 参数

3. **src/ai/providers/openai.zig**
   - 所有函数使用 `http_client.allocator` 替代 `page_allocator`
   - `serializeRequest()` 和 `parseResponse()` 添加 allocator 参数
   - 更新 `getApiKey()` 调用

4. **src/ai/providers/anthropic.zig**
   - 所有函数使用 `http_client.allocator` 替代 `page_allocator`
   - `serializeRequest()` 和 `parseResponse()` 添加 allocator 参数

5. **src/ai/providers/google.zig**
   - 所有函数使用 `http_client.allocator` 替代 `page_allocator`
   - `serializeRequest()` 和 `parseResponse()` 添加 allocator 参数
   - `processLine()` 添加 allocator 参数

6. **src/ai/providers/kimi.zig**
   - 所有函数使用 `http_client.allocator` 替代 `page_allocator`
   - `serializeCodeRequest()` 和 `parseCodeResponse()` 添加 allocator 参数
   - `processLine()` 添加 allocator 参数

7. **src/ai/providers/fireworks.zig**
   - 所有函数使用 `http_client.allocator` 替代 `page_allocator`
   - `serializeRequest()` 添加 allocator 参数
   - `StreamGuard` 和 `calculateSimilarity()` 使用传入的 allocator

**修复统计**:
- 修改文件: 7 个
- 替换 page_allocator 调用: 200+ 处
- 新增 allocator 参数: 15+ 个函数

**验收标准**:
- [x] 所有 provider 使用正确的 allocator ✅
- [x] `getApiKey` 接受 allocator 参数 ✅
- [x] 编译通过，测试通过 ✅

**验证**:
```bash
$ zig build        # ✅ 成功
$ zig build test   # ✅ 成功
```

**依赖**:
- URGENT-FIX-compilation-errors ✅
- TASK-BUG-014-fix-cli-unimplemented ✅

**笔记**:
所有 providers 已修复，使用 `http_client.allocator` 或传入的 allocator 替代 `page_allocator`。内存管理更加合理，避免了大块内存分配导致的碎片问题。
