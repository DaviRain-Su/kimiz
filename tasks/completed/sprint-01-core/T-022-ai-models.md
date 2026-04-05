### T-022: 实现 AI Models 定义和成本计算
**状态**: completed
**优先级**: P1
**创建**: 2026-04-05
**完成**: 2026-04-05
**预计耗时**: 2h
**实际耗时**: 2h

**描述**:
定义所有支持的 AI 模型及其成本计算规则。

**文件**:
- `src/ai/models.zig` (约250行)

**已实现功能**:
- [x] 模型定义结构体
- [x] 成本计算规则
- [x] 模型能力定义
- [x] 模型映射和查找

**支持的模型**:
- **OpenAI**: GPT-4o, GPT-4o-mini, o1-preview, o1-mini, o3-mini
- **Anthropic**: Claude 3.5 Sonnet, Claude 3 Opus/Haiku
- **Google**: Gemini 2.0 Flash, Gemini 1.5 Pro/Flash
- **Kimi**: k1, moonshot-v1 系列
- **Fireworks**: 各种开源模型

**成本计算**:
- [x] Input token 成本
- [x] Output token 成本
- [x] 缓存 token 折扣
- [x] 总成本计算

**验收标准**:
- [x] 所有模型定义完整
- [x] 成本计算准确
- [x] 模型查找功能正常
- [x] 支持新模型扩展

**依赖**: T-002 (核心类型)

**笔记**:
完整的模型定义和成本计算实现。
