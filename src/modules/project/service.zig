const std = @import("std");
const zigmodu = @import("zigmodu");
const persist = @import("persistence.zig");

pub const ProjectRow = persist.ProjectRow;
pub const ProjectListResult = persist.ProjectListResult;

pub const ProjectError = error{
    InvalidName,
    Unexpected,
};

pub const ProjectService = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    store: *persist.ProjectStore,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, store: *persist.ProjectStore) ProjectService {
        return .{ .allocator = allocator, .io = io, .store = store };
    }

    fn now(self: *ProjectService) i64 {
        return zigmodu.time.wallClockSeconds(self.io);
    }

    pub fn create(self: *ProjectService, tenant_id: i64, product_id: i64, name: []const u8, code: []const u8, model: []const u8, owner_id: i64) ProjectError!i64 {
        const trimmed = std.mem.trim(u8, name, " \t");
        if (trimmed.len == 0) return error.InvalidName;
        return self.store.create(.{
            .tenant_id = tenant_id, .product_id = product_id,
            .name = trimmed, .code = code, .mdl = model, .owner_id = owner_id,
        }, self.now()) catch error.Unexpected;
    }

    pub fn get(self: *ProjectService, tenant_id: i64, id: i64) ProjectError!?ProjectRow {
        return self.store.getById(tenant_id, id) catch error.Unexpected;
    }

    pub fn list(self: *ProjectService, tenant_id: i64, page: usize, page_size: usize) ProjectError!ProjectListResult {
        return self.store.listByTenant(tenant_id, page, page_size) catch error.Unexpected;
    }

    pub fn updateStatus(self: *ProjectService, tenant_id: i64, id: i64, status: []const u8) ProjectError!bool {
        return self.store.updateStatus(tenant_id, id, status, self.now()) catch error.Unexpected;
    }
};