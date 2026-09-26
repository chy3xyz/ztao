//! Persistence over the zent Client — OnboardingState.

const std = @import("std");
const zent = @import("zent");
const crud = zent.crud_helpers;
const model = @import("model.zig");
const schema = @import("../../schema.zig");

const graph = zent.codegen.graph.buildGraph(&.{model.OnboardingState});
pub const infos = graph.types;
pub const Client = schema.Client;
pub const OnboardingStateInfo = infos[0];

pub const OnboardingStateRow = struct {
    id: i64,
    user_id: i64,
    step: []const u8,
    updated_at: i64,

    pub fn free(self: OnboardingStateRow, allocator: std.mem.Allocator) void {
        allocator.free(self.step);
    }
};

pub const OnboardingStore = struct {
    allocator: std.mem.Allocator,
    client: Client,

    pub fn init(allocator: std.mem.Allocator, client: Client) OnboardingStore {
        return .{ .allocator = allocator, .client = client };
    }

    fn dup(self: *OnboardingStore, e: anytype) !OnboardingStateRow {
        const step = try self.allocator.dupe(u8, e.step);
        return .{
            .id = e.id,
            .user_id = e.user_id,
            .step = step,
            .updated_at = e.updated_at orelse 0,
        };
    }

    pub fn get(self: *OnboardingStore, user_id: i64) !?OnboardingStateRow {
        const preds = self.client.onboarding_state.predicates;
        var e = (try crud.first(self.client.onboarding_state, .{preds.user_idEQ(.{ .int = user_id })})) orelse return null;
        defer self.client.onboarding_state.deinitRow(@constCast(&e));
        return try self.dup(e);
    }

    pub fn upsert(self: *OnboardingStore, user_id: i64, step: []const u8, now: i64) !void {
        const preds = self.client.onboarding_state.predicates;
        if ((try crud.first(self.client.onboarding_state, .{preds.user_idEQ(.{ .int = user_id })}))) |existing| {
            defer self.client.onboarding_state.deinitRow(@constCast(&existing));
            _ = try crud.update(self.client.onboarding_state, .{
                .step = step,
                .updated_at = now,
            }, .{preds.idEQ(.{ .int = existing.id })});
            return;
        }
        var created = try crud.create(self.client.onboarding_state, .{
            .user_id = user_id,
            .step = step,
            .created_at = now,
            .updated_at = now,
        });
        defer self.client.onboarding_state.deinitRow(@constCast(&created));
    }
};