# fff C FFI 可行性验证报告

**日期**: 2026-04-05  
**验证者**: Claude Code  
**目标**: 确认 fff 是否支持 C FFI 导出

---

## 验证步骤

### Step 1: 检查 fff 源码结构

```bash
git clone https://github.com/dmtrKovalenko/fff.nvim /tmp/fff-verify
cd /tmp/fff-verify && ls -la
```

**预期检查项**:
- [ ] 是否有 `ffi/` 或 `c/` 目录
- [ ] `Cargo.toml` 是否有 `cdylib` 或 `cffi` feature
- [ ] 是否有 `.h` 头文件

### Step 2: 检查 Cargo.toml

```bash
cat /tmp/fff-verify/Cargo.toml | grep -A5 -B5 "cdylib\|ffi\|capi"
```

**关键查找**:
- `crate-type = ["cdylib"]` - 支持动态库导出
- `[features]` 中是否有 `cffi` 或 `c-api`

### Step 3: 尝试构建

```bash
cd /tmp/fff-verify

# 尝试 1: 原生 C FFI
cargo build --release --features cffi 2>&1 || echo "❌ No cffi feature"

# 尝试 2: 动态库
cargo build --release --crate-type cdylib 2>&1 || echo "❌ cdylib build failed"

# 尝试 3: 查看可用 features
cargo metadata --format-version 1 | grep -o '"features":{[^}]*}' | head -5
```

### Step 4: 检查导出符号

```bash
# 如果构建成功，检查 C 符号
nm -D /tmp/fff-verify/target/release/*.so 2>/dev/null | head -20 || \
nm /tmp/fff-verify/target/release/*.a 2>/dev/null | head -20
```

---

## 可能的结果

### 结果 A: fff 原生支持 C FFI ✅
```
发现:
- Cargo.toml 有 crate-type = ["cdylib"]
- 有现成的 .h 头文件
- 构建成功，有 C 符号导出

结论: 可以直接使用，无需 wrapper
下一步: 直接写 Zig 绑定
```

### 结果 B: fff 无 C FFI，需自行包装 ⚠️
```
发现:
- 只有 Rust API，无 C 导出
- 需要写 Rust wrapper

结论: 需要 8 小时实施 C FFI wrapper
下一步: 评估工作量，或先用 MCP Server
```

### 结果 C: fff 结构复杂，不易 FFI ❌
```
发现:
- 使用复杂 Rust 特性 (async, generics)
- 依赖 tokio/async-std
- 不易导出 C 接口

结论: 建议改用 MCP Server 方案
下一步: 放弃 C FFI，用 subprocess
```

---

## 执行命令

```bash
#!/bin/bash
set -e

echo "=== fff C FFI Feasibility Check ==="

# Clone
git clone --depth 1 https://github.com/dmtrKovalenko/fff.nvim /tmp/fff-verify 2>/dev/null || true
cd /tmp/fff-verify

echo -e "\n1. Checking structure..."
ls -la | head -20

echo -e "\n2. Checking Cargo.toml..."
grep -E "crate-type|features|ffi|capi" Cargo.toml || echo "No FFI features found"

echo -e "\n3. Checking for existing C bindings..."
find . -name "*.h" -o -name "*ffi*" -o -name "*c-api*" 2>/dev/null | head -10 || echo "No C binding files"

echo -e "\n4. Attempting build..."
rustc --version
cargo build --release 2>&1 | tail -20 || echo "Build failed or warnings"

echo -e "\n5. Checking output..."
ls -la target/release/*.so target/release/*.a target/release/*.dylib 2>/dev/null || echo "No libraries found"

echo -e "\n=== Verification Complete ==="
```

---

## 验证后决策

| 结果 | 建议 | 下一步 |
|------|------|--------|
| A (原生支持) | 直接 C FFI | 写 Zig 绑定 (3h) |
| B (需 wrapper) | 评估成本 | 8h 实施或转 MCP |
| C (不支持) | 用 MCP Server | 放弃 C FFI |

---

**执行验证吗？需要我运行上述检查命令？**
