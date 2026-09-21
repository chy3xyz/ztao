const std = @import("std");
const zent = @import("zent");
const crud = zent.crud_helpers;
const model = @import("model.zig");
const schema = @import("../../schema.zig");

const graph = zent.codegen.graph.buildGraph(&.{
    model.Plan,
    model.Subscription,
    model.Invoice,
});
pub const infos = graph.types;
pub const Client = schema.Client;
pub const PlanInfo = infos[0];
pub const SubscriptionInfo = infos[1];
pub const InvoiceInfo = infos[2];

pub const PlanRow = struct {
    id: i64,
    code: []const u8,
    name: []const u8,
    monthly_price_cents: i64,
    seat_limit: i64,
    ai_token_monthly: i64,
    feature_flags: []const u8,
    active: bool,
    created_at: i64,

    pub fn free(self: PlanRow, allocator: std.mem.Allocator) void {
        allocator.free(self.code);
        allocator.free(self.name);
        allocator.free(self.feature_flags);
    }
};

pub const SubscriptionRow = struct {
    id: i64,
    tenant_id: i64,
    plan_id: i64,
    plan_code: []const u8,
    status: []const u8,
    started_at: i64,
    period_end: i64,
    auto_renew: bool,

    pub fn free(self: SubscriptionRow, allocator: std.mem.Allocator) void {
        allocator.free(self.plan_code);
        allocator.free(self.status);
    }
};

pub const BillingStore = struct {
    allocator: std.mem.Allocator,
    client: Client,

    pub fn init(allocator: std.mem.Allocator, client: Client) BillingStore {
        return .{ .allocator = allocator, .client = client };
    }

    fn dupPlan(self: *BillingStore, e: anytype) !PlanRow {
        const code = try self.allocator.dupe(u8, e.code);
        errdefer self.allocator.free(code);
        const name = try self.allocator.dupe(u8, e.name);
        errdefer self.allocator.free(name);
        const flags = try self.allocator.dupe(u8, e.feature_flags);
        return .{
            .id = e.id,
            .code = code,
            .name = name,
            .monthly_price_cents = e.monthly_price_cents,
            .seat_limit = e.seat_limit,
            .ai_token_monthly = e.ai_token_monthly,
            .feature_flags = flags,
            .active = e.active,
            .created_at = e.created_at orelse 0,
        };
    }

    fn dupSub(self: *BillingStore, e: anytype) !SubscriptionRow {
        return .{
            .id = e.id,
            .tenant_id = e.tenant_id,
            .plan_id = e.plan_id,
            .plan_code = try self.allocator.dupe(u8, e.plan_code),
            .status = try self.allocator.dupe(u8, e.status),
            .started_at = e.started_at,
            .period_end = e.period_end,
            .auto_renew = e.auto_renew,
        };
    }

    // ---------- Plan ----------

    pub fn upsertPlan(self: *BillingStore, p: struct {
        code: []const u8, name: []const u8,
        monthly_price_cents: i64, seat_limit: i64, ai_token_monthly: i64,
    }, now: i64) !i64 {
        const preds = self.client.plan.predicates;
        if ((try crud.first(self.client.plan, .{preds.codeEQ(.{ .string = p.code })}))) |existing| {
            defer self.client.plan.deinitRow(&existing);
            _ = try crud.update(self.client.plan, .{
                .name = p.name,
                .monthly_price_cents = p.monthly_price_cents,
                .seat_limit = p.seat_limit,
                .ai_token_monthly = p.ai_token_monthly,
                .updated_at = now,
            }, .{preds.idEQ(.{ .int = existing.id })});
            return existing.id;
        }
        var created = try crud.create(self.client.plan, .{
            .code = p.code,
            .name = p.name,
            .monthly_price_cents = p.monthly_price_cents,
            .seat_limit = p.seat_limit,
            .ai_token_monthly = p.ai_token_monthly,
            .feature_flags = "{}",
            .active = true,
            .created_at = now,
            .updated_at = now,
        });
        defer self.client.plan.deinitRow(&created);
        return created.id;
    }

    pub fn getPlanByCode(self: *BillingStore, code: []const u8) !?PlanRow {
        const preds = self.client.plan.predicates;
        var e = (try crud.first(self.client.plan, .{preds.codeEQ(.{ .string = code })})) orelse return null;
        defer self.client.plan.deinitRow(&e);
        return try self.dupPlan(e);
    }

    // ---------- Subscription ----------

    pub fn ensureSubscription(self: *BillingStore, tenant_id: i64, plan_code: []const u8, now: i64) !i64 {
        const preds = self.client.subscription.predicates;
        if ((try crud.first(self.client.subscription, .{
            preds.tenant_idEQ(.{ .int = tenant_id }),
        }))) |existing| {
            defer self.client.subscription.deinitRow(&existing);
            return existing.id;
        }
        const plan = (try self.getPlanByCode(plan_code)) orelse return error.PlanNotFound;
        defer plan.free(self.allocator);
        var created = try crud.create(self.client.subscription, .{
            .tenant_id = tenant_id,
            .plan_id = plan.id,
            .plan_code = plan.code,
            .status = "active",
            .started_at = now,
            .period_end = now + 30 * 86400,
            .auto_renew = true,
            .created_at = now,
            .updated_at = now,
        });
        defer self.client.subscription.deinitRow(&created);
        return created.id;
    }

    pub fn getSubscription(self: *BillingStore, tenant_id: i64) !?SubscriptionRow {
        const preds = self.client.subscription.predicates;
        var e = (try crud.first(self.client.subscription, .{preds.tenant_idEQ(.{ .int = tenant_id })})) orelse return null;
        defer self.client.subscription.deinitRow(&e);
        return try self.dupSub(e);
    }
};