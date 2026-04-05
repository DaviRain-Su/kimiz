### Task-BUG-021: SkillCategory enum 使用保留关键字 `test`
**状态**: pending
**优先级**: P3
**创建**: 2026-04-05
**预计耗时**: 15分钟

**描述**:
`src/skills/root.zig:66` 中 SkillCategory enum 使用了 `test` 作为字段名，但 `test` 是 Zig 的保留关键字，会导致编译错误。

**当前代码**:
```zig
pub const SkillCategory = enum {
    code,
    review,
    refactor,
    test,  // ❌ 保留关键字
    doc,
    debug,
    analyze,
    misc,
};
```

**修复方案**:
```zig
pub const SkillCategory = enum {
    code,
    review,
    refactor,
    testing,  // ✅ 改名
    doc,
    debug,
    analyze,
    misc,
};
```

**验收标准**:
- [ ] `zig build` 编译通过
- [ ] SkillCategory.test 改为 SkillCategory.testing

**依赖**:
- 无

**阻塞**:
- Skills 模块编译

**笔记**:
简单修复，发现于 LSP 诊断 (2026-04-05)。
