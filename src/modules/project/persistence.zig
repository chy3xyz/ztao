const std = @import("std");
const zent = @import("zent");
const crud = zent.crud_helpers;
const model = @import("model.zig");
const schema = @import("../../schema.zig");

const graph = zent.codegen.graph.buildGraph(&.{ model.Project, model.ProjectMember });
pub const infos = graph.types;
pub const Client = schema.Client;
pub const ProjectInfo = infos[0];
pub const ProjectMemberInfo = infos[1];

pub const ProjectRow = struct {
    id: i64,
    tenant_id: i64,
    product_id: i64,
    name: []const u8,
    code: []const u8,
    type_: []const u8,
    status: []const u8,
    model: []const u8,
    parent_id: i64,
    begin: i64,
    end: i64,
    owner_id: i64,
    budget_hours: i64,
    ai_enabled: bool,
    created_at: i64,
    updated_at: i64,

    pub fn free(self: ProjectRow, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.code);
        allocator.free(self.type_);
        allocator.free(self.status);
        allocator.free(self.model);
    }
};

pub const ProjectListResult = struct {
    items: []ProjectRow,
    total: i64,

    pub fn free(self: *ProjectListResult, allocator: std.mem.Allocator) void {
        for (self.items) |r| r.free(allocator);
        allocator.free(self.items);
    }
};

pub const ProjectStore = struct {
    allocator: std.mem.Allocator,
    client: Client,

    pub fn init(allocator: std.mem.Allocator, client: Client) ProjectStore {
        return .{ .allocator = allocator, .client = client };
    }

    fn dup(self: *ProjectStore, e: anytype) !ProjectRow {
        const name = try self.allocator.dupe(u8, e.name);
        errdefer self.allocator.free(name);
        const code = try self.allocator.dupe(u8, e.code);
        errdefer self.allocator.free(code);
        const type_ = try self.allocator.dupe(u8, e.type_);
        errdefer self.allocator.free(type_);
        const status = try self.allocator.dupe(u8, e.status);
        errdefer self.allocator.free(status);
        const model = try self.allocator.dupe(u8, e.model);
        return .{
            .id = e.id,
            .tenant_id = e.tenant_id,
            .product_id = e.product_id,
            .name = name,
            .code = code,
            .type_ = type_,
            .status = status,
            .model = model,
            .parent_id = e.parent_id,
            .begin = e.begin,
            .end = e.end,
            .owner_id = e.owner_id,
            .budget_hours = e.budget_hours,
            .ai_enabled = e.ai_enabled,
            .created_at = e.created_at orelse 0,
            .updated_at = e.updated_at orelse 0,
        };
    }

    pub fn create(self: *ProjectStore, p: struct {
        tenant_id: i64,
        product_id: i64,
        name: []const u8,
        code: []const u8,
        model: []const u8,
        owner_id: i64,
    }, now: i64) !i64 {
        var created = try crud.create(self.client.project, .{
            .tenant_id = p.tenant_id,
            .product_id = p.product_id,
            .name = p.name,
            .code = p.code,
            .type_ = "internal",
            .status = "wait",
            .model = p.model,
            .parent_id = 0,
            .begin = 0,
            .end = 0,
            .owner_id = p.owner_id,
            .budget_hours = 0,
            .ai_enabled = true,
            .created_at = now,
            .updated_at = now,
        });
        defer self.client.project.deinitRow(&created);
        return created.id;
    }

    pub fn getById(self: *ProjectStore, tenant_id: i64, id: i64) !?ProjectRow {
        const preds = self.client.project.predicates;
        var e = (try crud.first(self.client.project, .{
            preds.tenant_idEQ(.{ .int = tenant_id }),
            preds.idEQ(.{ .int = id }),
        })) orelse return null;
        defer self.client.project.deinitRow(&e);
        return try self.dup(e);
    }

    pub fn listByTenant(self: *ProjectStore, tenant_id: i64, page: usize, page_size: usize) !ProjectListResult {
        var q = self.client.project.Query();
        defer q.deinit();
        const preds = self.client.project.predicates;
        _ = try q.Where(.{preds.tenant_idEQ(.{ .int = tenant_id })});
        _ = try q.OrderBy(&[_]zent.sql.Order{zent.sql.OrderDesc("id")});
        var paged = try q.paged(page, page_size);
        defer paged.deinit();
        var out = try self.allocator.alloc(ProjectRow, paged.items.items.len);
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

    pub fn updateStatus(self: *ProjectStore, tenant_id: i64, id: i64, status: []const u8, now: i64) !bool {
        const preds = self.client.project.predicates;
        const affected = try crud.update(self.client.project, .{
            .status = status,
            .updated_at = now,
        }, .{
            preds.tenant_idEQ(.{ .int = tenant_id }),
            preds.idEQ(.{ .int = id }),
        });
        return affected > 0;
    }
};