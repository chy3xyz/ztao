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
    kind: []const u8,
    status: []const u8,
    owner_id: i64,
    description: []const u8,
    acl: []const u8,
    created_at: i64,
    updated_at: i64,

    pub fn free(self: ProductRow, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.code);
        allocator.free(self.kind);
        allocator.free(self.status);
        allocator.free(self.description);
        allocator.free(self.acl);
    }
};

pub const ProductListResult = struct {
    items: []ProductRow,
    total: i64,

    pub fn free(self: *const ProductListResult, allocator: std.mem.Allocator) void {
        for (self.items) |r| r.free(allocator);
        allocator.free(self.items);
    }
};

pub const ProductUpdateFields = struct {
    name: []const u8 = "__SKIP__",
    code: []const u8 = "__SKIP__",
    status: []const u8 = "__SKIP__",
    description: []const u8 = "__SKIP__",
    acl: []const u8 = "__SKIP__",
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
        const knd = try self.allocator.dupe(u8, e.kind);
        errdefer self.allocator.free(knd);
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
            .kind = knd,
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
            .kind = "normal",
            .status = "active",
            .owner_id = p.owner_id,
            .description = p.description,
            .acl = p.acl,
            .created_at = now,
            .updated_at = now,
        });
        defer self.client.product.deinitRow(@constCast(&created));
        return created.id;
    }

    pub fn getById(self: *ProductStore, tenant_id: i64, id: i64) !?ProductRow {
        const preds = self.client.product.predicates;
        var e = (try crud.first(self.client.product, .{
            preds.tenant_idEQ(.{ .int = tenant_id }),
            preds.idEQ(.{ .int = id }),
        })) orelse return null;
        defer self.client.product.deinitRow(@constCast(&e));
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

    pub fn update(self: *ProductStore, tenant_id: i64, id: i64, fields: ProductUpdateFields, now: i64) !bool {
        const preds = self.client.product.predicates;
        var q = self.client.product.Update();
        defer q.deinit();
        // sentinel "__SKIP__" 表示不更新该字段
        if (!std.mem.eql(u8, fields.name, "__SKIP__")) {
            _ = try q.set("name", .{ .string = fields.name });
        }
        if (!std.mem.eql(u8, fields.code, "__SKIP__")) {
            _ = try q.set("code", .{ .string = fields.code });
        }
        if (!std.mem.eql(u8, fields.status, "__SKIP__")) {
            _ = try q.set("status", .{ .string = fields.status });
        }
        if (!std.mem.eql(u8, fields.description, "__SKIP__")) {
            _ = try q.set("description", .{ .string = fields.description });
        }
        if (!std.mem.eql(u8, fields.acl, "__SKIP__")) {
            _ = try q.set("acl", .{ .string = fields.acl });
        }
        _ = try q.set("updated_at", .{ .int = now });
        _ = try q.Where(.{preds.tenant_idEQ(.{ .int = tenant_id })});
        _ = try q.Where(.{preds.idEQ(.{ .int = id })});
        const affected = try q.Save();
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