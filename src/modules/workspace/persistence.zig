//! Persistence over the zent Client — Workspace.

const std = @import("std");
const zent = @import("zent");
const crud = zent.crud_helpers;
const model = @import("model.zig");
const schema = @import("../../schema.zig");

const graph = zent.codegen.graph.buildGraph(&.{model.Workspace});
pub const infos = graph.types;
pub const Client = schema.Client;
pub const WorkspaceInfo = infos[0];

pub const WorkspaceRow = struct {
    id: i64,
    tenant_id: i64,
    name: []const u8,
    kind: []const u8,
    owner_user_id: i64,
    created_at: i64,
    updated_at: i64,

    pub fn free(self: WorkspaceRow, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.kind);
    }
};

pub const WorkspaceStore = struct {
    allocator: std.mem.Allocator,
    client: Client,

    pub fn init(allocator: std.mem.Allocator, client: Client) WorkspaceStore {
        return .{ .allocator = allocator, .client = client };
    }

    fn dup(self: *WorkspaceStore, e: anytype) !WorkspaceRow {
        const name = try self.allocator.dupe(u8, e.name);
        errdefer self.allocator.free(name);
        const kind = try self.allocator.dupe(u8, e.kind);
        errdefer self.allocator.free(kind);
        return .{
            .id = e.id,
            .tenant_id = e.tenant_id,
            .name = name,
            .kind = kind,
            .owner_user_id = e.owner_user_id,
            .created_at = e.created_at orelse 0,
            .updated_at = e.updated_at orelse 0,
        };
    }

    /// Idempotently create a `solo` workspace for a freshly-created user.
    /// Returns the workspace row id.
    pub fn ensureSolo(self: *WorkspaceStore, tenant_id: i64, owner_user_id: i64, name: []const u8, now: i64) !i64 {
        const preds = self.client.workspace.predicates;
        var found = (try crud.first(self.client.workspace, .{
            preds.tenant_idEQ(.{ .int = tenant_id }),
            preds.owner_user_idEQ(.{ .int = owner_user_id }),
            preds.kindEQ(.{ .string = "solo" }),
        })) orelse {
            var row = try crud.create(self.client.workspace, .{
                .tenant_id = tenant_id,
                .name = name,
                .kind = "solo",
                .owner_user_id = owner_user_id,
                .created_at = now,
                .updated_at = now,
            });
            defer self.client.workspace.deinitRow(&row);
            return row.id;
        };
        defer self.client.workspace.deinitRow(&found);
        return found.id;
    }

    pub fn getById(self: *WorkspaceStore, id: i64) !?WorkspaceRow {
        const preds = self.client.workspace.predicates;
        var entity = (try crud.first(self.client.workspace, .{preds.idEQ(.{ .int = id })})) orelse return null;
        defer self.client.workspace.deinitRow(&entity);
        return try self.dup(entity);
    }

    pub fn listByTenant(self: *WorkspaceStore, tenant_id: i64) ![]WorkspaceRow {
        var q = self.client.workspace.Query();
        defer q.deinit();
        const preds = self.client.workspace.predicates;
        _ = try q.Where(.{preds.tenant_idEQ(.{ .int = tenant_id })});
        var rows = try q.All();
        defer rows.deinit();
        var out = try self.allocator.alloc(WorkspaceRow, rows.items.items.len);
        var n: usize = 0;
        errdefer {
            for (out[0..n]) |r| r.free(self.allocator);
            self.allocator.free(out);
        }
        for (rows.items.items) |e| {
            out[n] = try self.dup(e);
            n += 1;
        }
        return out;
    }
};