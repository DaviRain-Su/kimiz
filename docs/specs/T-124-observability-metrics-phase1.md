# Technical Spec: T-124 Observability Metrics System - Phase 1

**任务**: T-124  
**类型**: Implementation  
**作者**: Agent  
**日期**: 2026-04-06  
**状态**: Draft

---

## 1. 概述

为KimiZ实现内置的metrics收集系统，支持CLI查询和导出，无需外部依赖。

### 1.1 目标

- ✅ 最小依赖（仅JSON Lines格式）
- ✅ 低开销（单次记录 < 1ms）
- ✅ CLI友好（show/history/export命令）
- ✅ 透明集成（Agent/Tool无感知）

### 1.2 核心设计原则：监控为机器服务，不是给人类实时盯盘的

在 Hardness Engineering 的架构中，metrics 和 trace 处于**第三层防线**：

```
Layer 0: comptime DSL（编译时拦截结构错误）
Layer 1: assertion density（运行时立刻崩溃暴露假设 violation）
Layer 2: structured trace / metrics（事后分析，供 MetaHarness 学习进化）
```

因此，T-124 的 metrics 系统必须遵循以下原则：

1. **Metrics 的默认消费者是 MetaHarness（机器），不是人类**
   - trace 数据被用于自动识别失败模式、生成优化假设、进化 comptime 约束
   - `show` / `history` / `export` CLI 命令只是辅助调试工具，不是主入口

2. **任何需要"人在运行时查看"的指标，说明 comptime 约束或 assertion 规则有缺口**
   - 如果某个错误反复发生，但它既没被 comptime 拦住，也没触发 assertion，那说明 Hardness 防线有漏洞
   - 人工排查后，必须沉淀一条新的 comptime 验证规则或 assertion，而不是依赖"多看看监控"

3. **监控数据是 MetaHarness 的输入，输出是更强的编译时约束**
   - trace → MetaHarness 分析 → 生成新的 `@compileError` 条件或 `std.debug.assert`
   - 这是一个**单向循环**：运行时复杂性逐渐被吸收为编译时安全性

### 1.3 非目标（Phase 2+）

- ❌ Web Dashboard（Phase 2）
- ❌ Prometheus集成（Phase 3）
- ❌ 实时告警（Phase 3）
- ❌ 7x24 人类值班看监控（永远不是目标）

---

## 2. 数据模型

### 2.1 Metrics结构

```zig
// src/observability/metrics.zig

pub const MetricsSnapshot = struct {
    timestamp: i64,              // Unix timestamp (ms)
    session_id: []const u8,      // 会话ID
    event_type: EventType,       // 事件类型
    data: MetricsData,           // 事件数据（union）
    
    pub const EventType = enum {
        session_start,
        session_end,
        agent_iteration,
        tool_execution,
        llm_call,
        memory_snapshot,
        assertion_trigger,
    };
    
    pub const MetricsData = union(EventType) {
        session_start: SessionStartData,
        session_end: SessionEndData,
        agent_iteration: AgentIterationData,
        tool_execution: ToolExecutionData,
        llm_call: LLMCallData,
        memory_snapshot: MemorySnapshotData,
        assertion_trigger: AssertionTriggerData,
    };
};

pub const SessionStartData = struct {
    model: []const u8,
    max_iterations: u32,
};

pub const SessionEndData = struct {
    total_iterations: u32,
    total_messages: usize,
    exit_reason: []const u8,
};

pub const AgentIterationData = struct {
    iteration: u32,
    state: []const u8,           // "thinking" / "tool_calling" / etc.
    duration_ms: i64,
};

pub const ToolExecutionData = struct {
    tool_name: []const u8,
    success: bool,
    duration_ms: i64,
    error_msg: ?[]const u8,
};

pub const LLMCallData = struct {
    provider: []const u8,        // "anthropic" / "openai" / etc.
    model: []const u8,
    tokens_input: usize,
    tokens_output: usize,
    duration_ms: i64,
    cost_usd: ?f64,              // 可选，基于token计算
};

pub const MemorySnapshotData = struct {
    allocated_bytes: usize,
    freed_bytes: usize,
    live_bytes: usize,
    allocations_count: usize,
};

pub const AssertionTriggerData = struct {
    file: []const u8,
    line: u32,
    message: []const u8,
};
```

