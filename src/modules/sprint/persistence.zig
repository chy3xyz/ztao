const std = @import("std");
const zent = @import("zent");
const crud = zent.crud_helpers;
const model = @import("model.zig");
const schema = @import("../../schema.zig");

const graph = zent.codegen.graph.buildGraph(&.{model.Sprint});
pub const infos = graph.types;
pub const Client = schema.Client;
pub const SprintInfo = infos[0];

pub const SprintRow = struct {
    id: i64,
    tenant_id: i64,
    project_id: i64,
    name: []const u8,
    goal: []const u8,
    begin: i64,
    end: i64,
    status: []const u8,
    created_at: i64,
    updated_at: i64,

    pub fn free(self: SprintRow, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.goal);
        allocator.free(self.status);
    }
};

pub const SprintListResult = struct {
    items: []SprintRow,
    total: i64,

    pub fn free(self: *SprintListResult, allocator: std.mem.Allocator) void {
        for (self.items) |r| r.free(allocator);
        allocator.free(self.items);
    }
};

pub const SprintStore = struct {
    allocator: std.mem.Allocator,
    client: Client,

    pub fn init(allocator: std.mem.Allocator, client: Client) SprintStore {
        return .{ .allocator = allocator, .client = client };
    }

    fn dup(self: *SprintStore, e: anytype) !SprintRow {
        const name = try self.allocator.dupe(u8, e.name);
        errdefer self.allocator.free(name);
        const goal = try self.allocator.dupe(u8, e.goal);
        errdefer self.allocator.free(goal);
        const status = try self.allocator.dupe(u8, e.status);
        return .{
            .id = e.id,
            .tenant_id = e.tenant_id,
            .project_id = e.project_id,
            .name = name,
            .goal = goal,
            .begin = e.begin,
            .end = e.end,
            .status = status,
            .created_at = e.created_at orelse 0,
            .updated_at = e.updated_at orelse 0,
        };
    }

    pub fn create(self: *SprintStore, tenant_id: i64, project_id: i64, name: []const u8, goal: []const u8, begin: i64, end: i64, now: i64) !i64 {
        var created = try crud.create(self.client.sprint, .{
            .tenant_id = tenant_id,
            .project_id = project_id,
            .name = name,
            .goal = goal,
            .begin = begin,
            .end = end,
            .status = "planned",
            .created_at = now,
            .updated_at = now,
        });
        defer self.client.sprint.deinitRow(&created);
        return created.id;
    }

    pub fn listByProject(self: *SprintStore, tenant_id: i64, project_id: i64) !SprintListResult {
        var q = self.client.sprint.Query();
        defer q.deinit();
        const preds = self.client.sprint.predicates;
        _ = try q.Where(.{preds.tenant_idEQ(.{ .int = tenant_id })});
        _ = try q.Where(.{preds.project_idEQ(.{ .int = project_id })});
        _ = try q.OrderBy(&[_]zent.sql.Order{zent.sql.OrderDesc("id")});
        var rows = try q.All();
        defer rows.deinit();
        var out = try self.allocator.alloc(SprintRow, rows.items.items.len);
        var n: usize = 0;
        errdefer {
            for (out[0..n]) |r| r.free(self.allocator);
            self.allocator.free(out);
        }
        for (rows.items.items) |e| {
            out[n] = try self.dup(e);
            n += 1;
        }
        return .{ .items = out, .total = @intCast(rows.items.items.len) };
    }

    pub fn getById(self: *SprintStore, tenant_id: i64, id: i64) !?SprintRow {
        const preds = self.client.sprint.predicates;
        var e = (try crud.first(self.client.sprint, .{
            preds.tenant_idEQ(.{ .int = tenant_id }),
            preds.idEQ(.{ .int = id }),
        })) orelse return null;
        defer self.client.sprint.deinitRow(&e);
        return try self.dup(e);
    }
};