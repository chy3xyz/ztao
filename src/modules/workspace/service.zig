//! Workspace service — guarantees 1 个 solo workspace per user per tenant.

const std = @import("std");
const zigmodu = @import("zigmodu");
const persist = @import("persistence.zig");

pub const WorkspaceRow = persist.WorkspaceRow;

pub const WorkspaceService = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    store: *persist.WorkspaceStore,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, store: *persist.WorkspaceStore) WorkspaceService {
        return .{ .allocator = allocator, .io = io, .store = store };
    }

    fn now(self: *WorkspaceService) i64 {
        return zigmodu.time.wallClockSeconds(self.io);
    }

    /// Idempotent: creates a `solo` workspace the first time, returns the
    /// existing one on subsequent calls.
    pub fn ensureSolo(self: *WorkspaceService, tenant_id: i64, owner_user_id: i64) !i64 {
        const name = "默认 Workspace";
        return self.store.ensureSolo(tenant_id, owner_user_id, name, self.now());
    }

    pub fn get(self: *WorkspaceService, id: i64) !?WorkspaceRow {
        return self.store.getById(id);
    }

    pub fn listByTenant(self: *WorkspaceService, tenant_id: i64) ![]WorkspaceRow {
        return self.store.listByTenant(tenant_id);
    }
};