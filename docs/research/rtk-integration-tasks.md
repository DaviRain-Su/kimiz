# RTK Integration Tasks - Detailed Breakdown

## Phase 1: External Tool Wrapper (立即开始)

**目标**: 通过Skill包装rtk外部工具,快速验证token优化效果

### Task 1.1: 设计rtk Skill接口
**优先级**: P0  
**预计时间**: 1小时  
**输出**: Skill定义和参数设计

**设计要点**:
```zig
pub const rtk_optimize = Skill{
    .id = "rtk-optimize",
    .name = "RTK Token Optimizer",
    .description = "使用rtk压缩命令输出,减少60-90% tokens",
    .version = "1.0.0",
    .category = .misc,
    .params = &[_]SkillParam{
        .{
            .name = "command",
            .description = "要执行的命令",
            .param_type = .string,
            .required = true,
        },
        .{
            .name = "strategy",
            .description = "压缩策略: conservative/balanced/aggressive",
            .param_type = .selection,
            .required = false,
            .default_value = "balanced",
        },
    },
    .execute_fn = executeRTK,
};
```

**验收标准**:
- [ ] Skill参数定义清晰
- [ ] 支持3种压缩策略
- [ ] 文档说明完整

---

### Task 1.2: 实现rtk-optimize Skill
**优先级**: P0  
**预计时间**: 2-3小时  
**依赖**: Task 1.1  
**文件**: `src/skills/token_optimize.zig`

**实现步骤**:

1. **检测rtk是否安装**
```zig
fn checkRTKInstalled(allocator: std.mem.Allocator) !bool {
    const result = std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "which", "rtk" },
    }) catch return false;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    return result.term.Exited == 0;
}
```

2. **执行rtk命令**
```zig
fn executeRTK(
    ctx: SkillContext,
    args: std.json.ObjectMap,
    arena: std.mem.Allocator,
) !SkillResult {
    const start_time = std.time.milliTimestamp();
    
    // 检查rtk安装
    if (!try checkRTKInstalled(arena)) {
        return SkillResult{
            .success = false,
            .output = "",
            .error_message = "rtk not installed. Install: brew install rtk",
            .execution_time_ms = 0,
        };
    }
    
    // 获取参数
    const command = args.get("command").?.string;
    const strategy = if (args.get("strategy")) |s| 
        s.string 
    else 
        "balanced";
    
    // 构建rtk命令
    var argv = std.ArrayList([]const u8).init(arena);
    try argv.append("rtk");
    
    // 添加策略标志
    if (std.mem.eql(u8, strategy, "aggressive")) {
        try argv.append("-l");
        try argv.append("aggressive");
    }
    
    // 解析原始命令
    var cmd_iter = std.mem.tokenizeAny(u8, command, " \t");
    while (cmd_iter.next()) |part| {
        try argv.append(part);
    }
    
    // 执行
    const result = try std.ChildProcess.exec(.{
        .allocator = arena,
        .argv = argv.items,
        .cwd = ctx.working_dir,
    });
    defer arena.free(result.stdout);
    defer arena.free(result.stderr);
    
    const elapsed = std.time.milliTimestamp() - start_time;
    
    if (result.term.Exited == 0) {
        return SkillResult{
            .success = true,
            .output = try arena.dupe(u8, result.stdout),
            .execution_time_ms = @intCast(elapsed),
        };
    } else {
        return SkillResult{
            .success = false,
            .output = "",
            .error_message = try arena.dupe(u8, result.stderr),
            .execution_time_ms = @intCast(elapsed),
        };
    }
}
```

**验收标准**:
- [ ] rtk安装检测正常工作
- [ ] 支持3种策略(conservative/balanced/aggressive)
- [ ] 正确处理命令参数和工作目录
- [ ] 错误处理完善
- [ ] 返回执行时间

---

### Task 1.3: 注册rtk-optimize Skill
**优先级**: P0  
**预计时间**: 30分钟  
**依赖**: Task 1.2  
**文件**: `src/skills/builtin.zig`

**实现**:
```zig
// src/skills/builtin.zig
const token_optimize = @import("token_optimize.zig");

pub fn registerAll(registry: *SkillRegistry) !void {
    // 现有技能...
    
    // RTK token optimization
    try registry.register(token_optimize.rtk_optimize);
}
```

