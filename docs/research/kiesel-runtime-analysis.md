# Kiesel Runtime 分析与 Kimiz 整合评估

**研究日期**: 2026-04-05  
**项目链接**: https://codeberg.org/kiesel-js/runtime  
**平台**: Codeberg  
**相关项目**: https://codeberg.org/kiesel-js/kiesel (Kiesel JS 引擎)

---

## 1. 项目概述

**Kiesel Runtime** 是 Kiesel JavaScript 引擎的**运行时环境**：

- **定位**: Kiesel JS 引擎的运行时支持库
- **功能**: 可能提供标准库、模块系统、事件循环等
- **配套**: 与 Kiesel 引擎配合使用
- **语言**: Zig

**可能包含的功能**:
- JavaScript 标准库实现 (console, setTimeout, 等)
- 模块加载系统 (ES Modules)
- 事件循环 (Event Loop)
- 异步 I/O 支持
- 与宿主环境 (Zig) 的绑定

---

## 2. 与 Kiesel 引擎的关系

```
Kiesel JS 项目结构:
├── kiesel (引擎核心)
│   ├── 解析器 (Parser)
│   ├── 字节码编译器
│   └── 执行引擎
│
└── runtime (运行时)
    ├── 标准库 (console, Buffer, 等)
    ├── 模块系统
    ├── 事件循环
    └── I/O 绑定
```

**关系**: runtime 依赖引擎，提供完整的 JS 执行环境

---

## 3. 与 Kimiz 的关联

### 继承 Kiesel 的评估结论

基于 `docs/research/kiesel-js-engine-analysis.md` 的结论：

| 评估项 | Kiesel 引擎 | Kiesel Runtime | 结论 |
|--------|------------|----------------|------|
| **整合建议** | ⚠️ 保持关注 | ⚠️ 保持关注 | 相同 |
| **优先级** | P3 | P3 | 相同 |
| **原因** | Node.js 已足够 | Node.js 已足够 | 相同 |

### 具体场景

**场景 1: 完整的 JS 执行环境**

如果整合 Kiesel，通常也需要 runtime：
```
Kiesel 引擎 + Runtime = 完整的 JS 环境
```

**但**: kimiz 不需要嵌入式 JS 执行

**场景 2: 标准库支持**

Runtime 提供 JS 标准库：
- console.log
- setTimeout/setInterval
- Promise/async-await
- 等

**但**: 通过 bash 调用 Node.js 已有完整标准库

---

## 4. 决策

### 结论: 保持关注，与 Kiesel 一致

> **"Kiesel Runtime 与 Kiesel 引擎评估结论一致：保持关注，暂不整合"**

**理由**:
1. **依赖关系**: runtime 与引擎绑定，决策一致
2. **使用场景**: 同样需要嵌入式 JS 执行场景才需要
3. **替代方案**: Node.js 通过 bash 调用已有完整运行时

### 使用方式

```bash
# 如需 JS 执行，继续使用 Node.js
$ kimiz tool bash --command "node script.js"
```

---

## 5. 参考

- **Kiesel Runtime**: https://codeberg.org/kiesel-js/runtime
- **Kiesel 引擎**: https://codeberg.org/kiesel-js/kiesel
- **相关分析**: `docs/research/kiesel-js-engine-analysis.md`

---

*文档版本: 1.0*  
*最后更新: 2026-04-05*  
*维护者: kimiz-core-team*
