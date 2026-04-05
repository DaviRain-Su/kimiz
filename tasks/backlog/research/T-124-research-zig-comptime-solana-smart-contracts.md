# T-124: 研究 Zig comptime 在 Solana 智能合约开发中的可行性

**任务类型**: Research  
**优先级**: P2  
**预计耗时**: 8h  
**创建日期**: 2026-04-06

---

## 1. 背景与目标

智能合约有一个致命特性：**部署后不可变**。一旦上链，bug 就是永久性的，且可能直接造成资金损失。这意味着先验验证（编译时 + 形式化验证）比任何其他领域都更重要。

Zig 的 `comptime` 提供了最廉价、最前置的验证层。而 Solana 的 SBF（Solana Bytecode Format）基于 BPF，Zig 使用 LLVM 后端理论上可以编译为 BPF 目标。这引出一个核心问题：

> **能否将 KimiZ 的 Hardness Engineering 方法论应用于 Solana 智能合约开发，让 LLM 生成的 Zig 代码在 comptime 阶段就被严格验证，然后编译为链上可执行的字节码？**

本研究任务的目标是评估这一构想的可行性，找出最快验证路径，以及需要解决的关键技术障碍。

---

## 2. Research

- [ ] [Solana SBF Documentation](https://docs.solana.com/programs/faq) — 理解 SBF/BPF 虚拟机限制和官方支持的语言
- [ ] [Solana C SDK](https://github.com/solana-labs/solana/tree/master/sdk/bpf/c) — 了解 Solana 对 C 语言的官方支持，评估 Zig→C→BPF 路径
- [ ] [Zig LLVM BPF Target Status](https://ziglang.org/download/) / Zig Issue Tracker — 评估 Zig 直接编译到 BPF 的成熟度
- [ ] [Anchor Framework Architecture](https://book.anchor-lang.com/) — 理解 Rust/Anchor 如何抽象 Solana 底层，为可能的 Zig→Rust/Anchor 生成路径做准备
- [ ] [Neon EVM / LLVM on Solana](https://neonevm.org/) — 参考其他非 Rust 语言进入 Solana 生态的策略

> 如果在研究过程中发现新的关键参考，更新此列表并在 `Log` 中记录。

---

## 3. Spec

> 本任务为纯 Research 任务，不涉及代码实现。输出为一份可行性研究报告：

**研究报告**: `docs/research/ZIG-COMPTIME-SOLANA-FEASIBILITY.md`

### 3.1 关键设计决策（预研究假设）
- **假设 A**: Zig 的 `comptime` 运行在宿主编译器上，可以在部署前拦截 80% 的结构错误
- **假设 B**: Solana C SDK 为 Zig→C→BPF 提供了一条现成可用的路径
- **假设 C**: 纯 Zig Solana 框架需要 6-12 个月全职投入，且生态为零

---

## 4. 验收标准

- [ ] 完成 Solana SBF 虚拟机对非 Rust 语言支持的调研
- [ ] 验证 Zig 编译到 BPF/SBF 目标的技术状态（能否编译 hello world 级别的合约？）
- [ ] 明确三条可能路径的优缺点：
  - 路径 A：Zig 生成 Rust/Anchor 代码（利用现有生态）
  - 路径 B：Zig 编译为 C，再用 Solana C SDK 编译为 BPF
  - 路径 C：纯 Zig 框架直接编译为 BPF
- [ ] 识别智能合约特有漏洞（重入、权限绕过、整数溢出）能否通过 comptime DSL 编码约束
- [ ] 产出 `docs/research/ZIG-COMPTIME-SOLANA-FEASIBILITY.md` 报告
- [ ] 给出 go / no-go / 延后 的明确建议

---

## 5. Log

- `2026-04-06 17:30` — 任务创建，来自创始人提出的 "Zig comptime + Solana Hardness Engineering" 构想

---

## 6. Lessons Learned

> 任务完成后填写

**分类**: 架构决策 / 跨生态研究 / 长期战略

**内容**:
- （待研究完成后填写）

**后续动作**:
- [ ] 如果结果为 go，创建 Phase 1 设计任务（如 T-125-design-zig-anchor-generator）
- [ ] 更新 `docs/DESIGN-REFERENCES.md` 添加 Solana 相关参考
