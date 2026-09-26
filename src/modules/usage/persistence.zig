const std = @import("std");
const zent = @import("zent");
const crud = zent.crud_helpers;
const model = @import("model.zig");
const schema = @import("../../schema.zig");

const graph = zent.codegen.graph.buildGraph(&.{
    model.UsageMeter,
    model.ComputeBalance,
    model.QuotaAlert,
});
pub const infos = graph.types;
pub const Client = schema.Client;
pub const UsageMeterInfo = infos[0];
pub const ComputeBalanceInfo = infos[1];
pub const QuotaAlertInfo = infos[2];

pub const ComputeBalanceRow = struct {
    tenant_id: i64,
    balance_tokens: i64,
    period_end: i64,
    plan_code: []const u8,

    pub fn free(self: ComputeBalanceRow, allocator: std.mem.Allocator) void {
        allocator.free(self.plan_code);
    }
};

pub const UsageStore = struct {
    allocator: std.mem.Allocator,
    client: Client,

    pub fn init(allocator: std.mem.Allocator, client: Client) UsageStore {
        return .{ .allocator = allocator, .client = client };
    }

    /// 累加用量（M3 调用频率不高；M4 改 batched insert）
    pub fn add(self: *UsageStore, tenant_id: i64, user_id: i64, metric: []const u8, quantity: i64, period: []const u8, now: i64) !void {
        var row = try crud.create(self.client.usage_meter, .{
            .tenant_id = tenant_id,
            .user_id = user_id,
            .metric = metric,
            .period = period,
            .quantity = quantity,
            .unit = if (std.mem.eql(u8, metric, "ai_input_token") or std.mem.eql(u8, metric, "ai_output_token")) "token" else "count",
            .created_at = now,
            .updated_at = now,
        });
        defer self.client.usage_meter.deinitRow(&row);
    }

    /// 扣减 ComputeBalance（事务：先检查再加扣）
    pub fn ensureBalance(self: *UsageStore, tenant_id: i64, tokens: i64) !bool {
        const preds = self.client.compute_balance.predicates;
        var e = (try crud.first(self.client.compute_balance, .{preds.tenant_idEQ(.{ .int = tenant_id })})) orelse return false;
        defer self.client.compute_balance.deinitRow(@constCast(&e));
        return e.balance_tokens >= tokens;
    }

    pub fn debit(self: *UsageStore, tenant_id: i64, tokens: i64) !bool {
        const preds = self.client.compute_balance.predicates;
        var e = (try crud.first(self.client.compute_balance, .{preds.tenant_idEQ(.{ .int = tenant_id })})) orelse return false;
        defer self.client.compute_balance.deinitRow(@constCast(&e));
        const new_balance = e.balance_tokens - tokens;
        if (new_balance < 0) return false;
        _ = try crud.update(self.client.compute_balance, .{
            .balance_tokens = new_balance,
        }, .{preds.idEQ(.{ .int = e.id })});
        return true;
    }

    pub fn credit(self: *UsageStore, tenant_id: i64, tokens: i64) !void {
        const preds = self.client.compute_balance.predicates;
        var dummy_ts: std.c.timespec = .{ .sec = 0, .nsec = 0 };
        _ = std.c.clock_gettime(.REALTIME, &dummy_ts);
        const now = @as(i64, @intCast(dummy_ts.sec));
        var e = (try crud.first(self.client.compute_balance, .{preds.tenant_idEQ(.{ .int = tenant_id })})) orelse {
            var created = try crud.create(self.client.compute_balance, .{
                .tenant_id = tenant_id,
                .balance_tokens = tokens,
                .period_end = now + 30 * 86400,
                .plan_code = "free",
                .created_at = now,
                .updated_at = now,
            });
            defer self.client.compute_balance.deinitRow(@constCast(&created));
            return;
        };
        defer self.client.compute_balance.deinitRow(@constCast(&e));
        _ = try crud.update(self.client.compute_balance, .{
            .balance_tokens = e.balance_tokens + tokens,
        }, .{preds.idEQ(.{ .int = e.id })});
    }

    pub fn getBalance(self: *UsageStore, tenant_id: i64) !?ComputeBalanceRow {
        const preds = self.client.compute_balance.predicates;
        var e = (try crud.first(self.client.compute_balance, .{preds.tenant_idEQ(.{ .int = tenant_id })})) orelse return null;
        defer self.client.compute_balance.deinitRow(@constCast(&e));
        return .{
            .tenant_id = e.tenant_id,
            .balance_tokens = e.balance_tokens,
            .period_end = e.period_end,
            .plan_code = try self.allocator.dupe(u8, e.plan_code),
        };
    }
};