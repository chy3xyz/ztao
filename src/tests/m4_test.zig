//! M4 单元测试：算力商城 + 订阅。

const std = @import("common.zig").std;
const compute = @import("common.zig").compute;
const billing = @import("common.zig").billing;
const openMemory = @import("common.zig").openMemory;

test "compute: seedDefaults lists 4 active packages" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = compute.persistence.ComputeStore.init(allocator, env.client);
    var svc = compute.service.ComputeService.init(allocator, std.testing.io, &store);

    try svc.seedDefaults();
    try svc.seedDefaults(); // 二次调用幂等

    const list = svc.listPackages() catch unreachable;
    defer {
        for (list) |p| p.free(allocator);
        allocator.free(list);
    }
    try std.testing.expect(list.len >= 4);

    const pro = (svc.getPackageByCode("pro") orelse unreachable).?;
    defer pro.free(allocator);
    try std.testing.expectEqualStrings("pro", pro.code);
    try std.testing.expect(pro.tokens > 0);
    try std.testing.expect(pro.price_cents > 0);
}

test "compute: createOrder + markPaid grants tokens" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = compute.persistence.ComputeStore.init(allocator, env.client);
    var svc = compute.service.ComputeService.init(allocator, std.testing.io, &store);

    try svc.seedDefaults();

    const order_id = try svc.createOrder(1, 100, "lite", "wechat");
    try std.testing.expect(order_id > 0);

    {
        const o = (svc.getOrder(1, order_id) orelse unreachable).?;
        defer o.free(allocator);
        try std.testing.expectEqualStrings("pending", o.status);
        try std.testing.expect(o.amount_cents > 0);
    }

    // 模拟微信支付回调
    const granted = (try svc.markPaid(1, order_id, "wx_stub_txid")).?;
    try std.testing.expect(granted > 0);

    {
        const o = (svc.getOrder(1, order_id) orelse unreachable).?;
        defer o.free(allocator);
        try std.testing.expectEqualStrings("paid", o.status);
        try std.testing.expect(o.paid_at > 0);
        try std.testing.expectEqual(granted, o.granted_tokens);
    }
}

test "compute: cannot purchase free package" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = compute.persistence.ComputeStore.init(allocator, env.client);
    var svc = compute.service.ComputeService.init(allocator, std.testing.io, &store);

    try svc.seedDefaults();
    try std.testing.expectError(error.CannotPurchaseFree, svc.createOrder(1, 100, "free", "wechat"));
}

test "compute: unknown package returns error" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = compute.persistence.ComputeStore.init(allocator, env.client);
    var svc = compute.service.ComputeService.init(allocator, std.testing.io, &store);

    try svc.seedDefaults();
    try std.testing.expectError(error.PackageNotFound, svc.createOrder(1, 100, "unknown", "wechat"));
}

test "compute: markPaid on missing order returns null" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = compute.persistence.ComputeStore.init(allocator, env.client);
    var svc = compute.service.ComputeService.init(allocator, std.testing.io, &store);

    try svc.seedDefaults();
    try std.testing.expect((try svc.markPaid(1, 99999, "x")) == null);
}

test "billing: seedDefaults + ensureSubscription idempotent" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = billing.persistence.BillingStore.init(allocator, env.client);
    var svc = billing.service.BillingService.init(allocator, std.testing.io, &store);

    try svc.seedDefaults();

    // 同一 tenant 多次 ensureSubscription → 同 id
    const sub1 = try svc.ensureSubscription(1, "free");
    const sub2 = try svc.ensureSubscription(1, "pro");
    try std.testing.expect(sub1 == sub2);

    {
        const sub = (svc.getSubscription(1) orelse unreachable).?;
        defer sub.free(allocator);
        try std.testing.expectEqualStrings("free", sub.plan_code);
    }
}

test "billing: getPlan returns valid row" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = billing.persistence.BillingStore.init(allocator, env.client);
    var svc = billing.service.BillingService.init(allocator, std.testing.io, &store);

    try svc.seedDefaults();
    const plan = (svc.getPlan("team") orelse unreachable).?;
    defer plan.free(allocator);
    try std.testing.expectEqualStrings("team", plan.code);
    try std.testing.expect(plan.seat_limit >= 5);
    try std.testing.expect(plan.ai_token_monthly > 0);
}