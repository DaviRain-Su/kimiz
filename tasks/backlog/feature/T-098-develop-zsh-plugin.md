### T-098: develop-zsh-plugin
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 6h

**描述**:
开发 Zsh 插件 `zsh-kimiz`，实现从 Zsh 终端快速进入 KimiZ。

kimi-cli 有官方 `zsh-kimi-cli` 插件，按 Ctrl-X 即可切换。本任务需要：
1. 创建 `zsh-kimiz` 仓库（或放在 `integrations/zsh/` 目录）
2. 实现 Zsh widget，监听 Ctrl-X 键位
3. 当前行如果有输入，将其作为 prompt 传递给 KimiZ
4. 支持 Oh My Zsh、zinit、zplug 等插件管理器安装
5. 提供安装文档和示例配置

参考: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md (GAP-9)

**验收标准**:
- [ ] 核心功能实现
- [ ] 集成到主循环/CLI
- [ ] 基础测试覆盖
- [ ] 文档更新

**依赖**: 

**笔记**:
- 来自差距分析文档: docs/KIMIZ-vs-KIMI-CLI-GAP-ANALYSIS.md
