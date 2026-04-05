# Phase 2: Token Optimization Configuration Design

## Overview

Design a configuration system for native token optimization, allowing users to control compression behavior without depending on external rtk tool.

## Goals

1. **Enable/Disable**: Global switch for token optimization
2. **Strategy Control**: Configure compression level (conservative/balanced/aggressive)
3. **Command-Specific**: Per-command optimization rules
4. **Backwards Compatible**: Coexist with Phase 1 rtk skill

## Configuration Schema

### Config File Location

```
~/.kimiz/config.toml
```

### Schema

```toml
# Token Optimization Settings
[token_optimization]
enabled = true                    # Global enable/disable
strategy = "balanced"             # conservative | balanced | aggressive
use_native_filters = true        # Use native Zig filters (Phase 2)
fallback_to_rtk = false          # Fallback to rtk if native fails

# Command-specific overrides
[token_optimization.commands]
git_status = { strategy = "aggressive", max_output = 500 }
git_log = { strategy = "balanced", max_lines = 20 }
ls = { strategy = "aggressive", show_hidden = false }
find = { strategy = "balanced", group_by_dir = true }
grep = { strategy = "balanced", context_lines = 0 }

# Advanced settings
[token_optimization.advanced]
max_output_tokens = 2000          # Hard limit on output tokens
cache_enabled = true              # Cache filtered results
cache_ttl_seconds = 300           # Cache TTL
auto_detect_command = true        # Auto-detect command type
```

## Config Struct Design

```zig
// src/config.zig additions

pub const TokenOptimizationConfig = struct {
    enabled: bool = true,
    strategy: Strategy = .balanced,
    use_native_filters: bool = true,
    fallback_to_rtk: bool = false,
    commands: CommandConfigs = .{},
    advanced: AdvancedConfig = .{},

    pub const Strategy = enum {
        conservative,  // Keep more detail
        balanced,      // Default
        aggressive,    // Maximum compression
    };

    pub const CommandConfig = struct {
        strategy: ?Strategy = null,
        max_output: ?usize = null,
        max_lines: ?usize = null,
        enabled: bool = true,
    };

    pub const CommandConfigs = struct {
        git_status: CommandConfig = .{},
        git_log: CommandConfig = .{},
        git_diff: CommandConfig = .{},
        ls: CommandConfig = .{},
        find: CommandConfig = .{},
        grep: CommandConfig = .{},
    };

    pub const AdvancedConfig = struct {
        max_output_tokens: usize = 2000,
        cache_enabled: bool = false,  // Phase 3 feature
        cache_ttl_seconds: u32 = 300,
        auto_detect_command: bool = true,
    };

    pub fn getCommandConfig(self: *const TokenOptimizationConfig, command: []const u8) ?CommandConfig {
        if (std.mem.startsWith(u8, command, "git status")) {
            return self.commands.git_status;
        } else if (std.mem.startsWith(u8, command, "git log")) {
            return self.commands.git_log;
        } else if (std.mem.startsWith(u8, command, "git diff")) {
            return self.commands.git_diff;
        } else if (std.mem.startsWith(u8, command, "ls")) {
            return self.commands.ls;
        } else if (std.mem.startsWith(u8, command, "find")) {
            return self.commands.find;
        } else if (std.mem.startsWith(u8, command, "grep")) {
            return self.commands.grep;
        }
        return null;
    }

    pub fn getEffectiveStrategy(self: *const TokenOptimizationConfig, command: []const u8) Strategy {
        if (self.getCommandConfig(command)) |cmd_cfg| {
            if (cmd_cfg.strategy) |s| return s;
        }
        return self.strategy;
    }
};
```

## Integration with Existing Config

```zig
// src/config.zig - Update Config struct

pub const Config = struct {
    // ... existing fields ...
    
    // Token optimization (Phase 2)
    token_optimization: TokenOptimizationConfig = .{},

    pub fn loadFromEnv(self: *Config) !void {
        // ... existing env loading ...
        
        // Token optimization env vars
        if (std.process.getEnvVarOwned(self.allocator, "KIMIZ_TOKEN_OPTIMIZE") catch null) |val| {
            defer self.allocator.free(val);
            self.token_optimization.enabled = std.mem.eql(u8, val, "1") or 
                                              std.mem.eql(u8, val, "true") or
                                              std.mem.eql(u8, val, "yes");
        }
        
        if (std.process.getEnvVarOwned(self.allocator, "KIMIZ_TOKEN_STRATEGY") catch null) |val| {
            defer self.allocator.free(val);
            self.token_optimization.strategy = std.meta.stringToEnum(
                TokenOptimizationConfig.Strategy,
                val
            ) orelse .balanced;
        }
    }
};
```

## Environment Variables

Support for quick configuration without editing config file:

```bash
# Enable/disable
export KIMIZ_TOKEN_OPTIMIZE=true      # or 1, yes

# Set strategy
export KIMIZ_TOKEN_STRATEGY=aggressive  # conservative, balanced, aggressive

# Use native filters
export KIMIZ_USE_NATIVE_FILTERS=true

# Fallback to rtk
export KIMIZ_FALLBACK_TO_RTK=false
```

