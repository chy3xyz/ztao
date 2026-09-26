//! 微信小程序 BFF 路由（/api/v1/mp/*）。
//!
//! M1 提供：
//!   POST /api/v1/mp/auth/login        微信登录 + 自动一人公司引导
//!   GET  /api/v1/mp/auth/qr           生成扫码登录 Web 的二维码
//!   POST /api/v1/mp/auth/scan-confirm 小程序确认扫码
//!   POST /api/v1/mp/auth/refresh      刷新 token
//!   POST /api/v1/mp/auth/logout       登出（前端清本地 token）
//!   GET  /api/v1/mp/me                当前用户画像
//!   POST /api/v1/mp/me/onboarding/next 推进引导状态
//!   POST /api/v1/mp/me/role           切换当前角色（PM/RD/QA/Sales）
//!   GET  /api/v1/mp/ai/agents         列出 5 个 Agent
//!   GET  /api/v1/mp/ai/agents/{id}    Agent 详情
//!   POST /api/v1/mp/ai/chat           发送消息（M1 不调真实 LLM）
//!   GET  /api/v1/mp/health            健康检查（public）
//!   GET  /api/v1/mp/meta              应用级元信息（public）

const std = @import("std");
const zigmodu = @import("zigmodu");
const http = zigmodu.http;
const mw = @import("../../middleware/auth.zig");
const mp_mw = @import("../../middleware/mp_auth.zig");

const user_svc = @import("../user/service.zig");
const tenant_svc = @import("../tenant/service.zig");
const workspace_svc = @import("../workspace/service.zig");
const agent_svc = @import("../agent/service.zig");
const identity_svc = @import("../fan_identity/service.zig");
const onboarding_svc = @import("../onboarding/service.zig");
const runtime_svc = @import("../../../services/agent_runtime.zig");
const llm = @import("../../../services/llm.zig");

fn unixNow() i64 {
    var ts: std.c.timespec = .{ .tv_sec = 0, .tv_nsec = 0 };
    _ = std.c.clock_gettime(.REALTIME, &ts);
    return @intCast(ts.tv_sec);
}

const Self = @This();

// ---------- DTOs ----------

const AgentDto = struct {
    id: i64,
    preset_code: []const u8,
    name: []const u8,
    avatar: []const u8,
    status: []const u8,
    model: []const u8,
};

const LoginRespDto = struct {
    token: []const u8,
    expires_at: i64,
    user: UserDto,
    tenant: TenantDto,
    workspace: WorkspaceDto,
    agents: []AgentDto,
    onboarding: OnboardingDto,
};

const UserDto = struct {
    id: i64,
    tenant_id: i64,
    workspace_id: i64,
    name: []const u8,
    avatar: []const u8,
    role: []const u8,
    plan: []const u8,
};

const TenantDto = struct {
    id: i64,
    name: []const u8,
    slug: []const u8,
    plan_code: []const u8,
};

const WorkspaceDto = struct {
    id: i64,
    tenant_id: i64,
    kind: []const u8,
    name: []const u8,
};

const OnboardingDto = struct {
    step: []const u8,
    completed_steps: []const []const u8,
};

const LoginReq = struct {
    code: []const u8,
    encryptedData: ?[]const u8 = null,
    iv: ?[]const u8 = null,
    nickname: ?[]const u8 = null,
    avatar: ?[]const u8 = null,
    appid: ?[]const u8 = null, // 默认走 server config
};

const ChatReq = struct {
    agent_id: i64,
    message: []const u8,
    context: ?[]const u8 = null,
};

const OnboardingNextReq = struct {
    step: []const u8,
};

const RoleReq = struct {
    role: []const u8,
};

// ---------- API ----------

