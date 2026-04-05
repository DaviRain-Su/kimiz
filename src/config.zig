//! Configuration management for kimiz
//! Handles API keys, model settings, and user preferences

const std = @import("std");
const cli = @import("cli/root.zig");

// ============================================================================
// Token Optimization Configuration (Phase 2)
// ============================================================================

pub const TokenOptimizationConfig = struct {
    enabled: bool = true,
    strategy: Strategy = .balanced,
    use_native_filters: bool = true,
    fallback_to_rtk: bool = false,
    commands: CommandConfigs = .{},
    advanced: AdvancedConfig = .{},

    pub const Strategy = enum {
        conservative,  // Keep more detail (~60% compression)
        balanced,      // Default (~75% compression)
        aggressive,    // Maximum compression (~90% compression)

        pub fn fromString(s: []const u8) ?Strategy {
            if (std.mem.eql(u8, s, "conservative")) return .conservative;
            if (std.mem.eql(u8, s, "balanced")) return .balanced;
            if (std.mem.eql(u8, s, "aggressive")) return .aggressive;
            return null;
        }
    };

    pub const CommandConfig = struct {
        strategy: ?Strategy = null,
        max_output: ?usize = null,
        max_lines: ?usize = null,
        enabled: bool = true,
    };

    pub const CommandConfigs = struct {
        git_status: CommandConfig = .{ .strategy = .aggressive },
        git_log: CommandConfig = .{ .max_lines = 20 },
        git_diff: CommandConfig = .{},
        ls: CommandConfig = .{ .strategy = .aggressive },
        find: CommandConfig = .{},
        grep: CommandConfig = .{},
    };

    pub const AdvancedConfig = struct {
        max_output_tokens: usize = 2000,
        cache_enabled: bool = false,  // Phase 3 feature
        cache_ttl_seconds: u32 = 300,
        auto_detect_command: bool = true,
    };

    /// Get command-specific configuration
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

    /// Get effective strategy for a command (considers overrides)
    pub fn getEffectiveStrategy(self: *const TokenOptimizationConfig, command: []const u8) Strategy {
        if (self.getCommandConfig(command)) |cmd_cfg| {
            if (cmd_cfg.strategy) |s| return s;
        }
        return self.strategy;
    }

    /// Check if optimization should be applied to this command
    pub fn shouldOptimize(self: *const TokenOptimizationConfig, command: []const u8) bool {
        if (!self.enabled) return false;
        
        if (self.getCommandConfig(command)) |cmd_cfg| {
            return cmd_cfg.enabled;
        }
        
        return true; // Default: optimize if enabled globally
    }
};

// ============================================================================
// Main Configuration
// ============================================================================

pub const Config = struct {
    allocator: std.mem.Allocator,
    
    // API Keys
    openai_api_key: ?[]const u8,
    anthropic_api_key: ?[]const u8,
    google_api_key: ?[]const u8,
    kimi_api_key: ?[]const u8,
    fireworks_api_key: ?[]const u8,
    openrouter_api_key: ?[]const u8,
    
    // Model settings
    default_model: []const u8,
    default_temperature: f32,
    default_max_tokens: u32,
    
    // Behavior settings
    yolo_mode: bool,
    auto_confirm_tools: bool,
    
    // Token optimization (Phase 2)
    token_optimization: TokenOptimizationConfig,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) !Self {
        return .{
            .allocator = allocator,
            .openai_api_key = null,
            .anthropic_api_key = null,
            .google_api_key = null,
            .kimi_api_key = null,
            .fireworks_api_key = null,
            .openrouter_api_key = null,
            .default_model = "kimi-for-coding",
            .default_temperature = 0.7,
            .default_max_tokens = 4096,
            .yolo_mode = false,
            .auto_confirm_tools = false,
            .token_optimization = .{},
        };
    }
    
    pub fn deinit(self: *Self) void {
        if (self.openai_api_key) |key| self.allocator.free(key);
        if (self.anthropic_api_key) |key| self.allocator.free(key);
        if (self.google_api_key) |key| self.allocator.free(key);
        if (self.kimi_api_key) |key| self.allocator.free(key);
        if (self.fireworks_api_key) |key| self.allocator.free(key);
        if (self.openrouter_api_key) |key| self.allocator.free(key);
    }
    
    /// Load configuration from environment variables
    pub fn loadFromEnv(self: *Self) !void {
        // Load API keys
        if (cli.getEnvVar(self.allocator, "OPENAI_API_KEY")) |key| {
            self.openai_api_key = key;
        } else |_| {}
        
        if (cli.getEnvVar(self.allocator, "ANTHROPIC_API_KEY")) |key| {
            self.anthropic_api_key = key;
        } else |_| {}
        
        if (cli.getEnvVar(self.allocator, "GOOGLE_API_KEY")) |key| {
            self.google_api_key = key;
        } else |_| {}
        
        if (cli.getEnvVar(self.allocator, "KIMI_API_KEY")) |key| {
            self.kimi_api_key = key;
        } else |_| {}
        
        if (cli.getEnvVar(self.allocator, "FIREWORKS_API_KEY")) |key| {
            self.fireworks_api_key = key;
        } else |_| {}
        
        if (cli.getEnvVar(self.allocator, "OPENROUTER_API_KEY")) |key| {
            self.openrouter_api_key = key;
        } else |_| {}
        
        // Load model settings
        if (cli.getEnvVar(self.allocator, "KIMIZ_MODEL")) |model| {
            self.default_model = model;
        } else |_| {}
        
        // Load behavior settings
        if (cli.getEnvVar(self.allocator, "KIMIZ_YOLO_MODE")) |val| {
            defer self.allocator.free(val);
            self.yolo_mode = std.mem.eql(u8, val, "1") or 
                            std.mem.eql(u8, val, "true") or
                            std.mem.eql(u8, val, "yes");
        } else |_| {}
        
        // Load token optimization settings (Phase 2)
        if (cli.getEnvVar(self.allocator, "KIMIZ_TOKEN_OPTIMIZE")) |val| {
            defer self.allocator.free(val);
            self.token_optimization.enabled = std.mem.eql(u8, val, "1") or 
                                              std.mem.eql(u8, val, "true") or
                                              std.mem.eql(u8, val, "yes");
        } else |_| {}
        
        if (cli.getEnvVar(self.allocator, "KIMIZ_TOKEN_STRATEGY")) |val| {
            defer self.allocator.free(val);
            if (TokenOptimizationConfig.Strategy.fromString(val)) |strategy| {
                self.token_optimization.strategy = strategy;
            }
        } else |_| {}
        
        if (cli.getEnvVar(self.allocator, "KIMIZ_USE_NATIVE_FILTERS")) |val| {
            defer self.allocator.free(val);
            self.token_optimization.use_native_filters = std.mem.eql(u8, val, "1") or 
                                                         std.mem.eql(u8, val, "true") or
                                                         std.mem.eql(u8, val, "yes");
        } else |_| {}
    }
    
    /// Get API key for a provider
    pub fn getApiKey(self: Self, provider: []const u8) ?[]const u8 {
        if (std.mem.eql(u8, provider, "openai")) return self.openai_api_key;
        if (std.mem.eql(u8, provider, "anthropic")) return self.anthropic_api_key;
        if (std.mem.eql(u8, provider, "google")) return self.google_api_key;
        if (std.mem.eql(u8, provider, "kimi")) return self.kimi_api_key;
        if (std.mem.eql(u8, provider, "fireworks")) return self.fireworks_api_key;
        if (std.mem.eql(u8, provider, "openrouter")) return self.openrouter_api_key;
        return null;
    }
    
    /// Check if any API key is configured
    pub fn hasAnyApiKey(self: Self) bool {
        return self.openai_api_key != null or
               self.anthropic_api_key != null or
               self.google_api_key != null or
               self.kimi_api_key != null or
               self.fireworks_api_key != null or
               self.openrouter_api_key != null;
    }
};

