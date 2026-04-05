# RTK Integration Proposal for kimiz

## Executive Summary

rtk是一个高性能CLI代理,通过智能过滤将LLM token消耗降低60-90%。本文档提出将rtk的核心能力集成到kimiz的Skill系统中。

## rtk 核心能力

### Token压缩策略
1. **Smart Filtering** - 去除注释、空格、样板代码
2. **Grouping** - 按目录/类型聚合相似项
3. **Truncation** - 保留关键上下文,删除冗余
4. **Deduplication** - 用计数折叠重复行

### 支持的命令类型
- **文件操作**: ls, read, find, grep, diff
- **Git**: status, log, diff, add/commit/push
- **测试**: cargo test, npm test, pytest, go test
- **构建&Lint**: tsc, eslint, cargo clippy, ruff

### 性能指标
- 压缩率: 60-90%
- 延迟: <10ms
- 实现: Rust单二进制,零依赖

## kimiz当前架构

```
kimiz/
├── src/
│   ├── agent/          # Agent runtime
│   │   ├── tools/      # 5个核心工具
│   │   │   ├── bash.zig
│   │   │   ├── read_file.zig
│   │   │   ├── write_file.zig
│   │   │   ├── edit.zig
│   │   │   ├── grep.zig
│   │   │   └── fff.zig (文件搜索)
│   ├── cli/            # CLI入口
│   └── skills/         # ✨ Skill系统
│       ├── root.zig    # SkillRegistry + SkillEngine
│       ├── code_review.zig
│       ├── debug.zig
│       ├── doc_gen.zig
│       ├── refactor.zig
│       └── test_gen.zig
```

**已有Skill系统组件:**
- `SkillRegistry` - 技能注册、分类、搜索
- `SkillEngine` - 参数验证、执行管理
- 5个内置技能

## 三阶段集成方案

### Phase 1: External Tool Wrapper (立即可用)

**目标**: 通过Skill包装rtk外部工具

**实现**:
```zig
// src/skills/token_optimize.zig
pub const rtk_optimize = Skill{
    .id = "rtk-optimize",
    .name = "Token Optimize",
    .description = "使用rtk压缩命令输出",
    .category = .misc,
    .params = &[_]SkillParam{
        .{ .name = "command", .param_type = .string },
    },
    .execute_fn = executeRTK,
};

fn executeRTK(
    ctx: SkillContext,
    args: std.json.ObjectMap,
    arena: std.mem.Allocator,
) !SkillResult {
    // 调用: rtk <command>
    const cmd = args.get("command").?.string;
    // ... 通过bash tool执行rtk
}
```

**优点**:
- 零开发成本,立即可用
- 保持rtk的Rust性能优势

**缺点**:
- 依赖外部工具
- 需要用户安装rtk

### Phase 2: Hybrid Integration (增强工具层)

**目标**: 在kimiz的Agent工具层集成token优化

**修改点**:
```zig
// src/agent/tools/bash.zig - 增强版
pub const BashContext = struct {
    auto_approve: bool = false,
    token_optimize: bool = true,  // 新增
    
    // 新增rtk风格的输出过滤
    fn filterOutput(output: []const u8, cmd: []const u8) ![]const u8 {
        // 根据命令类型选择过滤策略
        if (std.mem.startsWith(u8, cmd, "git status")) {
            return filterGitStatus(output);
        } else if (std.mem.startsWith(u8, cmd, "ls")) {
            return filterLs(output);
        }
        // ... 更多过滤器
    }
};

// src/agent/tools/grep.zig - 优化版
// 应用rtk的grouping策略
fn groupResults(results: []Result) ![]const u8 {
    // 按文件分组,显示统计
}
```

**实现策略**:
1. 为每个核心工具(bash, read_file, grep)添加可选的token优化
2. 实现关键命令的过滤器(git, ls, test等)
3. 通过配置控制是否启用优化

**优点**:
- 不依赖外部工具
- 深度集成,可以针对kimiz优化
- 保持Zig的一致性

### Phase 3: Native Skill Library (长期目标)

**目标**: 将rtk的压缩算法完全移植为kimiz原生Skill

**架构**:
```zig
// src/skills/compress/
├── root.zig           # 压缩Skill注册
├── filters.zig        # Smart Filtering算法
├── grouping.zig       # Grouping策略
├── truncation.zig     # Truncation规则
├── dedup.zig          # Deduplication算法
└── commands/
    ├── git.zig        # Git命令优化
    ├── files.zig      # 文件命令优化
    ├── tests.zig      # 测试输出优化
    └── lint.zig       # Linter输出优化
```