pub fn MpApi(comptime UserService: type, comptime TenantService: type,
    comptime WorkspaceService: type, comptime AgentService: type,
    comptime IdentityService: type, comptime OnboardingService: type) type {
    return struct {
        const S = @This();
        users: *UserService,
        tenants: *TenantService,
        workspaces: *WorkspaceService,
        agents: *AgentService,
        identities: *IdentityService,
        onboarding: *OnboardingService,
        /// M3 注入的 AgentRuntime；为 nil 走纯 stub
        runtime: ?*runtime_svc.AgentRuntime,
        /// 微信小程序 appid；可被 ZTAO_MP_APPID 覆盖
        default_appid: []const u8,
        allocator: std.mem.Allocator,
        io: std.Io,

        pub const module_name = "mp";
        pub const nest: []const []const u8 = &.{};
        pub const State = S;

        pub const routes: []const http.RouteSpec(S) = &.{
            .{ .method = .POST, .path = "mp/auth/login", .handler = http.wrapHandler(S, login), .meta = .{ .auth = .public } },
            .{ .method = .GET, .path = "mp/auth/qr", .handler = http.wrapHandler(S, qr), .meta = .{ .auth = .public } },
            .{ .method = .POST, .path = "mp/auth/scan-confirm", .handler = http.wrapHandler(S, scanConfirm), .meta = .{ .auth = .jwt } },
            .{ .method = .POST, .path = "mp/auth/refresh", .handler = http.wrapHandler(S, refresh), .meta = .{ .auth = .jwt } },
            .{ .method = .POST, .path = "mp/auth/logout", .handler = http.wrapHandler(S, logout), .meta = .{ .auth = .jwt } },
            .{ .method = .GET, .path = "mp/me", .handler = http.wrapHandler(S, me), .meta = .{ .auth = .jwt } },
            .{ .method = .POST, .path = "mp/me/onboarding/next", .handler = http.wrapHandler(S, onboardingNext), .meta = .{ .auth = .jwt } },
            .{ .method = .POST, .path = "mp/me/role", .handler = http.wrapHandler(S, switchRole), .meta = .{ .auth = .jwt } },
            .{ .method = .GET, .path = "mp/ai/agents", .handler = http.wrapHandler(S, listAgents), .meta = .{ .auth = .jwt } },
            .{ .method = .GET, .path = "mp/ai/agents/{id}", .handler = http.wrapHandler(S, getAgent), .meta = .{ .auth = .jwt } },
            .{ .method = .POST, .path = "mp/ai/chat", .handler = http.wrapHandler(S, chatStub), .meta = .{ .auth = .jwt } },
            .{ .method = .GET, .path = "mp/health", .handler = http.wrapHandler(S, health), .meta = .{ .auth = .public } },
            .{ .method = .GET, .path = "mp/meta", .handler = http.wrapHandler(S, meta), .meta = .{ .auth = .public } },
        };

        pub fn init(
            users: *UserService,
            tenants: *TenantService,
            workspaces: *WorkspaceService,
            agents: *AgentService,
            identities: *IdentityService,
            onboarding: *OnboardingService,
            runtime: ?*runtime_svc.AgentRuntime,
            default_appid: []const u8,
            allocator: std.mem.Allocator,
            io: std.Io,
        ) S {
            return .{
                .users = users,
                .tenants = tenants,
                .workspaces = workspaces,
                .agents = agents,
                .identities = identities,
                .onboarding = onboarding,
                .runtime = runtime,
                .default_appid = default_appid,
                .allocator = allocator,
                .io = io,
            };
        }

        // ---------- Handlers ----------

        fn login(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const req = ctx.bindJson(LoginReq) catch {
                try ctx.sendErrorResponse(400, 400, "请求体格式错误");
                return;
            };
            defer ctx.allocator.free(req.code);

            if (req.code.len == 0) {
                try ctx.sendErrorResponse(10401, 400, "code 不能为空");
                return;
            }

            // 1. 调 jscode2session → openid
            const wx = callCode2Session(self, req.code) catch {
                try ctx.sendErrorResponse(40401, 502, "微信授权失败");
                return;
            };
            defer ctx.allocator.free(wx.openid);
            defer if (wx.unionid.len > 0) ctx.allocator.free(wx.unionid);

            const appid = req.appid orelse self.default_appid;

            // 2. 找 UserIdentity
            const appid_dup = try ctx.allocator.dupe(u8, appid);
            defer ctx.allocator.free(appid_dup);

            if ((try self.identities.findByOpenid("wechat-mp", appid_dup, wx.openid))) |identity_row| {
                defer identity_row.free(self.allocator);

                // 老用户：touch identity + 发新 token
                try self.identities.touch(identity_row.id);

                const user_row = (try self.users.getUserById(identity_row.user_id)) orelse {
                    try ctx.sendErrorResponse(10500, 500, "用户数据异常");
                    return;
                };
                defer user_row.free(self.users.store.allocator);

                const workspace_id = try self.workspaces.ensureSolo(user_row.tenant_id, user_row.id);
                const agents = try self.agents.clonePresetsToUser(user_row.tenant_id, user_row.id);
                const tokens = try buildLoginResponse(self, ctx, user_row, agents, workspace_id);
                try ctx.okValue(tokens);
                return;
            }

            // 3. 新用户：完整引导
            const bootstrap = try bootstrapOne(self, ctx, wx.openid, wx.unionid, appid_dup, req.nickname, req.avatar);
            try ctx.okValue(bootstrap);
        }

        fn qr(ctx: *http.Context) !void {
            // M1 stub：返回一个 fake token + URL，前端可扫
            // 真实实现需要 zent/QR + 缓存（key=token, value=状态）
            const token = try ctx.allocator.alloc(u8, 36);
            defer ctx.allocator.free(token);
            const charset = "0123456789abcdefghijklmnopqrstuvwxyz";
            var rng = std.Random.DefaultPrng.init(unixNow());
            for (token) |*c| c.* = charset[rng.random().intRangeAtMost(usize, 0, charset.len - 1)];
            try ctx.okValue(.{
                .qr_token = token,
                .expires_at = unixNow() + 300,
                .qr_url = "weixin://wxpay/bizpayurl?pr=ztao-stub",
            });
        }

        fn scanConfirm(ctx: *http.Context) !void {
            _ = ctx;
            try ctx.okValue(.{ .ok = true });
        }

        fn refresh(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            _ = self;
            try ctx.sendErrorResponse(30001, 401, "暂未实现，请重新登录");
        }

        fn logout(ctx: *http.Context) !void {
            try ctx.okValue(.{ .ok = true });
        }

        fn me(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const uid = mp_mw.mpUserId(ctx) orelse {
                try ctx.sendErrorResponse(401, 401, "未登录");
                return;
            };
            const user_row = (try self.users.getUserById(uid)) orelse {
                try ctx.sendErrorResponse(404, 404, "用户不存在");
                return;
            };
            defer user_row.free(self.users.store.allocator);

            const workspaces = try self.workspaces.listByTenant(user_row.tenant_id);
            defer {
                for (workspaces) |w| w.free(self.workspaces.allocator);
                self.workspaces.allocator.free(workspaces);
            }
            const workspace_id: i64 = if (workspaces.len > 0) workspaces[0].id else 0;

            const agents_arr = try self.agents.listByUser(user_row.tenant_id, user_row.id);
            defer {
                for (agents_arr) |a| a.free(self.agents.allocator);
                self.agents.allocator.free(agents_arr);
            }
            const agent_dtos = try agentsToDtos(ctx, agents_arr);

            const state = try self.onboarding.get(uid);
            defer state.free(self.onboarding.allocator);

            try ctx.okValue(.{
                .user = .{
                    .id = user_row.id,
                    .tenant_id = user_row.tenant_id,
                    .workspace_id = workspace_id,
                    .name = user_row.name,
                    .avatar = "",
                    .role = if (user_row.admin) "founder" else "user",
                    .plan = "free",
                },
                .plan = .{ .code = "free", .name = "Free", .seat_limit = 1, .ai_token_monthly = 50000 },
                .balance = .{
                    .tokens = 50000,
                    .tokens_used_this_month = 0,
                    .period_end = unixNow() + 30 * 86400,
                },
                .agents = agent_dtos,
                .onboarding = .{
                    .step = state.step,
                    .completed_steps = completedStepsFor(state.step),
                },
            });
        }

        fn onboardingNext(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const uid = mp_mw.mpUserId(ctx) orelse {
                try ctx.sendErrorResponse(401, 401, "未登录");
                return;
            };
            const req = ctx.bindJson(OnboardingNextReq) catch {
                try ctx.sendErrorResponse(400, 400, "请求体格式错误");
                return;
            };
            defer ctx.allocator.free(req.step);
            const next = self.onboarding.advance(uid, req.step) catch |err| {
                const msg = switch (err) {
                    error.InvalidStep => "步骤名无效",
                    error.StepRegress => "不能回退到上一步之前的步骤",
                    error.AlreadyDone => "引导已完成",
                    else => "服务器错误",
                };
                try ctx.sendErrorResponse(20402, 400, msg);
                return;
            };
            const next_str: ?[]const u8 = if (next) |s| @tagName(s) else null;
            try ctx.okValue(.{ .ok = true, .next_step = next_str });
        }

        fn switchRole(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const uid = mp_mw.mpUserId(ctx) orelse {
                try ctx.sendErrorResponse(401, 401, "未登录");
                return;
            };
            const req = ctx.bindJson(RoleReq) catch {
                try ctx.sendErrorResponse(400, 400, "请求体格式错误");
                return;
            };
            defer ctx.allocator.free(req.role);

            const activated = switch (req.role) {
                "pm" => [_]i64{ 1 },
                "rd" => [_]i64{ 2 },
                "qa" => [_]i64{ 3 },
                "sales" => [_]i64{ 4 },
                "ops" => [_]i64{ 5 },
                else => [_]i64{},
            };
            _ = self;
            _ = uid;
            try ctx.okValue(.{ .ok = true, .role = req.role, .activated_agents = &activated });
        }

        fn listAgents(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const uid = mp_mw.mpUserId(ctx) orelse {
                try ctx.sendErrorResponse(401, 401, "未登录");
                return;
            };
            const user_row = (try self.users.getUserById(uid)) orelse {
                try ctx.sendErrorResponse(404, 404, "用户不存在");
                return;
            };
            defer user_row.free(self.users.store.allocator);

            const agents_arr = try self.agents.listByUser(user_row.tenant_id, user_row.id);
            defer {
                for (agents_arr) |a| a.free(self.agents.allocator);
                self.agents.allocator.free(agents_arr);
            }
            const dtos = try agentsToDtos(ctx, agents_arr);
            try ctx.okValue(.{ .list = dtos });
        }

        fn getAgent(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const id = ctx.paramInt(i64, "id") catch {
                try ctx.sendErrorResponse(400, 400, "无效的 Agent ID");
                return;
            };
            const row = (try self.agents.get(id)) orelse {
                try ctx.sendErrorResponse(404, 404, "Agent 不存在");
                return;
            };
            defer row.free(self.agents.allocator);

            try ctx.okValue(.{
                .agent = .{
                    .id = row.id,
                    .preset_code = row.preset_code,
                    .name = row.name,
                    .avatar = row.avatar,
                    .status = row.status,
                    .model = row.model,
                    .system_prompt = "",
                    .tools = row.tools_override,
                    .scopes = row.scopes_override,
                    .memory_policy = row.memory_policy,
                    .max_daily_cost_cents = row.max_daily_cost_cents,
                },
                .stats = .{ .runs = 0, .tokens = 0, .cost_cents = 0, .last_run_at = null },
            });
        }

        fn chatStub(ctx: *http.Context) !void {
            // M3: 真实 Agent Runtime 占位。后续 SSE 模式在 chatStream 端点。
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const uid = mp_mw.mpUserId(ctx) orelse {
                try ctx.sendErrorResponse(401, 401, "未登录");
                return;
            };
            const user_row = (try self.users.getUserById(uid)) orelse {
                try ctx.sendErrorResponse(404, 404, "用户不存在");
                return;
            };
            defer user_row.free(self.users.store.allocator);

            const req = ctx.bindJson(ChatReq) catch {
                try ctx.sendErrorResponse(400, 400, "请求体格式错误");
                return;
            };
            defer ctx.allocator.free(req.message);

            // 没有 runtime 注入时退化为纯 stub
            if (self.runtime) |rt| {
                const history = &[_]llm.Message{};
                const outcome = rt.chat(user_row.tenant_id, user_row.id, req.agent_id, req.message, history) catch |err| {
                    const msg = switch (err) {
                        error.NoQuota => "算力不足，请购买 Token 包",
                        error.AgentNotFound => "Agent 不存在",
                        else => "服务暂时不可用",
                    };
                    try ctx.sendErrorResponse(20401, 503, msg);
                    return;
                };

                try ctx.okValue(.{
                    .session_id = 0,
                    .run_id = 0,
                    .stub_reply = outcome.reply,
                    .tokens_input = outcome.input_tokens,
                    .tokens_output = outcome.output_tokens,
                    .cost_cents = outcome.cost_cents,
                    .is_stub = false,
                });
                return;
            }

            // fallback: 无 runtime
            try ctx.okValue(.{
                .session_id = 0,
                .run_id = 0,
                .stub_reply = "(M3 占位 · 无 LLM runtime)" ++ " " ++ req.message,
                .tokens_input = 0,
                .tokens_output = 0,
                .cost_cents = 0,
                .is_stub = true,
            });
        }

        fn health(ctx: *http.Context) !void {
            try ctx.okValue(.{
                .ok = true,
                .version = "0.1.0",
                .build_at = "2026-09-20",
                .db = "postgres",
                .uptime_seconds = 0,
            });
        }

        fn meta(ctx: *http.Context) !void {
            try ctx.okValue(.{
                .app_name = "ztao",
                .tabs = [_][]const u8{ "workspace", "project", "mall", "me" },
                .subscribe_scenes = &[_]struct {
                    id: []const u8,
                    title: []const u8,
                    keywords: []const []const u8,
                }{
                    .{ .id = "task_assigned", .title = "任务分配通知", .keywords = &[_][]const u8{ "任务名", "项目名" } },
                    .{ .id = "ai_done", .title = "AI 任务完成", .keywords = &[_][]const u8{ "任务名", "耗时" } },
                    .{ .id = "quota_alert", .title = "Token 不足", .keywords = &[_][]const u8{ "余量", "推荐套餐" } },
                },
                .support_qq = "888-8888",
                .links = .{
                    .user_agreement = "https://ztao.cn/legal/user",
                    .privacy = "https://ztao.cn/legal/privacy",
                },
            });
        }

        // ---------- Bootstrap helper ----------

        fn bootstrapOne(
            self: *S,
            ctx: *http.Context,
            openid: []const u8,
            unionid: []const u8,
            appid: []const u8,
            nickname: ?[]const u8,
            avatar: ?[]const u8,
        ) !LoginRespDto {
            // 1. Tenant：保证至少存在一个默认 Tenant
            const tenant_id = try self.tenants.ensureDefault();
            // 2. User：邮箱用 "mp-{appid}-{openid_hash}@ztao.cn"
            const synthetic_email = try std.fmt.allocPrint(ctx.allocator, "mp+{s}+{s}@ztao.cn", .{ appid, openid });
            defer ctx.allocator.free(synthetic_email);
            const display_name = nickname orelse "Founder";
            // 用 user.register；但 password 是随机生成的（不会真用）
            const random_pw = try ctx.allocator.alloc(u8, 16);
            defer ctx.allocator.free(random_pw);
            const charset = "abcdefghijklmnopqrstuvwxyz0123456789";
            var rng = std.Random.DefaultPrng.init(unixNow());
            for (random_pw) |*c| c.* = charset[rng.random().intRangeAtMost(usize, 0, charset.len - 1)];

            const session = self.users.register(
                ctx.allocator,
                display_name,
                synthetic_email,
                random_pw,
                true, // 一人公司 = admin
                tenant_id,
            ) catch |err| switch (err) {
                error.EmailTaken => {
                    // 极小概率：邮箱已存在（openid 同邮箱前缀）—直接登录
                    return try self.loginByEmail(ctx, synthetic_email, random_pw);
                },
                else => return err,
            };
            // register 已 free session.row 但 token 是从 sec.allocator 来的；不要 free token
            defer self.users.freeSession(&session);

            // 3. Workspace
            const workspace_id = try self.workspaces.ensureSolo(tenant_id, session.row.id);

            // 4. Agents
            const agents = try self.agents.clonePresetsToUser(tenant_id, session.row.id);
            defer {
                for (agents) |a| a.free(self.agents.allocator);
                self.agents.allocator.free(agents);
            }

            // 5. Bind identity
            _ = try self.identities.bind(.{
                .user_id = session.row.id,
                .channel = "wechat-mp",
                .appid = appid,
                .openid = openid,
                .unionid = unionid,
                .encrypted_session_key = "",
            });

            // 6. 标记引导状态
            try self.onboarding.markFresh(session.row.id);

            // 7. 组装响应
            const agent_dtos = try agentsToDtos(ctx, agents);

            return .{
                .token = session.token,
                .expires_at = unixNow() + 7 * 86400,
                .user = .{
                    .id = session.row.id,
                    .tenant_id = tenant_id,
                    .workspace_id = workspace_id,
                    .name = display_name,
                    .avatar = avatar orelse "",
                    .role = "founder",
                    .plan = "free",
                },
                .tenant = .{
                    .id = tenant_id,
                    .name = "你的公司",
                    .slug = "default",
                    .plan_code = "free",
                },
                .workspace = .{
                    .id = workspace_id,
                    .tenant_id = tenant_id,
                    .kind = "solo",
                    .name = "默认 Workspace",
                },
                .agents = agent_dtos,
                .onboarding = .{
                    .step = "agents_ready",
                    .completed_steps = &[_][]const u8{ "login", "workspace", "agents_ready" },
                },
            };
        }

        fn loginByEmail(self: *S, ctx: *http.Context, email: []const u8, password: []const u8) !LoginRespDto {
            const session = (try self.users.login(ctx.allocator, email, password)) orelse {
                try ctx.sendErrorResponse(10500, 500, "用户数据异常");
                return error.Unexpected;
            };
            defer self.users.freeSession(&session);

            const workspace_id = try self.workspaces.ensureSolo(session.row.tenant_id, session.row.id);
            const agents = try self.agents.clonePresetsToUser(session.row.tenant_id, session.row.id);
            defer {
                for (agents) |a| a.free(self.agents.allocator);
                self.agents.allocator.free(agents);
            }
            const agent_dtos = try agentsToDtos(ctx, agents);

            return .{
                .token = session.token,
                .expires_at = unixNow() + 7 * 86400,
                .user = .{
                    .id = session.row.id,
                    .tenant_id = session.row.tenant_id,
                    .workspace_id = workspace_id,
                    .name = session.row.name,
                    .avatar = "",
                    .role = if (session.row.admin) "founder" else "user",
                    .plan = "free",
                },
                .tenant = .{
                    .id = session.row.tenant_id,
                    .name = "你的公司",
                    .slug = "default",
                    .plan_code = "free",
                },
                .workspace = .{
                    .id = workspace_id,
                    .tenant_id = session.row.tenant_id,
                    .kind = "solo",
                    .name = "默认 Workspace",
                },
                .agents = agent_dtos,
                .onboarding = .{
                    .step = "agents_ready",
                    .completed_steps = &[_][]const u8{ "login", "workspace", "agents_ready" },
                },
            };
        }

        fn buildLoginResponse(self: *S, ctx: *http.Context, user_row: anytype, agents: []const agent_svc.AgentInstanceRow, workspace_id: i64) !LoginRespDto {
            const tenant_row = (try self.tenants.get(user_row.tenant_id)) orelse {
                try ctx.sendErrorResponse(10500, 500, "租户数据异常");
                return error.Unexpected;
            };
            defer tenant_row.free(self.tenants.allocator);

            // 重新发 token（与 UserService.issueSession 走同一路径）
            const id_str = try std.fmt.allocPrint(ctx.allocator, "{d}", .{user_row.id});
            defer ctx.allocator.free(id_str);
            const tenant_str = try std.fmt.allocPrint(ctx.allocator, "{d}", .{user_row.tenant_id});
            defer ctx.allocator.free(tenant_str);
            const roles = if (user_row.admin) &[_][]const u8{"admin"} else &[_][]const u8{"user"};
            const token = try self.users.sec.module.generateTokenWithTenantAndVersion(id_str, roles, tenant_str, user_row.token_version);

            const agent_dtos = try agentsToDtos(ctx, agents);

            return .{
                .token = token,
                .expires_at = unixNow() + 7 * 86400,
                .user = .{
                    .id = user_row.id,
                    .tenant_id = user_row.tenant_id,
                    .workspace_id = workspace_id,
                    .name = user_row.name,
                    .avatar = "",
                    .role = if (user_row.admin) "founder" else "user",
                    .plan = "free",
                },
                .tenant = .{
                    .id = tenant_row.id,
                    .name = tenant_row.name,
                    .slug = tenant_row.name,
                    .plan_code = "free",
                },
                .workspace = .{
                    .id = workspace_id,
                    .tenant_id = user_row.tenant_id,
                    .kind = "solo",
                    .name = "默认 Workspace",
                },
                .agents = agent_dtos,
                .onboarding = .{
                    .step = "agents_ready",
                    .completed_steps = &[_][]const u8{ "login", "workspace", "agents_ready" },
                },
            };
        }
    };
}

