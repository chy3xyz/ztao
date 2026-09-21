//! Persistence over the zent Client — AgentPreset / AgentInstance / AgentMemory.

const std = @import("std");
const zent = @import("zent");
const crud = zent.crud_helpers;
const model = @import("model.zig");
const schema = @import("../../schema.zig");

const graph = zent.codegen.graph.buildGraph(&.{
    model.AgentPreset,
    model.AgentInstance,
    model.AgentMemory,
});
pub const infos = graph.types;
pub const Client = schema.Client;
pub const AgentPresetInfo = infos[0];
pub const AgentInstanceInfo = infos[1];
pub const AgentMemoryInfo = infos[2];

// ---------- Row types ----------

pub const AgentPresetRow = struct {
    id: i64,
    code: []const u8,
    name: []const u8,
    avatar: []const u8,
    kind: []const u8,
    system_prompt: []const u8,
    tools: []const u8,
    capabilities: []const u8,
    scopes: []const u8,
    is_default: bool,
    sort: i64,
    created_at: i64,
    updated_at: i64,

    pub fn free(self: AgentPresetRow, allocator: std.mem.Allocator) void {
        allocator.free(self.code);
        allocator.free(self.name);
        allocator.free(self.avatar);
        allocator.free(self.kind);
        allocator.free(self.system_prompt);
        allocator.free(self.tools);
        allocator.free(self.capabilities);
        allocator.free(self.scopes);
    }
};

pub const AgentInstanceRow = struct {
    id: i64,
    tenant_id: i64,
    user_id: i64,
    preset_id: i64,
    preset_code: []const u8,
    name: []const u8,
    avatar: []const u8,
    model: []const u8,
    tools_override: []const u8,
    scopes_override: []const u8,
    status: []const u8,
    memory_policy: []const u8,
    max_daily_cost_cents: i64,
    created_at: i64,
    updated_at: i64,

    pub fn free(self: AgentInstanceRow, allocator: std.mem.Allocator) void {
        allocator.free(self.preset_code);
        allocator.free(self.name);
        allocator.free(self.avatar);
        allocator.free(self.model);
        allocator.free(self.tools_override);
        allocator.free(self.scopes_override);
        allocator.free(self.status);
        allocator.free(self.memory_policy);
    }
};

// ---------- Store ----------