### 2.2 JSON Lines格式示例

```jsonl
{"timestamp":1712390400000,"session_id":"s-20260406-001","event_type":"session_start","data":{"model":"claude-3.7-sonnet","max_iterations":50}}
{"timestamp":1712390401234,"session_id":"s-20260406-001","event_type":"agent_iteration","data":{"iteration":1,"state":"thinking","duration_ms":523}}
{"timestamp":1712390402567,"session_id":"s-20260406-001","event_type":"tool_execution","data":{"tool_name":"read_file","success":true,"duration_ms":45,"error_msg":null}}
{"timestamp":1712390403890,"session_id":"s-20260406-001","event_type":"llm_call","data":{"provider":"anthropic","model":"claude-3.7-sonnet","tokens_input":1024,"tokens_output":256,"duration_ms":1200,"cost_usd":0.0048}}
```

---

## 3. 核心组件设计

### 3.1 MetricsCollector

```zig
// src/observability/metrics.zig

pub const MetricsCollector = struct {
    allocator: std.mem.Allocator,
    session_id: []const u8,
    file: std.fs.File,
    buffer: std.ArrayList(u8),    // 批量写入缓冲区
    last_flush: i64,              // 上次刷新时间
    
    const FLUSH_INTERVAL_MS = 500;
    const BUFFER_SIZE = 4096;
    
    pub fn init(allocator: std.mem.Allocator, session_id: []const u8) !*MetricsCollector {
        // 创建 ~/.kimiz/metrics/ 目录
        const home = std.os.getenv("HOME") orelse return error.NoHomeDir;
        const metrics_dir = try std.fs.path.join(allocator, &.{ home, ".kimiz", "metrics" });
        defer allocator.free(metrics_dir);
        
        std.fs.makeDirAbsolute(metrics_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };
        
        // 打开 {session_id}.jsonl 文件（追加模式）
        const filename = try std.fmt.allocPrint(allocator, "{s}.jsonl", .{session_id});
        defer allocator.free(filename);
        
        const filepath = try std.fs.path.join(allocator, &.{ metrics_dir, filename });
        defer allocator.free(filepath);
        
        const file = try std.fs.createFileAbsolute(filepath, .{ .truncate = false });
        
        const self = try allocator.create(MetricsCollector);
        self.* = .{
            .allocator = allocator,
            .session_id = try allocator.dupe(u8, session_id),
            .file = file,
            .buffer = std.ArrayList(u8).init(allocator),
            .last_flush = std.time.milliTimestamp(),
        };
        
        return self;
    }
    
    pub fn deinit(self: *MetricsCollector) void {
        self.flush() catch {};
        self.file.close();
        self.allocator.free(self.session_id);
        self.buffer.deinit();
        self.allocator.destroy(self);
    }
    
    pub fn record(self: *MetricsCollector, snapshot: MetricsSnapshot) !void {
        // 序列化为JSON
        const json_str = try std.json.stringifyAlloc(self.allocator, snapshot, .{});
        defer self.allocator.free(json_str);
        
        // 追加到缓冲区
        try self.buffer.appendSlice(json_str);
        try self.buffer.append('\n');
        
        // 检查是否需要刷新
        const now = std.time.milliTimestamp();
        if (self.buffer.items.len >= BUFFER_SIZE or (now - self.last_flush) >= FLUSH_INTERVAL_MS) {
            try self.flush();
        }
    }
    
    fn flush(self: *MetricsCollector) !void {
        if (self.buffer.items.len == 0) return;
        
        try self.file.writeAll(self.buffer.items);
        self.buffer.clearRetainingCapacity();
        self.last_flush = std.time.milliTimestamp();
    }
};
```

### 3.2 Agent集成

