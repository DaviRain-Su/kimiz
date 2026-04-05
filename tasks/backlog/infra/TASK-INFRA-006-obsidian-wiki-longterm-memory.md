### TASK-INFRA-006: 将 Obsidian Wiki 作为 Long-Term Memory 存储层
**状态**: pending
**优先级**: P1
**创建**: 2026-04-05
**预计耗时**: 6h

**描述**:
将 LongTermMemory 的存储从 JSON 文件改为 Obsidian 兼容的 Markdown 文件，利用 Obsidian 的双链、标签、搜索能力作为知识管理前端，同时用 LMDB 做快速索引。

**背景**:
Kimiz 的记忆系统目前使用 JSON 文件存储，长期记忆难以被人类直接阅读和编辑。改用 Obsidian 格式后：
- **可读性**：人类可以直接阅读、编辑记忆
- **可复用**：Obsidian 可被其他工具读取
- **双链**：支持 `[[link]]` 建立记忆间关联
- **搜索**：Obsidian 的搜索 + FFF/LMDB 索引实现快速定位

**架构设计**:
```
LongTermMemory 存储层
├── Markdown 文件 (Obsidian Vault)
│   ├── memories/
│   │   ├── {uuid}.md          # 单条记忆
│   │   ├── {uuid}.md
│   │   └── ...
│   └── .obsidian/             # Obsidian 配置 (可选)
└── LMDB 索引
    ├── key: memory_id → file_path
    ├── key: tag:* → [memory_ids]
    ├── key: type:* → [memory_ids]
    └── key: content:text → memory_id (全文索引)
```

**Markdown 格式**:
```markdown
---
id: 1704067200000
tier: long_term
type: learning_insight
importance: 8
created: 2026-04-05T10:00:00Z
tags: [zig, memory, optimization]
aliases: ["Zig内存管理", "memory best practices"]
---

# Learning: Zig Memory Management

## 核心发现

Zig 的 defer/errdefer 模式比 Go 的 defer 更强大...

## 相关记忆
- [[1704067100000]] - 之前的 defer 陷阱
- [[1704067200100]] - 后续的 allocator 优化

## 来源
- 来源: 代码审查 TASK-BUG-024
- 时间戳: 2026-04-05
```

**实施步骤**:

1. **创建 ObsidianStore 模块**
```zig
// src/memory/obsidian_store.zig
pub const ObsidianStore = struct {
    allocator: std.mem.Allocator,
    vault_path: []const u8,
    index: LMDBStore,
    
    pub fn init(allocator: std.mem.Allocator, vault_path: []const u8) !Self {
        // 创建 vault 目录结构
        try self.createVaultStructure(vault_path);
        
        // 初始化 LMDB 索引
        const index_path = try std.fs.path.join(allocator, &.{ vault_path, ".index" });
        defer allocator.free(index_path);
        const index = try LMDBStore.init(allocator, index_path);
        
        return .{
            .allocator = allocator,
            .vault_path = try allocator.dupe(u8, vault_path),
            .index = index,
        };
    }
    
    fn createVaultStructure(self: *Self, base_path: []const u8) !void {
        try std.fs.cwd().makePath(base_path);
        try std.fs.cwd().makePath(try std.fs.path.join(self.allocator, &.{ base_path, "memories" }));
        try std.fs.cwd().makePath(try std.fs.path.join(self.allocator, &.{ base_path, "journals" }));
        try std.fs.cwd().makePath(try std.fs.path.join(self.allocator, &.{ base_path, "scratch" }));
    }
};
```

