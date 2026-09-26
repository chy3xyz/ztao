const std = @import("std");
const zigmodu = @import("zigmodu");
const persist = @import("persistence.zig");

pub const BugRow = persist.BugRow;
pub const BugListResult = persist.BugListResult;

pub const BugError = error{
    InvalidTitle,
    InvalidSeverity,
    Unexpected,
};

pub const BugService = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    store: *persist.BugStore,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, store: *persist.BugStore) BugService {
        return .{ .allocator = allocator, .io = io, .store = store };
    }

    fn now(self: *BugService) i64 {
        return zigmodu.time.wallClockSeconds(self.io);
    }

    pub fn create(self: *BugService, tenant_id: i64, product_id: i64, project_id: i64, title: []const u8, severity: i64, type_: []const u8, steps: []const u8, assigned_to: i64, opened_by: i64) BugError!i64 {
        const trimmed = std.mem.trim(u8, title, " \t");
        if (trimmed.len == 0) return error.InvalidTitle;
        if (severity < 1 or severity > 4) return error.InvalidSeverity;
        return self.store.create(.{
            .tenant_id = tenant_id, .product_id = product_id, .project_id = project_id,
            .title = trimmed, .severity = severity, .kind = type_, .steps = steps,
            .assigned_to = assigned_to, .opened_by = opened_by,
        }, self.now()) catch error.Unexpected;
    }

    pub fn get(self: *BugService, tenant_id: i64, id: i64) BugError!?BugRow {
        return self.store.getById(tenant_id, id) catch error.Unexpected;
    }

    pub fn list(self: *BugService, tenant_id: i64, product_id: i64, page: usize, page_size: usize, status_filter: ?[]const u8) BugError!BugListResult {
        return self.store.listByProduct(tenant_id, product_id, page, page_size, status_filter) catch error.Unexpected;
    }

    pub fn resolve(self: *BugService, tenant_id: i64, id: i64, resolved_by: i64, resolution: []const u8) BugError!bool {
        return self.store.resolve(tenant_id, id, resolved_by, resolution, self.now()) catch error.Unexpected;
    }
};