```zig
// src/agent/agent.zig

pub const Agent = struct {
    // ... 现有字段
    metrics_collector: ?*observability.MetricsCollector,
    
    pub fn init(allocator: std.mem.Allocator, options: AgentOptions) !*Agent {
        // ... 现有初始化代码
        
        // 创建MetricsCollector
        const session_id = try generateSessionId(allocator);
        defer allocator.free(session_id);
        
        const metrics = try observability.MetricsCollector.init(allocator, session_id);
        errdefer metrics.deinit();
        
        // 记录session_start事件
        try metrics.record(.{
            .timestamp = std.time.milliTimestamp(),
            .session_id = session_id,
            .event_type = .session_start,
            .data = .{ .session_start = .{
                .model = options.model,
                .max_iterations = options.max_iterations,
            }},
        });
        
        self.metrics_collector = metrics;
        
        // ... 返回self
    }
    
    pub fn deinit(self: *Agent) void {
        if (self.metrics_collector) |m| m.deinit();
        // ... 现有清理代码
    }
    
    fn runLoop(self: *Self) !void {
        while (self.iteration_count < self.options.max_iterations) {
            const iter_start = std.time.milliTimestamp();
            
            // ... 现有Agent逻辑
            
            // 记录iteration完成
            if (self.metrics_collector) |m| {
                const duration = std.time.milliTimestamp() - iter_start;
                try m.record(.{
                    .timestamp = std.time.milliTimestamp(),
                    .session_id = m.session_id,
                    .event_type = .agent_iteration,
                    .data = .{ .agent_iteration = .{
                        .iteration = self.iteration_count,
                        .state = @tagName(self.state),
                        .duration_ms = duration,
                    }},
                });
            }
        }
    }
};
```

### 3.3 Tool集成

```zig
// src/agent/tool.zig

pub const AgentTool = struct {
    // ... 现有字段
    metrics_collector: ?*observability.MetricsCollector,
    
    pub fn execute(self: *AgentTool, allocator: std.mem.Allocator, args: std.json.Value) !ToolResult {
        const start_time = std.time.milliTimestamp();
        
        const result = self.execute_fn(self.ctx, allocator, args) catch |err| {
            // 记录失败
            if (self.metrics_collector) |m| {
                try m.record(.{
                    .timestamp = std.time.milliTimestamp(),
                    .session_id = m.session_id,
                    .event_type = .tool_execution,
                    .data = .{ .tool_execution = .{
                        .tool_name = self.tool.name,
                        .success = false,
                        .duration_ms = std.time.milliTimestamp() - start_time,
                        .error_msg = @errorName(err),
                    }},
                });
            }
            return err;
        };
        
        // 记录成功
        if (self.metrics_collector) |m| {
            try m.record(.{
                .timestamp = std.time.milliTimestamp(),
                .session_id = m.session_id,
                .event_type = .tool_execution,
                .data = .{ .tool_execution = .{
                    .tool_name = self.tool.name,
                    .success = true,
                    .duration_ms = std.time.milliTimestamp() - start_time,
                    .error_msg = null,
                }},
            });
        }
        
        return result;
    }
};
```

---

## 4. CLI命令实现

### 4.1 `kimiz metrics show`

显示当前/最近会话的统计信息。

```bash
$ kimiz metrics show

📊 Session: s-20260406-001
⏱️  Duration: 45s
🔁 Iterations: 12
📝 Messages: 24
🔧 Tools: 18 calls (16 success, 2 failed)
   └─ read_file: 8 calls (100%)
   └─ bash: 6 calls (83.3%)
   └─ grep: 4 calls (100%)
🤖 LLM Calls: 12
   └─ Input: 45,234 tokens
   └─ Output: 12,567 tokens
   └─ Cost: $0.23
💾 Memory: 2.3 MB allocated, 1.8 MB freed, 512 KB live
```

### 4.2 `kimiz metrics history --last 5`

显示最近N个会话的简要信息。

```bash
$ kimiz metrics history --last 5

Recent Sessions:
1. s-20260406-001 | 45s | 12 iter | $0.23
2. s-20260405-003 | 120s | 30 iter | $0.58
3. s-20260405-002 | 23s | 8 iter | $0.12
4. s-20260405-001 | 67s | 18 iter | $0.34
5. s-20260404-002 | 89s | 22 iter | $0.41
```

### 4.3 `kimiz metrics export --format csv`

导出为CSV格式。

