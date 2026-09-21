const std = @import("std");
const zigmodu = @import("zigmodu");
const persist = @import("persistence.zig");

pub const PlanRow = persist.PlanRow;
pub const SubscriptionRow = persist.SubscriptionRow;

pub const DEFAULT_PLANS = [_]struct {
    code: []const u8,
    name: []const u8,
    monthly_price_cents: i64,
    seat_limit: i64,
    ai_token_monthly: i64,
}{
    .{ .code = "free", .name = "Free", .monthly_price_cents = 0, .seat_limit = 1, .ai_token_monthly = 50000 },
    .{ .code = "lite", .name = "Lite", .monthly_price_cents = 2900, .seat_limit = 1, .ai_token_monthly = 200000 },
    .{ .code = "pro", .name = "Pro", .monthly_price_cents = 9900, .seat_limit = 1, .ai_token_monthly = 1000000 },
    .{ .code = "team", .name = "Team", .monthly_price_cents = 29900, .seat_limit = 5, .ai_token_monthly = 3000000 },
};

pub const BillingService = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    store: *persist.BillingStore,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, store: *persist.BillingStore) BillingService {
        return .{ .allocator = allocator, .io = io, .store = store };
    }

    fn now(self: *BillingService) i64 {
        return zigmodu.time.wallClockSeconds(self.io);
    }

    pub fn seedDefaults(self: *BillingService) !void {
        const now = self.now();
        for (DEFAULT_PLANS) |p| {
            _ = try self.store.upsertPlan(.{
                .code = p.code, .name = p.name,
                .monthly_price_cents = p.monthly_price_cents,
                .seat_limit = p.seat_limit,
                .ai_token_monthly = p.ai_token_monthly,
            }, now);
        }
    }

    pub fn getPlan(self: *BillingService, code: []const u8) !?PlanRow {
        return self.store.getPlanByCode(code);
    }

    pub fn ensureSubscription(self: *BillingService, tenant_id: i64, plan_code: []const u8) !i64 {
        return self.store.ensureSubscription(tenant_id, plan_code, self.now());
    }

    pub fn getSubscription(self: *BillingService, tenant_id: i64) !?SubscriptionRow {
        return self.store.getSubscription(tenant_id);
    }
};