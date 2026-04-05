# yazap 命令行解析库分析与 Kimiz 整合评估

**研究日期**: 2026-04-05  
**项目链接**: https://github.com/prajwalch/yazap  
**评估目标**: 是否可作为 kimiz 的 CLI 参数解析方案

---

## 1. 项目概述

**yazap** (Yet Another Zig Argument Parser) 是一个 **Zig 编写的命令行参数解析库**：

- **功能**: 解析命令行参数、选项、子命令
- **特性**: 类似 Python argparse 的 API 设计
- **支持**: 位置参数、可选参数、子命令、帮助生成
- **语言**: Zig (与 kimiz 同语言)

**示例**:
```zig
const yazap = @import("yazap");

var app = yazap.App.init(allocator, "myapp", "My app description");
defer app.deinit();

var root = app.rootCommand();
try root.addArg(yazap.Arg.positional("FILE", "File to process", null));

try app.run();
```

---

## 2. 与 Kimiz 使用场景匹配度分析

### 2.1 Kimiz CLI 现状

**当前 kimiz 需要 CLI 解析的场景**:

```
kimiz [command] [options] [arguments]

Examples:
- kimiz run "task description"
- kimiz init --template zig
- kimiz config set key value
- kimiz tool fff --query "main.zig"
```

### 2.2 现有方案评估

**kimiz 当前可能使用的方式**:

| 方案 | 说明 | 状态 |
|------|------|------|
| **手动解析** | 自己处理 std.process.args | 可能已存在 |
| **标准库** | Zig stdlib 有限支持 | 基础功能 |
| **外部库** | 如 yazap, clap 等 | 待评估 |

---

## 3. 整合方案评估

### 方案 A: 使用 yazap (推荐)

**作为 CLI 解析库替代手动解析**:

```zig
// src/cli.zig
const yazap = @import("yazap");

pub const Cli = struct {
    pub fn parse(allocator: Allocator) !CliOptions {
        var app = yazap.App.init(allocator, "kimiz", "AI Coding Agent");
        defer app.deinit();
        
        var root = app.rootCommand();
        
        // Add subcommands
        var run_cmd = try root.addSubcommand(yazap.Command.new("run", "Run a task"));
        try run_cmd.addArg(yazap.Arg.positional("TASK", "Task description", null));
        
        var init_cmd = try root.addSubcommand(yazap.Command.new("init", "Initialize project"));
        try init_cmd.addArg(yazap.Arg.singleOption("template", 't', "Project template"));
        
        // Parse
        const matches = try app.parseProcess();
        
        // Extract values
        if (matches.subcommand("run")) |run_matches| {
            return CliOptions{
                .command = .run,
                .task = run_matches.getSingleValue("TASK").?,
            };
        }
        // ...
    }
};
```

**优点**:
- ✅ Zig 原生，无外部依赖
- ✅ API 清晰，易于使用
- ✅ 自动生成帮助信息
- ✅ 支持复杂的子命令结构
- ✅ 类型安全

### 方案 B: 继续使用手动解析

如果当前解析足够简单：

```zig
// 手动解析 (现有)
for (args) |arg, i| {
    if (std.mem.eql(u8, arg, "run")) {
        // 处理 run 命令
    }
}
```

**缺点**:
- 命令复杂时难以维护
- 需要手动处理帮助生成
- 错误处理繁琐

### 方案 C: 其他 CLI 库

其他 Zig CLI 库对比：

| 库 | 特点 | 适合度 |
|----|------|--------|
| **yazap** | 类 Python argparse | ⭐⭐⭐⭐ |
| **clap** | 简洁 | ⭐⭐⭐ |
| **manual** | 手动解析 | ⭐⭐ |

---

## 4. 决策建议

### 推荐: 方案 A - 使用 yazap

**理由**:
1. **CLI 复杂度**: kimiz 需要支持多子命令 (run, init, config, tool 等)
2. **维护性**: 比手动解析更易维护
3. **用户体验**: 自动生成帮助和错误提示
4. **生态**: Zig 社区推荐的 CLI 解析方案

### 优先级

| 场景 | 优先级 | 说明 |
|------|--------|------|
| 替换现有 CLI 解析 | P2 | 如果已有简单实现，可后续迁移 |
| 新 CLI 功能开发 | P1 | 新项目直接使用 yazap |

---

## 5. 实施建议

### 如果 kimiz 已有 CLI 实现

**逐步迁移策略**:
```
Phase 1: 新功能使用 yazap
Phase 2: 逐步替换旧解析代码
Phase 3: 完全迁移
```

### 如果 kimiz CLI 较简单

**立即迁移**:
```bash
# 1. 添加依赖
# build.zig:
const yazap = b.dependency("yazap", .{});
exe.addModule("yazap", yazap.module("yazap"));

# 2. 重构 src/cli.zig
# 3. 测试所有命令
```

---

## 6. 使用场景示例

### 重构后的 kimiz CLI

```zig
// src/cli.zig
const yazap = @import("yazap");

pub fn main() !void {
    var app = yazap.App.init(allocator, "kimiz", "AI Coding Agent");
    
    // kimiz run "task"
    var run_cmd = try app.addSubcommand("run", "Run a task");
    try run_cmd.addArg(yazap.Arg.positional("TASK", "Task description", null));
    try run_cmd.addArg(yazap.Arg.booleanOption("notify", 'n', "Send notification"));
    
    // kimiz tool [name] [options]
    var tool_cmd = try app.addSubcommand("tool", "Run a tool");
    try tool_cmd.addArg(yazap.Arg.positional("NAME", "Tool name", null));
    
    // kimiz init [--template]
    var init_cmd = try app.addSubcommand("init", "Initialize project");
    try init_cmd.addArg(yazap.Arg.singleOption("template", 't', "Template name"));
    
    const matches = try app.parseProcess();
    
    // 处理解析结果
    try dispatchCommand(matches);
}
```

**生成的帮助**:
```bash
$ kimiz --help
AI Coding Agent

Usage: kimiz [COMMAND] [OPTIONS]

Commands:
  run     Run a task
  tool    Run a tool
  init    Initialize project
  config  Manage configuration

Options:
  -h, --help    Print help
  -v, --version Print version
```

---

## 7. 结论

### 一句话总结

> **"yazap 是 Zig CLI 的成熟方案，建议用于 kimiz 的命令行解析"**

### 决策

| 评估项 | 结论 |
|--------|------|
| 整合建议 | ✅ 使用 |
| 优先级 | P2 (如果已有 CLI) / P1 (如果重构) |
| 方式 | 替换现有手动解析 |
| 收益 | 更好的维护性、自动帮助、类型安全 |

### 立即行动

- [ ] 评估当前 kimiz CLI 实现复杂度
- [ ] 如果复杂，创建迁移任务
- [ ] 添加 yazap 依赖
- [ ] 重构 src/cli.zig

---

## 参考

- yazap: https://github.com/prajwalch/yazap
- Zig CLI 生态: https://github.com/natecraddock/zig-clap (备选)

---

*文档版本: 1.0*  
*最后更新: 2026-04-05*  
*维护者: kimiz-core-team*
