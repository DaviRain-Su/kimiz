### TASK-BUG-024: 修复测试编译错误
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 1h

**描述**:
测试编译失败，有 12 个编译错误。

**错误列表**:

1. `skills/root.zig:81` - undeclared identifier 'SkillCategory'
2. `skills/test_gen.zig:103` - `.test` 是 Zig 保留关键字
3. `skills/code_review.zig:35` - unused function parameter 'ctx'
4. `skills/debug.zig:41` - unused function parameter 'ctx'
5. `skills/doc_gen.zig:33` - unused function parameter 'ctx'
6. `skills/refactor.zig:44` - unused function parameter 'ctx'

**修复方案**:

1. **SkillCategory 问题** - skills/root.zig:66 使用了保留关键字 `test`
```zig
// 错误
pub const SkillCategory = enum {
    code,
    test,  // ❌ 保留关键字
};

// 修复
pub const SkillCategory = enum {
    code,
    testing,  // ✅
};
```

2. **test_gen.zig:103** - `.test` 改为 `.testing`

3. **unused parameter** - 在函数前加 `_` 前缀
```zig
// 错误
fn execute(ctx: SkillContext, ...) !SkillResult {

// 修复
fn execute(_: SkillContext, ...) !SkillResult {
    _ = ctx;  // 或者直接忽略
```

**验收标准**:
- [ ] `zig build test` 编译通过
- [ ] 所有测试运行成功

**依赖**:
- 无

**阻塞**:
- 测试无法运行

**笔记**:
这些是简单修复，应该快速完成。
