const std = @import("std");
const zent = @import("zent");
const crud = zent.crud_helpers;
const model = @import("model.zig");
const schema = @import("../../schema.zig");

const graph = zent.codegen.graph.buildGraph(&.{model.Bug});
pub const infos = graph.types;
pub const Client = schema.Client;
pub const BugInfo = infos[0];

pub const BugRow = struct {
    id: i64,
    tenant_id: i64,
    product_id: i64,
    project_id: i64,
    title: []const u8,
    severity: i64,
    type_: []const u8,
    steps: []const u8,
    status: []const u8,
    resolved_by: i64,
    resolved_at: i64,
    resolution: []const u8,
    build_id: i64,
    assigned_to: i64,
    opened_by: i64,
    ai_triage: []const u8,
    created_at: i64,
    updated_at: i64,

    pub fn free(self: BugRow, allocator: std.mem.Allocator) void {
        allocator.free(self.title);
        allocator.free(self.type_);
        allocator.free(self.steps);
        allocator.free(self.status);
        allocator.free(self.resolution);
        allocator.free(self.ai_triage);
    }
};

pub const BugListResult = struct {
    items: []BugRow,
    total: i64,

    pub fn free(self: *BugListResult, allocator: std.mem.Allocator) void {
        for (self.items) |r| r.free(allocator);
        allocator.free(self.items);
    }
};

pub const BugStore = struct {
    allocator: std.mem.Allocator,
    client: Client,

    pub fn init(allocator: std.mem.Allocator, client: Client) BugStore {
        return .{ .allocator = allocator, .client = client };
    }

    fn dup(self: *BugStore, e: anytype) !BugRow {
        const title = try self.allocator.dupe(u8, e.title);
        errdefer self.allocator.free(title);
        const type_ = try self.allocator.dupe(u8, e.type_);
        errdefer self.allocator.free(type_);
        const steps = try self.allocator.dupe(u8, e.steps);
        errdefer self.allocator.free(steps);
        const status = try self.allocator.dupe(u8, e.status);
        errdefer self.allocator.free(status);
        const resolution = try self.allocator.dupe(u8, e.resolution);
        errdefer self.allocator.free(resolution);
        const triage = try self.allocator.dupe(u8, e.ai_triage);
        return .{
            .id = e.id,
            .tenant_id = e.tenant_id,
            .product_id = e.product_id,
            .project_id = e.project_id,
            .title = title,
            .severity = e.severity,
            .type_ = type_,
            .steps = steps,
            .status = status,
            .resolved_by = e.resolved_by,
            .resolved_at = e.resolved_at,
            .resolution = resolution,
            .build_id = e.build_id,
            .assigned_to = e.assigned_to,
            .opened_by = e.opened_by,
            .ai_triage = triage,
            .created_at = e.created_at orelse 0,
            .updated_at = e.updated_at orelse 0,
        };
    }

    pub fn create(self: *BugStore, b: struct {
        tenant_id: i64, product_id: i64, project_id: i64,
        title: []const u8, severity: i64, type_: []const u8, steps: []const u8,
        assigned_to: i64, opened_by: i64,
    }, now: i64) !i64 {
        var created = try crud.create(self.client.bug, .{
            .tenant_id = b.tenant_id,
            .product_id = b.product_id,
            .project_id = b.project_id,
            .title = b.title,
            .severity = b.severity,
            .type_ = b.type_,
            .steps = b.steps,
            .status = "active",
            .resolved_by = 0,
            .resolved_at = 0,
            .resolution = "",
            .build_id = 0,
            .assigned_to = b.assigned_to,
            .opened_by = b.opened_by,
            .ai_triage = "",
            .created_at = now,
            .updated_at = now,
        });
        defer self.client.bug.deinitRow(&created);
        return created.id;
    }

    pub fn getById(self: *BugStore, tenant_id: i64, id: i64) !?BugRow {
        const preds = self.client.bug.predicates;
        var e = (try crud.first(self.client.bug, .{
            preds.tenant_idEQ(.{ .int = tenant_id }),
            preds.idEQ(.{ .int = id }),
        })) orelse return null;
        defer self.client.bug.deinitRow(&e);
        return try self.dup(e);
    }

    pub fn listByProduct(self: *BugStore, tenant_id: i64, product_id: i64, page: usize, page_size: usize, status_filter: ?[]const u8) !BugListResult {
        var q = self.client.bug.Query();
        defer q.deinit();
        const preds = self.client.bug.predicates;
        _ = try q.Where(.{preds.tenant_idEQ(.{ .int = tenant_id })});
        _ = try q.Where(.{preds.product_idEQ(.{ .int = product_id })});
        if (status_filter) |st| {
            _ = try q.Where(.{preds.statusEQ(.{ .string = st })});
        }
        _ = try q.OrderBy(&[_]zent.sql.Order{zent.sql.OrderDesc("severity"), zent.sql.OrderDesc("id")});
        var paged = try q.paged(page, page_size);
        defer paged.deinit();
        var out = try self.allocator.alloc(BugRow, paged.items.items.len);
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

    pub fn resolve(self: *BugStore, tenant_id: i64, id: i64, resolved_by: i64, resolution: []const u8, now: i64) !bool {
        const preds = self.client.bug.predicates;
        const affected = try crud.update(self.client.bug, .{
            .status = "resolved",
            .resolved_by = resolved_by,
            .resolved_at = now,
            .resolution = resolution,
            .updated_at = now,
        }, .{
            preds.tenant_idEQ(.{ .int = tenant_id }),
            preds.idEQ(.{ .int = id }),
        });
        return affected > 0;
    }
};