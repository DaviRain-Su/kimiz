//! kimiz-core - Core types and utilities
//! Memory, Context, Message, Error types

const std = @import("std");

// Session management
pub const session = @import("session.zig");
pub const Session = session.Session;
pub const SessionMetadata = session.SessionMetadata;

// ============================================================================
// Constants
// ============================================================================

pub const MAX_CONTENT_BLOCKS = 64;
pub const MAX_TOOL_ARGS_BYTES = 65536;
pub const MAX_MESSAGE_TEXT_BYTES = 1 << 20; // 1MB
pub const MAX_MESSAGES = 4096;
pub const MAX_TOOLS = 64;
pub const SSE_LINE_BUF_SIZE = 65536;
pub const HTTP_BUF_SIZE = 65536;
pub const DEFAULT_MAX_TOKENS = 8192;
pub const DEFAULT_TEMPERATURE: f32 = 1.0;

// API Base URLs
pub const OPENAI_BASE_URL = "https://api.openai.com/v1";
pub const ANTHROPIC_BASE_URL = "https://api.anthropic.com";
pub const GOOGLE_BASE_URL = "https://generativelanguage.googleapis.com";
pub const KIMI_BASE_URL = "https://api.moonshot.cn/v1";
pub const KIMI_CODE_BASE_URL = "https://api.kimi.com/coding";
pub const KIMI_CODE_OPENAI_BASE_URL = "https://api.kimi.com/coding/v1";
pub const FIREWORKS_BASE_URL = "https://api.fireworks.ai/inference/v1";
pub const ANTHROPIC_API_VERSION = "2023-06-01";

// ============================================================================
// Error Types
// ============================================================================

pub const AiError = error{
    // HTTP Layer
    HttpConnectionFailed,
    HttpTlsFailed,
    HttpRequestFailed,
    HttpResponseReadFailed,
    HttpRedirectFailed,
    // API Layer
    ApiAuthenticationFailed,
    ApiPermissionDenied,
    ApiNotFound,
    ApiRateLimitExceeded,
    ApiServerError,
    ApiUnexpectedResponse,
    // Parsing Layer
    JsonParseFailed,
    JsonFieldMissing,
    JsonFieldTypeError,
    SseFormatInvalid,
    SseDoneReceived,
    // Configuration Layer
    ApiKeyNotFound,
    ProviderNotSupported,
    ModelNotFound,
    // Runtime
    OutOfMemory,
    Aborted,
    ToolExecutionFailed,
    ToolNotFound,
};

// ============================================================================
// Provider Types
// ============================================================================

pub const KnownProvider = enum {
    openai,
    anthropic,
    google,
    kimi,
    fireworks,
    openrouter,
};

pub const KnownApi = enum {
    @"openai-completions",
    @"anthropic-messages",
    @"google-generative-ai",
    @"kimi-code",
    @"kimi-code-openai",
    @"kimi-code-anthropic",
};

pub const Provider = union(enum) {
    known: KnownProvider,
    custom: []const u8,
};

pub const Api = union(enum) {
    known: KnownApi,
    custom: []const u8,
};

// ============================================================================
// Model Types
// ============================================================================

pub const ThinkingLevel = enum {
    off,
    minimal,
    low,
    medium,
    high,
    xhigh,
};

pub const StopReason = enum {
    stop,
    length,
    tool_use,
    @"error",
    aborted,
};

pub const ModelCost = struct {
    input_token_cost: f64, // per 1M tokens
    output_token_cost: f64, // per 1M tokens
    cache_token_cost: ?f64 = null,
};

pub const Model = struct {
    id: []const u8,
    provider: Provider,
    api: Api,
    context_window: u32,
    max_tokens: u32,
    cost: ModelCost,
    supports_thinking: bool = false,
    supports_tools: bool = true,
    supports_multimodal: bool = false,
    supports_streaming: bool = true,
};

// ============================================================================
// Message Types
// ============================================================================

pub const TextContent = struct {
    type: enum { text } = .text,
    text: []const u8,
};

pub const ThinkingContent = struct {
    type: enum { thinking } = .thinking,
    thinking: []const u8,
    thinking_signature: ?[]const u8 = null,
    redacted: bool = false,
};

pub const ImageContent = struct {
    type: enum { image } = .image,
    data: []const u8, // base64
    mime_type: []const u8,
    url: ?[]const u8 = null,
    width: ?u32 = null,
    height: ?u32 = null,
};

pub const ImageUrlContent = struct {
    type: enum { image_url } = .image_url,
    url: []const u8,
    detail: ImageDetail = .auto,
};

pub const ImageDetail = enum {
    auto,
    low,
    high,
};

pub const ToolCall = struct {
    id: []const u8,
    type: enum { function } = .function,
    name: []const u8,
    arguments: []const u8, // JSON string
};

pub const ToolCallContent = struct {
    type: enum { tool_call } = .tool_call,
    tool_call: ToolCall,
};

pub const AssistantContentBlock = union(enum) {
    text: TextContent,
    thinking: ThinkingContent,
    tool_call: ToolCallContent,

    pub fn deinit(self: AssistantContentBlock, allocator: std.mem.Allocator) void {
        switch (self) {
            .text => |t| allocator.free(t.text),
            .thinking => |th| {
                allocator.free(th.thinking);
                if (th.thinking_signature) |s| allocator.free(s);
            },
            .tool_call => |tc| {
                allocator.free(tc.tool_call.id);
                allocator.free(tc.tool_call.name);
                allocator.free(tc.tool_call.arguments);
            },
        }
    }
};

