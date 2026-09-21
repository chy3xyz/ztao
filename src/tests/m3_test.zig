//! M3 单元测试：usage 计量 + 审批流 + Agent Runner 占位调用。

const std = @import("common.zig").std;
const zigmodu = @import("common.zig").zigmodu;
const usage = @import("common.zig").usage;
const approval = @import("common.zig").approval;
const openMemory = @import("common.zig").openMemory;

test "usage: credit then debit" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = usage.persistence.UsageStore.init(allocator, env.client);
    var svc = usage.service.UsageService.init(allocator, std.testing.io, &store);

    // 新租户默认没余额
    try std.testing.expect((try svc.getBalance(1)) == null);

    // 加 1000 token
    try svc.credit(1, 1000);
    {
        const b = (try svc.getBalance(1)).?;
        defer b.free(allocator);
        try std.testing.expectEqual(@as(i64, 1000), b.balance_tokens);
    }

    // 扣 300
    try std.testing.expect(try svc.debitForRun(1, 200, 100));
    {
        const b = (try svc.getBalance(1)).?;
        defer b.free(allocator);
        try std.testing.expectEqual(@as(i64, 700), b.balance_tokens);
    }

    // 透支
    try std.testing.expect(!try svc.debitForRun(1, 5000, 0));
}

test "usage: recordLlmCall + estimateCostCents" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = usage.persistence.UsageStore.init(allocator, env.client);
    var svc = usage.service.UsageService.init(allocator, std.testing.io, &store);

    try svc.credit(1, 100000);

    // 一次 LLM 调用：1k input + 500 output
    try svc.recordLlmCall(1, 1, 1000, 500);
    try std.testing.expect(try svc.debitForRun(1, 1000, 500));

    // 成本估算（¥0.02 / 1k token）：1500 token ≈ 3 分
    const cost = svc.estimateCostCents(1000, 500);
    try std.testing.expectEqual(@as(i64, 3), cost);
}

test "approval: request + listPending + decide" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = approval.persistence.ApprovalStore.init(allocator, env.client);
    var svc = approval.service.ApprovalService.init(allocator, std.testing.io, &store);

    const id1 = try svc.request(1, 100, 1, "deploy", "{\"env\":\"prod\"}");
    const id2 = try svc.request(1, 101, 2, "shell.run", "rm -rf ...");
    try std.testing.expect(id1 != id2);

    const list = try svc.listPending(1, 1);
    defer list.free(allocator);
    try std.testing.expectEqual(@as(usize, 2), list.items.len);

    // 批准一个
    try std.testing.expect(try svc.decide(1, id1, "approved", 1, ""));
    {
        const list2 = try svc.listPending(1, 1);
        defer list2.free(allocator);
        try std.testing.expectEqual(@as(usize, 1), list2.items.len);
        try std.testing.expectEqualStrings("shell.run", list2.items[0].tool_name);
    }

    // 拒绝一个
    try std.testing.expect(try svc.decide(1, id2, "rejected", 1, "危险"));
    {
        const list3 = try svc.listPending(1, 1);
        defer list3.free(allocator);
        try std.testing.expectEqual(@as(usize, 0), list3.items.len);
    }
}

test "approval: invalid decision rejected" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = approval.persistence.ApprovalStore.init(allocator, env.client);
    var svc = approval.service.ApprovalService.init(allocator, std.testing.io, &store);

    const id = try svc.request(1, 100, 1, "deploy", "{}");
    try std.testing.expectError(error.InvalidDecision, svc.decide(1, id, "maybe", 1, ""));
}