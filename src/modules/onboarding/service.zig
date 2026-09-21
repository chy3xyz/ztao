//! Onboarding service — 一人公司引导状态机。
//!
//! 步骤（只升不降）：
//!   login → workspace → agents_ready → first_chat → first_task → done
//!
//! M1 入口只有 `POST /api/v1/mp/me/onboarding/next`，由小程序引导页每步调用一次。

const std = @import("std");
const zigmodu = @import("zigmodu");
const persist = @import("persistence.zig");

pub const OnboardingStateRow = persist.OnboardingStateRow;

pub const Step = enum {
    login,
    workspace,
    agents_ready,
    first_chat,
    first_task,
    done,

    pub fn fromStr(s: []const u8) ?Step {
        if (std.mem.eql(u8, s, "login")) return .login;
        if (std.mem.eql(u8, s, "workspace")) return .workspace;
        if (std.mem.eql(u8, s, "agents_ready")) return .agents_ready;
        if (std.mem.eql(u8, s, "first_chat")) return .first_chat;
        if (std.mem.eql(u8, s, "first_task")) return .first_task;
        if (std.mem.eql(u8, s, "done")) return .done;
        return null;
    }

    pub fn next(self: Step) ?Step {
        return switch (self) {
            .login => .workspace,
            .workspace => .agents_ready,
            .agents_ready => .first_chat,
            .first_chat => .first_task,
            .first_task => .done,
            .done => null,
        };
    }
};

pub const OnboardingError = error{
    InvalidStep,
    StepRegress,
    AlreadyDone,
};

pub const OnboardingService = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    store: *persist.OnboardingStore,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, store: *persist.OnboardingStore) OnboardingService {
        return .{ .allocator = allocator, .io = io, .store = store };
    }

    fn now(self: *OnboardingService) i64 {
        return zigmodu.time.wallClockSeconds(self.io);
    }

    /// Mark initial state at signup.
    pub fn markFresh(self: *OnboardingService, user_id: i64) !void {
        try self.store.upsert(user_id, "agents_ready", self.now());
    }

    pub fn get(self: *OnboardingService, user_id: i64) !OnboardingStateRow {
        if (try self.store.get(user_id)) |row| return row;
        // Return a synthetic "login" row if nothing exists.
        return .{
            .id = 0,
            .user_id = user_id,
            .step = try self.allocator.dupe(u8, "login"),
            .updated_at = 0,
        };
    }

    /// Advance one step. Validates the target step is reachable from the current.
    pub fn advance(self: *OnboardingService, user_id: i64, target: []const u8) OnboardingError!?Step {
        const target_step = Step.fromStr(target) orelse return error.InvalidStep;
        const cur_row = try self.get(user_id);
        defer cur_row.free(self.allocator);
        const cur = Step.fromStr(cur_row.step) orelse .login;

        if (target_step == .done and cur == .done) return error.AlreadyDone;
        // Walk forward; reject if target is behind current.
        var s: ?Step = cur;
        while (s) |v| : (s = v.next()) {
            if (v == target_step) {
                try self.store.upsert(user_id, target, self.now());
                    return target_step.next();
                }
                if (v == .done) break;
        }
        return error.StepRegress;
    }
};