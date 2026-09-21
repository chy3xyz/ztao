//! AI BFF 扩展（M3）：算力余额 + Agent 审批。

const std = @import("std");
const zigmodu = @import("zigmodu");
const http = zigmodu.http;
const mp_mw = @import("../../middleware/mp_auth.zig");

const user_svc = @import("../user/service.zig");
const usage_svc = @import("../usage/service.zig");
const approval_svc = @import("../approval/service.zig");

pub fn AiBffApi(comptime UserService: type, comptime UsageService: type,
    comptime ApprovalService: type) type {
    return struct {
        const S = @This();
        users: *UserService,
        usage: *UsageService,
        approvals: *ApprovalService,

        pub const module_name = "ai_bff";
        pub const nest: []const []const u8 = &.{};
        pub const State = S;

        pub const routes: []const http.RouteSpec(S) = &.{
            .{ .method = .GET, .path = "mp/usage/balance", .handler = http.wrapHandler(S, getBalance), .meta = .{ .auth = .jwt } },
            .{ .method = .GET, .path = "mp/approval/pending", .handler = http.wrapHandler(S, listPending), .meta = .{ .auth = .jwt } },
            .{ .method = .POST, .path = "mp/approval/{id}/decide", .handler = http.wrapHandler(S, decide), .meta = .{ .auth = .jwt } },
        };

        pub fn init(users: *UserService, usage: *UsageService, approvals: *ApprovalService) S {
            return .{ .users = users, .usage = usage, .approvals = approvals };
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

        fn getBalance(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx, self)) orelse return;
            defer user_row.free(self.users.store.allocator);

            const row = (try self.usage.getBalance(user_row.tenant_id)) orelse {
                // 首次访问默认给 50k token
                try self.usage.credit(user_row.tenant_id, 50000);
                try ctx.okValue(.{
                    .tenant_id = user_row.tenant_id,
                    .balance_tokens = 50000,
                    .period_end = std.time.timestamp() + 30 * 86400,
                    .plan_code = "free",
                });
                return;
            };
            defer row.free(self.usage.allocator);
            try ctx.okValue(.{
                .tenant_id = row.tenant_id,
                .balance_tokens = row.balance_tokens,
                .period_end = row.period_end,
                .plan_code = row.plan_code,
            });
        }

        fn listPending(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx, self)) orelse return;
            defer user_row.free(self.users.store.allocator);

            const result = self.approvals.listPending(user_row.tenant_id, user_row.id) catch {
                try ctx.sendErrorResponse(500, 500, "服务器错误");
                return;
            };
            defer result.free(self.approvals.allocator);

            const dtos = try ctx.allocator.alloc(struct {
                id: i64,
                run_id: i64,
                agent_id: i64,
                tool_name: []const u8,
                payload: []const u8,
                requested_at: i64,
            }, result.items.len);
            for (result.items, 0..) |a, i| {
                dtos[i] = .{
                    .id = a.id, .run_id = a.run_id, .agent_id = a.agent_id,
                    .tool_name = a.tool_name, .payload = a.payload,
                    .requested_at = a.requested_at,
                };
            }
            try ctx.okValue(.{ .list = dtos });
        }

        const DecideReq = struct {
            decision: []const u8,
            comment: ?[]const u8 = null,
        };

        fn decide(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx, self)) orelse return;
            defer user_row.free(self.users.store.allocator);

            const id = ctx.paramInt(i64, "id") catch {
                try ctx.sendErrorResponse(400, 400, "无效的审批 ID");
                return;
            };
            const req = ctx.bindJson(DecideReq) catch {
                try ctx.sendErrorResponse(400, 400, "请求体格式错误");
                return;
            };
            defer ctx.allocator.free(req.decision);
            const comment = req.comment orelse "";

            const ok = self.approvals.decide(user_row.tenant_id, id, req.decision, user_row.id, comment) catch |err| {
                const msg = switch (err) {
                    error.InvalidDecision => "decision 必须是 approved / rejected",
                    else => "服务器错误",
                };
                try ctx.sendErrorResponse(400, 400, msg);
                return;
            };
            if (!ok) {
                try ctx.sendErrorResponse(404, 404, "审批不存在");
                return;
            }
            try ctx.okValue(.{ .ok = true });
        }
    };
}

pub const AiBffApiDefault = AiBffApi(
    user_svc.UserService,
    usage_svc.UsageService,
    approval_svc.ApprovalService,
);