# T-128-05: Review Agent — 多角色评审 + Prompt Cascade

**优先级**: P1 | **预计耗时**: 2h | **依赖**: T-128-04

## 描述

实现 Review 角色定义、ReviewReport 结构、Prompt cascade 加载。

## 影响文件

| 文件 | 改动 |
|------|------|
| `src/engine/review.zig` | 新增：ReviewRole 枚举、ReviewReport、ReviewAgent、review() |
| `src/prompts/loader.zig` | 新增：PromptLoader、loadPrompt()、cascade 优先级加载 |
| `prompts/review/` | 新增：至少 4 个角色 prompt（product-manager, system-architect, tech-lead, code-reviewer） |

## 验收标准

- [ ] 7 个 Review 角色枚举
- [ ] ReviewReport 包含 status(PASS/NEEDS_REVISION/BLOCKED) + feedback
- [ ] PromptLoader 按 `.kimiz/prompts/review/` > `~/.kimiz/` > `prompts/review/` 优先级加载
- [ ] `prompts/review/` 目录下至少 4 个角色 prompt 文件
- [ ] 至少 3 个测试（cascade 加载/角色覆盖/评审结果解析）

