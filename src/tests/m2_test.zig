//! M2 单元测试：产品 / 项目 / 迭代 / 需求 / 任务 / Bug 基础 CRUD。

const std = @import("common.zig").std;
const product = @import("common.zig").product;
const project = @import("common.zig").project;
const sprint = @import("common.zig").sprint;
const story = @import("common.zig").story;
const pms_task = @import("common.zig").pms_task;
const pms_bug = @import("common.zig").pms_bug;
const openMemory = @import("common.zig").openMemory;

test "product create / get / list / update / delete" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = product.persistence.ProductStore.init(allocator, env.client);
    var svc = product.service.ProductService.init(allocator, std.testing.io, &store);

    const id = try svc.create(1, "ztao", "ztao", 1, "核心产品", "open");
    try std.testing.expect(id > 0);

    const got = (try svc.get(1, id)).?;
    defer got.free(allocator);
    try std.testing.expectEqualStrings("ztao", got.name);
    try std.testing.expectEqualStrings("active", got.status);

    const list = try svc.list(1, 1, 20);
    defer list.free(allocator);
    try std.testing.expectEqual(@as(usize, 1), list.items.len);

    try std.testing.expect(try svc.update(1, id, null, null, "closed", null, null));
    {
        const r = (try svc.get(1, id)).?;
        defer r.free(allocator);
        try std.testing.expectEqualStrings("closed", r.status);
    }

    try std.testing.expect(try svc.delete(1, id));
    try std.testing.expect((try svc.get(1, id)) == null);
}

test "project create + listByTenant + updateStatus" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = project.persistence.ProjectStore.init(allocator, env.client);
    var svc = project.service.ProjectService.init(allocator, std.testing.io, &store);

    const id1 = try svc.create(1, 1, "MVP", "MVP", "scrum", 1);
    const id2 = try svc.create(1, 1, "V2", "V2", "kanban", 1);
    try std.testing.expect(id1 != id2);

    try std.testing.expect(try svc.updateStatus(1, id1, "doing"));

    const list = try svc.list(1, 1, 20);
    defer list.free(allocator);
    try std.testing.expectEqual(@as(usize, 2), list.items.len);
}

test "sprint create / list / get" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = sprint.persistence.SprintStore.init(allocator, env.client);
    var svc = sprint.service.SprintService.init(allocator, std.testing.io, &store);


    var dummy_ts: std.c.timespec = .{ .sec = 0, .nsec = 0 };
    _ = std.c.clock_gettime(.REALTIME, &dummy_ts);
    const now = @as(i64, @intCast(dummy_ts.sec));
    const id1 = try svc.create(1, 1, "Sprint 1", "完成登录", now, now + 7 * 86400);
    const id2 = try svc.create(1, 1, "Sprint 2", "完成支付", now, now + 7 * 86400);
    try std.testing.expect(id1 != id2);

    const list = try svc.list(1, 1);
    defer list.free(allocator);
    try std.testing.expectEqual(@as(usize, 2), list.items.len);

    const got = (try svc.get(1, id1)).?;
    defer got.free(allocator);
    try std.testing.expectEqualStrings("Sprint 1", got.name);
}

test "story create + listByProject + updateStage" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = story.persistence.StoryStore.init(allocator, env.client);
    var svc = story.service.StoryService.init(allocator, std.testing.io, &store);

    const id1 = try svc.create(1, 1, 1, "登录页", "支持手机号一键登录", 1, false);
    const id2 = try svc.create(1, 1, 1, "支付", "接入微信支付 v3", 1, true);
    try std.testing.expect(id1 != id2);

    const list = try svc.listByProject(1, 1, 1, 20);
    defer list.free(allocator);
    try std.testing.expectEqual(@as(usize, 2), list.items.len);

    try std.testing.expect(try svc.updateStage(1, id1, "developing"));
    {
        const r = (try svc.get(1, id1)).?;
        defer r.free(allocator);
        try std.testing.expectEqualStrings("developing", r.stage);
        try std.testing.expect(!r.ai_assisted);
    }

    // AI 标记
    {
        const r = (try svc.get(1, id2)).?;
        defer r.free(allocator);
        try std.testing.expect(r.ai_assisted);
    }
}

