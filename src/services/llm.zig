//! LLM Provider 抽象 — OpenAI 兼容 chat completions 接口。
//!
//! 支持 OpenAI / Azure OpenAI / Qwen / Doubao / Ollama / 自定义（任何 OpenAI-compatible API）。
//! 流式输出由 stdio Streaming 异步处理。
//!
//! 本文件是规划骨架；M3 完成 HTTP 客户端 + SSE 解析 + 与 AgentRunner 集成。
//! 不引入新的 git 依赖；用 zig std.http + std.json 即可。

const std = @import("std");

pub const MessageRole = enum {
    system,
    user,
    assistant,
    tool,
};

pub const Message = struct {
    role: MessageRole,
    content: []const u8,
    name: ?[]const u8 = null,
    tool_call_id: ?[]const u8 = null,
};

pub const ToolDef = struct {
    name: []const u8,
    description: []const u8,
    parameters_json: []const u8,
};

pub const ChatRequest = struct {
    model: []const u8,
    messages: []const Message,
    tools: ?[]const ToolDef = null,
    temperature: f32 = 0.7,
    max_tokens: ?i64 = null,
    stream: bool = false,
};

pub const ToolCall = struct {
    id: []const u8,
    name: []const u8,
    arguments_json: []const u8,
};

pub const ChatChunk = struct {
    /// 流式 token 增量
    delta_content: ?[]const u8 = null,
    delta_tool_calls: ?[]ToolCall = null,
    finish_reason: ?[]const u8 = null,
};

pub const ChatResponse = struct {
    content: []const u8,
    tool_calls: []ToolCall = &.{},
    input_tokens: i64,
    output_tokens: i64,
    cost_cents: i64,
};

pub const ProviderConfig = struct {
    api_base: []const u8,
    api_key: []const u8,
    model: []const u8,
    timeout_ms: i64 = 30000,
};

pub const ProviderError = error{
    NetworkError,
    AuthError,
    RateLimited,
    InvalidResponse,
    OutOfQuota,
};

/// Provider 客户端抽象。
/// 不同 provider 只需实现 `chat` 方法；流式变体在 M3+。
pub const LlmClient = struct {
    config: ProviderConfig,

    pub fn init(config: ProviderConfig) LlmClient {
        return .{ .config = config };
    }

    /// 阻塞式 chat（一次返回完整响应）。
    /// 真实实现应走 zig std.http.Client + JSON 序列化 + 解析。
    /// M3 占位：返回 mock。
    pub fn chat(self: *LlmClient, allocator: std.mem.Allocator, req: ChatRequest) ProviderError!ChatResponse {
        _ = self;
        _ = allocator;
        _ = req;
        // TODO: HTTP POST + JSON parse
        return .{
            .content = "(M3 stub · LLM 未接入)",
            .tool_calls = &.{},
            .input_tokens = 0,
            .output_tokens = 0,
            .cost_cents = 0,
        };
    }
};

// ---------- 流式（SSE）----------

/// 流式 chat — 通过 chunk 回调逐 token 输出。
/// M3 占位；真实实现用 std.http + SSE 解析。
pub const StreamCallback = *const fn (chunk: ChatChunk, user_data: ?*anyopaque) anyerror!void;

pub fn streamChat(
    client: *LlmClient,
    allocator: std.mem.Allocator,
    req: ChatRequest,
    cb: StreamCallback,
    user_data: ?*anyopaque,
) ProviderError!void {
    _ = client;
    _ = allocator;
    _ = req;
    _ = cb;
    _ = user_data;
    // TODO: HTTP streaming + 逐 chunk 回调
}

// ---------- 工厂 ----------

/// 根据 env 选择 provider
pub fn providerFromEnv() ProviderConfig {
    return .{
        .api_base = std.posix.getenv("ZTAO_LLM_API_BASE") orelse "https://api.openai.com/v1",
        .api_key = std.posix.getenv("ZTAO_LLM_API_KEY") orelse "",
        .model = std.posix.getenv("ZTAO_LLM_MODEL") orelse "gpt-4o-mini",
    };
}