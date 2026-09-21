//! M1 测试：一人公司引导 / Agent 模板与实例 / 身份绑定 / 引导状态机。
//!
//! 覆盖 PLAN.md 的 M1 验收清单：
//!   - 一人公司引导：Tenant 默认存在
//!   - Workspace.ensureSolo 幂等（第二次不重复建）
//!   - Agent seedDefaults 5 次；clonePresetsToUser 幂等
//!   - UserIdentity findOrBind 第二次同 openid 返回同 user_id
//!   - OnboardingStep 顺序约束

const std = @import("common.zig").std;
const zigmodu = @import("common.zig").zigmodu;
const tenant = @import("common.zig").tenant;
const workspace = @import("common.zig").workspace;
const agent = @import("common.zig").agent;
const fan_identity = @import("common.zig").fan_identity;
const onboarding = @import("common.zig").onboarding;
const openMemory = @import("common.zig").openMemory;

test "tenant ensureDefault returns a stable id" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = tenant.persistence.TenantStore.init(allocator, env.client);
    var svc = tenant.service.TenantService.init(allocator, std.testing.io, &store);

    const id1 = try svc.ensureDefault();
    const id2 = try svc.ensureDefault();
    try std.testing.expect(id1 == id2);
    try std.testing.expect(id1 > 0);
}

test "workspace ensureSolo is idempotent per user" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = workspace.persistence.WorkspaceStore.init(allocator, env.client);
    var svc = workspace.service.WorkspaceService.init(allocator, std.testing.io, &store);

    // First call creates
    const id1 = try svc.ensureSolo(1, 100);
    try std.testing.expect(id1 > 0);

    // Second call returns same id
    const id2 = try svc.ensureSolo(1, 100);
    try std.testing.expect(id1 == id2);

    // Different user → different workspace
    const id3 = try svc.ensureSolo(1, 200);
    try std.testing.expect(id1 != id3);

    // Different tenant → different workspace even for same user
    const id4 = try svc.ensureSolo(2, 100);
    try std.testing.expect(id1 != id4);
}

test "agent seedDefaults inserts exactly 5 presets with unique codes" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = agent.persistence.AgentStore.init(allocator, env.client);
    var svc = agent.service.AgentService.init(allocator, std.testing.io, &store);

    try svc.seedDefaults();
    try svc.seedDefaults(); // 二次调用幂等

    const presets = try svc.listDefaults();
    defer {
        for (presets) |p| p.free(allocator);
        allocator.free(presets);
    }
    try std.testing.expectEqual(@as(usize, 5), presets.len);

    // 每个 code 唯一
    const codes = [_][]const u8{ "pm", "dev", "qa", "support", "ops" };
    for (codes) |c| {
        const p = (try svc.getPresetByCode(c)).?;
        try std.testing.expectEqualStrings(c, p.code);
        p.free(allocator);
    }
}

test "agent clonePresetsToUser is idempotent across calls" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = agent.persistence.AgentStore.init(allocator, env.client);
    var svc = agent.service.AgentService.init(allocator, std.testing.io, &store);

    try svc.seedDefaults();

    const first = try svc.clonePresetsToUser(1, 42);
    defer {
        for (first) |a| a.free(allocator);
        allocator.free(first);
    }
    try std.testing.expectEqual(@as(usize, 5), first.len);

    const second = try svc.clonePresetsToUser(1, 42);
    defer {
        for (second) |a| a.free(allocator);
        allocator.free(second);
    }
    try std.testing.expectEqual(@as(usize, 5), second.len);

    // Same instances returned
    for (first, second) |a, b| {
        try std.testing.expectEqual(a.id, b.id);
    }

    // listByUser 看到 5 个
    const list = try svc.listByUser(1, 42);
    defer {
        for (list) |a| a.free(allocator);
        allocator.free(list);
    }
    try std.testing.expectEqual(@as(usize, 5), list.len);
}

test "fan_identity bind and find roundtrip" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = fan_identity.persistence.UserIdentityStore.init(allocator, env.client);
    var svc = fan_identity.service.UserIdentityService.init(allocator, std.testing.io, &store);

    // 先 user (因 user_id FK 在不同 DB 允许；sqlite 默认没 FK)
    const user_id: i64 = 7;

    const id1 = try svc.bind(.{
        .user_id = user_id,
        .channel = "wechat-mp",
        .appid = "wx_test",
        .openid = "openid_abc",
        .unionid = "union_abc",
        .encrypted_session_key = "",
    });
    try std.testing.expect(id1 > 0);

    const found = (try svc.findByOpenid("wechat-mp", "wx_test", "openid_abc")).?;
    defer found.free(allocator);
    try std.testing.expectEqual(user_id, found.user_id);
    try std.testing.expectEqualStrings("openid_abc", found.openid);
    try std.testing.expectEqualStrings("union_abc", found.unionid);
}

test "onboarding step machine: valid advances, invalid is rejected" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = onboarding.persistence.OnboardingStore.init(allocator, env.client);
    var svc = onboarding.service.OnboardingService.init(allocator, std.testing.io, &store);

    const user_id: i64 = 99;

    // markFresh 强制到 agents_ready
    try svc.markFresh(user_id);
    {
        const s = try svc.get(user_id);
        defer s.free(allocator);
        try std.testing.expectEqualStrings("agents_ready", s.step);
    }

    // 顺序推进：agents_ready → first_chat
    const next1 = try svc.advance(user_id, "first_chat");
    try std.testing.expect(next1 != null);
    try std.testing.expectEqualStrings("first_task", next1.?);

    // 跳级：first_task → done（M3 才用，M1 允许跳到 done）
    const next2 = try svc.advance(user_id, "done");
    try std.testing.expect(next2 == null);

    // 再 advance 到 done → AlreadyDone
    try std.testing.expectError(error.AlreadyDone, svc.advance(user_id, "done"));

    // 非法 step 名
    try std.testing.expectError(error.InvalidStep, svc.advance(user_id, "nonsense"));
}

test "onboarding cannot regress" {
    const allocator = std.testing.allocator;
    var env = try openMemory(allocator);
    defer env.deinit();
    var store = onboarding.persistence.OnboardingStore.init(allocator, env.client);
    var svc = onboarding.service.OnboardingService.init(allocator, std.testing.io, &store);

    const user_id: i64 = 100;

    try svc.markFresh(user_id);
    _ = try svc.advance(user_id, "first_chat");
    _ = try svc.advance(user_id, "first_task");

    // 不能再 advance 到 agents_ready（回退）
    try std.testing.expectError(error.StepRegress, svc.advance(user_id, "agents_ready"));
}