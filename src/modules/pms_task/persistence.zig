const std = @import("std");
const zent = @import("zent");
const crud = zent.crud_helpers;
const model = @import("model.zig");
const schema = @import("../../schema.zig");

const graph = zent.codegen.graph.buildGraph(&.{model.Task});
pub const infos = graph.types;
pub const Client = schema.Client;
pub const TaskInfo = infos[0];

pub const PmsTaskRow = struct {
    id: i64,
    tenant_id: i64,
    project_id: i64,
    sprint_id: i64,
    story_id: i64,
    parent_id: i64,
    name: []const u8,
    kind: []const u8,
    pri: i64,
    estimate: f64,
    consumed: f64,
    left: f64,
    status: []const u8,
    assigned_to: i64,
    assignee_kind: []const u8,
    finished_by: i64,
    finished_at: i64,
    ai_assisted: bool,
    agent_run_id: i64,
    created_at: i64,
    updated_at: i64,

    pub fn free(self: PmsTaskRow, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.kind);
        allocator.free(self.status);
        allocator.free(self.assignee_kind);
    }
};

pub const PmsTaskListResult = struct {
    items: []PmsTaskRow,
    total: i64,

    pub fn free(self: *const PmsTaskListResult, allocator: std.mem.Allocator) void {
        for (self.items) |r| r.free(allocator);
        allocator.free(self.items);
    }
};

pub const PmsTaskStore = struct {
    allocator: std.mem.Allocator,
    client: Client,

    pub fn init(allocator: std.mem.Allocator, client: Client) PmsTaskStore {
        return .{ .allocator = allocator, .client = client };
    }

    fn dup(self: *PmsTaskStore, e: anytype) !PmsTaskRow {
        const name = try self.allocator.dupe(u8, e.name);
        errdefer self.allocator.free(name);
        const knd = try self.allocator.dupe(u8, e.kind);
        errdefer self.allocator.free(knd);
        const status = try self.allocator.dupe(u8, e.status);
        errdefer self.allocator.free(status);
        const kind = try self.allocator.dupe(u8, e.assignee_kind);
        return .{
            .id = e.id,
            .tenant_id = e.tenant_id,
            .project_id = e.project_id,
            .sprint_id = e.sprint_id,
            .story_id = e.story_id,
            .parent_id = e.parent_id,
            .name = name,
            .kind = knd,
            .pri = e.pri,
            .estimate = e.estimate,
            .consumed = e.consumed,
            .left = e.left,
            .status = status,
            .assigned_to = e.assigned_to,
            .assignee_kind = kind,
            .finished_by = e.finished_by,
            .finished_at = e.finished_at,
            .ai_assisted = e.ai_assisted,
            .agent_run_id = e.agent_run_id,
            .created_at = e.created_at orelse 0,
            .updated_at = e.updated_at orelse 0,
        };
    }

    pub fn create(self: *PmsTaskStore, t: struct {
        tenant_id: i64, project_id: i64, sprint_id: i64, story_id: i64,
        name: []const u8, pri: i64, estimate: f64, left: f64,
        assigned_to: i64, assignee_kind: []const u8,
        ai_assisted: bool,
    }, now: i64) !i64 {
        var created = try crud.create(self.client.pms_task, .{
            .tenant_id = t.tenant_id,
            .project_id = t.project_id,
            .sprint_id = t.sprint_id,
            .story_id = t.story_id,
            .parent_id = 0,
            .name = t.name,
            .kind = "task",
            .pri = t.pri,
            .estimate = t.estimate,
            .consumed = @as(f64, 0),
            .left = t.left,
            .status = "wait",
            .assigned_to = t.assigned_to,
            .assignee_kind = t.assignee_kind,
            .finished_by = 0,
            .finished_at = 0,
            .ai_assisted = t.ai_assisted,
            .agent_run_id = 0,
            .created_at = now,
            .updated_at = now,
        });
        defer self.client.pms_task.deinitRow(@constCast(&created));
        return created.id;
    }

    pub fn getById(self: *PmsTaskStore, tenant_id: i64, id: i64) !?PmsTaskRow {
        const preds = self.client.pms_task.predicates;
        var e = (try crud.first(self.client.pms_task, .{
            preds.tenant_idEQ(.{ .int = tenant_id }),
            preds.idEQ(.{ .int = id }),
        })) orelse return null;
        defer self.client.pms_task.deinitRow(@constCast(&e));
        return try self.dup(e);
    }

    pub fn listByProject(self: *PmsTaskStore, tenant_id: i64, project_id: i64, page: usize, page_size: usize) !PmsTaskListResult {
        var q = self.client.pms_task.Query();
        defer q.deinit();
        const preds = self.client.pms_task.predicates;
        _ = try q.Where(.{preds.tenant_idEQ(.{ .int = tenant_id })});
        _ = try q.Where(.{preds.project_idEQ(.{ .int = project_id })});
        _ = try q.OrderBy(&[_]zent.sql.Order{zent.sql.OrderDesc("id")});
        var paged = try q.paged(page, page_size);
        defer paged.deinit();
        var out = try self.allocator.alloc(PmsTaskRow, paged.items.items.len);
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

    pub fn listAssignedTo(self: *PmsTaskStore, tenant_id: i64, user_id: i64, page: usize, page_size: usize) !PmsTaskListResult {
        var q = self.client.pms_task.Query();
        defer q.deinit();
        const preds = self.client.pms_task.predicates;
        _ = try q.Where(.{preds.tenant_idEQ(.{ .int = tenant_id })});
        _ = try q.Where(.{preds.assigned_toEQ(.{ .int = user_id })});
        _ = try q.OrderBy(&[_]zent.sql.Order{zent.sql.OrderDesc("id")});
        var paged = try q.paged(page, page_size);
        defer paged.deinit();
        var out = try self.allocator.alloc(PmsTaskRow, paged.items.items.len);
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

    pub fn updateStatus(self: *PmsTaskStore, tenant_id: i64, id: i64, status: []const u8, finished_by: i64, now: i64) !bool {
        const preds = self.client.pms_task.predicates;
        const upd = .{
            .status = status,
            .updated_at = now,
            .finished_by = if (std.mem.eql(u8, status, "done")) finished_by else @as(i64, 0),
            .finished_at = if (std.mem.eql(u8, status, "done")) now else @as(i64, 0),
        };
        const affected = try crud.update(self.client.pms_task, upd, .{
            preds.tenant_idEQ(.{ .int = tenant_id }),
            preds.idEQ(.{ .int = id }),
        });
        return affected > 0;
    }

    pub fn logTime(self: *PmsTaskStore, tenant_id: i64, id: i64, hours: f64, now: i64) !bool {
        const preds = self.client.pms_task.predicates;
        const row = (try self.getById(tenant_id, id)) orelse return false;
        defer row.free(self.allocator);
        const new_consumed = row.consumed + hours;
        const new_left = if (row.left > hours) row.left - hours else @as(f64, 0);
        const affected = try crud.update(self.client.pms_task, .{
            .consumed = new_consumed,
            .left = new_left,
            .updated_at = now,
        }, .{
            preds.tenant_idEQ(.{ .int = tenant_id }),
            preds.idEQ(.{ .int = id }),
        });
        return affected > 0;
    }
};