// ---------- Helpers ----------

const WxCode2SessionResult = struct {
    openid: []const u8,
    unionid: []const u8,
};

/// M1 stub：实际应走 HTTPS GET https://api.weixin.qq.com/sns/jscode2session
fn callCode2Session(self: anytype, code: []const u8) !WxCode2SessionResult {
    _ = self;
    const openid = try std.fmt.allocPrint(std.heap.page_allocator, "stub_openid_{s}", .{code});
    const unionid = try std.fmt.allocPrint(std.heap.page_allocator, "stub_unionid_{s}", .{code});
    return .{ .openid = openid, .unionid = unionid };
}

fn agentsToDtos(ctx: *http.Context, agents: []const agent_svc.AgentInstanceRow) ![]AgentDto {
    const out = try ctx.allocator.alloc(AgentDto, agents.len);
    for (agents, 0..) |a, i| {
        out[i] = .{
            .id = a.id,
            .preset_code = try ctx.allocator.dupe(u8, a.preset_code),
            .name = try ctx.allocator.dupe(u8, a.name),
            .avatar = try ctx.allocator.dupe(u8, a.avatar),
            .status = try ctx.allocator.dupe(u8, a.status),
            .model = try ctx.allocator.dupe(u8, a.model),
        };
    }
    return out;
}

fn completedStepsFor(step: []const u8) []const []const u8 {
    if (std.mem.eql(u8, step, "login")) return &.{"login"};
    if (std.mem.eql(u8, step, "workspace")) return &.{ "login", "workspace" };
    if (std.mem.eql(u8, step, "agents_ready")) return &.{ "login", "workspace", "agents_ready" };
    if (std.mem.eql(u8, step, "first_chat")) return &.{ "login", "workspace", "agents_ready", "first_chat" };
    if (std.mem.eql(u8, step, "first_task")) return &.{ "login", "workspace", "agents_ready", "first_chat", "first_task" };
    if (std.mem.eql(u8, step, "done")) return &.{ "login", "workspace", "agents_ready", "first_chat", "first_task", "done" };
    return &.{};
}

// ---------- Convenience aliases ----------

pub const MpApiDefault = MpApi(
    user_svc.UserService,
    tenant_svc.TenantService,
    workspace_svc.WorkspaceService,
    agent_svc.AgentService,
    identity_svc.UserIdentityService,
    onboarding_svc.OnboardingService,
    ?*runtime_svc.AgentRuntime,
);