pub const UserContentBlock = union(enum) {
    text: []const u8,
    image: ImageContent,
    image_url: ImageUrlContent,

    pub fn deinit(self: UserContentBlock, allocator: std.mem.Allocator) void {
        switch (self) {
            .text => |t| allocator.free(t),
            .image => |img| {
                allocator.free(img.data);
                // mime_type is typically a string literal, do not free
                if (img.url) |u| allocator.free(u);
            },
            .image_url => |imgu| allocator.free(imgu.url),
        }
    }
};

pub const UserMessage = struct {
    role: enum { user } = .user,
    content: []const UserContentBlock,

    pub fn deinit(self: UserMessage, allocator: std.mem.Allocator) void {
        for (self.content) |block| block.deinit(allocator);
        allocator.free(self.content);
    }
};

pub const AssistantMessage = struct {
    role: enum { assistant } = .assistant,
    content: []const AssistantContentBlock,
    stop_reason: StopReason = .stop,
    usage: ?TokenUsage = null,

    pub fn deinit(self: AssistantMessage, allocator: std.mem.Allocator) void {
        for (self.content) |block| block.deinit(allocator);
        allocator.free(self.content);
    }
};

pub const ToolResultMessage = struct {
    role: enum { tool_result } = .tool_result,
    tool_call_id: []const u8,
    tool_name: []const u8,
    content: []const UserContentBlock,
    is_error: bool = false,

    pub fn deinit(self: ToolResultMessage, allocator: std.mem.Allocator) void {
        allocator.free(self.tool_call_id);
        allocator.free(self.tool_name);
        for (self.content) |block| block.deinit(allocator);
        allocator.free(self.content);
    }
};

pub const Message = union(enum) {
    user: UserMessage,
    assistant: AssistantMessage,
    tool_result: ToolResultMessage,

    pub fn deinit(self: Message, allocator: std.mem.Allocator) void {
        switch (self) {
            .user => |m| m.deinit(allocator),
            .assistant => |m| m.deinit(allocator),
            .tool_result => |m| m.deinit(allocator),
        }
    }
};

// ============================================================================
// Context and Usage
// ============================================================================

pub const TokenUsage = struct {
    input_tokens: u32,
    output_tokens: u32,
    cache_creation_input_tokens: ?u32 = null,
    cache_read_input_tokens: ?u32 = null,
};

pub const Context = struct {
    model: Model,
    messages: []const Message,
    temperature: f32 = DEFAULT_TEMPERATURE,
    max_tokens: u32 = DEFAULT_MAX_TOKENS,
    tools: []const Tool = &.{},
    stream: bool = false,
    thinking_level: ThinkingLevel = .off,
};

// ============================================================================
// Tool Types
// ============================================================================

pub const Tool = struct {
    name: []const u8,
    description: []const u8,
    parameters_json: []const u8,
};

// ============================================================================
// Memory Types
// ============================================================================

pub const MemoryType = enum {
    code_style,
    architecture,
    tool_usage,
    project_context,
    conversation,
};

pub const Memory = struct {
    id: []const u8,
    type: MemoryType,
    content: []const u8,
    embedding: ?[]const f32 = null,
    created_at: i64,
    updated_at: i64,
    access_count: u32 = 0,
    last_accessed: ?i64 = null,
};

// ============================================================================
// API Key Management
// ============================================================================

/// Get API key for a provider.
/// Caller owns the returned memory and must free it with the provided allocator.
pub fn getApiKey(allocator: std.mem.Allocator, provider: KnownProvider) ?[]const u8 {
    const env_var = switch (provider) {
        .openai => "OPENAI_API_KEY",
        .anthropic => "ANTHROPIC_API_KEY",
        .google => "GOOGLE_API_KEY",
        .kimi => "KIMI_API_KEY",
        .fireworks => "FIREWORKS_API_KEY",
        .openrouter => "OPENROUTER_API_KEY",
    };

    // Use CLI's getEnvVar function
    const cli = @import("../cli/root.zig");
    return cli.getEnvVar(allocator, env_var) catch null;
}

// ============================================================================
// Tests
// ============================================================================

test "Model cost calculation" {
    const model = Model{
        .id = "gpt-4",
        .provider = .{ .known = .openai },
        .api = .{ .known = .@"openai-completions" },
        .context_window = 8192,
        .max_tokens = 4096,
        .cost = .{
            .input_token_cost = 30.0,
            .output_token_cost = 60.0,
        },
    };

    try std.testing.expectEqualStrings("gpt-4", model.id);
    try std.testing.expectEqual(@as(u32, 8192), model.context_window);
}

test "Message types" {
    const user_msg = Message{
        .user = .{
            .content = &[_]UserContentBlock{.{ .text = "Hello" }},
        },
    };

    try std.testing.expectEqual(.user, user_msg);
}

test "StopReason enum" {
    try std.testing.expectEqual(.stop, StopReason.stop);
    try std.testing.expectEqual(.length, StopReason.length);
    try std.testing.expectEqual(.tool_use, StopReason.tool_use);
}