2. **实现 Markdown 序列化**
```zig
// src/memory/obsidian_store.zig
fn serializeToMarkdown(self: *Self, entry: MemoryEntry) ![]u8 {
    var buf = std.ArrayList(u8).init(self.allocator);
    defer buf.deinit();
    const w = buf.writer();
    
    // Frontmatter
    try w.print(
        \\---
        \\id: {d}
        \\tier: {s}
        \\type: {s}
        \\importance: {d}
        \\created: {s}
        \\tags: [{s}]
        \\---
        \\
    , .{
        entry.id,
        @tagName(entry.tier),
        @tagName(entry.mem_type),
        entry.importance,
        try self.formatTimestamp(entry.created_at),
        try self.formatTags(entry.tags),
    });
    
    // Title
    const title = try self.extractTitle(entry.content);
    try w.print("# {s}\n\n", .{title});
    
    // Content
    try w.print("{s}\n", .{entry.content});
    
    // Footer with metadata
    try w.print(
        \\
        \\---
        \\* 创建: {s} | 访问: {d}次 | 重要性: {d}/10 *
    , .{
        try self.formatTimestamp(entry.created_at),
        entry.access_count,
        entry.importance,
    });
    
    return buf.toOwnedSlice();
}

fn deserializeFromMarkdown(self: *Self, content: []const u8) !MemoryEntry {
    // 解析 frontmatter
    const frontmatter = try self.parseFrontmatter(content);
    
    // 解析标题和内容
    const body = try self.parseBody(content);
    
    return MemoryEntry{
        .id = frontmatter.id,
        .tier = try self.parseTier(frontmatter.tier),
        .mem_type = try self.parseMemType(frontmatter.type),
        .content = body,
        .tags = try self.parseTags(frontmatter.tags),
        .importance = frontmatter.importance,
        .created_at = try self.parseTimestamp(frontmatter.created),
        .access_count = 0,
    };
}
```

3. **实现双链支持**
```zig
// src/memory/obsidian_store.zig
/// 从内容中提取 [[link]] 并解析为 ID
fn extractLinks(content: []const u8) ![][:0]const u8 {
    var links = std.ArrayList([][:0]const u8).init(self.allocator);
    
    var i: usize = 0;
    while (i < content.len - 2) {
        if (content[i] == '[' and content[i+1] == '[') {
            const start = i + 2;
            var end = start;
            while (end < content.len and content[end] != ']' and content[end+1] != ']') end += 1;
            if (end > start) {
                const link = try self.allocator.dupe(u8, content[start..end]);
                try links.append(link);
            }
            i = end + 2;
        } else {
            i += 1;
        }
    }
    
    return links.toOwnedSlice();
}

/// 解析 Obsidian link 格式 [[id|display]]
fn parseObsidianLink(link: []const u8) !struct { id: i64, display: ?[]const u8 } {
    const parts = std.mem.splitScalar(u8, link, '|');
    const id_str = parts.first();
    const display = parts.rest();
    
    const id = try std.fmt.parseInt(i64, id_str, 10);
    const display_opt: ?[]const u8 = if (display.len > 0) display else null;
    
    return .{ .id = id, .display = display_opt };
}
```

4. **更新 LongTermMemory 使用 ObsidianStore**
```zig
// src/memory/root.zig
pub const LongTermMemory = struct {
    allocator: std.mem.Allocator,
    store: ObsidianStore,    // 替换 JSON store
    entries: std.ArrayList(MemoryEntry),  // 保留内存索引
    dirty: bool,
    
    pub fn init(allocator: std.mem.Allocator, vault_path: []const u8) !Self {
        const store = try ObsidianStore.init(allocator, vault_path);
        return .{
            .allocator = allocator,
            .store = store,
            .entries = .empty,
            .dirty = false,
        };
    }
    
    // 存储记忆为 Markdown
    pub fn store(self: *Self, entry: MemoryEntry) !void {
        const file_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/memories/{d}.md",
            .{ self.store.vault_path, entry.id }
        );
        defer self.allocator.free(file_path);
        
        const content = try self.store.serializeToMarkdown(entry);
        defer self.allocator.free(content);
        
        try std.fs.cwd().writeFile(file_path, content);
        
        // 更新索引
        try self.store.indexMemory(entry);
        
        // 更新内存缓存
        try self.entries.append(self.allocator, try self.copyEntry(entry));
        
        self.dirty = true;
    }
    
    // 按标签搜索
    pub fn queryByTag(self: *Self, tag: []const u8) ![]MemoryEntry {
        const ids = try self.store.index.queryByTag(tag);
        defer self.allocator.free(ids);
        
        var results = std.ArrayList(MemoryEntry).init(self.allocator);
        for (ids) |id| {
            const entry = try self.load(id);
            try results.append(entry);
        }
        return results.toOwnedSlice();
    }
    
    // 按链接关系搜索
    pub fn queryLinked(self: *Self, id: i64) ![]MemoryEntry {
        const ids = try self.store.index.queryByLink(id);
        // ...
    }
};
```