test "Config init/deinit" {
    const allocator = std.testing.allocator;
    var config = try Config.init(allocator);
    defer config.deinit();
    
    try std.testing.expectEqualStrings("kimi-for-coding", config.default_model);
    try std.testing.expect(!config.yolo_mode);
}

test "TokenOptimizationConfig defaults" {
    const cfg = TokenOptimizationConfig{};
    try std.testing.expectEqual(true, cfg.enabled);
    try std.testing.expectEqual(.balanced, cfg.strategy);
    try std.testing.expectEqual(true, cfg.use_native_filters);
    try std.testing.expectEqual(false, cfg.fallback_to_rtk);
}

test "TokenOptimizationConfig.Strategy.fromString" {
    try std.testing.expectEqual(.conservative, TokenOptimizationConfig.Strategy.fromString("conservative").?);
    try std.testing.expectEqual(.balanced, TokenOptimizationConfig.Strategy.fromString("balanced").?);
    try std.testing.expectEqual(.aggressive, TokenOptimizationConfig.Strategy.fromString("aggressive").?);
    try std.testing.expectEqual(@as(?TokenOptimizationConfig.Strategy, null), TokenOptimizationConfig.Strategy.fromString("invalid"));
}

test "TokenOptimizationConfig.getEffectiveStrategy" {
    var cfg = TokenOptimizationConfig{
        .strategy = .balanced,
    };
    
    // git status has aggressive override
    try std.testing.expectEqual(.aggressive, cfg.getEffectiveStrategy("git status"));
    
    // git log uses global strategy
    try std.testing.expectEqual(.balanced, cfg.getEffectiveStrategy("git log"));
    
    // unknown command uses global
    try std.testing.expectEqual(.balanced, cfg.getEffectiveStrategy("unknown"));
}

test "TokenOptimizationConfig.shouldOptimize" {
    var cfg = TokenOptimizationConfig{
        .enabled = true,
    };
    
    // Should optimize when enabled
    try std.testing.expectEqual(true, cfg.shouldOptimize("git status"));
    
    // Should not optimize when disabled globally
    cfg.enabled = false;
    try std.testing.expectEqual(false, cfg.shouldOptimize("git status"));
}

test "TokenOptimizationConfig.getCommandConfig" {
    const cfg = TokenOptimizationConfig{};
    
    // Known commands return config
    try std.testing.expect(cfg.getCommandConfig("git status") != null);
    try std.testing.expect(cfg.getCommandConfig("git log") != null);
    try std.testing.expect(cfg.getCommandConfig("ls -la") != null);
    
    // Unknown commands return null
    try std.testing.expect(cfg.getCommandConfig("unknown") == null);
}
