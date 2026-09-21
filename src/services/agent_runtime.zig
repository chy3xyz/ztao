//! Agent Runtime — 一次 chat 的完整生命周期：
//!
//! 1. 加载 AgentInstance
//! 2. 构造消息列表（system prompt + 历史 + 当前 user）
//! 3. 调 LLM
//! 4. 落 UsageMeter / 扣减 ComputeBalance
//! 5. 返回 reply + tokens + tool_calls
//!
//! M3 占位：实际 HTTP 调用在 LlmClient 里；这里编排。

const std = @import("std");
const zigmodu = @import("zigmodu");
const llm = @import("llm.zig");
const agent_svc_mod = @import("../modules/agent/service.zig");
const usage_mod = @import("../modules/usage/service.zig");

pub const AgentRuntimeError = error{
    NoQuota,
    AgentNotFound,
    LlmError,
};

pub const RunOutcome = struct {
    reply: []const u8,
    input_tokens: i64,
    output_tokens: i64,
    cost_cents: i64,
    tool_calls: []const llm.ToolCall,
};

pub const AgentRuntime = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    llm_client: *llm.LlmClient,
    agent_svc: *agent_svc_mod.AgentService,
    usage: *usage_mod.UsageService,

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        llm_client: *llm.LlmClient,
        agent_svc: *agent_svc_mod.AgentService,
        usage: *usage_mod.UsageService,
    ) AgentRuntime {
        return .{
            .allocator = allocator,
            .io = io,
            .llm_client = llm_client,
            .agent_svc = agent_svc,
            .usage = usage,
        };
    }

    fn now(self: *AgentRuntime) i64 {
        return zigmodu.time.wallClockSeconds(self.io);
    }

    /// 阻塞 chat（M3 stub：调 LlmClient 占位实现）
    pub fn chat(
        self: *AgentRuntime,
        tenant_id: i64,
        user_id: i64,
        agent_id: i64,
        user_message: []const u8,
        history: []const llm.Message,
    ) AgentRuntimeError!RunOutcome {
        const inst = (self.agent_svc.get(agent_id) catch return error.AgentNotFound) orelse return error.AgentNotFound;
        defer inst.free(self.agent_svc.allocator);

        // 1. 构造 messages（system prompt 暂取 preset 默认）
        var msgs = std.ArrayList(llm.Message).init(self.allocator);
        defer msgs.deinit();

        const preset = self.agent_svc.getPresetByCode(inst.preset_code) catch null;
        defer if (preset) |p| p.free(self.agent_svc.allocator);

        const sys_prompt = if (preset) |p| p.system_prompt else "";
        try msgs.append(.{ .role = .system, .content = sys_prompt });
        for (history) |m| try msgs.append(m);
        try msgs.append(.{ .role = .user, .content = user_message });

        // 2. 调 LLM（占位实现）
        const req = llm.ChatRequest{
            .model = inst.model,
            .messages = msgs.items,
        };
        var resp = self.llm_client.chat(self.allocator, req) catch return error.LlmError;

        // 3. 计量 + 扣减
        self.usage.recordLlmCall(tenant_id, user_id, resp.input_tokens, resp.output_tokens) catch {};
        const cost_cents = self.usage.estimateCostCents(resp.input_tokens, resp.output_tokens);
        _ = self.usage.debitForRun(tenant_id, resp.input_tokens, resp.output_tokens) catch {};

        return .{
            .reply = resp.content,
            .input_tokens = resp.input_tokens,
            .output_tokens = resp.output_tokens,
            .cost_cents = cost_cents,
            .tool_calls = resp.tool_calls,
        };
    }
};