## CLI Flags

Allow per-invocation overrides:

```bash
# Disable optimization for this run
kimiz --no-token-optimize "Review this code"

# Override strategy
kimiz --token-strategy=aggressive "Run tests"

# Force use of rtk
kimiz --use-rtk "git status"
```

## Usage Examples

### Example 1: Global Enable with Command Override

```toml
[token_optimization]
enabled = true
strategy = "balanced"

[token_optimization.commands]
git_log = { strategy = "aggressive", max_lines = 10 }
```

Result:
- `git status` → balanced compression
- `git log` → aggressive compression, max 10 lines
- `ls` → balanced compression

### Example 2: Disable for Specific Command

```toml
[token_optimization]
enabled = true

[token_optimization.commands]
grep = { enabled = false }
```

Result:
- `git status` → optimized
- `grep` → **NOT** optimized (full output)
- `ls` → optimized

### Example 3: Aggressive Mode with Token Limit

```toml
[token_optimization]
strategy = "aggressive"

[token_optimization.advanced]
max_output_tokens = 1000
```

Result:
- All commands compressed aggressively
- Hard limit at 1000 tokens (truncate if exceeds)

## Default Configuration

If no config file exists, use sensible defaults:

```zig
pub const DEFAULT_TOKEN_OPTIMIZATION = TokenOptimizationConfig{
    .enabled = true,
    .strategy = .balanced,
    .use_native_filters = true,
    .fallback_to_rtk = false,
    .commands = .{
        .git_status = .{ .strategy = .aggressive },
        .git_log = .{ .max_lines = 20 },
        .ls = .{ .strategy = .aggressive },
    },
    .advanced = .{
        .max_output_tokens = 2000,
        .cache_enabled = false,
        .auto_detect_command = true,
    },
};
```

## Migration from Phase 1

Phase 1 rtk skill continues to work:

```bash
# Old way (still works)
kimiz skill rtk-optimize command="git status"

# New way (automatic)
# kimiz Agent tools automatically apply optimization if enabled
```

## Implementation Plan

### Step 1: Config Structure (30min)

```zig
// src/config.zig
// Add TokenOptimizationConfig struct and integration
```

### Step 2: Environment Loading (30min)

```zig
// src/config.zig - loadFromEnv()
// Parse KIMIZ_TOKEN_* env vars
```

### Step 3: CLI Flags (1hr)

```zig
// src/cli/root.zig
// Add --no-token-optimize, --token-strategy flags
```

### Step 4: Helper Functions (30min)

```zig
// Utility functions for checking if optimization should apply
pub fn shouldOptimize(config: *const Config, command: []const u8) bool;
pub fn getOptimizationStrategy(config: *const Config, command: []const u8) Strategy;
```

## Testing

```zig
test "TokenOptimizationConfig defaults" {
    const cfg = TokenOptimizationConfig{};
    try std.testing.expectEqual(true, cfg.enabled);
    try std.testing.expectEqual(.balanced, cfg.strategy);
}

test "getEffectiveStrategy with override" {
    var cfg = TokenOptimizationConfig{
        .strategy = .balanced,
        .commands = .{
            .git_status = .{ .strategy = .aggressive },
        },
    };
    
    try std.testing.expectEqual(.aggressive, cfg.getEffectiveStrategy("git status"));
    try std.testing.expectEqual(.balanced, cfg.getEffectiveStrategy("git log"));
}

test "command config detection" {
    const cfg = TokenOptimizationConfig{};
    
    try std.testing.expect(cfg.getCommandConfig("git status") != null);
    try std.testing.expect(cfg.getCommandConfig("unknown") == null);
}
```

## Future Enhancements

### Phase 3 Features

- **Adaptive Strategy**: Learn optimal strategy per command based on usage
- **User Feedback**: "Was this output useful?" → adjust strategy
- **Custom Rules**: User-defined regex patterns for filtering
- **Compression Stats**: Track actual token savings per command

### Advanced Scenarios

```toml
# Custom command patterns (Phase 3)
[token_optimization.custom]
"npm test" = { strategy = "aggressive", show_only = "failures" }
"cargo clippy" = { strategy = "balanced", group_by = "file" }
"pytest .*" = { strategy = "aggressive", context_lines = 2 }
```

## Backwards Compatibility

✅ Phase 1 rtk skill remains functional  
✅ Default config enables native filters  
✅ Users can opt-out with `enabled = false`  
✅ Fallback to rtk if native filter not implemented

## Next Steps

After Task 2.1 (Config Design):
1. Task 2.2: Implement filter interface
2. Task 2.3: Implement git filters
3. Task 2.4: Implement file filters
4. Task 2.5: Integrate with Agent tools
5. Task 2.6: Test and validate

---

**Design Status**: ✅ Complete  
**Ready for Implementation**: Yes  
**Estimated Time**: 2 hours
