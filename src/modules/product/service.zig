//! Product service — 业务层（参数校验、错误归类）。

const std = @import("std");
const zigmodu = @import("zigmodu");
const persist = @import("persistence.zig");

pub const ProductRow = persist.ProductRow;
pub const ProductListResult = persist.ProductListResult;
pub const ProductUpdateFields = persist.ProductUpdateFields;

pub const ProductError = error{
    InvalidName,
    Unexpected,
    NotFound,
};

pub const ProductService = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    store: *persist.ProductStore,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, store: *persist.ProductStore) ProductService {
        return .{ .allocator = allocator, .io = io, .store = store };
    }

    fn now(self: *ProductService) i64 {
        return zigmodu.time.wallClockSeconds(self.io);
    }

    pub fn create(self: *ProductService, tenant_id: i64, name: []const u8, code: []const u8, owner_id: i64, description: []const u8, acl: []const u8) ProductError!i64 {
        const trimmed = std.mem.trim(u8, name, " \t");
        if (trimmed.len == 0) return error.InvalidName;
        return self.store.create(.{
            .tenant_id = tenant_id, .name = trimmed, .code = code,
            .owner_id = owner_id, .description = description, .acl = acl,
        }, self.now()) catch error.Unexpected;
    }

    pub fn get(self: *ProductService, tenant_id: i64, id: i64) ProductError!?ProductRow {
        return self.store.getById(tenant_id, id) catch error.Unexpected;
    }

    pub fn list(self: *ProductService, tenant_id: i64, page: usize, page_size: usize) ProductError!ProductListResult {
        return self.store.listByTenant(tenant_id, page, page_size) catch error.Unexpected;
    }

    pub fn update(self: *ProductService, tenant_id: i64, id: i64, name: ?[]const u8, code: ?[]const u8, status: ?[]const u8, description: ?[]const u8, acl: ?[]const u8) ProductError!bool {
        const fields = persist.ProductUpdateFields{
            .name = name orelse "__SKIP__",
            .code = code orelse "__SKIP__",
            .status = status orelse "__SKIP__",
            .description = description orelse "__SKIP__",
            .acl = acl orelse "__SKIP__",
        };
        return self.store.update(tenant_id, id, fields, self.now()) catch error.Unexpected;
    }

    pub fn delete(self: *ProductService, tenant_id: i64, id: i64) ProductError!bool {
        return self.store.delete(tenant_id, id) catch error.Unexpected;
    }
};