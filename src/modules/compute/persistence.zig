const std = @import("std");
const zent = @import("zent");
const crud = zent.crud_helpers;
const model = @import("model.zig");
const schema = @import("../../schema.zig");

const graph = zent.codegen.graph.buildGraph(&.{
    model.ComputePackage,
    model.ComputeOrder,
});
pub const infos = graph.types;
pub const Client = schema.Client;
pub const ComputePackageInfo = infos[0];
pub const ComputeOrderInfo = infos[1];

pub const ComputePackageRow = struct {
    id: i64,
    code: []const u8,
    name: []const u8,
    description: []const u8,
    tokens: i64,
    valid_days: i64,
    price_cents: i64,
    bonus_tokens: i64,
    kind: []const u8,
    seat: i64,
    active: bool,
    sort: i64,
    created_at: i64,
    updated_at: i64,

    pub fn free(self: ComputePackageRow, allocator: std.mem.Allocator) void {
        allocator.free(self.code);
        allocator.free(self.name);
        allocator.free(self.description);
        allocator.free(self.kind);
    }
};

pub const ComputeOrderRow = struct {
    id: i64,
    tenant_id: i64,
    user_id: i64,
    package_id: i64,
    package_code: []const u8,
    amount_cents: i64,
    status: []const u8,
    channel: []const u8,
    external_id: []const u8,
    paid_at: i64,
    granted_tokens: i64,
    created_at: i64,
    updated_at: i64,

    pub fn free(self: ComputeOrderRow, allocator: std.mem.Allocator) void {
        allocator.free(self.package_code);
        allocator.free(self.status);
        allocator.free(self.channel);
        allocator.free(self.external_id);
    }
};

