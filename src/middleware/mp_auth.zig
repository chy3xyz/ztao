//! 小程序鉴权中间件。
//!
//! 与 `auth.zig` 的 JWT 校验共用底层；本中间件专注"小程序 JWT"语义：
//!   - 解析 `Authorization: Bearer <jwt>`
//!   - 校验 JWT（含 `tid` claim）
//!   - 通过则把 `tid` / `uid` 注入 context（attr 名：`mp_tid` / `mp_uid`）
//!
//! 设计要点：
//!   - 与 Web JWT 共享 secret + claims 格式；前端只在小程序里发出 `mp_*` 命名空间
//!   - 不依赖 `tenantGuard` 等 admin-only 中间件
//!
//! M1 实现注释：本文件为规划骨架，TODO 列表见文件尾。

const std = @import("std");
const zigmodu = @import("zigmodu");
const http = zigmodu.http;

const Self = @This();
const Context = http.Context;
const AuthUser = @import("auth.zig");

/// 小程序 JWT 校验：通过 `requireMpFan` 中间件把 tid/uw/email 注入 context。
/// 失败的请求一律 401。
pub const MpFanAuth = struct {
    auth: *AuthUser,

    pub fn init(auth: *AuthUser) MpFanAuth {
        return .{ .auth = auth };
    }

    /// 进入路由前调用；通过则 ctx 携带 `mp_uid` / `mp_tid` / `mp_role` 属性。
    pub fn middleware(self: *MpFanAuth, ctx: *Context, next: *const fn (ctx: *Context) anyerror!void) !void {
        const auth_header = ctx.request.headers.getFirstValue("Authorization") orelse {
            try ctx.sendErrorResponse(401, 401, "缺少 Authorization");
            return;
        };
        if (!std.mem.startsWith(u8, auth_header, "Bearer ")) {
            try ctx.sendErrorResponse(401, 401, "Authorization 格式错误");
            return;
        }
        const token = auth_header["Bearer ".len..];

        const claims = self.auth.verify(token) catch {
            try ctx.sendErrorResponse(401, 401, "登录已过期，请重新登录");
            return;
        };

        try ctx.setAttr("mp_uid", claims.user_id);
        try ctx.setAttr("mp_tid", claims.tenant_id);
        try ctx.setAttr("mp_role", claims.role);

        try next(ctx);
    }
};

// ---------- 公共辅助 ----------

/// 从 ctx 拿 `mp_uid`；鉴权失败的请求不该走到这一步。
pub fn mpUserId(ctx: *Context) ?i64 {
    return ctx.getAttrInt("mp_uid");
}

pub fn mpTenantId(ctx: *Context) ?i64 {
    return ctx.getAttrInt("mp_tid");
}

pub fn mpRole(ctx: *Context) ?[]const u8 {
    return ctx.getAttr("mp_role");
}

// ---------- TODO（M1 实施清单）----------
//
// - 关联 `AuthUser.verify` 的真实签名
// - 与 `modules/user/service.zig` 的 `token_version` 校验
// - 失败时是否回 401 还是 498（业务无 token）
// - refresh 端点 / 自动刷新
// - rate-limit：单 user_id 每秒最多 50 次
//