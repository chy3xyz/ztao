//! Mall BFF（/api/v1/mp/mall/*）— 算力商城 + 礼品 / 配件（M5+）。

const std = @import("std");
const zigmodu = @import("zigmodu");
const http = zigmodu.http;
const mp_mw = @import("../../middleware/mp_auth.zig");

const user_svc = @import("../user/service.zig");
const compute_svc = @import("../compute/service.zig");
const usage_svc = @import("../usage/service.zig");
const gift_svc = @import("../gift_accessory/service.zig");

pub fn MallBffApi(comptime UserService: type, comptime ComputeService: type,
    comptime UsageService: type, comptime GiftAccessoryService: type) type {
    return struct {
        const S = @This();
        users: *UserService,
        compute: *ComputeService,
        usage: *UsageService,
        gifts: *GiftAccessoryService,

        pub const module_name = "mall_bff";
        pub const nest: []const []const u8 = &.{};
        pub const State = S;

        pub const routes: []const http.RouteSpec(S) = &.{
            .{ .method = .GET, .path = "mp/mall/compute/packages", .handler = http.wrapHandler(S, listComputePackages), .meta = .{ .auth = .jwt } },
            .{ .method = .POST, .path = "mp/mall/compute/buy", .handler = http.wrapHandler(S, buyCompute), .meta = .{ .auth = .jwt } },
            .{ .method = .GET, .path = "mp/mall/compute/orders", .handler = http.wrapHandler(S, listComputeOrders), .meta = .{ .auth = .jwt } },
            .{ .method = .GET, .path = "mp/mall/gift", .handler = http.wrapHandler(S, listGifts), .meta = .{ .auth = .jwt } },
            .{ .method = .GET, .path = "mp/mall/accessory", .handler = http.wrapHandler(S, listAccessories), .meta = .{ .auth = .jwt } },
            .{ .method = .POST, .path = "mp/mall/buy", .handler = http.wrapHandler(S, buyProduct), .meta = .{ .auth = .jwt } },
            .{ .method = .GET, .path = "mp/mall/orders", .handler = http.wrapHandler(S, listMallOrders), .meta = .{ .auth = .jwt } },
            // 微信支付 v3 异步回调（不走 JWT；用 WeChatPay 签名验证）
            .{ .method = .POST, .path = "pay/v3/notify", .handler = http.wrapHandler(S, wechatPayNotify), .meta = .{ .auth = .public } },
        };

        pub fn init(users: *UserService, compute: *ComputeService, usage: *UsageService, gifts: *GiftAccessoryService) S {
            return .{ .users = users, .compute = compute, .usage = usage, .gifts = gifts };
        }

        fn requireUser(ctx: *http.Context, self: *S) !?user_svc.UserRow {
            const uid = mp_mw.mpUserId(ctx) orelse {
                try ctx.sendErrorResponse(401, 401, "未登录");
                return null;
            };
            const row = (try self.users.getUserById(uid)) orelse {
                try ctx.sendErrorResponse(404, 404, "用户不存在");
                return null;
            };
            return row;
        }

        fn listComputePackages(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            _ = (try requireUser(ctx, self)) orelse return;

            const list = self.compute.listPackages() catch {
                try ctx.sendErrorResponse(500, 500, "服务器错误");
                return;
            };
            defer {
                for (list) |p| p.free(self.compute.allocator);
                self.compute.allocator.free(list);
            }

            const dtos = try ctx.allocator.alloc(struct {
                code: []const u8,
                name: []const u8,
                description: []const u8,
                tokens: i64,
                bonus_tokens: i64,
                price_cents: i64,
                kind: []const u8,
                seat: i64,
            }, list.len);
            for (list, 0..) |p, i| {
                dtos[i] = .{
                    .code = p.code, .name = p.name, .description = p.description,
                    .tokens = p.tokens, .bonus_tokens = p.bonus_tokens,
                    .price_cents = p.price_cents, .kind = p.kind, .seat = p.seat,
                };
            }
            try ctx.okValue(.{ .list = dtos });
        }

        const BuyReq = struct {
            package_code: []const u8,
            channel: ?[]const u8 = null,
        };

        fn buyCompute(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx, self)) orelse return;
            defer user_row.free(self.users.store.allocator);

            const req = ctx.bindJson(BuyReq) catch {
                try ctx.sendErrorResponse(400, 400, "请求体格式错误");
                return;
            };
            defer ctx.allocator.free(req.package_code);
            if (req.channel) |c| defer ctx.allocator.free(c);

            const order_id = self.compute.createOrder(user_row.tenant_id, user_row.id, req.package_code, req.channel orelse "wechat") catch |err| {
                const msg = switch (err) {
                    error.PackageNotFound => "套餐不存在",
                    error.CannotPurchaseFree => "免费套餐无需购买",
                    else => "服务器错误",
                };
                try ctx.sendErrorResponse(400, 400, msg);
                return;
            };

            // 调微信支付 v3 统一下单 → 返回 prepay_id
            // M4 占位：返回 pay_params 由小程序前端拉起支付
            try ctx.okValue(.{
                .order_id = order_id,
                .pay_params = .{
                    .timeStamp = "",
                    .nonceStr = "",
                    .package = "prepay_id=stub_" ++ std.fmt.allocPrint(ctx.allocator, "{d}", .{order_id}) catch "stub",
                    .signType = "RSA",
                    .paySign = "stub-sign-m4",
                },
                .note = "M4 stub · 真实接入需 wechat v3 merchant credentials",
            });
        }

        fn listComputeOrders(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx, self)) orelse return;
            defer user_row.free(self.users.store.allocator);

            const list = self.compute.listOrders(user_row.tenant_id, user_row.id, 1, 20) catch {
                try ctx.sendErrorResponse(500, 500, "服务器错误");
                return;
            };
            defer {
                for (list) |o| o.free(self.compute.allocator);
                self.compute.allocator.free(list);
            }
            const dtos = try ctx.allocator.alloc(struct {
                id: i64,
                package_code: []const u8,
                amount_cents: i64,
                status: []const u8,
                granted_tokens: i64,
                paid_at: i64,
            }, list.len);
            for (list, 0..) |o, i| {
                dtos[i] = .{
                    .id = o.id, .package_code = o.package_code,
                    .amount_cents = o.amount_cents, .status = o.status,
                    .granted_tokens = o.granted_tokens, .paid_at = o.paid_at,
                };
            }
            try ctx.okValue(.{ .list = dtos });
        }

        // ---------- 微信支付 v3 回调 ----------
        // 真实实现：zwechat 验签 → 解析 out_trade_no → markPaid → credit
        fn wechatPayNotify(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            // M4 占位：直接信任 body。真实实现用 zwechat 验签。
            const body = ctx.request.body orelse "";
            _ = body;

            // 占位：返回 success XML
            try ctx.setHeader("Content-Type", "application/xml");
            try ctx.okValue("<xml><return_code><![CDATA[SUCCESS]]></return_code></xml>");
            _ = self;
        }

        // ---------- M5 · 礼品 / 配件 ----------

        fn listGifts(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            _ = (try requireUser(ctx, self)) orelse return;

            const list = self.gifts.listGifts() catch {
                try ctx.sendErrorResponse(500, 500, "服务器错误");
                return;
            };
            defer {
                for (list) |p| p.free(self.gifts.allocator);
                self.gifts.allocator.free(list);
            }
            try ctx.okValue(.{ .list = productsToDtos(ctx, list) });
        }

        fn listAccessories(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            _ = (try requireUser(ctx, self)) orelse return;

            const list = self.gifts.listAccessories() catch {
                try ctx.sendErrorResponse(500, 500, "服务器错误");
                return;
            };
            defer {
                for (list) |p| p.free(self.gifts.allocator);
                self.gifts.allocator.free(list);
            }
            try ctx.okValue(.{ .list = productsToDtos(ctx, list) });
        }

        const BuyProductReq = struct {
            code: []const u8,
            quantity: ?i64 = null,
        };

        fn buyProduct(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx, self)) orelse return;
            defer user_row.free(self.users.store.allocator);

            const req = ctx.bindJson(BuyProductReq) catch {
                try ctx.sendErrorResponse(400, 400, "请求体格式错误");
                return;
            };
            defer ctx.allocator.free(req.code);

            const order_id = self.gifts.createOrder(
                user_row.tenant_id,
                user_row.id,
                req.code,
                req.quantity orelse 1,
            ) catch |err| {
                const msg = switch (err) {
                    error.ProductNotFound => "商品不存在",
                    error.CannotOrderFree => "免费商品请直接领取",
                    else => "服务器错误",
                };
                try ctx.sendErrorResponse(400, 400, msg);
                return;
            };
            try ctx.okValue(.{ .order_id = order_id, .note = "M5 stub · 真实接入走 /pay/v3/notify" });
        }

        fn listMallOrders(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx, self)) orelse return;
            defer user_row.free(self.users.store.allocator);

            const list = self.gifts.listOrders(user_row.tenant_id, user_row.id) catch {
                try ctx.sendErrorResponse(500, 500, "服务器错误");
                return;
            };
            defer {
                for (list) |o| o.free(self.gifts.allocator);
                self.gifts.allocator.free(list);
            }
            const dtos = try ctx.allocator.alloc(struct {
                id: i64,
                kind: []const u8,
                product_code: []const u8,
                quantity: i64,
                amount_cents: i64,
                status: []const u8,
                created_at: i64,
            }, list.len);
            for (list, 0..) |o, i| {
                dtos[i] = .{
                    .id = o.id, .kind = o.kind, .product_code = o.product_code,
                    .quantity = o.quantity, .amount_cents = o.amount_cents,
                    .status = o.status, .created_at = o.created_at,
                };
            }
            try ctx.okValue(.{ .list = dtos });
        }
    };
}

