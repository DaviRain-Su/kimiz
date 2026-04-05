### T-085: integrate-codedb-explore-index-module
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 8h

**描述**:
将 CodeDB 的代码智能索引能力集成进 KimiZ，弥补当前项目在大型代码库中缺乏结构性查询能力的短板。

CodeDB 提供了强大的结构性索引（trigram search、word index、symbol/outline、deps graph），而 KimiZ 目前仅依赖基础的 read_file / search_files tools。集成后，KimiZ 的 Agent 将能够快速定位符号定义、分析依赖关系、搜索代码内容，显著提升在大型项目中的编码效率。

**集成方案**（二选一，建议方案 B）：
- 方案 A: 将 CodeDB 的 `explore.zig`、`index.zig`、`store.zig` 核心模块内嵌到 KimiZ 中
- 方案 B: KimiZ 作为 MCP client，通过 stdio 调用 CodeDB 的 16 个 MCP tools

**验收标准**:
- [ ] 确定最终集成方案（A 内嵌 / B MCP）
- [ ] KimiZ 能执行 `symbol` 查询（查找函数/结构体定义）
- [ ] KimiZ 能执行 `outline` 查询（获取文件符号列表）
- [ ] KimiZ 能执行 `search` / `word` 查询（快速代码搜索）
- [ ] KimiZ 能执行 `deps` / `tree` 查询（依赖分析和文件树）
- [ ] 在 KimiZ 的 read/edit workflows 中实际使用上述查询结果
- [ ] 更新相关文档和测试

**依赖**: 
- CodeDB 仓库研究完成
- KimiZ tool system 架构稳定

**笔记**:
- CodeDB 是 Zig 编写的 MCP-native 代码智能服务器
- 核心优势: structural indexing、16 MCP tools、多代理锁、版本存储
- 参考: https://github.com/justrach/codedb
