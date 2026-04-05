//! Configuration management for kimiz
//! Handles API keys, model settings, and user preferences

const std = @import("std");
const cli = @import("cli/root.zig");

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