pub const ComputeStore = struct {
    allocator: std.mem.Allocator,
    client: Client,

    pub fn init(allocator: std.mem.Allocator, client: Client) ComputeStore {
        return .{ .allocator = allocator, .client = client };
    }

    fn dupPackage(self: *ComputeStore, e: anytype) !ComputePackageRow {
        const code = try self.allocator.dupe(u8, e.code);
        errdefer self.allocator.free(code);
        const name = try self.allocator.dupe(u8, e.name);
        errdefer self.allocator.free(name);
        const description = try self.allocator.dupe(u8, e.description);
        errdefer self.allocator.free(description);
        const kind = try self.allocator.dupe(u8, e.kind);
        return .{
            .id = e.id,
            .code = code,
            .name = name,
            .description = description,
            .tokens = e.tokens,
            .valid_days = e.valid_days,
            .price_cents = e.price_cents,
            .bonus_tokens = e.bonus_tokens,
            .kind = kind,
            .seat = e.seat,
            .active = e.active,
            .sort = e.sort,
            .created_at = e.created_at orelse 0,
            .updated_at = e.updated_at orelse 0,
        };
    }

    fn dupOrder(self: *ComputeStore, e: anytype) !ComputeOrderRow {
        const code = try self.allocator.dupe(u8, e.package_code);
        errdefer self.allocator.free(code);
        const status = try self.allocator.dupe(u8, e.status);
        errdefer self.allocator.free(status);
        const channel = try self.allocator.dupe(u8, e.channel);
        errdefer self.allocator.free(channel);
        const external_id = try self.allocator.dupe(u8, e.external_id);
        return .{
            .id = e.id,
            .tenant_id = e.tenant_id,
            .user_id = e.user_id,
            .package_id = e.package_id,
            .package_code = code,
            .amount_cents = e.amount_cents,
            .status = status,
            .channel = channel,
            .external_id = external_id,
            .paid_at = e.paid_at,
            .granted_tokens = e.granted_tokens,
            .created_at = e.created_at orelse 0,
            .updated_at = e.updated_at orelse 0,
        };
    }

    // ---------- Package ----------

    pub fn upsertPackage(self: *ComputeStore, p: struct {
        code: []const u8, name: []const u8, description: []const u8,
        tokens: i64, valid_days: i64, price_cents: i64, bonus_tokens: i64,
        kind: []const u8, seat: i64, sort: i64,
    }, now: i64) !i64 {
        const preds = self.client.compute_package.predicates;
        if ((try crud.first(self.client.compute_package, .{preds.codeEQ(.{ .string = p.code })}))) |existing| {
            defer self.client.compute_package.deinitRow(&existing);
            _ = try crud.update(self.client.compute_package, .{
                .name = p.name,
                .description = p.description,
                .tokens = p.tokens,
                .valid_days = p.valid_days,
                .price_cents = p.price_cents,
                .bonus_tokens = p.bonus_tokens,
                .kind = p.kind,
                .seat = p.seat,
                .active = true,
                .sort = p.sort,
                .updated_at = now,
            }, .{preds.idEQ(.{ .int = existing.id })});
            return existing.id;
        }
        var created = try crud.create(self.client.compute_package, .{
            .code = p.code,
            .name = p.name,
            .description = p.description,
            .tokens = p.tokens,
            .valid_days = p.valid_days,
            .price_cents = p.price_cents,
            .bonus_tokens = p.bonus_tokens,
            .kind = p.kind,
            .seat = p.seat,
            .active = true,
            .sort = p.sort,
            .created_at = now,
            .updated_at = now,
        });
        defer self.client.compute_package.deinitRow(&created);
        return created.id;
    }

    pub fn listActivePackages(self: *ComputeStore) ![]ComputePackageRow {
        var q = self.client.compute_package.Query();
        defer q.deinit();
        const preds = self.client.compute_package.predicates;
        _ = try q.Where(.{preds.activeEQ(.{ .bool = true })});
        _ = try q.OrderBy(&[_]zent.sql.Order{zent.sql.OrderAsc("sort")});
        var rows = try q.All();
        defer rows.deinit();
        var out = try self.allocator.alloc(ComputePackageRow, rows.items.items.len);
        var n: usize = 0;
        errdefer {
            for (out[0..n]) |r| r.free(self.allocator);
            self.allocator.free(out);
        }
        for (rows.items.items) |e| {
            out[n] = try self.dupPackage(e);
            n += 1;
        }
        return out;
    }

    pub fn getPackageByCode(self: *ComputeStore, code: []const u8) !?ComputePackageRow {
        const preds = self.client.compute_package.predicates;
        var e = (try crud.first(self.client.compute_package, .{preds.codeEQ(.{ .string = code })})) orelse return null;
        defer self.client.compute_package.deinitRow(&e);
        return try self.dupPackage(e);
    }

    pub fn getPackageById(self: *ComputeStore, id: i64) !?ComputePackageRow {
        const preds = self.client.compute_package.predicates;
        var e = (try crud.first(self.client.compute_package, .{preds.idEQ(.{ .int = id })})) orelse return null;
        defer self.client.compute_package.deinitRow(&e);
        return try self.dupPackage(e);
    }

    // ---------- Order ----------

    pub fn createOrder(self: *ComputeStore, tenant_id: i64, user_id: i64, package_id: i64, package_code: []const u8, amount_cents: i64, channel: []const u8, now: i64) !i64 {
        var created = try crud.create(self.client.compute_order, .{
            .tenant_id = tenant_id,
            .user_id = user_id,
            .package_id = package_id,
            .package_code = package_code,
            .amount_cents = amount_cents,
            .status = "pending",
            .channel = channel,
            .external_id = "",
            .paid_at = 0,
            .granted_tokens = 0,
            .created_at = now,
            .updated_at = now,
        });
        defer self.client.compute_order.deinitRow(&created);
        return created.id;
    }

    pub fn getOrder(self: *ComputeStore, tenant_id: i64, id: i64) !?ComputeOrderRow {
        const preds = self.client.compute_order.predicates;
        var e = (try crud.first(self.client.compute_order, .{
            preds.tenant_idEQ(.{ .int = tenant_id }),
            preds.idEQ(.{ .int = id }),
        })) orelse return null;
        defer self.client.compute_order.deinitRow(&e);
        return try self.dupOrder(e);
    }

    pub fn markPaid(self: *ComputeStore, tenant_id: i64, id: i64, external_id: []const u8, granted_tokens: i64, now: i64) !bool {
        const preds = self.client.compute_order.predicates;
        const affected = try crud.update(self.client.compute_order, .{
            .status = "paid",
            .external_id = external_id,
            .paid_at = now,
            .granted_tokens = granted_tokens,
            .updated_at = now,
        }, .{
            preds.tenant_idEQ(.{ .int = tenant_id }),
            preds.idEQ(.{ .int = id }),
        });
        return affected > 0;
    }

    pub fn markClosed(self: *ComputeStore, tenant_id: i64, id: i64, now: i64) !bool {
        const preds = self.client.compute_order.predicates;
        const affected = try crud.update(self.client.compute_order, .{
            .status = "closed",
            .updated_at = now,
        }, .{
            preds.tenant_idEQ(.{ .int = tenant_id }),
            preds.idEQ(.{ .int = id }),
        });
        return affected > 0;
    }

    pub fn listOrdersByUser(self: *ComputeStore, tenant_id: i64, user_id: i64, page: usize, page_size: usize) ![]ComputeOrderRow {
        var q = self.client.compute_order.Query();
        defer q.deinit();
        const preds = self.client.compute_order.predicates;
        _ = try q.Where(.{preds.tenant_idEQ(.{ .int = tenant_id })});
        _ = try q.Where(.{preds.user_idEQ(.{ .int = user_id })});
        _ = try q.OrderBy(&[_]zent.sql.Order{zent.sql.OrderDesc("id")});
        var rows = try q.All();
        defer rows.deinit();
        // 简单分页
        const start = if (page > 1) (page - 1) * page_size else 0;
        const end = @min(start + page_size, rows.items.items.len);
        if (start >= end) return &.{};
        var out = try self.allocator.alloc(ComputeOrderRow, end - start);
        var n: usize = 0;
        errdefer {
            for (out[0..n]) |r| r.free(self.allocator);
            self.allocator.free(out);
        }
        for (rows.items.items[start..end]) |e| {
            out[n] = try self.dupOrder(e);
            n += 1;
        }
        return out;
    }
};