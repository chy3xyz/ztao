const std = @import("std");
const zigmodu = @import("zigmodu");
const persist = @import("persistence.zig");

pub const ProductRow = persist.ProductRow;
pub const ProductOrderRow = persist.ProductOrderRow;

pub const DEFAULT_GIFTS = [_]struct {
    code: []const u8,
    name: []const u8,
    description: []const u8,
    image: []const u8,
    price_cents: i64,
    original_price_cents: i64,
    stock: i64,
    category: []const u8,
    reward_points: i64,
    sort: i64,
}{
    .{
        .code = "gift-coffee", .name = "精品咖啡券", .description = "10 元精品咖啡电子券",
        .image = "☕", .price_cents = 1000, .original_price_cents = 1500,
        .stock = 1000, .category = "电子券", .reward_points = 100, .sort = 1,
    },
    .{
        .code = "gift-book", .name = "PM 必读电子书包", .description = "10 本产品经理必读",
        .image = "📚", .price_cents = 9900, .original_price_cents = 14900,
        .stock = 100, .category = "电子书", .reward_points = 1000, .sort = 2,
    },
    .{
        .code = "gift-card", .name = "任务完成贺卡", .description = "AI 自动生成的电子贺卡",
        .image = "🎉", .price_cents = 0, .original_price_cents = 0,
        .stock = 9999, .category = "电子卡", .reward_points = 0, .sort = 3,
    },
};

pub const DEFAULT_ACCESSORIES = [_]struct {
    code: []const u8,
    name: []const u8,
    description: []const u8,
    image: []const u8,
    price_cents: i64,
    original_price_cents: i64,
    stock: i64,
    category: []const u8,
    reward_points: i64,
    sort: i64,
}{
    .{
        .code = "acc-monitor", .name = "戴尔 27 寸 4K 显示器", .description = "U2723QE · USB-C 90W",
        .image = "🖥️", .price_cents = 459900, .original_price_cents = 529900,
        .stock = 50, .category = "硬件", .reward_points = 0, .sort = 1,
    },
    .{
        .code = "acc-keyboard", .name = "HHKB Studio 键盘", .description = "静音机械键盘 · 适合编程",
        .image = "⌨️", .price_cents = 239900, .original_price_cents = 279900,
        .stock = 30, .category = "硬件", .reward_points = 0, .sort = 2,
    },
    .{
        .code = "acc-notion", .name = "Notion 年付", .description = "1 年 Notion Plus 订阅",
        .image = "📝", .price_cents = 39600, .original_price_cents = 48000,
        .stock = 100, .category = "工具 SaaS", .reward_points = 0, .sort = 3,
    },
};

pub const GiftAccessoryService = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    store: *persist.GiftAccessoryStore,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, store: *persist.GiftAccessoryStore) GiftAccessoryService {
        return .{ .allocator = allocator, .io = io, .store = store };
    }

    fn now(self: *GiftAccessoryService) i64 {
        return zigmodu.time.wallClockSeconds(self.io);
    }

    pub fn seedDefaults(self: *GiftAccessoryService) !void {
        const now = self.now();
        for (DEFAULT_GIFTS) |g| {
            _ = try self.store.upsertProduct(.{
                .kind = "gift",
                .code = g.code, .name = g.name, .description = g.description,
                .image = g.image, .price_cents = g.price_cents, .original_price_cents = g.original_price_cents,
                .stock = g.stock, .category = g.category,
                .reward_points = g.reward_points, .sort = g.sort,
            }, now);
        }
        for (DEFAULT_ACCESSORIES) |a| {
            _ = try self.store.upsertProduct(.{
                .kind = "accessory",
                .code = a.code, .name = a.name, .description = a.description,
                .image = a.image, .price_cents = a.price_cents, .original_price_cents = a.original_price_cents,
                .stock = a.stock, .category = a.category,
                .reward_points = a.reward_points, .sort = a.sort,
            }, now);
        }
    }

    pub fn listGifts(self: *GiftAccessoryService) ![]ProductRow {
        return self.store.listByKind("gift");
    }

    pub fn listAccessories(self: *GiftAccessoryService) ![]ProductRow {
        return self.store.listByKind("accessory");
    }

    pub fn get(self: *GiftAccessoryService, code: []const u8) !?ProductRow {
        return self.store.getByCode(code);
    }

    pub fn createOrder(self: *GiftAccessoryService, tenant_id: i64, user_id: i64, code: []const u8, qty: i64) !i64 {
        const p = (try self.store.getByCode(code)) orelse return error.ProductNotFound;
        defer p.free(self.allocator);
        if (p.price_cents == 0 and p.reward_points == 0) return error.CannotOrderFree;
        return self.store.createOrder(tenant_id, user_id, p.kind, p.code, qty, p.price_cents * qty, self.now());
    }

    pub fn getOrder(self: *GiftAccessoryService, tenant_id: i64, id: i64) !?ProductOrderRow {
        return self.store.getOrder(tenant_id, id);
    }

    pub fn listOrders(self: *GiftAccessoryService, tenant_id: i64, user_id: i64) ![]ProductOrderRow {
        return self.store.listOrdersByUser(tenant_id, user_id);
    }
};