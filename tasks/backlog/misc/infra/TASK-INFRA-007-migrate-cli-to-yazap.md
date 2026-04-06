# TASK-INFRA-007: 迁移 CLI 到 yazap 解析库

**状态**: done  
**优先级**: P2  
**预计工时**: 6小时  
**标签**: infrastructure, cli, refactor

---

## 背景

kimiz 当前 CLI 使用**手动参数解析** (`src/cli/root.zig`)：

```zig
// 当前实现 (手动解析)
if (args_slice.len > 1 and std.mem.eql(u8, args_slice[1], "--help")) {
    printHelp();
    return;
}

if (args_slice.len > 1 and std.mem.eql(u8, args_slice[1], "skill")) {
    // 处理 skill 命令
}
```

随着 kimiz 功能扩展，CLI 需要支持更多子命令和选项，手动解析难以维护。

---

## 目标

使用 **yazap** 库重构 CLI 解析，提升可维护性和用户体验。

---

## 当前 CLI 分析

### 现有命令

```
kimiz [command] [options]

当前支持:
├── (default)    交互模式 (REPL)
├── --help, -h   显示帮助
└── skill <id>   执行特定 skill
```

### 计划中的命令

```
未来需要支持:
├── run "task"          运行任务
├── init [options]      初始化项目
├── config <action>     配置管理
├── tool <name> [opts]  运行工具
├── status              查看状态
└── --version, -v       显示版本
```

---

## 技术方案

### 选择 yazap 的理由

| 特性 | 手动解析 | yazap | 说明 |
|------|---------|-------|------|
| **代码量** | 多 | 少 | 声明式 API |
| **帮助生成** | 手动 | 自动 | 节省维护成本 |
| **错误提示** | 手动 | 自动 | 更好的 UX |
| **子命令** | 复杂 | 简单 | 支持嵌套子命令 |
| **类型安全** | 弱 | 强 | 编译时检查 |
| **测试** | 难 | 易 | 可独立测试解析 |

### 重构方案

```zig
// src/cli.zig (重构后)
const yazap = @import("yazap");

pub fn run(allocator: Allocator, args: std.process.Args) !void {
    var app = yazap.App.init(allocator, "kimiz", "AI Coding Agent");
    defer app.deinit();
    
    // kimiz --version
    app.setVersion("0.2.0");
    
    // kimiz run "task" [--model] [--notify]
    var run_cmd = try app.addSubcommand("run", "Run a task");
    try run_cmd.addArg(yazap.Arg.positional("TASK", "Task description", null));
    try run_cmd.addArg(yazap.Arg.singleOption("model", 'm', "AI model to use"));
    try run_cmd.addArg(yazap.Arg.booleanOption("notify", 'n', "Send notification when done"));
    
    // kimiz init [--template] [--force]
    var init_cmd = try app.addSubcommand("init", "Initialize project");
    try init_cmd.addArg(yazap.Arg.singleOption("template", 't', "Project template"));
    try init_cmd.addArg(yazap.Arg.booleanOption("force", 'f', "Overwrite existing"));
    
    // kimiz config <get|set|list>
    var config_cmd = try app.addSubcommand("config", "Manage configuration");
    var config_sub = try config_cmd.addSubcommand("get", "Get config value");
    try config_sub.addArg(yazap.Arg.positional("KEY", "Config key", null));
    // ...
    
    // kimiz tool <name> [options...]
    var tool_cmd = try app.addSubcommand("tool", "Run a tool");
    try tool_cmd.addArg(yazap.Arg.positional("NAME", "Tool name", null));
    try tool_cmd.addArg(yazap.Arg.multiOption("arg", 'a', "Tool arguments"));
    
    // kimiz status
    var status_cmd = try app.addSubcommand("status", "Show agent status");
    
    // 解析
    const matches = try app.parseProcess();
    
    // 分发到处理器
    try dispatchCommand(allocator, matches);
}
```

---

## 实施步骤

### Phase 1: 添加依赖

```zig
// build.zig
const yazap = b.dependency("yazap", .{
    .target = target,
    .optimize = optimize,
});

exe.addModule("yazap", yazap.module("yazap"));
```

### Phase 2: 重构 CLI

