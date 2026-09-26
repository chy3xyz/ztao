const std = @import("std");
const zent = @import("zent");
const crud = zent.crud_helpers;
const model = @import("model.zig");
const schema = @import("../../schema.zig");

const graph = zent.codegen.graph.buildGraph(&.{model.AgentApproval});
pub const infos = graph.types;
pub const Client = schema.Client;
pub const AgentApprovalInfo = infos[0];

pub const AgentApprovalRow = struct {
    id: i64,
    tenant_id: i64,
    run_id: i64,
    agent_id: i64,
    tool_name: []const u8,
    payload: []const u8,
    requested_at: i64,
    decision: []const u8,
    decided_by: i64,
    decided_at: i64,
    comment: []const u8,
    created_at: i64,
    updated_at: i64,

    pub fn free(self: AgentApprovalRow, allocator: std.mem.Allocator) void {
        allocator.free(self.tool_name);
        allocator.free(self.payload);
        allocator.free(self.decision);
        allocator.free(self.comment);
    }
};

pub const ApprovalListResult = struct {
    items: []AgentApprovalRow,
    total: i64,

    pub fn free(self: *const ApprovalListResult, allocator: std.mem.Allocator) void {
        for (self.items) |r| r.free(allocator);
        allocator.free(self.items);
    }
};

pub const ApprovalStore = struct {
    allocator: std.mem.Allocator,
    client: Client,

    pub fn init(allocator: std.mem.Allocator, client: Client) ApprovalStore {
        return .{ .allocator = allocator, .client = client };
    }

    fn dup(self: *ApprovalStore, e: anytype) !AgentApprovalRow {
        const tool = try self.allocator.dupe(u8, e.tool_name);
        errdefer self.allocator.free(tool);
        const payload = try self.allocator.dupe(u8, e.payload);
        errdefer self.allocator.free(payload);
        const decision = try self.allocator.dupe(u8, e.decision);
        errdefer self.allocator.free(decision);
        const comment = try self.allocator.dupe(u8, e.comment);
        return .{
            .id = e.id,
            .tenant_id = e.tenant_id,
            .run_id = e.run_id,
            .agent_id = e.agent_id,
            .tool_name = tool,
            .payload = payload,
            .requested_at = e.requested_at,
            .decision = decision,
            .decided_by = e.decided_by,
            .decided_at = e.decided_at,
            .comment = comment,
            .created_at = e.created_at orelse 0,
            .updated_at = e.updated_at orelse 0,
        };
    }

    pub fn create(self: *ApprovalStore, a: struct {
        tenant_id: i64, run_id: i64, agent_id: i64,
        tool_name: []const u8, payload: []const u8,
    }, now: i64) !i64 {
        var created = try crud.create(self.client.agent_approval, .{
            .tenant_id = a.tenant_id,
            .run_id = a.run_id,
            .agent_id = a.agent_id,
            .tool_name = a.tool_name,
            .payload = a.payload,
            .requested_at = now,
            .decision = "pending",
            .decided_by = 0,
            .decided_at = 0,
            .comment = "",
            .created_at = now,
            .updated_at = now,
        });
        defer self.client.agent_approval.deinitRow(@constCast(&created));
        return created.id;
    }

    pub fn listPending(self: *ApprovalStore, tenant_id: i64, user_id: i64) !ApprovalListResult {
        var q = self.client.agent_approval.Query();
        defer q.deinit();
        const preds = self.client.agent_approval.predicates;
        _ = try q.Where(.{preds.tenant_idEQ(.{ .int = tenant_id })});
        _ = try q.Where(.{preds.decisionEQ(.{ .string = "pending" })});
        _ = try q.OrderBy(&[_]zent.sql.Order{zent.sql.OrderDesc("requested_at")});
        var rows = try q.All();
        defer self.client.agent_approval.deinitRows(&rows);
        _ = user_id; // M3 占位：所有 pending 都属于该 tenant 的 founder
        var out = try self.allocator.alloc(AgentApprovalRow, rows.items.len);
        var n: usize = 0;
        errdefer {
            for (out[0..n]) |r| r.free(self.allocator);
            self.allocator.free(out);
        }
        for (rows.items) |e| {
            out[n] = try self.dup(e);
            n += 1;
        }
        return .{ .items = out, .total = @intCast(rows.items.len) };
    }

    pub fn decide(self: *ApprovalStore, tenant_id: i64, id: i64, decision: []const u8, decided_by: i64, comment: []const u8, now: i64) !bool {
        const preds = self.client.agent_approval.predicates;
        const affected = try crud.update(self.client.agent_approval, .{
            .decision = decision,
            .decided_by = decided_by,
            .decided_at = now,
            .comment = comment,
            .updated_at = now,
        }, .{
            preds.tenant_idEQ(.{ .int = tenant_id }),
            preds.idEQ(.{ .int = id }),
        });
        return affected > 0;
    }
};