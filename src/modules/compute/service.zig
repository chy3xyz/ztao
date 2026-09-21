//! Compute service — 算力商城（商品 + 订单）。

const std = @import("std");
const zigmodu = @import("zigmodu");
const persist = @import("persistence.zig");

pub const ComputePackageRow = persist.ComputePackageRow;
pub const ComputeOrderRow = persist.ComputeOrderRow;

/// 默认 4 档套餐（M4 seed）
pub const DEFAULT_PACKAGES = [_]struct {
    code: []const u8,
    name: []const u8,
    description: []const u8,
    tokens: i64,
    valid_days: i64,
    price_cents: i64,
    bonus_tokens: i64,
    kind: []const u8,
    seat: i64,
    sort: i64,
}{
    .{
        .code = "free", .name = "Free", .description = "永久免费 50k token",
        .tokens = 50000, .valid_days = 36500, .price_cents = 0,
        .bonus_tokens = 0, .kind = "month", .seat = 1, .sort = 1,
    },
    .{
        .code = "lite", .name = "Lite 月包", .description = "¥29/月 · 200k token",
        .tokens = 200000, .valid_days = 30, .price_cents = 2900,
        .bonus_tokens = 0, .kind = "month", .seat = 1, .sort = 2,
    },
    .{
        .code = "pro", .name = "Pro 月包", .description = "¥99/月 · 1M token",
        .tokens = 1000000, .valid_days = 30, .price_cents = 9900,
        .bonus_tokens = 100000, .kind = "month", .seat = 1, .sort = 3,
    },
    .{
        .code = "team", .name = "Team 团队包", .description = "¥299/月 · 3M token · 5 席",
        .tokens = 3000000, .valid_days = 30, .price_cents = 29900,
        .bonus_tokens = 500000, .kind = "team", .seat = 5, .sort = 4,
    },
};

pub const ComputeService = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    store: *persist.ComputeStore,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, store: *persist.ComputeStore) ComputeService {
        return .{ .allocator = allocator, .io = io, .store = store };
    }

    fn now(self: *ComputeService) i64 {
        return zigmodu.time.wallClockSeconds(self.io);
    }

    /// 启动期 seed 默认 4 档套餐（幂等）
    pub fn seedDefaults(self: *ComputeService) !void {
        const now = self.now();
        for (DEFAULT_PACKAGES) |p| {
            _ = try self.store.upsertPackage(.{
                .code = p.code, .name = p.name, .description = p.description,
                .tokens = p.tokens, .valid_days = p.valid_days, .price_cents = p.price_cents,
                .bonus_tokens = p.bonus_tokens, .kind = p.kind,
                .seat = p.seat, .sort = p.sort,
            }, now);
        }
    }

    pub fn listPackages(self: *ComputeService) ![]ComputePackageRow {
        return self.store.listActivePackages();
    }

    pub fn getPackageByCode(self: *ComputeService, code: []const u8) !?ComputePackageRow {
        return self.store.getPackageByCode(code);
    }

    pub fn createOrder(self: *ComputeService, tenant_id: i64, user_id: i64, package_code: []const u8, channel: []const u8) !i64 {
        const pkg = (try self.store.getPackageByCode(package_code)) orelse return error.PackageNotFound;
        if (pkg.price_cents == 0) return error.CannotPurchaseFree;
        defer pkg.free(self.allocator);
        const id = try self.store.createOrder(tenant_id, user_id, pkg.id, pkg.code, pkg.price_cents, channel, self.now());
        return id;
    }

    pub fn getOrder(self: *ComputeService, tenant_id: i64, id: i64) !?ComputeOrderRow {
        return self.store.getOrder(tenant_id, id);
    }

    /// 支付回调：标记订单已支付，返回应发放的 token（含 bonus）
    pub fn markPaid(self: *ComputeService, tenant_id: i64, id: i64, external_id: []const u8) !?i64 {
        const order = (try self.store.getOrder(tenant_id, id)) orelse return null;
        defer order.free(self.allocator);
        if (!std.mem.eql(u8, order.status, "pending")) return null;

        const pkg = (try self.store.getPackageById(order.package_id)) orelse return null;
        defer pkg.free(self.allocator);

        const granted = pkg.tokens + pkg.bonus_tokens;
        _ = try self.store.markPaid(tenant_id, id, external_id, granted, self.now());
        return granted;
    }

    pub fn listOrders(self: *ComputeService, tenant_id: i64, user_id: i64, page: usize, page_size: usize) ![]ComputeOrderRow {
        return self.store.listOrdersByUser(tenant_id, user_id, page, page_size);
    }
};