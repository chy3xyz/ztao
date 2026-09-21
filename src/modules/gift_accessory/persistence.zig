const std = @import("std");
const zent = @import("zent");
const crud = zent.crud_helpers;
const model = @import("model.zig");
const schema = @import("../../schema.zig");

const graph = zent.codegen.graph.buildGraph(&.{ model.Product, model.Order });
pub const infos = graph.types;
pub const Client = schema.Client;
pub const ProductInfo = infos[0];
pub const ProductOrderInfo = infos[1];

pub const ProductRow = struct {
    id: i64,
    tenant_id: i64,
    kind: []const u8,
    code: []const u8,
    name: []const u8,
    description: []const u8,
    image: []const u8,
    price_cents: i64,
    original_price_cents: i64,
    stock: i64,
    sales: i64,
    status: []const u8,
    category: []const u8,
    reward_points: i64,
    sort: i64,
    created_at: i64,
    updated_at: i64,

    pub fn free(self: ProductRow, allocator: std.mem.Allocator) void {
        allocator.free(self.kind);
        allocator.free(self.code);
        allocator.free(self.name);
        allocator.free(self.description);
        allocator.free(self.image);
        allocator.free(self.status);
        allocator.free(self.category);
    }
};

pub const ProductOrderRow = struct {
    id: i64,
    tenant_id: i64,
    user_id: i64,
    kind: []const u8,
    product_code: []const u8,
    quantity: i64,
    amount_cents: i64,
    receiver_name: []const u8,
    receiver_phone: []const u8,
    address: []const u8,
    status: []const u8,
    tracking_no: []const u8,
    paid_at: i64,
    shipped_at: i64,
    created_at: i64,
    updated_at: i64,

    pub fn free(self: ProductOrderRow, allocator: std.mem.Allocator) void {
        allocator.free(self.kind);
        allocator.free(self.product_code);
        allocator.free(self.receiver_name);
        allocator.free(self.receiver_phone);
        allocator.free(self.address);
        allocator.free(self.status);
        allocator.free(self.tracking_no);
    }
};

