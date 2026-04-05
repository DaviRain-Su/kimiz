### T-011: 创建 kimiz-prompts 模块
**状态**: completed
**优先级**: P1
**创建**: 2026-04-05
**完成**: 2026-04-05
**预计耗时**: 3h
**实际耗时**: 2.5h

**描述**:
实现 PRD 中的 kimiz-prompts 模块 - 提示词工程、模板、优化。

**文件**:
- `src/prompts/root.zig` - 完整实现

**已实现功能**:
- [x] 创建 `src/prompts/` 目录
- [x] 提示词模板系统 (PromptTemplate, PromptRegistry)
- [x] 模板变量定义支持
- [x] 提示词分类 (system, user, tool, skill, analysis)
- [x] 内置系统提示词模板
- [x] **模板变量替换实现** - `render()` 和 `renderSimple()` 方法
- [x] **6个内置提示词模板** - system, code_review, refactor, test_gen, doc_gen, debug

**验收标准**:
- [x] 创建 `src/prompts/` 目录
- [x] 提示词模板系统
- [x] 模板变量替换（已实现）
- [x] 常用提示词模板（6个模板已定义）

**依赖**: 

**笔记**:
模板变量使用 `{variable_name}` 格式，支持：
- `render()` - 使用 StringHashMap 提供变量值
- `renderSimple()` - 使用简单的键值对数组
- 缺失变量时会记录警告并保持占位符