**验收标准**:
- [ ] Skill成功注册到registry
- [ ] 可通过ID查询到
- [ ] 出现在misc类别中

---

### Task 1.4: CLI命令支持
**优先级**: P0  
**预计时间**: 1-2小时  
**依赖**: Task 1.3  
**文件**: `src/cli/root.zig`

**已有基础**:
```zig
// src/cli/root.zig已有skill命令支持
if (args_slice.len > 1 and std.mem.eql(u8, args_slice[1], "skill")) {
    if (args_slice.len < 3) {
        printLine("Usage: kimiz skill <skill_id> [param=value...]");
        return;
    }
    try runSkillCommand(allocator, args_slice[2..]);
    return;
}
```

**需要增强**:
- 验证skill命令对特殊字符的处理(git命令中的引号等)
- 添加更好的参数解析(支持复杂命令)

**测试命令**:
```bash
kimiz skill rtk-optimize command="git status"
kimiz skill rtk-optimize command="ls -la" strategy=aggressive
kimiz skill rtk-optimize command="cargo test"
```

**验收标准**:
- [ ] 基本命令执行正常
- [ ] 支持带引号的复杂命令
- [ ] strategy参数正常工作
- [ ] 错误消息友好

---

### Task 1.5: 测试rtk-optimize功能
**优先级**: P0  
**预计时间**: 2小时  
**依赖**: Task 1.4

**测试用例**:

1. **基本功能测试**
```bash
# 1. Git命令
kimiz skill rtk-optimize command="git status"
kimiz skill rtk-optimize command="git log -n 10"

# 2. 文件命令
kimiz skill rtk-optimize command="ls -la"
kimiz skill rtk-optimize command="find . -name '*.zig'"

# 3. 测试命令
kimiz skill rtk-optimize command="cargo test"
```

2. **策略测试**
```bash
kimiz skill rtk-optimize command="git diff" strategy=conservative
kimiz skill rtk-optimize command="git diff" strategy=balanced
kimiz skill rtk-optimize command="git diff" strategy=aggressive
```

3. **错误处理测试**
```bash
# rtk未安装
unset RTK_PATH && kimiz skill rtk-optimize command="git status"

# 无效命令
kimiz skill rtk-optimize command="invalidcmd"

# 缺少参数
kimiz skill rtk-optimize
```

4. **Token节省验证**
```bash
# 对比测试
bash -c "git status" | wc -c          # 原始输出
kimiz skill rtk-optimize command="git status" | wc -c  # 优化后
# 计算节省百分比
```

**验收标准**:
- [ ] 所有测试用例通过
- [ ] Token节省达到预期(60-90%)
- [ ] 性能开销<50ms
- [ ] 错误消息清晰

---

### Task 1.6: 文档和示例
**优先级**: P1  
**预计时间**: 1-2小时  
**依赖**: Task 1.5

**文档内容**:

1. **README更新** (`README.md`)
```markdown
## Token优化

kimiz集成了rtk token优化器,可将命令输出压缩60-90%。

### 安装rtk
```bash
brew install rtk
```

### 使用
```bash
# 基本用法
kimiz skill rtk-optimize command="git status"

# 指定压缩策略
kimiz skill rtk-optimize command="ls -la" strategy=aggressive
```

### 支持的命令
- Git: status, log, diff, add, commit, push
- 文件: ls, find, grep, cat
- 测试: cargo test, npm test, pytest
- 构建: tsc, eslint, cargo clippy
```

2. **Skill文档** (`docs/skills/rtk-optimize.md`)
```markdown
# RTK Token Optimizer Skill

## 概述
使用rtk工具压缩命令输出,减少60-90%的token消耗。

## 参数
- `command` (必需): 要执行的命令
- `strategy` (可选): 压缩策略
  - `conservative`: 保留更多信息
  - `balanced`: 平衡(默认)
  - `aggressive`: 最大压缩

## 示例
[详细示例...]

## Token节省效果
[基准测试数据...]
```

3. **示例脚本** (`examples/rtk_demo.sh`)
```bash
#!/bin/bash
# RTK Token Optimizer演示

echo "=== Git Status ==="
kimiz skill rtk-optimize command="git status"

echo "=== Directory Listing ==="
kimiz skill rtk-optimize command="ls -la"

echo "=== Test Results ==="
kimiz skill rtk-optimize command="cargo test"
```