pub const AgentStore = struct {
    allocator: std.mem.Allocator,
    client: Client,

    pub fn init(allocator: std.mem.Allocator, client: Client) AgentStore {
        return .{ .allocator = allocator, .client = client };
    }

    // ----- helpers -----

    fn dupPreset(self: *AgentStore, e: anytype) !AgentPresetRow {
        const code = try self.allocator.dupe(u8, e.code);
        errdefer self.allocator.free(code);
        const name = try self.allocator.dupe(u8, e.name);
        errdefer self.allocator.free(name);
        const avatar = try self.allocator.dupe(u8, e.avatar);
        errdefer self.allocator.free(avatar);
        const kind = try self.allocator.dupe(u8, e.kind);
        errdefer self.allocator.free(kind);
        const sp = try self.allocator.dupe(u8, e.system_prompt);
        errdefer self.allocator.free(sp);
        const tools = try self.allocator.dupe(u8, e.tools);
        errdefer self.allocator.free(tools);
        const caps = try self.allocator.dupe(u8, e.capabilities);
        errdefer self.allocator.free(caps);
        const scopes = try self.allocator.dupe(u8, e.scopes);
        return .{
            .id = e.id,
            .code = code,
            .name = name,
            .avatar = avatar,
            .kind = kind,
            .system_prompt = sp,
            .tools = tools,
            .capabilities = caps,
            .scopes = scopes,
            .is_default = e.is_default,
            .sort = e.sort,
            .created_at = e.created_at orelse 0,
            .updated_at = e.updated_at orelse 0,
        };
    }

    fn dupInstance(self: *AgentStore, e: anytype) !AgentInstanceRow {
        const pcode = try self.allocator.dupe(u8, e.preset_code);
        errdefer self.allocator.free(pcode);
        const name = try self.allocator.dupe(u8, e.name);
        errdefer self.allocator.free(name);
        const avatar = try self.allocator.dupe(u8, e.avatar);
        errdefer self.allocator.free(avatar);
        const model = try self.allocator.dupe(u8, e.model);
        errdefer self.allocator.free(model);
        const tools = try self.allocator.dupe(u8, e.tools_override);
        errdefer self.allocator.free(tools);
        const scopes = try self.allocator.dupe(u8, e.scopes_override);
        errdefer self.allocator.free(scopes);
        const status = try self.allocator.dupe(u8, e.status);
        errdefer self.allocator.free(status);
        const policy = try self.allocator.dupe(u8, e.memory_policy);
        return .{
            .id = e.id,
            .tenant_id = e.tenant_id,
            .user_id = e.user_id,
            .preset_id = e.preset_id,
            .preset_code = pcode,
            .name = name,
            .avatar = avatar,
            .model = model,
            .tools_override = tools,
            .scopes_override = scopes,
            .status = status,
            .memory_policy = policy,
            .max_daily_cost_cents = e.max_daily_cost_cents,
            .created_at = e.created_at orelse 0,
            .updated_at = e.updated_at orelse 0,
        };
    }

    // ----- Preset ops -----

    /// Idempotent upsert by `code`.
    pub fn upsertPreset(self: *AgentStore, row: struct {
        code: []const u8,
        name: []const u8,
        avatar: []const u8,
        kind: []const u8,
        system_prompt: []const u8,
        tools: []const u8,
        capabilities: []const u8,
        scopes: []const u8,
        is_default: bool,
        sort: i64,
    }, now: i64) !i64 {
        const preds = self.client.agent_preset.predicates;
        if ((try crud.first(self.client.agent_preset, .{preds.codeEQ(.{ .string = row.code })}))) |existing| {
            defer self.client.agent_preset.deinitRow(&existing);
            _ = try crud.update(self.client.agent_preset, .{
                .name = row.name,
                .avatar = row.avatar,
                .kind = row.kind,
                .system_prompt = row.system_prompt,
                .tools = row.tools,
                .capabilities = row.capabilities,
                .scopes = row.scopes,
                .is_default = row.is_default,
                .sort = row.sort,
                .updated_at = now,
            }, .{preds.idEQ(.{ .int = existing.id })});
            return existing.id;
        }
        var created = try crud.create(self.client.agent_preset, .{
            .code = row.code,
            .name = row.name,
            .avatar = row.avatar,
            .kind = row.kind,
            .system_prompt = row.system_prompt,
            .tools = row.tools,
            .capabilities = row.capabilities,
            .scopes = row.scopes,
            .is_default = row.is_default,
            .sort = row.sort,
            .created_at = now,
            .updated_at = now,
        });
        defer self.client.agent_preset.deinitRow(&created);
        return created.id;
    }

    pub fn listDefaults(self: *AgentStore) ![]AgentPresetRow {
        var q = self.client.agent_preset.Query();
        defer q.deinit();
        const preds = self.client.agent_preset.predicates;
        _ = try q.Where(.{preds.is_defaultEQ(.{ .bool = true })});
        _ = try q.OrderBy(&[_]zent.sql.Order{zent.sql.OrderAsc("sort")});
        var rows = try q.All();
        defer rows.deinit();
        var out = try self.allocator.alloc(AgentPresetRow, rows.items.items.len);
        var n: usize = 0;
        errdefer {
            for (out[0..n]) |r| r.free(self.allocator);
            self.allocator.free(out);
        }
        for (rows.items.items) |e| {
            out[n] = try self.dupPreset(e);
            n += 1;
        }
        return out;
    }

    pub fn getPresetByCode(self: *AgentStore, code: []const u8) !?AgentPresetRow {
        const preds = self.client.agent_preset.predicates;
        var e = (try crud.first(self.client.agent_preset, .{preds.codeEQ(.{ .string = code })})) orelse return null;
        defer self.client.agent_preset.deinitRow(&e);
        return try self.dupPreset(e);
    }

    // ----- Instance ops -----

    pub fn findInstance(self: *AgentStore, tenant_id: i64, user_id: i64, preset_id: i64) !?AgentInstanceRow {
        const preds = self.client.agent_instance.predicates;
        var e = (try crud.first(self.client.agent_instance, .{
            preds.tenant_idEQ(.{ .int = tenant_id }),
            preds.user_idEQ(.{ .int = user_id }),
            preds.preset_idEQ(.{ .int = preset_id }),
        })) orelse return null;
        defer self.client.agent_instance.deinitRow(&e);
        return try self.dupInstance(e);
    }

    pub fn createInstance(self: *AgentStore, row: struct {
        tenant_id: i64,
        user_id: i64,
        preset_id: i64,
        preset_code: []const u8,
        name: []const u8,
        avatar: []const u8,
        model: []const u8,
        max_daily_cost_cents: i64,
    }, now: i64) !i64 {
        var created = try crud.create(self.client.agent_instance, .{
            .tenant_id = row.tenant_id,
            .user_id = row.user_id,
            .preset_id = row.preset_id,
            .preset_code = row.preset_code,
            .name = row.name,
            .avatar = row.avatar,
            .model = row.model,
            .tools_override = "",
            .scopes_override = "",
            .status = "active",
            .memory_policy = "session",
            .max_daily_cost_cents = row.max_daily_cost_cents,
            .created_at = now,
            .updated_at = now,
        });
        defer self.client.agent_instance.deinitRow(&created);
        return created.id;
    }

    pub fn listInstancesByUser(self: *AgentStore, tenant_id: i64, user_id: i64) ![]AgentInstanceRow {
        var q = self.client.agent_instance.Query();
        defer q.deinit();
        const preds = self.client.agent_instance.predicates;
        _ = try q.Where(.{preds.tenant_idEQ(.{ .int = tenant_id })});
        _ = try q.Where(.{preds.user_idEQ(.{ .int = user_id })});
        _ = try q.Where(.{preds.statusNEQ(.{ .string = "deleted" })});
        _ = try q.OrderBy(&[_]zent.sql.Order{zent.sql.OrderAsc("id")});
        var rows = try q.All();
        defer rows.deinit();
        var out = try self.allocator.alloc(AgentInstanceRow, rows.items.items.len);
        var n: usize = 0;
        errdefer {
            for (out[0..n]) |r| r.free(self.allocator);
            self.allocator.free(out);
        }
        for (rows.items.items) |e| {
            out[n] = try self.dupInstance(e);
            n += 1;
        }
        return out;
    }

    pub fn getInstance(self: *AgentStore, id: i64) !?AgentInstanceRow {
        const preds = self.client.agent_instance.predicates;
        var e = (try crud.first(self.client.agent_instance, .{preds.idEQ(.{ .int = id })})) orelse return null;
        defer self.client.agent_instance.deinitRow(&e);
        return try self.dupInstance(e);
    }
};