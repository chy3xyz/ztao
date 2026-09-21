//! Persistence over the zent Client — Product + ProductPlan.

const std = @import("std");
const zent = @import("zent");
const crud = zent.crud_helpers;
const model = @import("model.zig");
const schema = @import("../../schema.zig");

const graph = zent.codegen.graph.buildGraph(&.{ model.Product, model.ProductPlan });
pub const infos = graph.types;
pub const Client = schema.Client;
pub const ProductInfo = infos[0];
pub const ProductPlanInfo = infos[1];

pub const ProductRow = struct {
    id: i64,
    tenant_id: i64,
    name: []const u8,
    code: []const u8,
    type_: []const u8,
    status: []const u8,
    owner_id: i64,
    description: []const u8,
    acl: []const u8,
    created_at: i64,
    updated_at: i64,

    pub fn free(self: ProductRow, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.code);
        allocator.free(self.type_);
        allocator.free(self.status);
        allocator.free(self.description);
        allocator.free(self.acl);
    }
};

pub const ProductListResult = struct {
    items: []ProductRow,
    total: i64,

    pub fn free(self: *ProductListResult, allocator: std.mem.Allocator) void {
        for (self.items) |r| r.free(allocator);
        allocator.free(self.items);
    }
};

pub const ProductStore = struct {
    allocator: std.mem.Allocator,
    client: Client,

    pub fn init(allocator: std.mem.Allocator, client: Client) ProductStore {
        return .{ .allocator = allocator, .client = client };
    }

    fn dup(self: *ProductStore, e: anytype) !ProductRow {
        const name = try self.allocator.dupe(u8, e.name);
        errdefer self.allocator.free(name);
        const code = try self.allocator.dupe(u8, e.code);
        errdefer self.allocator.free(code);
        const type_ = try self.allocator.dupe(u8, e.type_);
        errdefer self.allocator.free(type_);
        const status = try self.allocator.dupe(u8, e.status);
        errdefer self.allocator.free(status);
        const desc = try self.allocator.dupe(u8, e.description);
        errdefer self.allocator.free(desc);
        const acl = try self.allocator.dupe(u8, e.acl);
        return .{
            .id = e.id,
            .tenant_id = e.tenant_id,
            .name = name,
            .code = code,
            .type_ = type_,
            .status = status,
            .owner_id = e.owner_id,
            .description = desc,
            .acl = acl,
            .created_at = e.created_at orelse 0,
            .updated_at = e.updated_at orelse 0,
        };
    }

    pub fn create(self: *ProductStore, p: struct {
        tenant_id: i64,
        name: []const u8,
        code: []const u8,
        owner_id: i64,
        description: []const u8,
        acl: []const u8,
    }, now: i64) !i64 {
        var created = try crud.create(self.client.product, .{
            .tenant_id = p.tenant_id,
            .name = p.name,
            .code = p.code,
            .type_ = "normal",
            .status = "active",
            .owner_id = p.owner_id,
            .description = p.description,
            .acl = p.acl,
            .created_at = now,
            .updated_at = now,
        });
        defer self.client.product.deinitRow(&created);
        return created.id;
    }

    pub fn getById(self: *ProductStore, tenant_id: i64, id: i64) !?ProductRow {
        const preds = self.client.product.predicates;
        var e = (try crud.first(self.client.product, .{
            preds.tenant_idEQ(.{ .int = tenant_id }),
            preds.idEQ(.{ .int = id }),
        })) orelse return null;
        defer self.client.product.deinitRow(&e);
        return try self.dup(e);
    }

    pub fn listByTenant(self: *ProductStore, tenant_id: i64, page: usize, page_size: usize) !ProductListResult {
        var q = self.client.product.Query();
        defer q.deinit();
        const preds = self.client.product.predicates;
        _ = try q.Where(.{preds.tenant_idEQ(.{ .int = tenant_id })});
        _ = try q.OrderBy(&[_]zent.sql.Order{zent.sql.OrderDesc("id")});

        var paged = try q.paged(page, page_size);
        defer paged.deinit();

        var out = try self.allocator.alloc(ProductRow, paged.items.items.len);
        var n: usize = 0;
        errdefer {
            for (out[0..n]) |r| r.free(self.allocator);
            self.allocator.free(out);
        }
        for (paged.items.items) |e| {
            out[n] = try self.dup(e);
            n += 1;
        }
        return .{ .items = out, .total = paged.total };
    }

    pub fn update(self: *ProductStore, tenant_id: i64, id: i64, fields: struct {
        name: ?[]const u8 = null,
        code: ?[]const u8 = null,
        status: ?[]const u8 = null,
        description: ?[]const u8 = null,
        acl: ?[]const u8 = null,
    }, now: i64) !bool {
        const preds = self.client.product.predicates;
        var upd: zent.sql.UpdateMap = .{};
        if (fields.name) |v| upd.name = v;
        if (fields.code) |v| upd.code = v;
        if (fields.status) |v| upd.status = v;
        if (fields.description) |v| upd.description = v;
        if (fields.acl) |v| upd.acl = v;
        upd.updated_at = now;
        const affected = try crud.update(self.client.product, upd, .{
            preds.tenant_idEQ(.{ .int = tenant_id }),
            preds.idEQ(.{ .int = id }),
        });
        return affected > 0;
    }

    pub fn delete(self: *ProductStore, tenant_id: i64, id: i64) !bool {
        const preds = self.client.product.predicates;
        var d = self.client.product.Delete();
        defer d.deinit();
        _ = try d.Where(.{preds.tenant_idEQ(.{ .int = tenant_id })});
        _ = try d.Where(.{preds.idEQ(.{ .int = id })});
        const affected = try d.Exec();
        return affected > 0;
    }
};