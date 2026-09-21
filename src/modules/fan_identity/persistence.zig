//! Persistence over the zent Client — UserIdentity.

const std = @import("std");
const zent = @import("zent");
const crud = zent.crud_helpers;
const model = @import("model.zig");
const schema = @import("../../schema.zig");

const graph = zent.codegen.graph.buildGraph(&.{model.UserIdentity});
pub const infos = graph.types;
pub const Client = schema.Client;
pub const UserIdentityInfo = infos[0];

pub const UserIdentityRow = struct {
    id: i64,
    user_id: i64,
    channel: []const u8,
    openid: []const u8,
    unionid: []const u8,
    appid: []const u8,
    encrypted_session_key: []const u8,
    created_at: i64,
    last_used_at: i64,

    pub fn free(self: UserIdentityRow, allocator: std.mem.Allocator) void {
        allocator.free(self.channel);
        allocator.free(self.openid);
        allocator.free(self.unionid);
        allocator.free(self.appid);
        allocator.free(self.encrypted_session_key);
    }
};

pub const UserIdentityStore = struct {
    allocator: std.mem.Allocator,
    client: Client,

    pub fn init(allocator: std.mem.Allocator, client: Client) UserIdentityStore {
        return .{ .allocator = allocator, .client = client };
    }

    fn dup(self: *UserIdentityStore, e: anytype) !UserIdentityRow {
        const channel = try self.allocator.dupe(u8, e.channel);
        errdefer self.allocator.free(channel);
        const openid = try self.allocator.dupe(u8, e.openid);
        errdefer self.allocator.free(openid);
        const unionid = try self.allocator.dupe(u8, e.unionid);
        errdefer self.allocator.free(unionid);
        const appid = try self.allocator.dupe(u8, e.appid);
        errdefer self.allocator.free(appid);
        const sk = try self.allocator.dupe(u8, e.encrypted_session_key);
        return .{
            .id = e.id,
            .user_id = e.user_id,
            .channel = channel,
            .openid = openid,
            .unionid = unionid,
            .appid = appid,
            .encrypted_session_key = sk,
            .created_at = e.created_at orelse 0,
            .last_used_at = e.last_used_at orelse 0,
        };
    }

    /// Find identity by (channel, appid, openid). Returns null if not bound.
    pub fn findByOpenid(self: *UserIdentityStore, channel: []const u8, appid: []const u8, openid: []const u8) !?UserIdentityRow {
        const preds = self.client.user_identity.predicates;
        var e = (try crud.first(self.client.user_identity, .{
            preds.channelEQ(.{ .string = channel }),
            preds.appidEQ(.{ .string = appid }),
            preds.openidEQ(.{ .string = openid }),
        })) orelse return null;
        defer self.client.user_identity.deinitRow(&e);
        return try self.dup(e);
    }

    /// Insert a fresh identity row.
    pub fn create(self: *UserIdentityStore, row: struct {
        user_id: i64,
        channel: []const u8,
        appid: []const u8,
        openid: []const u8,
        unionid: []const u8,
        encrypted_session_key: []const u8,
    }, now: i64) !i64 {
        var created = try crud.create(self.client.user_identity, .{
            .user_id = row.user_id,
            .channel = row.channel,
            .appid = row.appid,
            .openid = row.openid,
            .unionid = row.unionid,
            .encrypted_session_key = row.encrypted_session_key,
            .created_at = now,
            .last_used_at = now,
        });
        defer self.client.user_identity.deinitRow(&created);
        return created.id;
    }

    /// Update last_used_at; called on every login.
    pub fn touch(self: *UserIdentityStore, id: i64, now: i64) !void {
        const preds = self.client.user_identity.predicates;
        _ = try crud.update(self.client.user_identity, .{
            .last_used_at = now,
        }, .{preds.idEQ(.{ .int = id })});
    }
};