fn productsToDtos(ctx: *http.Context, list: []const gift_svc.ProductRow) []struct {
    code: []const u8,
    name: []const u8,
    description: []const u8,
    image: []const u8,
    price_cents: i64,
    original_price_cents: i64,
    stock: i64,
    category: []const u8,
} {
    const dtos = ctx.allocator.alloc(@TypeOf((struct {
        code: []const u8,
        name: []const u8,
        description: []const u8,
        image: []const u8,
        price_cents: i64,
        original_price_cents: i64,
        stock: i64,
        category: []const u8,
    }){}), list.len) catch &.{};
    for (list, 0..) |p, i| {
        dtos[i] = .{
            .code = ctx.allocator.dupe(u8, p.code) catch p.code,
            .name = ctx.allocator.dupe(u8, p.name) catch p.name,
            .description = ctx.allocator.dupe(u8, p.description) catch p.description,
            .image = ctx.allocator.dupe(u8, p.image) catch p.image,
            .price_cents = p.price_cents,
            .original_price_cents = p.original_price_cents,
            .stock = p.stock,
            .category = ctx.allocator.dupe(u8, p.category) catch p.category,
        };
    }
    return dtos;
}

pub const MallBffApiDefault = MallBffApi(
    user_svc.UserService,
    compute_svc.ComputeService,
    usage_svc.UsageService,
    gift_svc.GiftAccessoryService,
);