5. **添加 Obsidian 特性支持**
```zig
// src/memory/obsidian_store.zig

/// 生成每日日志 (Daily Notes)
pub fn createDailyNote(self: *Self, date: i64, content: []const u8) !void {
    const path = try self.getDailyNotePath(date);
    defer self.allocator.free(path);
    
    const frontmatter = try std.fmt.allocPrint(self.allocator,
        \\---
        \\created: {s}
        \\type: journal
        \\---
        \\
    , .{ try self.formatTimestamp(date) });
    
    const full_content = try std.mem.concat(self.allocator, u8, &.{
        frontmatter,
        content,
    });
    defer self.allocator.free(frontmatter);
    defer self.allocator.free(full_content);
    
    try std.fs.cwd().writeFile(path, full_content);
}

/// 获取反向链接 (Backlinks)
pub fn getBacklinks(self: *Self, memory_id: i64) ![]Backlink {
    var backlinks = std.ArrayList(Backlink).init(self.allocator);
    
    try self.store.index.iterateByLink(memory_id, struct {
        fn callback(self: *BacklinkArray, source_id: i64, context: []const u8) !void {
            const source = try self.load(source_id);
            try self.append(.{
                .source = source,
                .context = context,  // 引用上下文
            });
        }
    }.callback, &backlinks);
    
    return backlinks.toOwnedSlice();
}
```

6. **迁移现有数据**
```zig
// src/memory/migration.zig
/// 从 JSON 文件迁移到 Obsidian Vault
pub fn migrateFromJSON(
    allocator: std.mem.Allocator,
    json_path: []const u8,
    vault_path: []const u8,
) !void {
    // 读取旧 JSON
    const content = try std.fs.cwd().readFileAlloc(allocator, json_path, 1024 * 1024);
    defer allocator.free(content);
    
    const old_data = try std.json.parseFromSlice(
        OldMemoryFormat,
        allocator,
        content,
        .{}
    );
    
    // 创建 Obsidian Store
    var store = try ObsidianStore.init(allocator, vault_path);
    
    // 迁移每条记忆
    for (old_data.entries) |entry| {
        const new_entry = try convertEntry(entry);
        try store.store(new_entry);
    }
    
    std.debug.print("Migrated {} entries to Obsidian Vault\n", .{old_data.entries.len});
}
```

**Obsidian Vault 目录结构**:
```
~/.kimiz/vault/
├── memories/               # 记忆存储
│   ├── 1704067200000.md   # 按时间戳命名
│   ├── 1704067300000.md
│   └── ...
├── journals/               # 每日日志
│   └── 2026-04-05.md
├── scratch/               # 临时笔记
│   └── ...
├── inbox/                 # 收件箱 (待整理)
│   └── ...
├── .obsidian/             # Obsidian 配置 (可选)
│   ├── .vault-name
│   └── workspace.json
└── .index/                # LMDB 索引
    ├── memories.mdb
    └── memories.lock
```

**与现有系统的集成**:
```zig
// src/memory/root.zig (完整内存系统)
pub const Memory = struct {
    allocator: std.mem.Allocator,
    short_term: ShortTermMemory,
    working: WorkingMemory,
    long_term: LongTermMemory,  // 现在是 Obsidian Store
    
    // 新增：Obsidian 特有功能
    pub fn getDailyJournal(self: *Self, date: i64) ![]const u8 { ... }
    pub fn getBacklinks(self: *Self, memory_id: i64) ![]Backlink { ... }
    pub fn searchObsidian(self: *Self, query: []const u8) ![]SearchResult { ... }
};
```

**验收标准**:
- [ ] `zig build` 编译通过
- [ ] 新记忆存储为 Markdown 格式
- [ ] frontmatter 正确解析
- [ ] `[[link]]` 双链正确提取
- [ ] 标签搜索正常工作
- [ ] 每日日志功能正常
- [ ] LMDB 索引正常更新
- [ ] 反向链接查询正常
- [ ] 迁移脚本可转换旧数据

**依赖**:
- TASK-INFRA-002 (LMDB 已集成)

**阻塞**:
- 无

**笔记**:
- Obsidian 兼容性优先：使用标准 Markdown + frontmatter
- 不依赖 Obsidian 运行时，纯文件系统操作
- 支持未来可选 Obsidian 插件扩展
- LMDB 索引是关键性能保障
