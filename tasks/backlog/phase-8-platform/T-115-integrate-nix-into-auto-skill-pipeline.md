### T-115: integrate-nix-into-auto-skill-pipeline
**状态**: pending
**优先级**: P0
**创建**: 2026-04-05
**预计耗时**: 14h

**描述**:
将 Nix 集成到 auto skill 的编译流水线中，确保生成的 skill 在任何机器上都能可复现地编译。

Nix 是 Hardness Engineer 的"免疫系统"。需要：
1. 为 KimiZ 项目本身建立 flake.nix，锁定开发环境
2. 在 src/skills/auto/{name}/ 下自动生成 shell.nix
3. 修改生成流水线：编译 auto skill 前先进入 nix shell
4. 确保 zig 版本、系统依赖（如 libcurl, openssl）被精确锁定
5. 文档化：如何在 Nix 环境下开发和运行 KimiZ

参考文档: docs/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md

**验收标准**:
- [ ] 核心设计/原型实现
- [ ] 集成测试或验证通过
- [ ] 文档更新
- [ ] 与现有任务（T-100 ~ T-111）的兼容性确认

**依赖**: 

**笔记**:
- 来自战略文档: docs/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md
- 这是构建 Hardness Engineer 多层防御系统的核心组成部分
