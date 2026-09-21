const std = @import("std");
const zigmodu = @import("zigmodu");
const persist = @import("persistence.zig");

pub const SprintRow = persist.SprintRow;
pub const SprintListResult = persist.SprintListResult;

pub const SprintService = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    store: *persist.SprintStore,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, store: *persist.SprintStore) SprintService {
        return .{ .allocator = allocator, .io = io, .store = store };
    }

    fn now(self: *SprintService) i64 {
        return zigmodu.time.wallClockSeconds(self.io);
    }

    pub fn create(self: *SprintService, tenant_id: i64, project_id: i64, name: []const u8, goal: []const u8, begin: i64, end: i64) !i64 {
        if (std.mem.trim(u8, name, " \t").len == 0) return error.InvalidName;
        return self.store.create(tenant_id, project_id, name, goal, begin, end, self.now());
    }

    pub fn list(self: *SprintService, tenant_id: i64, project_id: i64) !SprintListResult {
        return self.store.listByProject(tenant_id, project_id);
    }

    pub fn get(self: *SprintService, tenant_id: i64, id: i64) !?SprintRow {
        return self.store.getById(tenant_id, id);
    }
};