test "pms_task create + listByProject + updateStatus + logTime" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = pms_task.persistence.PmsTaskStore.init(allocator, env.client);
    var svc = pms_task.service.PmsTaskService.init(allocator, std.testing.io, &store);

    const id = try svc.create(1, 1, 1, 1, "写登录 UI", 1, 4.0, 1, "user", false);
    try std.testing.expect(id > 0);

    const list = try svc.listByProject(1, 1, 1, 20);
    defer list.free(allocator);
    try std.testing.expectEqual(@as(usize, 1), list.items.len);

    try std.testing.expect(try svc.updateStatus(1, id, "doing", 0));

    try std.testing.expect(try svc.logTime(1, id, 1.5));
    {
        const r = (try svc.get(1, id)).?;
        defer r.free(allocator);
        try std.testing.expectApproxEqAbs(@as(f64, 1.5), r.consumed, 0.001);
        try std.testing.expectApproxEqAbs(@as(f64, 2.5), r.left, 0.001);
        try std.testing.expectEqualStrings("doing", r.status);
    }

    // 标记完成 → finished_by / finished_at 写入
    try std.testing.expect(try svc.updateStatus(1, id, "done", 1));
    {
        const r = (try svc.get(1, id)).?;
        defer r.free(allocator);
        try std.testing.expectEqualStrings("done", r.status);
        try std.testing.expectEqual(@as(i64, 1), r.finished_by);
        try std.testing.expect(r.finished_at > 0);
    }
}

test "pms_task: listAssignedTo filters correctly" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = pms_task.persistence.PmsTaskStore.init(allocator, env.client);
    var svc = pms_task.service.PmsTaskService.init(allocator, std.testing.io, &store);

    _ = try svc.create(1, 1, 1, 1, "alice 的任务", 1, 2.0, 100, "user", false);
    _ = try svc.create(1, 1, 1, 1, "bob 的任务", 1, 2.0, 200, "user", false);

    const list = try svc.listAssignedTo(1, 100, 1, 20);
    defer list.free(allocator);
    try std.testing.expectEqual(@as(usize, 1), list.items.len);
    try std.testing.expectEqualStrings("alice 的任务", list.items[0].name);
}

test "bug create + list + resolve" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = pms_bug.persistence.BugStore.init(allocator, env.client);
    var svc = pms_bug.service.BugService.init(allocator, std.testing.io, &store);

    const id = try svc.create(1, 1, 1, "登录卡顿", 1, "performance", "复现步骤 1. 2. 3.", 1, 1);
    try std.testing.expect(id > 0);

    const list = try svc.list(1, 1, 1, 20, null);
    defer list.free(allocator);
    try std.testing.expectEqual(@as(usize, 1), list.items.len);
    try std.testing.expectEqualStrings("登录卡顿", list.items[0].title);
    try std.testing.expectEqual(@as(i64, 1), list.items[0].severity);

    try std.testing.expect(try svc.resolve(1, id, 1, "fixed"));
    {
        const r = (try svc.get(1, id)).?;
        defer r.free(allocator);
        try std.testing.expectEqualStrings("resolved", r.status);
        try std.testing.expectEqualStrings("fixed", r.resolution);
        try std.testing.expect(r.resolved_at > 0);
    }
}

test "bug severity bounds" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = pms_bug.persistence.BugStore.init(allocator, env.client);
    var svc = pms_bug.service.BugService.init(allocator, std.testing.io, &store);

    try std.testing.expectError(error.InvalidSeverity, svc.create(1, 1, 1, "x", 0, "code", "other", 1, 1));
    try std.testing.expectError(error.InvalidSeverity, svc.create(1, 1, 1, "x", 5, "code", "other", 1, 1));
    try std.testing.expectError(error.InvalidTitle, svc.create(1, 1, 1, "  ", 3, "code", "other", 1, 1));
}