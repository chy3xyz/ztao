//! UserIdentity service — find-or-bind.

const std = @import("std");
const zigmodu = @import("zigmodu");
const persist = @import("persistence.zig");

pub const UserIdentityRow = persist.UserIdentityRow;

pub const UserIdentityService = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    store: *persist.UserIdentityStore,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, store: *persist.UserIdentityStore) UserIdentityService {
        return .{ .allocator = allocator, .io = io, .store = store };
    }

    fn now(self: *UserIdentityService) i64 {
        return zigmodu.time.wallClockSeconds(self.io);
    }

    pub fn findByOpenid(self: *UserIdentityService, channel: []const u8, appid: []const u8, openid: []const u8) !?UserIdentityRow {
        return self.store.findByOpenid(channel, appid, openid);
    }

    pub fn bind(self: *UserIdentityService, row: struct {
        user_id: i64,
        channel: []const u8,
        appid: []const u8,
        openid: []const u8,
        unionid: []const u8,
        encrypted_session_key: []const u8,
    }) !i64 {
        const id = try self.store.create(row, self.now());
        return id;
    }

    pub fn touch(self: *UserIdentityService, id: i64) !void {
        try self.store.touch(id, self.now());
    }
};