### T-117: wasm-wasi-sandbox-prototype
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 20h

**描述**:
实现 WASM/WASI 沙箱原型，让 auto skill 在受控环境中运行。

Capability-based security 的核心落地。需要：
1. 调研并选型一个 Zig 友好的 WASM runtime（wasmtime / wasmer / wazero）
2. 将一个简单的 auto skill 编译为 .wasm（使用 zig target wasm32-wasi）
3. 在 KimiZ host 中加载该 WASM，并通过 WASI 接口调用
4. 实现 capability 注入：只授予 manifest 中声明的文件/网络权限
5. 验证：WASM 模块无法访问未授权的资源

参考文档: docs/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md, NullClaw main_wasi.zig

**验收标准**:
- [ ] 核心设计/原型实现
- [ ] 集成测试或验证通过
- [ ] 文档更新
- [ ] 与现有任务（T-100 ~ T-111）的兼容性确认

**依赖**: 

**笔记**:
- 来自战略文档: docs/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md
- 这是构建 Hardness Engineer 多层防御系统的核心组成部分