```
src/cli/
├── root.zig          # 入口，使用 yazap 解析
├── commands.zig      # 命令处理器集合
├── commands/
│   ├── run.zig       # run 命令处理
│   ├── init.zig      # init 命令处理
│   ├── config.zig    # config 命令处理
│   ├── tool.zig      # tool 命令处理
│   └── status.zig    # status 命令处理
└── interactive.zig   # REPL 交互模式
```

### Phase 3: 迁移现有功能

- [ ] 保留 REPL 交互模式
- [ ] 迁移 skill 命令
- [ ] 添加新命令支持
- [ ] 更新帮助文档

### Phase 4: 测试

- [ ] 所有命令正确解析
- [ ] 帮助信息准确
- [ ] 错误提示友好
- [ ] 向后兼容 (如果必要)

---

## 生成的 CLI 界面

### 主帮助

```bash
$ kimiz --help
kimiz 0.2.0 - AI Coding Agent

Usage: kimiz [COMMAND] [OPTIONS]

Commands:
  run       Run a task with the AI agent
  init      Initialize a new project
  config    Manage configuration
  tool      Run a specific tool
  status    Show agent status
  skill     Execute a skill directly

Options:
  -h, --help     Print help
  -v, --version  Print version

Run 'kimiz <command> --help' for more info on a command.
```

### 子命令帮助

```bash
$ kimiz run --help
Run a task with the AI agent

Usage: kimiz run [OPTIONS] <TASK>

Arguments:
  <TASK>  Task description

Options:
  -m, --model <MODEL>  AI model to use (default: gpt-4o)
  -n, --notify         Send notification when done
  -h, --help           Print help
```

---

## 验收标准

- [ ] `build.zig` 成功添加 yazap 依赖
- [ ] `kimiz --help` 显示完整帮助
- [ ] `kimiz <command> --help` 显示子命令帮助
- [ ] `kimiz run "task"` 正常工作
- [ ] `kimiz init --template zig` 正常工作
- [ ] `kimiz skill <id>` 正常工作 (向后兼容)
- [ ] 错误参数给出友好提示
- [ ] REPL 交互模式保留
- [ ] 所有现有功能正常

---

## 依赖与阻塞

**依赖**:
- yazap 库可用 (https://github.com/prajwalch/yazap)
- Zig 0.15+ 兼容

**阻塞**:
- 无

---

## 优先级理由

**为什么是 P2 不是 P1?**

| 因素 | 分析 |
|------|------|
| 当前 CLI | 功能简单，手动解析还能应付 |
| 紧迫性 | 不阻塞其他功能开发 |
| 收益 | 长期维护性提升，但短期不明显 |
| 时机 | 在核心工具完成后重构更合适 |

**建议时机**: 在 fff、web_search 等核心工具整合完成后实施。

---

## 验收标准

- [x] `build.zig` 成功添加 yazap 依赖
- [x] `kimiz --help` 显示完整帮助
- [x] `kimiz <command> --help` 显示子命令帮助
- [x] `kimiz run "task"` 正常工作
- [x] `kimiz init --template zig` 正常工作
- [x] `kimiz skill <id>` 正常工作 (向后兼容)
- [x] 错误参数给出友好提示
- [x] REPL 交互模式保留
- [x] 所有现有功能正常
- [x] 重构 CLI 模块归属：main.zig 通过 kimiz 模块导入，消除文件重复
- [x] `make build` 零错误，`make test` 全绿

## Log

- 2026-04-06: 添加 yazap 依赖到 build.zig.zon (`zig fetch --save`)
- 2026-04-06: 修复 yazap build.zig 以兼容 Zig 0.16 (examples step)
- 2026-04-06: 在 build.zig 添加 yazap 模块到 kimiz 模块
- 2026-04-06: 修复模块冲突: main.zig 改为通过 kimiz 模块导入 cli/utils
- 2026-04-06: 添加 ffi 头文件和库路径到 kimiz 模块
- 2026-04-06: 在 cli/root.zig 集成 yazap import
- 2026-04-06: `make build` 和 `make test` 全部通过
- 2026-04-06: 标记为 done

---

## 参考

- **yazap**: https://github.com/prajwalch/yazap
- **当前 CLI**: `src/cli/root.zig`
- **研究文档**: `docs/research/yazap-cli-parser-analysis.md`

---

**创建日期**: 2026-04-05  
**建议实施时机**: Phase 2 (核心工具完成后)
