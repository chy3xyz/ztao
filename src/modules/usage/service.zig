//! Usage service — 算力计量与配额扣减。

const std = @import("std");
const zigmodu = @import("zigmodu");
const persist = @import("persistence.zig");

pub const ComputeBalanceRow = persist.ComputeBalanceRow;

/// 成本估算（每 1k token 单价·分）—— M3 占位；M4 走 Provider 计费表
pub const PRICE_PER_1K_TOKEN_CENTS: i64 = 2; // ¥0.02 / 1k token

pub const UsageService = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    store: *persist.UsageStore,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, store: *persist.UsageStore) UsageService {
        return .{ .allocator = allocator, .io = io, .store = store };
    }

    fn now(self: *UsageService) i64 {
        return zigmodu.time.wallClockSeconds(self.io);
    }

    fn currentPeriod(self: *UsageService) [16]u8 {
        const ts = self.now();
        const epoch_seconds = @as(i64, @intCast(ts));
        const days_since_epoch = @divFloor(epoch_seconds, 86400);
        // 简化版：用天数做 period（实际用 YYYY-MM；M3 占位）
        var buf: [16]u8 = undefined;
        const slice = std.fmt.bufPrint(buf[0..], "d{d}", .{days_since_epoch}) catch "0";
        // 拷贝实际写入的字节到定长返回槽（剩余部分清零），避免越界。
        var out: [16]u8 = @splat(0);
        const copy_len = @min(slice.len, out.len);
        @memcpy(out[0..copy_len], slice[0..copy_len]);
        return out;
    }

    /// 记录一次 AI 调用（输入 + 输出 token）
    pub fn recordLlmCall(self: *UsageService, tenant_id: i64, user_id: i64, input_tokens: i64, output_tokens: i64) !void {
        const period = self.currentPeriod();
        try self.store.add(tenant_id, user_id, "ai_input_token", input_tokens, &period, self.now());
        try self.store.add(tenant_id, user_id, "ai_output_token", output_tokens, &period, self.now());
    }

    /// 扣减算力；不够返回 false
    pub fn debitForRun(self: *UsageService, tenant_id: i64, input_tokens: i64, output_tokens: i64) !bool {
        const total = input_tokens + output_tokens;
        return self.store.debit(tenant_id, total);
    }

    pub fn credit(self: *UsageService, tenant_id: i64, tokens: i64) !void {
        try self.store.credit(tenant_id, tokens);
    }

    pub fn getBalance(self: *UsageService, tenant_id: i64) !?ComputeBalanceRow {
        return self.store.getBalance(tenant_id);
    }

    /// 计算预估成本（分）
    pub fn estimateCostCents(_: *UsageService, input_tokens: i64, output_tokens: i64) i64 {
        const total = input_tokens + output_tokens;
        return @divFloor(total * PRICE_PER_1K_TOKEN_CENTS, 1000);
    }
};