//! M5 单元测试：礼品 + 配件商城。

const std = @import("common.zig").std;
const gift_accessory = @import("common.zig").gift_accessory;
const openMemory = @import("common.zig").openMemory;

test "gift_accessory: seedDefaults inserts 3 gifts + 3 accessories" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = gift_accessory.persistence.GiftAccessoryStore.init(allocator, env.client);
    var svc = gift_accessory.service.GiftAccessoryService.init(allocator, std.testing.io, &store);

    try svc.seedDefaults();
    try svc.seedDefaults(); // 二次幂等

    const gifts = svc.listGifts() catch unreachable;
    defer {
        for (gifts) |g| g.free(allocator);
        allocator.free(gifts);
    }
    try std.testing.expect(gifts.len >= 3);

    const accs = svc.listAccessories() catch unreachable;
    defer {
        for (accs) |a| a.free(allocator);
        allocator.free(accs);
    }
    try std.testing.expect(accs.len >= 3);
}

test "gift_accessory: createOrder grants order id" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = gift_accessory.persistence.GiftAccessoryStore.init(allocator, env.client);
    var svc = gift_accessory.service.GiftAccessoryService.init(allocator, std.testing.io, &store);

    try svc.seedDefaults();

    // 付费礼品
    const id1 = try svc.createOrder(1, 100, "gift-coffee", 2);
    try std.testing.expect(id1 > 0);

    // 配件
    const id2 = try svc.createOrder(1, 100, "acc-keyboard", 1);
    try std.testing.expect(id2 > 0);

    {
        const o = (try svc.getOrder(1, id1)).?;
        defer o.free(allocator);
        try std.testing.expectEqualStrings("gift", o.kind);
        try std.testing.expectEqual(@as(i64, 2), o.quantity);
        try std.testing.expectEqual(@as(i64, 2000), o.amount_cents);
        try std.testing.expectEqualStrings("pending", o.status);
    }
}

test "gift_accessory: unknown product returns error" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = gift_accessory.persistence.GiftAccessoryStore.init(allocator, env.client);
    var svc = gift_accessory.service.GiftAccessoryService.init(allocator, std.testing.io, &store);

    try svc.seedDefaults();
    try std.testing.expectError(error.ProductNotFound, svc.createOrder(1, 100, "unknown", 1));
}

test "gift_accessory: list orders by user" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = gift_accessory.persistence.GiftAccessoryStore.init(allocator, env.client);
    var svc = gift_accessory.service.GiftAccessoryService.init(allocator, std.testing.io, &store);

    try svc.seedDefaults();
    _ = try svc.createOrder(1, 100, "gift-coffee", 1);
    _ = try svc.createOrder(1, 100, "gift-book", 1);
    _ = try svc.createOrder(1, 200, "gift-coffee", 1); // 另一个用户

    const list = svc.listOrders(1, 100) catch unreachable;
    defer {
        for (list) |o| o.free(allocator);
        allocator.free(list);
    }
    try std.testing.expectEqual(@as(usize, 2), list.len);

    const list200 = svc.listOrders(1, 200) catch unreachable;
    defer {
        for (list200) |o| o.free(allocator);
        allocator.free(list200);
    }
    try std.testing.expectEqual(@as(usize, 1), list200.len);
}