**验收标准**:
- [ ] README有清晰的使用说明
- [ ] Skill文档完整
- [ ] 示例可运行
- [ ] 包含性能数据

---

## Phase 1 总结

**完成后的状态**:
```
kimiz/
├── src/
│   ├── skills/
│   │   ├── token_optimize.zig  ✅ 新增
│   │   ├── builtin.zig         📝 更新
│   │   └── root.zig
│   └── cli/
│       └── root.zig             📝 验证
├── docs/
│   └── skills/
│       └── rtk-optimize.md      ✅ 新增
├── examples/
│   └── rtk_demo.sh              ✅ 新增
└── README.md                    📝 更新
```

**成果**:
- ✅ 快速验证token优化效果
- ✅ 无需修改核心代码
- ✅ 用户可立即使用
- ✅ 为Phase 2打基础

**限制**:
- ⚠️ 依赖外部rtk工具
- ⚠️ 需要用户手动安装rtk

---

## Phase 2: Hybrid Integration (Phase 1完成后)

**目标**: 在Agent工具层集成原生token优化,消除外部依赖

### 高层任务概览

**Task 2.1**: 设计配置系统
- 添加`token_optimize_enabled`配置
- 支持3种策略选择
- 预计2小时

**Task 2.2**: 实现过滤器接口
- 定义`OutputFilter`接口
- 实现基础过滤函数
- 预计3小时

**Task 2.3**: Git命令过滤器
- `git status`: 只显示变更文件
- `git log`: 单行格式
- `git diff`: 压缩diff输出
- 预计4小时

**Task 2.4**: 文件命令过滤器
- `ls`: 树状压缩
- `find`: 分组显示
- 预计3小时

**Task 2.5**: 增强Agent工具
- `bash.zig`: 添加自动过滤
- `grep.zig`: grouping策略
- `read_file.zig`: truncation规则
- 预计6小时

**Task 2.6**: 测试和验证
- 性能测试
- Token节省验证
- 对比rtk效果
- 预计4小时

**总计**: ~22小时 (3-4天)

---

## Phase 3: Native Skill Library (Phase 2完成后)

**目标**: 完全原生Zig实现,添加高级特性

### 高层任务概览

**Task 3.1**: 移植rtk核心算法
- Smart Filtering
- Grouping
- Truncation
- Deduplication
- 预计2周

**Task 3.2**: Skill组合系统
- 链式调用支持
- Skill pipeline
- 预计1周

**Task 3.3**: 高级特性
- 自适应压缩
- 学习用户偏好
- Skill市场
- 预计2-3周

**总计**: ~5-6周

---

## 时间估算总览

| Phase | 任务数 | 预计时间 | 状态 |
|-------|--------|----------|------|
| Phase 1 | 6 | 8-12小时 (1-2天) | 📋 待开始 |
| Phase 2 | 6 | 22小时 (3-4天) | 🔮 Phase 1后 |
| Phase 3 | 3 | 5-6周 | 🔮 Phase 2后 |

---

## 立即开始: Phase 1 实施计划

### Day 1 上午 (4小时)
- ✅ Task 1.1: 设计Skill接口 (1h)
- ✅ Task 1.2: 实现token_optimize.zig (3h)

### Day 1 下午 (4小时)
- ✅ Task 1.3: 注册Skill (30min)
- ✅ Task 1.4: CLI命令支持 (1.5h)
- ✅ Task 1.5: 基本测试 (2h)

### Day 2 (4小时)
- ✅ Task 1.5: 完整测试和验证 (2h)
- ✅ Task 1.6: 文档和示例 (2h)

**Phase 1 可在1-2天内完成!**

---

## 依赖关系图

```
Task 1.1 (设计)
    ↓
Task 1.2 (实现)
    ↓
Task 1.3 (注册)
    ↓
Task 1.4 (CLI)
    ↓
Task 1.5 (测试)
    ↓
Task 1.6 (文档)
    ↓
Phase 1 完成 ✅
    ↓
Task 2.1-2.6 (并行开始)
    ↓
Phase 2 完成 ✅
    ↓
Task 3.1-3.3 (并行开始)
    ↓
Phase 3 完成 ✅
```

---

## 下一步行动

**现在开始**: Task 1.1 - 设计rtk Skill接口

准备好了就说,我们立即开始! 🚀