pub const GiftAccessoryStore = struct {
    allocator: std.mem.Allocator,
    client: Client,

    pub fn init(allocator: std.mem.Allocator, client: Client) GiftAccessoryStore {
        return .{ .allocator = allocator, .client = client };
    }

    fn dupProduct(self: *GiftAccessoryStore, e: anytype) !ProductRow {
        const kind = try self.allocator.dupe(u8, e.kind);
        errdefer self.allocator.free(kind);
        const code = try self.allocator.dupe(u8, e.code);
        errdefer self.allocator.free(code);
        const name = try self.allocator.dupe(u8, e.name);
        errdefer self.allocator.free(name);
        const desc = try self.allocator.dupe(u8, e.description);
        errdefer self.allocator.free(desc);
        const image = try self.allocator.dupe(u8, e.image);
        errdefer self.allocator.free(image);
        const status = try self.allocator.dupe(u8, e.status);
        errdefer self.allocator.free(status);
        const category = try self.allocator.dupe(u8, e.category);
        return .{
            .id = e.id,
            .tenant_id = e.tenant_id,
            .kind = kind,
            .code = code,
            .name = name,
            .description = desc,
            .image = image,
            .price_cents = e.price_cents,
            .original_price_cents = e.original_price_cents,
            .stock = e.stock,
            .sales = e.sales,
            .status = status,
            .category = category,
            .reward_points = e.reward_points,
            .sort = e.sort,
            .created_at = e.created_at orelse 0,
            .updated_at = e.updated_at orelse 0,
        };
    }

    fn dupOrder(self: *GiftAccessoryStore, e: anytype) !ProductOrderRow {
        const kind = try self.allocator.dupe(u8, e.kind);
        errdefer self.allocator.free(kind);
        const code = try self.allocator.dupe(u8, e.product_code);
        errdefer self.allocator.free(code);
        const rname = try self.allocator.dupe(u8, e.receiver_name);
        errdefer self.allocator.free(rname);
        const rphone = try self.allocator.dupe(u8, e.receiver_phone);
        errdefer self.allocator.free(rphone);
        const addr = try self.allocator.dupe(u8, e.address);
        errdefer self.allocator.free(addr);
        const status = try self.allocator.dupe(u8, e.status);
        errdefer self.allocator.free(status);
        const track = try self.allocator.dupe(u8, e.tracking_no);
        return .{
            .id = e.id,
            .tenant_id = e.tenant_id,
            .user_id = e.user_id,
            .kind = kind,
            .product_code = code,
            .quantity = e.quantity,
            .amount_cents = e.amount_cents,
            .receiver_name = rname,
            .receiver_phone = rphone,
            .address = addr,
            .status = status,
            .tracking_no = track,
            .paid_at = e.paid_at,
            .shipped_at = e.shipped_at,
            .created_at = e.created_at orelse 0,
            .updated_at = e.updated_at orelse 0,
        };
    }

    pub fn upsertProduct(self: *GiftAccessoryStore, p: struct {
        kind: []const u8, code: []const u8, name: []const u8, description: []const u8,
        image: []const u8, price_cents: i64, original_price_cents: i64,
        stock: i64, category: []const u8, reward_points: i64, sort: i64,
    }, now: i64) !i64 {
        const preds = self.client.gift_accessory_product.predicates;
        if ((try crud.first(self.client.gift_accessory_product, .{preds.codeEQ(.{ .string = p.code })}))) |existing| {
            defer self.client.gift_accessory_product.deinitRow(&existing);
            _ = try crud.update(self.client.gift_accessory_product, .{
                .kind = p.kind,
                .name = p.name,
                .description = p.description,
                .image = p.image,
                .price_cents = p.price_cents,
                .original_price_cents = p.original_price_cents,
                .stock = p.stock,
                .status = "on",
                .category = p.category,
                .reward_points = p.reward_points,
                .sort = p.sort,
                .updated_at = now,
            }, .{preds.idEQ(.{ .int = existing.id })});
            return existing.id;
        }
        var created = try crud.create(self.client.gift_accessory_product, .{
            .tenant_id = 1,
            .kind = p.kind,
            .code = p.code,
            .name = p.name,
            .description = p.description,
            .image = p.image,
            .price_cents = p.price_cents,
            .original_price_cents = p.original_price_cents,
            .stock = p.stock,
            .sales = 0,
            .status = "on",
            .category = p.category,
            .reward_points = p.reward_points,
            .sort = p.sort,
            .created_at = now,
            .updated_at = now,
        });
        defer self.client.gift_accessory_product.deinitRow(&created);
        return created.id;
    }

    pub fn listByKind(self: *GiftAccessoryStore, kind: []const u8) ![]ProductRow {
        var q = self.client.gift_accessory_product.Query();
        defer q.deinit();
        const preds = self.client.gift_accessory_product.predicates;
        _ = try q.Where(.{preds.kindEQ(.{ .string = kind })});
        _ = try q.Where(.{preds.statusEQ(.{ .string = "on" })});
        _ = try q.OrderBy(&[_]zent.sql.Order{zent.sql.OrderAsc("sort")});
        var rows = try q.All();
        defer rows.deinit();
        var out = try self.allocator.alloc(ProductRow, rows.items.items.len);
        var n: usize = 0;
        errdefer {
            for (out[0..n]) |r| r.free(self.allocator);
            self.allocator.free(out);
        }
        for (rows.items.items) |e| {
            out[n] = try self.dupProduct(e);
            n += 1;
        }
        return out;
    }

    pub fn getByCode(self: *GiftAccessoryStore, code: []const u8) !?ProductRow {
        const preds = self.client.gift_accessory_product.predicates;
        var e = (try crud.first(self.client.gift_accessory_product, .{preds.codeEQ(.{ .string = code })})) orelse return null;
        defer self.client.gift_accessory_product.deinitRow(&e);
        return try self.dupProduct(e);
    }

    pub fn createOrder(self: *GiftAccessoryStore, tenant_id: i64, user_id: i64, kind: []const u8, code: []const u8, qty: i64, amount_cents: i64, now: i64) !i64 {
        var created = try crud.create(self.client.gift_accessory_order, .{
            .tenant_id = tenant_id,
            .user_id = user_id,
            .kind = kind,
            .product_code = code,
            .quantity = qty,
            .amount_cents = amount_cents,
            .receiver_name = "",
            .receiver_phone = "",
            .address = "",
            .status = "pending",
            .tracking_no = "",
            .paid_at = 0,
            .shipped_at = 0,
            .created_at = now,
            .updated_at = now,
        });
        defer self.client.gift_accessory_order.deinitRow(&created);
        return created.id;
    }

    pub fn getOrder(self: *GiftAccessoryStore, tenant_id: i64, id: i64) !?ProductOrderRow {
        const preds = self.client.gift_accessory_order.predicates;
        var e = (try crud.first(self.client.gift_accessory_order, .{
            preds.tenant_idEQ(.{ .int = tenant_id }),
            preds.idEQ(.{ .int = id }),
        })) orelse return null;
        defer self.client.gift_accessory_order.deinitRow(&e);
        return try self.dupOrder(e);
    }

    pub fn listOrdersByUser(self: *GiftAccessoryStore, tenant_id: i64, user_id: i64) ![]ProductOrderRow {
        var q = self.client.gift_accessory_order.Query();
        defer q.deinit();
        const preds = self.client.gift_accessory_order.predicates;
        _ = try q.Where(.{preds.tenant_idEQ(.{ .int = tenant_id })});
        _ = try q.Where(.{preds.user_idEQ(.{ .int = user_id })});
        _ = try q.OrderBy(&[_]zent.sql.Order{zent.sql.OrderDesc("id")});
        var rows = try q.All();
        defer rows.deinit();
        var out = try self.allocator.alloc(ProductOrderRow, rows.items.items.len);
        var n: usize = 0;
        errdefer {
            for (out[0..n]) |r| r.free(self.allocator);
            self.allocator.free(out);
        }
        for (rows.items.items) |e| {
            out[n] = try self.dupOrder(e);
            n += 1;
        }
        return out;
    }
};