**Skill定义**:
```zig
pub const compress_output = Skill{
    .id = "compress-output",
    .name = "Compress Command Output",
    .description = "智能压缩命令输出,减少60-90% tokens",
    .category = .misc,
    .params = &[_]SkillParam{
        .{ .name = "command", .param_type = .string },
        .{ .name = "output", .param_type = .string },
        .{ .name = "strategy", .param_type = .selection },
    },
    .execute_fn = compressOutput,
};
```

**优点**:
- 完全控制,可深度优化
- 无外部依赖
- 可扩展(添加新的压缩策略)

## CLI Skill系统设计

### 为什么CLI适合Skill系统

```
用户请求
    ↓
┌─────────────────────────────────┐
│  CLI (统一入口)                   │
│  - 解析用户意图                   │
│  - 选择合适的Skill                │
│  - 编排工具调用                   │
└──────────┬──────────────────────┘
           │
    ┌──────┴──────┐
    ↓             ↓
┌────────┐   ┌─────────┐
│ Skill  │   │  Agent  │
│ Engine │←─→│  Tools  │
└────────┘   └─────────┘
```

**优势**:
1. **上下文感知** - CLI掌握项目状态、工作目录等
2. **工具编排** - 可组合Agent工具 + Skills
3. **透明集成** - 用户只需发出高级指令
4. **灵活扩展** - 新Skill无需修改核心

### Skill命令接口设计

```bash
# 直接调用Skill
kimiz skill compress-output --command="git status" --strategy=aggressive

# 通过Agent自动选择Skill
kimiz "帮我优化git status的输出"
# → Agent选择compress-output Skill

# Skill链式调用
kimiz skill refactor --file=main.zig | skill doc-gen
```

## 实施建议

### 优先级

**P0 (立即)** - Phase 2: Hybrid Integration
- 为bash/grep/read_file工具添加token_optimize选项
- 实现3-5个最常用命令的过滤器(git status, ls, test)
- 通过配置控制启用

**P1 (短期)** - 完善Skill系统基础设施
- 丰富SkillRegistry的发现和搜索功能
- 添加Skill组合/链式调用支持
- CLI Skill命令接口

**P2 (中期)** - Phase 3: Native Skill Library
- 移植rtk的核心压缩算法
- 扩展支持的命令类型
- 性能优化和基准测试

**P3 (长期)** - 高级特性
- 自适应压缩(根据上下文智能调整策略)
- 学习用户偏好
- Skill市场/插件系统

### 技术细节

**配置方式**:
```zig
// src/config.zig
pub const Config = struct {
    // ... existing fields
    
    // Token optimization
    token_optimize_enabled: bool = true,
    token_optimize_strategy: TokenOptimizeStrategy = .balanced,
    
    pub const TokenOptimizeStrategy = enum {
        conservative,  // 保留更多信息
        balanced,      // 平衡(默认)
        aggressive,    // 最大压缩
    };
};
```

**过滤器接口**:
```zig
// src/skills/compress/filters.zig
pub const OutputFilter = struct {
    pub fn filter(
        raw_output: []const u8,
        command: []const u8,
        strategy: TokenOptimizeStrategy,
        allocator: std.mem.Allocator,
    ) ![]const u8;
};
```

## 差异化优势

相比直接使用rtk,kimiz的原生实现可以:

1. **深度集成Agent** - 压缩策略可以基于对话历史动态调整
2. **项目感知** - 了解项目结构,更智能的过滤
3. **学习能力** - 记住用户偏好,优化压缩策略
4. **Zig性能** - 保持整个系统的一致性和性能
5. **可扩展** - 用户可以添加自定义压缩规则

## 下一步行动

1. **原型验证** (1-2天)
   - 实现git status的简单过滤器
   - 测试token节省效果
   - 验证性能开销

2. **核心实现** (1周)
   - 为bash/grep/read_file添加优化
   - 实现5个最常用命令的过滤器
   - 添加配置支持

3. **文档和测试** (2-3天)
   - API文档
   - 使用示例
   - 性能基准测试

## 结论

**推荐方案**: 直接进入Phase 2 (Hybrid Integration)

**理由**:
- 立即带来价值(60-90% token节省)
- 保持kimiz的独立性(无外部依赖)
- 为Phase 3打下基础
- CLI + Skill系统确实是最优架构

**你的直觉是对的** - CLI工具内置Skill系统是最合适的设计。kimiz已经有了很好的Skill基础架构,现在只需要添加token优化能力。
