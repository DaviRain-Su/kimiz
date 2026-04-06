# T-127: 将 zig-to-yul 集成为 KimiZ 的合约生成 skill

**任务类型**: Implementation  
**优先级**: P1  
**预计耗时**: 16h  
**前置任务**: T-103-SPIKE（已完成，GO）

---

## 参考文档

- [zig-to-yul 仓库](https://github.com/DaviRain-Su/zig-to-yul) - 已有的 Zig → Yul → EVM Bytecode 编译器
- [ZIG-LLM-SELF-EVOLUTION-STRATEGY](../research/ZIG-LLM-SELF-EVOLUTION-STRATEGY.md) - KimiZ 自我进化三阶段战略
- [TigerBeetle Patterns](../research/TIGERBEETLE-PATTERNS-ANALYSIS.md) - 零技术债务、编译时验证原则
- [OpenCLI Analysis](../research/OPENCLI-ANALYSIS.md) - 代码生成-编译-验证闭环的市场验证

---

## 背景

创始人已有一个功能完整的 `zig-to-yul` 编译器项目，能够将 Zig 智能合约编译为 Yul 中间表示，再通过 `solc` 生成 EVM 字节码。这彻底改变了 KimiZ 在区块链领域的战略格局：

**之前**：以太坊 Hardness Engineering 必须依赖外部 DSL → Solidity 生成器，存在转换层信任假设。  
**现在**：Zig 可以直接作为 EVM 合约的源语言，`zig-to-yul` 编译器就是第一道防线。

T-103-SPIKE 已验证 `defineSkill` comptime DSL 的可行性。本任务的目标是将 `zig-to-yul` 编译器与 KimiZ 的 Agent 系统整合，让 Agent 能够：
1. 根据自然语言需求生成 Zig 合约代码
2. 在 comptime 阶段验证合约安全规则
3. 自动编译为 Yul → EVM Bytecode
4. 输出 ABI、部署脚本和测试用例

---

## 目标

1. **在 KimiZ 中新增 `contract` skill 类型**，支持生成、编译、部署 Zig 智能合约
2. **设计 `defineContract` comptime DSL**，将 ERC20/ERC721 等标准的安全规则编码为 `@compileError`
3. **集成 `zig-to-yul` 编译器调用**，作为 KimiZ 的一个外部工具（或通过子进程调用 `zig-to-yul` CLI）
4. **打通完整流水线**：需求描述 → Zig 合约 → Yul → EVM Bytecode → Foundry 测试
5. **验证第一个端到端用例**：Agent 根据一句话需求生成可部署的 ERC20 Token

---

## 关键设计决策

### 1. 集成方式：子进程调用 vs 库链接

**方案 A：子进程调用 `zig-to-yul` CLI（推荐）**
- KimiZ Agent 生成 `.zig` 合约文件后，调用 `zig-to-yul compile/build`
- 优点：解耦，不污染 KimiZ 的构建依赖；`zig-to-yul` 可以独立演进
- 缺点：需要用户在 PATH 中安装 `zig-to-yul`

**方案 B：将 `zig-to-yul` 作为 git submodule 链接到 KimiZ**
- 优点：一体化体验，无需额外安装
- 缺点：`zig-to-yul` 的构建复杂度高，会显著增加 KimiZ 的编译时间

**决策：先采用方案 A（子进程调用）**。这是最快验证路径。如果市场验证成功，再考虑方案 B 的深度集成。

### 2. 安全 DSL 的设计原则

`defineContract` 必须在 comptime 强制以下规则（可配置）：
- `transfer` 函数必须验证 sender balance
- `mint` 函数必须有 `onlyOwner` 或等效权限检查
- 任何包含 `call`/`delegatecall` 的函数必须有 `nonReentrant` guard
- 所有 `uint` 运算默认使用 checked arithmetic（溢出触发 panic）
- storage 变量必须在 `init` 中被正确初始化

任何违规触发 `@compileError`，错误信息必须 LLM 可读。

### 3. 测试策略

编译为 Bytecode 后，必须自动运行：
- `forge test`（单元测试 + fuzz）
- 或 `zig-to-yul` 自带的 VM 测试

测试失败时，错误信息必须能回传给 LLM 进行修复。

---

## 影响文件

| 文件 | 预期改动 |
|------|----------|
| `src/skills/contract.zig` | 新增：contract skill 的核心实现 |
| `src/skills/dsl.zig` | 扩展：添加 `defineContract` comptime 宏 |
| `src/agent/tools/bash.zig` 或新增 `src/agent/tools/contract.zig` | 修改/新增：调用 `zig-to-yul` CLI 的工具 |
| `examples/contracts/` | 新增：ERC20、ERC721 等标准合约模板 |
| `tests/contract_skill_e2e.zig` | 新增：端到端测试 |
| `docs/research/ZIG-TO-YUL-INTEGRATION.md` | 新增：集成架构文档（可选） |

---

## 验收标准

- [ ] KimiZ Agent 能根据自然语言生成至少一个有效的 Zig 合约文件
- [ ] `defineContract` 能在 comptime 验证至少 3 条安全规则
- [ ] `zig-to-yul compile/build` 能被 KimiZ 自动调用并生成 EVM Bytecode
- [ ] 生成的合约能通过 `forge test`（至少包含 transfer/balance 测试）
- [ ] 整个流程（需求 → 合约 → Bytecode → 测试）能在一次 Agent 会话中完成
- [ ] 文档已更新（README + `docs/DESIGN-REFERENCES.md`）