```bash
$ kimiz metrics export --session s-20260406-001 --format csv > metrics.csv

$ head metrics.csv
timestamp,session_id,event_type,iteration,tool_name,success,duration_ms,tokens_input,tokens_output,cost_usd
1712390400000,s-20260406-001,session_start,,,,,,
1712390401234,s-20260406-001,agent_iteration,1,,,523,,,
1712390402567,s-20260406-001,tool_execution,,read_file,true,45,,,
1712390403890,s-20260406-001,llm_call,,,,,1200,1024,256,0.0048
```

---

## 5. 实现步骤

### Phase 1: 核心结构（2h）
1. 创建`src/observability/metrics.zig`
2. 实现`MetricsSnapshot`和数据结构
3. 实现`MetricsCollector`（init/deinit/record/flush）
4. 单元测试

### Phase 2: Agent集成（1.5h）
1. 修改`Agent.init`创建MetricsCollector
2. 在`runLoop`中记录iteration事件
3. 在LLM调用点记录llm_call事件
4. 测试

### Phase 3: Tool集成（1h）
1. 修改Tool执行wrapper记录tool_execution事件
2. 测试所有内置工具

### Phase 4: CLI命令（2h）
1. 实现`kimiz metrics show`
2. 实现`kimiz metrics history`
3. 实现`kimiz metrics export`
4. 测试

### Phase 5: 性能测试（0.5h）
1. 基准测试：单次record开销
2. 长会话测试（100轮迭代）
3. 内存泄漏检测

### Phase 6: 文档（1h）
1. 更新README
2. 更新DESIGN-REFERENCES.md
3. 填写Lessons Learned

---

## 6. 测试计划

### 6.1 单元测试

```zig
test "MetricsCollector basic operations" {
    const allocator = std.testing.allocator;
    
    const collector = try MetricsCollector.init(allocator, "test-session");
    defer collector.deinit();
    
    try collector.record(.{
        .timestamp = 1712390400000,
        .session_id = "test-session",
        .event_type = .session_start,
        .data = .{ .session_start = .{ .model = "test", .max_iterations = 10 }},
    });
    
    // 验证文件存在且内容正确
}

test "MetricsCollector performance" {
    const allocator = std.testing.allocator;
    const collector = try MetricsCollector.init(allocator, "perf-test");
    defer collector.deinit();
    
    const start = std.time.milliTimestamp();
    for (0..1000) |i| {
        try collector.record(.{
            .timestamp = start + @as(i64, @intCast(i)),
            .session_id = "perf-test",
            .event_type = .agent_iteration,
            .data = .{ .agent_iteration = .{ .iteration = @as(u32, @intCast(i)), .state = "thinking", .duration_ms = 100 }},
        });
    }
    const duration = std.time.milliTimestamp() - start;
    
    // 验证平均每次记录 < 1ms
    try std.testing.expect(duration / 1000 < 1);
}
```

### 6.2 集成测试

- E2E测试：运行完整Agent会话，验证metrics文件生成
- CLI测试：验证所有`kimiz metrics`命令输出正确

---

## 7. 性能要求

- ✅ 单次`record()`调用 < 1ms
- ✅ 内存占用 < 100KB（缓冲区）
- ✅ 对Agent主流程性能影响 < 5%

---

## 8. 安全性考虑

- ✅ Metrics文件存储在用户目录（`~/.kimiz/metrics/`），权限600
- ✅ 不记录敏感信息（API keys, 用户输入内容）
- ✅ 自动清理：保留最近30天的metrics文件

---

## 9. 未来扩展

### Phase 2: Web Dashboard
- 简单的HTTP服务器（`kimiz metrics serve`）
- 静态HTML + Chart.js可视化
- 实时更新（WebSocket）

### Phase 3: Prometheus集成
- `/metrics` endpoint
- Grafana dashboard模板
- AlertManager告警规则

---

## 10. 参考资料

- [JSON Lines规范](https://jsonlines.org/)
- [TigerBeetle Metrics设计](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/about/internals/vsr.md#metrics)
- [OpenTelemetry Metrics](https://opentelemetry.io/docs/specs/otel/metrics/)
