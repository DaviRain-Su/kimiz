# ziggy-pydust Python 互操作分析与 Kimiz 整合评估

**研究日期**: 2026-04-05  
**项目链接**: https://github.com/spiraldb/ziggy-pydust  
**作者**: SpiralDB (Zig 生态活跃团队)  
**评估目标**: 是否可作为 kimiz 的 Python 互操作工具

---

## 1. 项目概述

**ziggy-pydust** 是一个 **Zig 编写的 Python 扩展框架**，核心功能：

- **Python 模块**: 用 Zig 编写 Python 可导入的模块
- **性能**: Zig 性能 + Python 易用性
- **类型转换**: 自动 Zig/Python 类型转换
- **用途**: 性能关键代码用 Zig 写，业务逻辑用 Python

**示例**:
```zig
// 用 Zig 写 Python 模块
const py = @import("pydust");

pub fn add(a: i64, b: i64) i64 {
    return a + b;
}
```

```python
# Python 调用 Zig 代码
import my_zig_module
result = my_zig_module.add(1, 2)  # 3
```

---

## 2. 与 Kimiz 使用场景匹配度分析

### 2.1 Kimiz 是什么?

- **类型**: CLI AI Coding Agent
- **语言**: Zig (核心) + 可能的外部工具
- **场景**: 代码编辑、文件操作、命令执行、网络请求
- **用户**: 开发者直接使用

### 2.2 Python 互操作的需求分析

| 场景 | 描述 | 需求度 | 说明 |
|------|------|--------|------|
| **调用 Python 库** | 使用 Python 生态 (如 numpy, pandas) | 低 | kimiz 是 CLI 工具，不需要 |
| **被 Python 调用** | 作为 Python 模块使用 | 很低 | 用户直接用 CLI |
| **混合编程** | Zig + Python 混合项目 | 低 | 不是核心功能 |
| **性能优化** | 用 Zig 加速 Python 代码 | 低 | 不适用 |

### 2.3 关键问题

**kimiz 需要 Python 互操作吗?**

> **答案: 不需要**

原因:
1. kimiz 是**独立 CLI 工具**，不是库
2. 用户直接执行 `kimiz run ...`，不通过 Python 调用
3. kimiz 的功能 (文件操作、命令执行) 不需要 Python 生态

---

## 3. 整合方案评估

### 方案 A: 不整合 (推荐)

**理由**:
- kimiz 是 CLI 工具，不需要 Python 互操作
- 增加复杂度，但无实际收益
- 与核心功能无关

### 方案 B: Python 插件系统 (未来可能)

如果 kimiz 未来支持 Python 插件：

```zig
// 用 ziggy-pydust 支持 Python 插件
pub const PythonPlugin = struct {
    // 加载 Python 脚本作为插件
    // 用户可用 Python 扩展 kimiz 功能
};
```

**但这需要重大架构变更，当前不适用。**

### 方案 C: 利用 Python 生态 (不适用)

例如：
- 用 Python 的文档解析库
- 用 Python 的机器学习库
- 用 Python 的网络爬虫

**不适用**: kimiz 可以用 Zig 原生库或外部 CLI 工具实现这些功能。

---

## 4. 与现有工具的对比

| 工具类型 | 例子 | 是否需要 Python | 说明 |
|---------|------|----------------|------|
| **文件搜索** | fff | ❌ 不需要 | Zig 原生 |
| **网络搜索** | web_search | ❌ 不需要 | HTTP API |
| **PDF 处理** | zpdf | ❌ 不需要 | Zig 原生 |
| **图像处理** | zigimg | ❌ 不需要 | Zig 原生 |
| **浏览器** | Lightpanda | ❌ 不需要 | Zig 原生 |

**趋势**: kimiz 选择 **Zig 原生** 或 **外部 CLI** 工具，不需要 Python 互操作。

---

## 5. 决策建议

### 推荐: 不整合

> **ziggy-pydust 是优秀的项目，但与 kimiz 无关**

**理由**:
1. **架构不匹配**: kimiz 是 CLI 工具，不是 Python 库
2. **无使用场景**: 用户不通过 Python 使用 kimiz
3. **增加复杂度**: 引入 Python 依赖，但无收益
4. **与定位冲突**: kimiz 是 Zig 原生 Agent，不是混合方案

### 如果未来需要...

只有当 kimiz 演进为以下形态时才考虑：
- **Python 库**: `import kimiz` 在 Python 中使用
- **插件系统**: 支持 Python 插件扩展
- **混合项目**: 需要 Zig + Python 协作

**当前无此计划。**

---

## 6. 结论

### 一句话总结

> **"ziggy-pydust 是 Zig↔Python 桥梁，但 kimiz 不需要这座桥"**

### 决策

| 工具 | 功能 | 决策 | 理由 |
|------|------|------|------|
| ziggy-pydust | Python 互操作 | ❌ 不整合 | kimiz 是 CLI 工具，不需要 Python 集成 |

### 替代方案

如果用户需要 Python 功能：
```bash
# 通过 bash 调用 Python 脚本
$ kimiz tool bash --command "python3 my_script.py"

# 或调用 Python 编写的工具
$ kimiz tool bash --command "python3 -m http.server"
```

---

## 7. 参考

- ziggy-pydust: https://github.com/spiraldb/ziggy-pydust
- 相关讨论:
  - kimiz 是 CLI 工具，不是库
  - Zig 原生工具优先策略

---

*文档版本: 1.0*  
*最后更新: 2026-04-05*  
*维护者: kimiz-core-team*
